// SPDX-License-Identifier: Apache-2.0
// JF2.2 diagnostic tests on the actual FoundationModels SDK, not a model session.
#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels
import JSON
import JSONSchema
import JSONFoundationModels
import Testing

@available(macOS 27.0, iOS 27.0, *)
@Generable
struct JF22GuidedArguments {
    @Guide(description: "Search query")
    var query: String
    @Guide(.range(1...20))
    var limit: Int
    @Guide(.anyOf(["date", "title"]))
    var sort: String
    @Guide(.count(2))
    var tags: [String]
    var note: String?
}

private struct VectorReceipt: Encodable {
    let id: String
    let source: String
    let raw: String?
    let complete: Bool?
    let equal: Bool?
    let exportOutcome: String
    let importOutcome: String
}

private struct GuideReceipt: Encodable {
    let id: String
    let source: String
    let expected: Bool
    let actual: Bool
}

private struct TypedReceipt: Encodable {
    let source: String
    let returned: String
    let inputValid: Bool
    let outputValid: Bool
    let equal: Bool
}

private func emit<T: Encodable>(_ kind: String, _ receipt: T) throws {
    print("JF22_\(kind) \(try JSONWriter().writeString(JSONValueEncoder().encode(receipt)))")
}

private func disposition<T>(_ work: () throws -> T) throws -> String {
    do { _ = try work(); return "accepted" }
    catch let error as JSONGeneratedContentBridgeFailure {
        switch error {
        case .incompleteContent: return "incompleteContent"
        case .changedValue: return "changedValue"
        case .frameworkRejected: return "frameworkRejected"
        }
    }
    // Unexpected native, operational or cancellation failures escape.
}

@available(macOS 27.0, iOS 27.0, *)
private func observe(_ id: String, _ source: String) throws {
    let original = try JSONParser().parse(source)
    let nativeText = try JSONWriter().writeString(original)
    let bridge = JSONGeneratedContentBridge()
    let content: GeneratedContent
    do { content = try GeneratedContent(json: nativeText) }
    catch is CancellationError { throw CancellationError() }
    catch {
        let outcome = try disposition { try bridge.generatedContent(from: original) }
        try emit("VALUE", VectorReceipt(id: id, source: nativeText, raw: nil, complete: nil, equal: nil,
            exportOutcome: outcome, importOutcome: "notAttempted"))
        #expect(outcome == "frameworkRejected")
        return
    }
    let raw = content.jsonString
    // Log raw before native parsing so even unexpected malformed output is inspectable.
    print("JF22_RAW \(id) \(try JSONWriter().writeString(.string(raw)))")
    let returned = try JSONParser().parse(raw)
    let equal = try JSONComparison.equals(original, returned)
    let complete = content.isComplete
    let expectedExport = !complete ? "incompleteContent" : equal ? "accepted" : "changedValue"
    let expectedImport = complete ? "accepted" : "incompleteContent"
    let exportOutcome = try disposition {
        let exported = try bridge.generatedContentWithReport(from: original)
        #expect(exported.result.isComplete)
        #expect(try JSONComparison.equals(original, bridge.json(from: exported.result)))
        #expect(exported.statistics[.workUnits] > 0)
    }
    let importOutcome = try disposition {
        let imported = try bridge.jsonWithReport(from: content)
        #expect(try JSONComparison.equals(returned, imported.result))
        #expect(imported.statistics[.workUnits] > 0)
    }
    try emit("VALUE", VectorReceipt(id: id, source: nativeText, raw: raw, complete: complete, equal: equal,
        exportOutcome: exportOutcome, importOutcome: importOutcome))
    #expect(exportOutcome == expectedExport)
    #expect(importOutcome == expectedImport)
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf22AppleFidelityMatrix() throws {
    let numbers = [
        ("zero", "0"), ("one", "1"), ("safe-below", "9007199254740991"),
        ("safe-boundary", "9007199254740992"), ("safe-above", "9007199254740993"),
        ("negative-above", "-9007199254740993"), ("int64-min", "-9223372036854775808"),
        ("int64-max", "9223372036854775807"), ("uint64-max", "18446744073709551615"),
        ("binary-fraction", "0.125"), ("decimal-tenth", "0.1"),
        ("precise-decimal", "0.12345678901234567890123456789"),
        ("large-exponent", "1e100"), ("small-exponent", "1e-100"),
    ]
    for (id, number) in numbers {
        try observe("root-\(id)", number)
        try observe("object-\(id)", "{\"n\":\(number)}")
        try observe("array-\(id)", "[\(number)]")
    }
    for (id, source) in [
        ("ordinary", #"{"a":[true,false,1,"hello"],"b":{}}"#),
        ("explicit-null", #"{"a":null}"#), ("absent", "{}"),
        ("unicode-keys", #"{"\u00e9":1,"e\u0301":2}"#),
        ("unicode-keys-reversed", #"{"e\u0301":2,"\u00e9":1}"#),
        ("unicode-keys-nested", #"{"a":[{"\u00e9":1,"e\u0301":2}]}"#),
        ("unicode-value", #""e\u0301""#), ("nested", #"[{"a":[1,null,{"b":2}]}]"#),
        ("null-root", "null"), ("bool-root", "true"),
    ] { try observe(id, source) }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf22AppleCompleteUnicodeCollision() throws {
    // Pinned SDK regression reproduction; a future SDK fix is a reviewable change.
    let original = try JSONParser().parse(#"{"\u00e9":1,"e\u0301":2}"#)
    let raw = try GeneratedContent(json: JSONWriter().writeString(original))
    let returned = try JSONParser().parse(raw.jsonString)
    #expect(raw.isComplete)
    #expect(original.objectValue?.count == 2)
    #expect(returned.objectValue?.count == 1)
    #expect(try !JSONComparison.equals(original, returned))
    #expect(throws: JSONGeneratedContentBridgeFailure.changedValue) {
        try JSONGeneratedContentBridge().generatedContent(from: original)
    }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf22AppleGuideValidation() throws {
    let schema = try JSONValueEncoder().encode(JF22GuidedArguments.generationSchema)
    print("JF22_SCHEMA \(try JSONWriter().writeString(schema))")
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(schema))
    let cases: [(String, String, Bool)] = [
        ("base", #"{"query":"test","limit":1,"sort":"date","tags":["a","b"]}"#, true),
        ("upper-bound", #"{"query":"test","limit":20,"sort":"date","tags":["a","b"]}"#, true),
        ("enum-title", #"{"query":"test","limit":1,"sort":"title","tags":["a","b"]}"#, true),
        ("note-string", #"{"query":"test","limit":1,"sort":"date","tags":["a","b"],"note":"ok"}"#, true),
        ("note-null", #"{"query":"test","limit":1,"sort":"date","tags":["a","b"],"note":null}"#, false),
        ("range-low", #"{"query":"test","limit":0,"sort":"date","tags":["a","b"]}"#, false),
        ("range-high", #"{"query":"test","limit":21,"sort":"date","tags":["a","b"]}"#, false),
        ("enum-other", #"{"query":"test","limit":1,"sort":"other","tags":["a","b"]}"#, false),
        ("count-low", #"{"query":"test","limit":1,"sort":"date","tags":["a"]}"#, false),
        ("count-high", #"{"query":"test","limit":1,"sort":"date","tags":["a","b","c"]}"#, false),
        ("item-type", #"{"query":"test","limit":1,"sort":"date","tags":["a",2]}"#, false),
        ("required-query", #"{"limit":1,"sort":"date","tags":["a","b"]}"#, false),
        ("extra-property", #"{"query":"test","limit":1,"sort":"date","tags":["a","b"],"extra":true}"#, false),
        ("query-type", #"{"query":1,"limit":1,"sort":"date","tags":["a","b"]}"#, false),
    ]
    for (id, source, expected) in cases {
        let value = try JSONParser().parse(source)
        let actual = try JSONSchemaValidator().validate(value, against: plan).isValid
        try emit("GUIDE", GuideReceipt(id: id, source: source, expected: expected, actual: actual))
        #expect(actual == expected)
    }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf22AppleTypedOptionality() throws {
    // JF1 observed typed construction accepts explicit null and then omits note.
    let source = #"{"query":"test","limit":2,"sort":"date","tags":["a","b"],"note":null}"#
    let original = try JSONParser().parse(source)
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONValueEncoder().encode(JF22GuidedArguments.generationSchema)))
    let typed = try JF22GuidedArguments(GeneratedContent(json: source))
    let raw = typed.generatedContent.jsonString
    let returned = try JSONParser().parse(raw)
    let inputValid = try JSONSchemaValidator().validate(original, against: plan).isValid
    let outputValid = try JSONSchemaValidator().validate(returned, against: plan).isValid
    let equal = try JSONComparison.equals(original, returned)
    try emit("TYPED", TypedReceipt(source: source, returned: raw, inputValid: inputValid, outputValid: outputValid, equal: equal))
    #expect(!inputValid && outputValid && !equal)
    #expect(typed.note == nil)
    #expect(returned.objectValue?["note"] == nil)
}
#endif
