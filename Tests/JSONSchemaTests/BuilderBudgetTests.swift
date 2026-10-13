// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func schemaBuilderSharesConstructionAndDocumentAdmissionWork() throws {
    var limits = JSONLimits.balanced
    limits[.workUnits] = 150
    // Each phase scans these 100 payload bytes; neither may restart the quota.
    let payload = String(repeating: "x", count: 100)
    var document: JSONSchemaDocument?
    var failure: JSONFailure?
    do {
        document = try JSONSchemaBuilder.object(limits: limits) { builder in
            try builder.append("description", value: .string(payload))
        }
    } catch let error as JSONFailure { failure = error }
    #expect(document == nil)
    #expect(failure?.code == .limitExceeded)
    #expect(failure?.resource?.metric == .workUnits)
    #expect(failure?.resource?.domain == .schemaCompilation)
}

@Test func schemaBuilderSharesSchemaDomainWorkAtInclusiveBoundary() throws {
    // The fixed one-member vector charges 238 primitive units across both phases.
    for metric: JSONResourceMetric in [.workUnits, .compileWorkUnits] {
        var limits = JSONLimits.balanced
        limits[metric] = 238
        let accepted = try JSONSchemaBuilder.object(limits: limits) { builder in
            try builder.append("description", value: .string(String(repeating: "x", count: 100)))
        }
        #expect(accepted.raw.objectValue?.count == 1)
        limits[metric] = 237
        do {
            _ = try JSONSchemaBuilder.object(limits: limits) { builder in
                try builder.append("description", value: .string(String(repeating: "x", count: 100)))
            }
            Issue.record("The next work unit must fail before returning a document")
        } catch let error as JSONFailure {
            #expect(error.resource?.metric == metric)
            #expect(error.resource?.attemptedUsage == 238)
            #expect(error.resource?.domain == .schemaCompilation)
        }
    }
}

@Test func schemaBuilderKeepsConstructedObjectLiveDuringAdmission() throws {
    // 231 logical bytes of object/key/value/index state overlap the 16-byte frame.
    for metric: JSONResourceMetric in [.retainedBytes, .compiledPlanBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = 247
        let accepted = try JSONSchemaBuilder.object(limits: limits) { builder in
            try builder.append("description", value: .string(String(repeating: "x", count: 100)))
        }
        #expect(accepted.raw.objectValue?.count == 1)
        limits[metric] = 246
        do {
            _ = try JSONSchemaBuilder.object(limits: limits) { builder in
                try builder.append("description", value: .string(String(repeating: "x", count: 100)))
            }
            Issue.record("Live object state must overlap document admission scratch")
        } catch let error as JSONFailure {
            #expect(error.resource?.metric == metric)
            #expect(error.resource?.attemptedUsage == 247)
        }
    }
}

@Test func schemaBuilderDoesNotRestartAggregateAdmissionCounters() throws {
    for (metric, boundary): (JSONResourceMetric, UInt64) in [(.nodes, 4), (.schemaNodes, 4), (.aggregateTextBytes, 222)] {
        var limits = JSONLimits.balanced
        limits[metric] = boundary
        let document = try JSONSchemaBuilder.object(limits: limits) { builder in
            try builder.append("description", value: .string(String(repeating: "x", count: 100)))
        }
        #expect(document.raw.objectValue?.count == 1)
        limits[metric] = boundary - 1
        do {
            _ = try JSONSchemaBuilder.object(limits: limits) { builder in
                try builder.append("description", value: .string(String(repeating: "x", count: 100)))
            }
            Issue.record("Aggregate admission must remain cumulative")
        } catch let error as JSONFailure { #expect(error.resource?.metric == metric) }
    }
}

@Test func schemaBuilderCaughtOwnedFailureRemainsTerminal() throws {
    var limits = JSONLimits.balanced
    limits[.stringBytes] = 1
    var caught: JSONFailure?
    do {
        _ = try JSONSchemaBuilder.object(limits: limits) { builder in
            do { try builder.append("description", value: "xx") }
            catch let error as JSONFailure { caught = error }
        }
        Issue.record("Catching an owned quota error cannot return an empty schema")
    } catch let error as JSONFailure {
        #expect(error == caught)
        #expect(error.resource?.metric == .stringBytes)
    }
    #expect(caught != nil)
}

@Test func schemaBuilderCaughtCancellationRemainsTerminal() async throws {
    let task = Task {
        do {
            _ = try JSONSchemaBuilder.object { builder in
                try builder.append("type", value: "integer")
                withUnsafeCurrentTask { $0?.cancel() }
                do { try builder.append("description", value: "later") }
                catch is CancellationError { }
            }
            return false
        } catch is CancellationError { return true }
    }
    #expect(try await task.value)
}

private enum SchemaBuilderCallerFailure: Error, Equatable { case stopped }
@Test func schemaBuilderPreservesCallerErrorsAndDuplicateChecks() throws {
    #expect(throws: SchemaBuilderCallerFailure.stopped) {
        try JSONSchemaBuilder.object { _ in throw SchemaBuilderCallerFailure.stopped }
    }
    #expect(throws: JSONFailure(.syntax, code: .duplicateKey)) {
        try JSONSchemaBuilder.object { builder in
            try builder.append("type", value: "integer")
            try builder.append("type", value: "string")
        }
    }
}

@Test func schemaBuilderPreservesExactOrderedDeclarationsAndSeparateCompilation() throws {
    let number = try JSONNumber(parsing: "9007199254740993")
    let metadata = try JSONObject(members: [JSONMember("é", value: 1), JSONMember("e\u{301}", value: 2)])
    let document = try JSONSchemaBuilder.object { builder in
        try builder.append("type", value: "integer")
        try builder.append("minimum", value: .number(number))
        try builder.append("unknown", value: .object(metadata))
    }
    let object = try #require(document.raw.objectValue)
    #expect(object.map { $0.key.string } == ["type", "minimum", "unknown"])
    #expect(object["minimum"]?.numberValue == number)
    #expect(object["unknown"]?.objectValue?.count == 2)
    let plan = try JSONSchemaCompiler().compile(document)
    #expect(try JSONSchemaValidator().validate(.number(number), against: plan).isValid)
    #expect(try !JSONSchemaValidator().validate(0, against: plan).isValid)
}

@Test func schemaBuilderRejectsCallbackReplacementOfItsLedger() throws {
    #expect(throws: JSONFailure(.configuration, code: .invalidOperation)) {
        try JSONSchemaBuilder.object { builder in
            builder = try JSONObjectAccumulator()
            try builder.append("type", value: "integer")
        }
    }
    // Matching operation domains alone cannot detect swapping nested invocations.
    #expect(throws: JSONFailure(.configuration, code: .invalidOperation)) {
        try JSONSchemaBuilder.object { outer in
            _ = try JSONSchemaBuilder.object { inner in swap(&outer, &inner) }
        }
    }
    var limits = JSONLimits.balanced
    limits[.stringBytes] = 1
    do {
        _ = try JSONSchemaBuilder.object(limits: limits) { builder in
            do { try builder.append("description", value: "xx") }
            catch is JSONFailure { builder = try JSONObjectAccumulator() }
        }
        Issue.record("Replacing a failed accumulator cannot clear its terminal error")
    } catch let error as JSONFailure { #expect(error.resource?.metric == .stringBytes) }
}
