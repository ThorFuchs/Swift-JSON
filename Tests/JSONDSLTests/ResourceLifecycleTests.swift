import JSON
import JSONDSLCore
import JSONSchema
import JSONSchemaDSL
import JSONValueDSL
import Synchronization
// SPDX-License-Identifier: Apache-2.0
import Testing

@Test func dslV18ParentNodeCapacityIncludesAllNestedChildren() throws {
    var limits = JSONLimits.balanced
    limits[.nodes] = 4
    let accepted = try JSONValueDSL.object(limits: limits) {
        Field.array("a") {
            Element(1)
            Element(2)
        }
    }
    #expect(accepted == (try JSONParser().parse(#"{"a":[1,2]}"#)))
    limits[.nodes] = 3
    do {
        _ = try JSONValueDSL.object(limits: limits) {
            Field.array("a") {
                Element(1)
                Element(2)
            }
        }
        Issue.record("Parent quota must include nested children")
    } catch let error as JSONFailure {
        #expect(error.category == .resource && error.code == .limitExceeded)
        #expect(error.resource?.metric == .nodes && error.resource?.attemptedUsage == 4)
    }
}

@Test func dslFinalizationSharesWorkAndRetentionAcrossSiblings() throws {
    let node = JSONDSLNode.object([
        .init("one", .array([.literal(1), .literal(2)])),
        .init("two", .object([.init("text", .literal("é"))])),
    ])
    let stats = try node.finalize(limits: .balanced, domain: .core) { _, meter in meter.statistics() }
    #expect(stats[.nodes] == 6 && stats[.workUnits] > 10 && stats.peakLogicalRetainedBytes > 0)
    var limits = JSONLimits.balanced
    limits[.workUnits] = stats[.workUnits]
    _ = try node.materialize(limits: limits)
    limits[.workUnits] -= 1
    do {
        _ = try node.materialize(limits: limits)
        Issue.record("Work must not reset at siblings")
    } catch let error as JSONFailure {
        #expect(error.resource?.metric == .workUnits && error.code == .limitExceeded)
    }
    limits = .balanced
    limits[.retainedBytes] = stats.peakLogicalRetainedBytes
    _ = try node.materialize(limits: limits)
    limits[.retainedBytes] -= 1
    do {
        _ = try node.materialize(limits: limits)
        Issue.record("Overlapping finalization ownership must be charged")
    } catch let error as JSONFailure {
        #expect(error.resource?.metric == .retainedBytes && error.code == .limitExceeded)
    }
}

@Test func dslSchemaDocumentAdmissionContinuesTheSameLedger() throws {
    let node = JSONDSLNode.object([.init("title", .literal("x"))])
    let stats = try node.finalize(limits: .balanced, domain: .schemaCompilation) { raw, meter in
        _ = try JSONSchemaDocument(raw, meter: &meter)
        return meter.statistics()
    }
    #expect(stats.domain == .schemaCompilation && stats[.nodes] == 4 && stats[.schemaNodes] == 4)
    var limits = JSONLimits.balanced
    limits[.nodes] = 4
    _ = try JSONSchemaDSL.document(limits: limits) { Schema.title("x") }
    limits[.nodes] = 3
    do {
        _ = try JSONSchemaDSL.document(limits: limits) { Schema.title("x") }
        Issue.record("Document admission must not start a fresh meter")
    } catch let error as JSONFailure {
        #expect(error.resource?.domain == .schemaCompilation && error.resource?.metric == .nodes)
        #expect(error.resource?.attemptedUsage == 4)
    }
}

@Test func dslLiteralPayloadAdmissionCannotBypassCoreCaps() throws {
    let payloads: [(JSON, JSONResourceMetric, UInt64)] = [
        (.array([1, 2]), .arrayItems, 1),
        (.object(try JSONObject(members: [.init("long", value: 1)])), .keyBytes, 3),
        (.string("é"), .stringBytes, 1),
        (.number(try JSONNumber(parsing: "1234")), .numberDigits, 3),
        (.number(try JSONNumber(parsing: "1e9")), .absoluteExponent, 8),
    ]
    for (payload, metric, cap) in payloads {
        var limits = JSONLimits.balanced
        limits[metric] = cap
        do {
            _ = try JSONValueDSL.array(limits: limits) { Element(payload) }
            Issue.record("Literal payload must be admitted")
        } catch let error as JSONFailure {
            #expect(error.code == .limitExceeded && error.resource?.metric == metric)
        }
    }
}

@Test func dslFinalizationFailureIsTerminalEvenWhenPackageContinuationCatchesIt() throws {
    var observed = false
    do {
        _ = try JSONDSLNode.literal(.null).finalize(limits: .balanced, domain: .core) { value, meter in
            do { try meter.work(UInt64.max) } catch let error as JSONFailure {
                observed = true
                #expect(error.code == .counterOverflow)
            }
            return value
        }
        Issue.record("Caught finalization failure must prevent publication")
    } catch let error as JSONFailure { #expect(observed && error.code == .counterOverflow) }
}

@Test func dslFlatIRRejectsFiveThousandLevelsWithoutRecursiveLoweringOrIRTeardown() throws {
    var node = JSONDSLNode.literal(.null)
    for _ in 0..<5_000 { node = .array([node]) }
    var limits = JSONLimits.balanced
    limits[.maxDepth] = 64
    do {
        _ = try node.materialize(limits: limits)
        Issue.record("Deep staging must fail the finalization ceiling")
    } catch let error as JSONFailure {
        #expect(error.resource?.metric == .maxDepth && error.resource?.attemptedUsage == 65)
    }
    var admitted = JSONDSLNode.literal(.null)
    for _ in 0..<128 { admitted = .array([admitted]) }
    let exact = try admitted.materialize()
    #expect(
        try JSONWriter().writeString(exact) == String(repeating: "[", count: 128) + "null"
            + String(repeating: "]", count: 128))
}

@Test func dslV19CancellationAtEntryDoesNotRunAuthoredCallback() async throws {
    let started = Mutex(false)
    let gate = AsyncStream<Void>.makeStream()
    let task = Task {
        for await _ in gate.stream { break }
        return try JSONValueDSL.object {
            Field(
                "visited",
                started.withLock { state -> Bool in
                    state = true
                    return true
                })
        }
    }
    task.cancel()
    gate.continuation.yield(())
    gate.continuation.finish()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(started.withLock { !$0 })
}

@Test func dslV19CancellationInsideOwnedFinalizationNeverReturnsAValue() async throws {
    let cancelled = Mutex(false)
    let handle = Mutex<Task<JSON, any Error>?>(nil)
    let gate = AsyncStream<Void>.makeStream()
    let node = JSONDSLNode.array((0..<4_096).map { .literal(.number(JSONNumber(integer: $0))) })
    let task = Task {
        for await _ in gate.stream { break }
        var limits = JSONLimits.balanced
        limits[.cancellationQuantum] = 1
        return try node.finalize(
            limits: limits, domain: .core,
            checkpointObserver: { work in
                if work >= 64 {
                    cancelled.withLock { $0 = true }
                    handle.withLock { $0?.cancel() }
                }
            }
        ) { value, _ in value }
    }
    handle.withLock { $0 = task }
    gate.continuation.yield(())
    gate.continuation.finish()
    await #expect(throws: CancellationError.self) { try await task.value }
    #expect(cancelled.withLock { $0 })
    handle.withLock { $0 = nil }
}

@Test func dslSharedFinalizationAndPlansAreInvocationOwned() async throws {
    let declaration = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties {
            Property("id") {
                Schema.type(.integer)
                Schema.minimum(JSONNumber(integer: 1))
            }
        }
        Schema.required("id")
    }
    let plan = try JSONSchemaCompiler().compile(declaration)
    let field = Field("id", UInt64(9_007_199_254_740_993))
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for index in 0..<32 {
            group.addTask {
                var limits = JSONLimits.balanced
                if index.isMultiple(of: 2) {
                    limits[.nodes] = 1
                    do {
                        _ = try JSONValueDSL.object(limits: limits) { field }
                        return false
                    } catch let error as JSONFailure { return error.resource?.metric == .nodes }
                }
                let value = try JSONValueDSL.object { field }
                return try JSONSchemaValidator().validate(value, against: plan).isValid
            }
        }
        var completed = 0
        for try await outcome in group {
            #expect(outcome)
            completed += 1
        }
        #expect(completed == 32)
    }
}
