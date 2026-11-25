// SPDX-License-Identifier: Apache-2.0
// Public-consumer API tests. Deliberately no @testable import.
#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels
import JSON
import JSONSchema
import JSONSchemaDSL
import JSONFoundationModels
import Testing

@available(macOS 27.0, iOS 27.0, *)
@Generable
struct JF4SearchArguments {
    @Guide(description: "Search query") var query: String
    @Guide(.range(1...20)) var limit: Int
    @Guide(.anyOf(["date", "title"])) var sort: String
    @Guide(.count(2)) var tags: [String]
    var note: String?
}

private func emit4<T: Encodable>(_ kind: String, _ receipt: T) throws {
    print("JF4_\(kind) \(try JSONWriter().writeString(JSONValueEncoder().encode(receipt)))")
}
private func json4(_ source: String) throws -> JSON { try JSONParser().parse(source) }
private struct Invalid4: Encodable {
    let id: String
    let route: String
    let issues: [String]
}
private func invalid4(_ id: String, route: String, keyword: String, _ work: () throws -> Void) throws {
    do { try work(); Issue.record("Expected native invalidity: \(id)/\(route)") }
    catch let failure as JSONGenerationArgumentFailure {
        guard case .invalidArguments(let result) = failure else { Issue.record("Wrong argument failure"); return }
        #expect(!result.isValid && result.diagnosticsComplete)
        let issues = result.issues.map { $0.keyword.string }
        #expect(issues.contains(keyword), "\(id)/\(route)")
        try emit4("INVALID", Invalid4(id: id, route: route, issues: issues))
    }
}
private struct Typed4: Encodable {
    let id: String
    let source: String
    let returned: String
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf4AppleTypedPublicRoundtrip() throws {
    let preparation = try JSONGenerableCodec<JF4SearchArguments>.prepareWithReport()
    let codec = preparation.result
    #expect(preparation.statistics[.workUnits] > 0)
    #expect(codec.prepared.additions.isEmpty && codec.prepared.rewrites.isEmpty)
    #expect(try JSONComparison.equals(codec.prepared.canonical.document.raw, JSONValueEncoder().encode(codec.prepared.schema)))
    try emit4("SCHEMA", JSONWriter().writeString(codec.prepared.canonical.document.raw))
    for (id, source) in [
        ("absent", #"{"query":"Swift","limit":2,"sort":"date","tags":["a","b"]}"#),
        ("present", #"{"query":"Swift","limit":2,"sort":"date","tags":["a","b"],"note":"exact"}"#),
    ] {
        let original = try json4(source)
        let typed = try codec.decodeWithReport(original)
        #expect(typed.statistics[.workUnits] > 0)
        #expect(typed.result.query == "Swift" && typed.result.limit == 2 && typed.result.sort == "date")
        #expect(typed.result.tags == ["a","b"])
        #expect(typed.result.note == (id == "present" ? "exact" : nil))
        let encoded = try codec.encodeWithReport(typed.result)
        #expect(encoded.statistics[.workUnits] > 0)
        #expect(try JSONComparison.equals(original, encoded.result))
        let content = try codec.prepared.generatedContent(from: original)
        let fromContent = try codec.decode(content)
        #expect(try JSONComparison.equals(original, codec.encode(fromContent)))
        #expect(try JSONComparison.equals(original, codec.prepared.json(from: content)))
        try emit4("TYPED", Typed4(id: id, source: source, returned: JSONWriter().writeString(encoded.result)))
    }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf4AppleValidationPrecedesTypedConversion() throws {
    let codec = try JSONGenerableCodec<JF4SearchArguments>.prepare()
    let cases = [
        ("null-note", #"{"query":"Swift","limit":2,"sort":"date","tags":["a","b"],"note":null}"#, "type"),
        ("range", #"{"query":"Swift","limit":21,"sort":"date","tags":["a","b"]}"#, "maximum"),
        ("enum", #"{"query":"Swift","limit":2,"sort":"other","tags":["a","b"]}"#, "enum"),
        ("count", #"{"query":"Swift","limit":2,"sort":"date","tags":["a"]}"#, "minItems"),
        ("required", #"{"limit":2,"sort":"date","tags":["a","b"]}"#, "required"),
        ("unknown", #"{"query":"Swift","limit":2,"sort":"date","tags":["a","b"],"extra":true}"#, "additionalProperties"),
    ]
    for (id, source, keyword) in cases {
        let raw = try json4(source)
        #expect(try !codec.prepared.validate(raw).isValid)
        try invalid4(id, route: "decodeJSON", keyword: keyword) { _ = try codec.decode(raw) }
        let content = try GeneratedContent(json: source)
        try invalid4(id, route: "decodeContent", keyword: keyword) { _ = try codec.decode(content) }
        try invalid4(id, route: "export", keyword: keyword) { _ = try codec.prepared.generatedContent(from: raw) }
        try invalid4(id, route: "import", keyword: keyword) { _ = try codec.prepared.json(from: content) }
    }
    var typed = try codec.decode(json4(#"{"query":"Swift","limit":2,"sort":"date","tags":["a","b"]}"#))
    typed.limit = 21
    try invalid4("range", route: "encodeTyped", keyword: "maximum") { _ = try codec.encode(typed) }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf4AppleDSLPreparedGeneration() throws {
    // The same closed nested shape qualified in JF3.3, authored using the
    // existing DSL product rather than introducing a second schema language.
    let document = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.title("Root")
        Schema.properties {
            Property("child") {
                Schema.type(.object)
                Schema.title("Child")
                Schema.properties { Property("name") { Schema.type(.string) } }
                Schema.required("name")
                Schema.additionalProperties(false)
                Schema.rawKeyword("x-order", .array([.string("name")]))
            }
        }
        Schema.required("child")
        Schema.additionalProperties(false)
        Schema.rawKeyword("x-order", .array([.string("child")]))
    }
    let report = try JSONPreparedGeneration.prepareWithReport(document, metadata: .allowStructuralEquivalence)
    let prepared = report.result
    #expect(report.statistics[.workUnits] > 0)
    #expect(prepared.additions.isEmpty && prepared.rewrites.count == 1)
    let rewrite = try #require(prepared.rewrites.first)
    #expect(rewrite.kind == .localReference && rewrite.definition == JSONKey("Child"))
    #expect(rewrite.path == [.key(JSONKey("properties")), .key(JSONKey("child"))])
    #expect(try JSONComparison.equals(document.raw, prepared.canonical.document.raw))
    #expect(try JSONComparison.equals(prepared.roundtripped.raw, JSONValueEncoder().encode(prepared.schema)))
    let source = try json4(#"{"child":{"name":"Swift"}}"#)
    let content = try prepared.generatedContentWithReport(from: source)
    #expect(content.statistics[.workUnits] > 0)
    let returned = try prepared.jsonWithReport(from: content.result)
    #expect(returned.statistics[.workUnits] > 0)
    #expect(try JSONComparison.equals(source, returned.result))
    try invalid4("nested-required", route: "dslExport", keyword: "required") {
        _ = try prepared.generatedContent(from: json4(#"{"child":{}}"#))
    }
    try emit4("DSL", [
        "canonical": try JSONWriter().writeString(document.raw),
        "projected": try JSONWriter().writeString(prepared.roundtripped.raw),
        "returned": try JSONWriter().writeString(returned.result),
    ])
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf4AppleSchemaValidButUnrepresentableValue() throws {
    let minimum = try JSONNumber(parsing: "9007199254740992")
    let maximum = try JSONNumber(parsing: "9007199254740993")
    let document = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.title("Large")
        Schema.properties {
            Property("n") {
                Schema.type(.integer)
                Schema.minimum(minimum)
                Schema.maximum(maximum)
            }
        }
        Schema.required("n")
        Schema.additionalProperties(false)
        Schema.rawKeyword("x-order", .array([.string("n")]))
    }
    let prepared = try JSONPreparedGeneration.prepare(document)
    let exact = try json4(#"{"n":9007199254740992}"#)
    let changed = try json4(#"{"n":9007199254740993}"#)
    #expect(try prepared.validate(exact).isValid && prepared.validate(changed).isValid)
    #expect(try JSONComparison.equals(exact, prepared.json(from: prepared.generatedContent(from: exact))))
    #expect(throws: JSONGeneratedContentBridgeFailure.changedValue) {
        try prepared.generatedContent(from: changed)
    }
    try emit4("NUMBER", ["accepted": "9007199254740992", "rejected": "9007199254740993", "issue": "changedValue"])
}
#endif
