// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

public enum ReadinessFailure: Error { case expectation(String) }
private func require(_ condition: Bool, _ message: String) throws {
    if !condition { throw ReadinessFailure.expectation(message) }
}
public struct VectorOutcome: Codable, Sendable {
    public let id: String
    public let selectedDefinition: String
    public let expected: Bool
    public let actual: Bool
    public let evaluationWork: UInt64
}
public struct ReadinessReceipt: Codable, Sendable {
    public let schemaVersion: Int
    public let status: String
    public let scope: String
    public let definitionCount: Int
    public let selectedDefinitions: [String]
    public let outcomes: [VectorOutcome]
    public let positiveCases: Int
    public let negativeCases: Int
    public let operationalErrors: Int
    public let checks: [String]
    public let cumulativeStages: [RemainingWork.Stage]
}
private func resource(_ name: String) throws -> [UInt8] {
    // The copied directory is relative to the bundle itself. On Linux,
    // resourceURL may already select a directory literally named Resources.
    let path = Bundle.module.bundleURL.appendingPathComponent("Resources").appendingPathComponent(name)
    return Array(try Data(contentsOf: path))
}
public func runReadiness() throws -> ReadinessReceipt {
    let frozen = try JSONParser().parse(resource("schema-2026-07-28.json"))
    let definitions = try frozen.requiredMember("$defs")
    try require(definitions.objectValue?.count == 155, "Frozen definition inventory changed")
    let vectors = try JSONParser().parse(resource("mcp-public-consumer-vectors.json")).requiredMember("cases").arrayValue!
    try require(vectors.count == 20, "Missing/zero/changed vector inventory")
    var plans: [String: CompiledJSONSchema] = [:], outcomes: [VectorOutcome] = []
    var checks: [String] = []
    for vector in vectors {
        let id = try vector.requiredMember("id").stringValue!
        let name = try vector.requiredMember("definition").stringValue!
        let text = try vector.requiredMember("instance_json").stringValue!
        let expected = try vector.requiredMember("expected_schema_valid").booleanValue!
        if plans[name] == nil {
            try require(definitions.objectValue?[name] != nil, "Missing selected definition")
            let wrapper = JSON.object(try JSONObject(members: [
                JSONMember("$schema", value: try frozen.requiredMember("$schema")),
                JSONMember("$defs", value: definitions),
                JSONMember("$ref", value: .string("#/$defs/"+name))
            ]))
            plans[name] = try JSONSchemaCompiler().compileWithReport(wrapper, registry: .empty).result
        }
        let value = try JSONParser().parseWithReport(Array(text.utf8)).result
        let report = try JSONSchemaValidator(options: .init(output: .flag)).validateWithReport(value, against: plans[name]!)
        try require(report.result.isValid == expected, "Rooted verdict mismatch: "+id)
        outcomes.append(.init(id: id, selectedDefinition: name, expected: expected,
            actual: report.result.isValid, evaluationWork: report.statistics[.workUnits]))
        if id == "mcp-discover-large-exact-integer" || id == "mcp-discover-integer-exponent" {
            let number = try value.requiredMember("id").numberValue!
            try require(number == JSONNumber(parsing: "9007199254740993") && number.isInteger, "Rounded request ID")
            try require(number.originalLexeme == (id.hasSuffix("exponent") ? "9.007199254740993e15" : "9007199254740993"), "Original lexeme lost")
            let preserved = try JSONWriter(options: .init(numberStyle: .preserved)).write(value)
            let reparsed = try JSONParser().parse(preserved).requiredMember("id").numberValue!
            try require(reparsed.originalLexeme == number.originalLexeme, "Preserved lexical write changed ID")
            checks.append(id+": exact equality, integrality, preserved lexical write")
        }
        if id == "mcp-discover-beyond-machine-integer" {
            try require(try value.requiredMember("id") == .number(JSONNumber(parsing: "90071992547409931234567890123456789")), "Large ID changed")
            checks.append(id+": exact beyond UInt64")
        }
        if id == "mcp-discover-string-id" {
            try require(try value.requiredMember("id") == .string("e\u{301}") && value.requiredMember("id") != .string("é"), "Scalar string changed")
            checks.append(id+": distinct scalar string")
        }
        if id == "mcp-discover-scalar-distinct-unknown-metadata" {
            let annotation = try JSONPointer(parsing: "/params/_meta/org.example~1annotation").resolve(in: value)
            try require(annotation.objectValue?.count == 2 && annotation.objectValue?["é"] == "composed" && annotation.objectValue?["e\u{301}"] == "decomposed", "Scalar metadata keys collapsed")
            try require(try JSONParser().parse(JSONWriter().write(value)) == value, "Raw write/read changed metadata")
            checks.append(id+": both exact keys survive round trip")
        }
        if id == "mcp-tool-schema-and-annotation" {
            let raw = try value.requiredMember("inputSchema")
            try require(try raw == JSONParser().parse(resource("synthetic-tool-input-schema.json")), "Raw tool schema changed")
            let document = try JSONSchemaDocument(raw)
            let view = try document.nodeWithReport(at: JSONPointer(parsing: "/properties/value"))
            try require(view.result.declaredAnnotations.presence(of: "x-mcp-header") == .value("Value"), "Unknown declaration annotation lost")
            try require(try value.requiredMember("_meta").presence(of: "org.example/privateAnnotation") == .null, "Explicit null became absent")
            try require(try value.presence(of: "description") == .absent, "Absent field invented")
            let tool = try JSONSchemaCompiler().compileWithReport(raw).result
            try require(try JSONSchemaValidator().validate(JSONParser().parse(#"{"value":"ok"}"#), against: tool).isValid, "Tool positive failed")
            for invalid in [#"{}"#, #"{"value":null}"#, #"{"value":"ok","extra":1}"#] {
                try require(try !JSONSchemaValidator().validate(JSONParser().parse(invalid), against: tool).isValid, "Tool negative passed")
            }
            checks.append(id+": raw schema, unknown annotation, presence, positive + three negatives")
        }
    }
    var operationalErrors = 0
    do {
        _ = try JSONSchemaCompiler().compileWithReport(JSONParser().parse(#"{"$ref":"https://unavailable.invalid/offline"}"#))
        throw ReadinessFailure.expectation("Unavailable reference compiled")
    } catch is JSONSchemaCompilationFailure { operationalErrors += 1 }
    var finite = JSONLimits.balanced; finite[.evaluationWorkUnits] = 1
    do {
        _ = try JSONSchemaValidator(options: .init(limits: finite)).validate(.null, against: plans["DiscoverRequest"]!)
        throw ReadinessFailure.expectation("Evaluation escaped finite ceiling")
    } catch let failure as JSONFailure {
        try require(failure.category == .resource, "Operational failure became invalidity")
        operationalErrors += 1
    }
    checks.append("unavailable offline reference and finite evaluation throw operational errors")
    let account = try runCumulativeOperation(limits: .balanced)
    let positive = outcomes.filter(\.actual).count
    return .init(schemaVersion: 1, status: "passed", scope: "Public JSON/JSONSchema integration; no MCP protocol/server conformance claim",
        definitionCount: 155, selectedDefinitions: plans.keys.sorted(), outcomes: outcomes,
        positiveCases: positive, negativeCases: outcomes.count-positive, operationalErrors: operationalErrors,
        checks: checks, cumulativeStages: account.stages)
}

public func runCumulativeOperation(limits: JSONLimits) throws -> RemainingWork {
    var account = try RemainingWork(limits: limits)
    let raw = try account.perform("parse schema") { try JSONParser(options: .init(limits: $0)).parseWithReport(Array(#"{"type":"integer","minimum":9007199254740993}"#.utf8)) }
    let plan = try account.perform("admit and compile raw schema") { try JSONSchemaCompiler(options: .init(limits: $0)).compileWithReport(raw, registry: .empty) }
    let instance = try account.perform("parse instance") { try JSONParser(options: .init(limits: $0)).parseWithReport(Array("9.007199254740993e15".utf8)) }
    let result = try account.perform("evaluate") { try JSONSchemaValidator(options: .init(limits: $0, output: .flag)).validateWithReport(instance, against: plan) }
    try require(result.isValid, "Composed operation returned false")
    _ = try account.perform("write") { try JSONWriter(options: .init(limits: $0)).writeWithReport(instance) }
    return account
}
