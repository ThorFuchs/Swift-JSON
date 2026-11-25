// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import Testing
@testable import JSONFoundationModels

private let graph42 = ##"{"type":"object","properties":{"primary":{"$ref":"#/$defs/Filter"},"alternatives":{"type":"array","items":{"$ref":"#/$defs/Filter"},"minItems":2,"maxItems":2},"fallback":{"$ref":"#/$defs/Filter"}},"required":["primary","alternatives"],"additionalProperties":false,"$defs":{"Filter":{"type":"object","properties":{"query":{"type":"string"},"limit":{"type":"integer","minimum":1,"maximum":20}},"required":["query","limit"],"additionalProperties":false}}}"##
private let childPath42 = ["properties","primary"]
private func parse42(_ text: String) throws -> JSON { try JSONParser().parse(text) }
private func import42(_ text: String, limits: JSONLimits = .balanced) throws -> JSONOperationReport<CompiledJSONSchema> {
    try JF42SchemaImport.importSchema(parse42(text), policy: .allowLocalObjectDefinitions, limits: limits)
}
private func reject42(_ text: String, _ issue: JSONGenerationSchemaIssue, _ path: [String]) throws {
    do {
        _ = try import42(text)
        Issue.record("Expected local import rejection at \(path)")
    } catch let error as JSONGenerationSchemaFailure {
        #expect(error.issue == issue)
        #expect(error.path == path.map { .key(JSONKey($0)) })
    }
}

@Test func jf42CanonicalLocalGraph() throws {
    let result = try import42(graph42)
    #expect(try JSONComparison.equals(result.result.document.raw, parse42(graph42)))
    #expect(result.statistics[.workUnits] > 0)
    let good = #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}]}"#
    let bad = #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":21},{"query":"MCP","limit":2}]}"#
    #expect(try result.result.validate(parse42(good)).isValid)
    #expect(try !result.result.validate(parse42(bad)).isValid)
    #expect(throws: JSONGenerationSchemaFailure.self) {
        try JF42SchemaImport.importSchema(parse42(graph42), policy: .referenceFree, limits: .balanced)
    }
    // Native fragment parsing handles escaping exactly once, with scalar keys.
    let escaped = graph42.replacingOccurrences(of: "#/$defs/Filter", with: "#/$defs/A~1B~0C%25")
        .replacingOccurrences(of: "\"Filter\":", with: "\"A/B~C%\":")
    #expect(try import42(escaped).result.validate(parse42(good)).isValid)
    let once = graph42.replacingOccurrences(of: "#/$defs/Filter", with: "#/$defs/A%252FB")
        .replacingOccurrences(of: "\"Filter\":", with: "\"A%2FB\":")
    #expect(try import42(once).result.validate(parse42(good)).isValid)
}

@Test func jf42RejectReferenceShapes() throws {
    for ref in ["https://example.invalid/remote#/$defs/Filter","#/$defs/Missing",
                "#/$defs/Filter/properties","#Filter","#","#/$defs/Fil~2ter","#/$defs/Fil%GGter"] {
        try reject42(graph42.replacingOccurrences(of: "#/$defs/Filter", with: ref),
                     .invalidLocalReference, childPath42 + ["$ref"])
    }
    let siblings = graph42.replacingOccurrences(of: ##""primary":{"$ref":"#/$defs/Filter"}"##,
        with: ##""primary":{"$ref":"#/$defs/Filter","description":"extra"}"##)
    try reject42(siblings, .invalidLocalReference, childPath42 + ["$ref"])
    let root = ##"{"$ref":"#/$defs/Filter","$defs":{"Filter":{"type":"object","properties":{},"required":[],"additionalProperties":false}}}"##
    try reject42(root, .invalidLocalReference, ["$ref"])
    let scalar = ##"{"type":"object","properties":{"primary":{"$ref":"#/$defs/Filter"}},"required":["primary"],"additionalProperties":false,"$defs":{"Filter":{"type":"integer"}}}"##
    try reject42(scalar, .invalidLocalReference, childPath42 + ["$ref"])
    let alias = ##"{"type":"object","properties":{"primary":{"$ref":"#/$defs/Filter"}},"required":["primary"],"additionalProperties":false,"$defs":{"Filter":{"$ref":"#/$defs/Other"},"Other":{"type":"object","properties":{},"required":[],"additionalProperties":false}}}"##
    try reject42(alias, .invalidLocalReference, childPath42 + ["$ref"])
}

@Test func jf42RejectCyclesScopesAndUnusedDefinitions() throws {
    let cyclic = ##"{"type":"object","properties":{"primary":{"$ref":"#/$defs/A"}},"required":["primary"],"additionalProperties":false,"$defs":{"A":{"type":"object","properties":{"next":{"$ref":"#/$defs/B"}},"required":[],"additionalProperties":false},"B":{"type":"object","properties":{"back":{"$ref":"#/$defs/A"}},"required":[],"additionalProperties":false}}}"##
    try reject42(cyclic, .cyclicLocalReference, childPath42 + ["properties","next","properties","back","$ref"])
    let unused = ##"{"type":"object","properties":{"primary":{"$ref":"#/$defs/Filter"}},"required":["primary"],"additionalProperties":false,"$defs":{"Filter":{"type":"object","properties":{},"required":[],"additionalProperties":false},"Unused":{"type":"object","properties":{},"required":[],"additionalProperties":false}}}"##
    try reject42(unused, .unusedDefinition, ["$defs","Unused"])
    let scoped = graph42.replacingOccurrences(of: #""Filter":{"type":"object""#,
        with: #""Filter":{"$id":"https://example.invalid/changed","type":"object""#)
    try reject42(scoped, .unsupportedDeclaration, childPath42 + ["$id"])
    let nestedDefs = graph42.replacingOccurrences(of: #""Filter":{"type":"object""#,
        with: #""Filter":{"$defs":{"X":{"type":"string"}},"type":"object""#)
    try reject42(nestedDefs, .unsupportedDeclaration, childPath42 + ["$defs"])
}

@Test func jf42RejectUnqualifiedConstraintsAndDepth() throws {
    let pattern = graph42.replacingOccurrences(of: #""query":{"type":"string"}"#,
        with: #""query":{"type":"string","pattern":"x"}"#)
    try reject42(pattern, .unsupportedDeclaration, childPath42 + ["properties","query","pattern"])
    let nullable = graph42.replacingOccurrences(of: #""query":{"type":"string"}"#,
        with: #""query":{"type":["string","null"]}"#)
    try reject42(nullable, .unsupportedShape, childPath42 + ["properties","query"])
    let emptyDefinitions = #"{"type":"object","properties":{},"required":[],"additionalProperties":false,"$defs":{}}"#
    try reject42(emptyDefinitions, .unsupportedShape, ["$defs"])
    var deep = #"{"type":"object","properties":{},"required":[],"additionalProperties":false}"#
    for _ in 0..<16 {
        deep = "{\"type\":\"object\",\"properties\":{\"x\":" + deep + "},\"required\":[],\"additionalProperties\":false}"
    }
    try reject42(deep, .unsupportedShape, Array(repeating: ["properties","x"], count: 16).flatMap { $0 })
}

@Test func jf42CumulativeImportBudget() throws {
    let baseline = try import42(graph42)
    var limits = JSONLimits.balanced
    limits[.workUnits] = baseline.statistics[.workUnits]
    limits[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try import42(graph42, limits: limits).statistics == baseline.statistics)
    var less = limits; less[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { try import42(graph42, limits: less) }
    less = limits; less[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try import42(graph42, limits: less) }
}

@Test func jf42CancellationDuringLocalImport() async throws {
    let raw = try parse42(graph42)
    let task = Task {
        try JSON.withComposition { scope in
            let admitted = try scope.admitTrusted(raw)
            return try scope.withMeter { meter in
                meter.checkpointObserver = { _ in withUnsafeCurrentTask { $0?.cancel() } }
                try JF42LocalImport.check(admitted, meter: &meter)
                return true
            }
        }.result
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
