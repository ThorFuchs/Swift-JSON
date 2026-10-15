// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import Testing

private func providerSchema(_ source: String = ##"{"type":"object","properties":{"value":{"type":"integer"}},"required":["value"],"additionalProperties":false}"##) throws -> JSONSchemaDocument {
    try JSONSchemaDocument(JSONParser().parse(source))
}
private let formatBridge = OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1)

@Test func providerResponsesEnvelopesAndAllNativeTextDataReportsAgree() throws {
    let schema = try providerSchema(), tool = OpenAIJSONSchemaBridge(profile: .openAIResponsesFunctionV1)
    let format = try formatBridge.responseFormatWithReport(schema, name: "summary", description: "Exact 🦊")
    let function = try tool.functionToolWithReport(schema, name: "summary", description: "Exact 🦊")
    #expect(try JSONPointer(parsing: "/schema").resolve(in: format.result) == schema.raw)
    #expect(try JSONPointer(parsing: "/parameters").resolve(in: function.result) == schema.raw)
    #expect(format.result.objectValue?[JSONKey("type")] == .string("json_schema"))
    #expect(function.result.objectValue?[JSONKey("type")] == .string("function"))
    #expect(function.result.objectValue?[JSONKey("function")] == nil)
    #expect(format.result.objectValue?[JSONKey("text")] == nil)
    #expect(format.result.objectValue?[JSONKey("strict")] == .boolean(true))
    for isTool in [false, true] {
        let bridge = isTool ? tool : formatBridge
        let value = try isTool ? bridge.functionTool(schema, name: "summary", description: "Exact 🦊") : bridge.responseFormat(schema, name: "summary", description: "Exact 🦊")
        let data = try isTool ? bridge.functionToolData(schema, name: "summary", description: "Exact 🦊") : bridge.responseFormatData(schema, name: "summary", description: "Exact 🦊")
        let text = try isTool ? bridge.functionToolString(schema, name: "summary", description: "Exact 🦊") : bridge.responseFormatString(schema, name: "summary", description: "Exact 🦊")
        let dr = try isTool ? bridge.functionToolDataWithReport(schema, name: "summary", description: "Exact 🦊") : bridge.responseFormatDataWithReport(schema, name: "summary", description: "Exact 🦊")
        let sr = try isTool ? bridge.functionToolStringWithReport(schema, name: "summary", description: "Exact 🦊") : bridge.responseFormatStringWithReport(schema, name: "summary", description: "Exact 🦊")
        #expect(try JSONParser().parse(data) == value)
        #expect(try JSONParser().parse(text) == value)
        #expect(dr.result == data && sr.result == text)
        #expect(dr.statistics[.workUnits] > format.statistics[.workUnits])
        #expect(dr.statistics[.outputBytes] == UInt64(data.count))
    }
}
@Test func providerOptionalityNullabilityClosureAndRootRemainDistinct() throws {
    let optional = try providerSchema(##"{"type":"object","properties":{"value":{"type":"integer"}},"additionalProperties":false}"##)
    let raw = optional.raw
    let check = try formatBridge.checkWithReport(optional)
    #expect(!check.result.isCompatible && check.result.issues.contains { $0.code == .allPropertiesRequired })
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try formatBridge.responseFormat(optional, name: "summary") }
    #expect(optional.raw == raw)
    let nullable = try providerSchema(##"{"type":"object","properties":{"value":{"type":["integer","null"]}},"required":["value"],"additionalProperties":false}"##)
    #expect(try formatBridge.check(nullable).isCompatible)
    let open = try providerSchema(##"{"type":"object","properties":{},"required":[]}"##)
    #expect(try formatBridge.check(open).issues.contains { $0.code == .closedObjectRequired })
    #expect(try !formatBridge.check(providerSchema("true")).isCompatible)
    #expect(try !formatBridge.check(providerSchema(##"{"type":"string"}"##)).isCompatible)
    #expect(check.statistics[.compileWorkUnits] > 0)
}
@Test func providerUnknownDeclarationsAndTypedNumericKeyUnionPathsAreHonest() throws {
    let schema = try providerSchema(##"{"type":"object","properties":{"0":{"anyOf":[{"type":"string"},{"type":"integer","x-local":1}]}},"required":["0"],"additionalProperties":false}"##)
    let report = try formatBridge.check(schema)
    let issue = try #require(report.issues.first { $0.code == .unverifiedDeclaration })
    #expect(issue.unverified)
    #expect(issue.path == [.key(JSONKey("properties")), .key(JSONKey("0")), .key(JSONKey("anyOf")), .index(1), .key(JSONKey("x-local"))])
    let invalid = try providerSchema(##"{"type":"object","properties":{},"required":[],"additionalProperties":false,"allOf":[{"type":"object"}]}"##)
    #expect(try formatBridge.check(invalid).issues.contains { $0.code == .unsupportedKeyword })
}
@Test func providerExactNumbersScalarKeysAndDeclarationOrderSurviveOutput() throws {
    let source = ##"{"type":"object","properties":{"é":{"type":"integer","minimum":9007199254740993},"é":{"type":"number","maximum":1.2300e+2}},"required":["é","é"],"additionalProperties":false}"##
    let schema = try providerSchema(source)
    let encoded = try formatBridge.responseFormatString(schema, name: "exact")
    #expect(encoded.contains("9007199254740993") && encoded.contains("1.2300e+2"))
    let roundTrip = try JSONPointer(parsing: "/schema").resolve(in: JSONParser().parse(encoded))
    #expect(roundTrip == schema.raw)
    let original = try #require(schema.raw.objectValue?[JSONKey("properties")]?.objectValue)
    let retained = try #require(roundTrip.objectValue?[JSONKey("properties")]?.objectValue)
    #expect(Array(original).map(\.key) == Array(retained).map(\.key))
    #expect(retained.count == 2)
}
@Test func providerLocalDefinitionsAndProductiveRecursionAreNotUnrolled() throws {
    let recursive = try providerSchema(##"{"type":"object","properties":{"next":{"anyOf":[{"$ref":"#"},{"type":"null"}]}},"required":["next"],"additionalProperties":false}"##)
    #expect(try formatBridge.check(recursive).isCompatible)
    let definitions = try providerSchema(##"{"type":"object","properties":{"value":{"$ref":"#/$defs/value"}},"required":["value"],"additionalProperties":false,"$defs":{"value":{"type":"integer"}}}"##)
    #expect(try formatBridge.check(definitions).isCompatible)
    let cycle = try providerSchema(##"{"type":"object","properties":{"value":{"$ref":"#/$defs/value"}},"required":["value"],"additionalProperties":false,"$defs":{"value":{"$ref":"#/$defs/value"}}}"##)
    #expect(try formatBridge.check(cycle).issues.contains { $0.code == .nonProductiveReference })
    let epsilon = try providerSchema(##"{"type":"object","properties":{"value":{"$ref":"#/$defs/value"}},"required":["value"],"additionalProperties":false,"$defs":{"value":{"anyOf":[{"$ref":"#/$defs/value"}]}}}"##)
    #expect(try formatBridge.check(epsilon).issues.contains { $0.code == .nonProductiveReference })

    var chainDefinitions: [String] = []
    for index in 0..<12 {
        let next = index == 11 ? "{\"type\":\"null\"}" : "{\"$ref\":\"#/$defs/n" + String(index + 1) + "\"}"
        chainDefinitions.append("\"n" + String(index) + "\":{\"type\":\"object\",\"properties\":{\"next\":" + next + "},\"required\":[\"next\"],\"additionalProperties\":false}")
    }
    let deep = try providerSchema("{\"type\":\"object\",\"properties\":{\"next\":{\"$ref\":\"#/$defs/n0\"}},\"required\":[\"next\"],\"additionalProperties\":false,\"$defs\":{" + chainDefinitions.joined(separator: ",") + "}}")
    #expect(try formatBridge.check(deep).issues.contains { $0.code == .profileCapacity })

}
@Test func providerExternalRegistryResolutionIsOperationalBeforeExportCompatibility() throws {
    let schema = try providerSchema(##"{"type":"object","properties":{"value":{"$ref":"https://example.invalid/value"}},"required":["value"],"additionalProperties":false}"##)
    #expect(throws: JSONSchemaCompilationFailure.self) { _ = try formatBridge.check(schema) }
    let uri = try JSONSchemaURI("https://example.invalid/value")
    let external = try JSONSchemaDocument(JSONParser().parse(##"{"type":"integer"}"##), retrievalURI: uri)
    let registry = try JSONSchemaRegistry(documents: [external])
    let result = try formatBridge.check(schema, registry: registry)
    #expect(!result.isCompatible && result.issues.contains { $0.code == .externalReference })
    let relativeRaw = try JSONParser().parse(##"{"type":"object","properties":{"value":{"$ref":"value"}},"required":["value"],"additionalProperties":false}"##)
    let relative = try JSONSchemaDocument(relativeRaw, retrievalURI: JSONSchemaURI("https://example.invalid/root"))
    #expect(try formatBridge.check(relative, registry: registry).issues.contains { $0.code == .externalReference })
    do { _ = try formatBridge.responseFormat(relative, name: "x", registry: registry); Issue.record("Resolved external references are not exportable") }
    catch JSONSchemaProviderFailure.incompatible(let report) { #expect(report.issues.contains { $0.code == .externalReference }) }

}
@Test func providerFrozenCeilingsAndConservativeUtf8RulesHaveRealBoundaries() throws {
    let enumItems = (0...1_000).map(String.init).joined(separator: ",")
    let schema = try providerSchema("{\"type\":\"object\",\"properties\":{\"value\":{\"type\":\"integer\",\"enum\":[" + enumItems + "]}},\"required\":[\"value\"],\"additionalProperties\":false}")
    #expect(try formatBridge.check(schema).issues.contains { $0.code == .profileCapacity })
    let first = String(repeating: "🦊", count: 15_000)
    func namedSchema(_ second: String) throws -> JSONSchemaDocument {
        try providerSchema("{\"type\":\"object\",\"properties\":{\"" + first + "\":{\"type\":\"string\"},\"" + second + "\":{\"type\":\"string\"}},\"required\":[\"" + first + "\",\"" + second + "\"],\"additionalProperties\":false}")
    }
    var textLimits = JSONSchemaProviderLimits.offline
    textLimits.json[.pointerBytes] = 1_048_576
    let utf8 = OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: textLimits)
    #expect(try utf8.check(namedSchema(String(repeating: "a", count: 60_000))).isCompatible)
    #expect(try utf8.check(namedSchema(String(repeating: "a", count: 60_001))).issues.contains { $0.code == .profileCapacity })
    let format = try providerSchema(##"{"type":"object","properties":{"value":{"type":"string","format":"uri"}},"required":["value"],"additionalProperties":false}"##)
    #expect(try formatBridge.check(format).issues.contains { $0.code == .unsupportedFormat })
    let unsupportedLength = try providerSchema(##"{"type":"object","properties":{"value":{"type":"string","minLength":1}},"required":["value"],"additionalProperties":false}"##)
    #expect(try formatBridge.check(unsupportedLength).issues.contains { $0.unverified })
}
@Test func providerFiniteCapacitiesTruncationAndInvalidConfigurationsRemainErrors() throws {
    let schema = try providerSchema()
    for metric in [JSONSchemaProviderMetric.schemaNodes, .referenceEdges, .declarations, .metadataBytes] {
        var limits = JSONSchemaProviderLimits()
        switch metric { case .schemaNodes: limits.schemaNodes = 0; case .referenceEdges: limits.referenceEdges = 0; case .declarations: limits.declarations = 0; case .metadataBytes: limits.metadataBytes = 0 }
        #expect(throws: JSONSchemaProviderFailure.self) { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits).responseFormat(schema, name: "x") }
    }
    let measured = try formatBridge.checkWithReport(schema)
    for metric in [JSONSchemaProviderMetric.schemaNodes, .referenceEdges, .declarations] {
        var limits = JSONSchemaProviderLimits()
        let used: UInt64
        switch metric {
        case .schemaNodes: used = measured.result.checkedSchemaNodes; limits.schemaNodes = used
        case .referenceEdges: used = measured.result.checkedReferenceEdges; limits.referenceEdges = used
        case .declarations: used = measured.result.checkedDeclarations; limits.declarations = used
        case .metadataBytes: used = 0
        }
        #expect(used > 0)
        #expect(try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits).check(schema).isCompatible)
        switch metric { case .schemaNodes: limits.schemaNodes -= 1; case .referenceEdges: limits.referenceEdges -= 1; case .declarations: limits.declarations -= 1; case .metadataBytes: break }
        #expect(throws: JSONSchemaProviderFailure.self) { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits).check(schema) }
    }
    var wide = JSONSchemaProviderLimits(); wide.schemaNodes = UInt64(1) << 40; wide.referenceEdges = UInt64(1) << 40; wide.declarations = UInt64(1) << 40; wide.metadataBytes = UInt64(1) << 40
    #expect(try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: wide).check(schema).isCompatible)
    var invalid = JSONSchemaProviderLimits(); invalid.schemaNodes = UInt64.max
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: invalid).check(schema) }
    var limits = JSONSchemaProviderLimits(); limits.json[.issues] = 0
    let bridge = OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits)
    let unsupported = try providerSchema(##"{"type":"object","properties":{"value":{"type":"integer"}},"additionalProperties":true}"##)
    let result = try bridge.check(unsupported)
    #expect(!result.isCompatible && result.issues.isEmpty && result.truncated)
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try bridge.responseFormat(unsupported, name: "x") }
}
@Test func providerCompoundWorkAndMetadataBoundariesAreInclusiveWithoutHelperResets() throws {
    let schema = try providerSchema(), name = String(repeating: "n", count: 64)
    #expect(try formatBridge.responseFormat(schema, name: name).objectValue != nil)
    for bad in ["", name + "n", "with space", "é"] {
        #expect(throws: JSONSchemaProviderFailure.self) { _ = try formatBridge.responseFormat(schema, name: bad) }
    }
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try formatBridge.functionTool(schema, name: "x") }
    let measured = try formatBridge.responseFormatDataWithReport(schema, name: "x")
    var limits = JSONSchemaProviderLimits(); limits.json[.workUnits] = measured.statistics[.workUnits]
    #expect(try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits).responseFormatData(schema, name: "x") == measured.result)
    limits.json[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits).responseFormatData(schema, name: "x") }
    for metric in [JSONResourceMetric.outputBytes, .retainedBytes] {
        var capacity = JSONSchemaProviderLimits()
        capacity.json[metric] = metric == .outputBytes ? measured.statistics[.outputBytes] : measured.statistics.peakLogicalRetainedBytes
        #expect(try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: capacity).responseFormatData(schema, name: "x") == measured.result)
        capacity.json[metric] -= 1
        #expect(throws: JSONFailure.self) { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: capacity).responseFormatData(schema, name: "x") }
    }
    var metadata = JSONSchemaProviderLimits(); metadata.metadataBytes = 1
    #expect(try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: metadata).responseFormat(schema, name: "x").objectValue != nil)
    metadata.metadataBytes = 0
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: metadata).responseFormat(schema, name: "x") }
}
@Test func providerCancellationInsideActualOwnedCheckStopsFurtherWork() async throws {
    let schema = try providerSchema()
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
        meter.checkpointObserver = { work in if work > 1_000 { withUnsafeCurrentTask { $0?.cancel() } } }
        do { _ = try formatBridge.check(schema.raw, registry: .empty, meter: &meter); Issue.record("Expected in-loop cancellation") }
        catch { #expect(error is CancellationError) }
        let work = meter.used(.workUnits)
        #expect(throws: CancellationError.self) { try meter.work() }
        #expect(meter.used(.workUnits) == work)
    }
    try await task.value
}
@Test func providerCaughtCapacityFailureCannotRestartBorrowedLedger() throws {
    let schema = try providerSchema()
    var limits = JSONSchemaProviderLimits(); limits.schemaNodes = 0
    var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
    let bounded = OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: limits)
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try bounded.check(schema.raw, registry: .empty, meter: &meter) }
    let work = meter.used(.workUnits)
    #expect(throws: JSONSchemaProviderFailure.self) { _ = try formatBridge.prepare(schema.raw, name: "x", description: nil, registry: .empty, purpose: .openAIResponsesFormatV1, meter: &meter) }
    #expect(meter.used(.workUnits) == work)
}
@Test func providerMalformedSchemasAndNativeRegexFailuresAreNotCompatibilityFalse() throws {
    for raw in [##"{"type":"object","minimum":"wrong"}"##, ##"{"type":"object","properties":{"value":{"type":"string","pattern":"["}},"required":["value"],"additionalProperties":false}"##] {
        let schema = try providerSchema(raw)
        #expect(throws: JSONSchemaCompilationFailure.self) { _ = try formatBridge.check(schema) }
    }
}
@Test func sharedProviderBridgeHasIndependentConcurrentInvocations() async throws {
    let schema = try providerSchema()
    try await withThrowingTaskGroup(of: JSON.self) { group in
        for _ in 0..<8 { group.addTask { try formatBridge.responseFormat(schema, name: "parallel") } }
        var count = 0
        for try await value in group {
            #expect(value.objectValue?[JSONKey("schema")] == schema.raw); count += 1
        }
        #expect(count == 8)
    }
}
