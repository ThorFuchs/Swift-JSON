// SPDX-License-Identifier: Apache-2.0
// Disposable JF1 probe, not a released adapter API.
#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import Foundation
import FoundationModels
import JSON
import JSONSchema

@available(macOS 27.0, iOS 27.0, *)
@Generable
struct GuidedArguments {
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

@available(macOS 27.0, iOS 27.0, *)
public enum JF1Probe {
    // These are intentionally independent operations on fixed synthetic inputs.
    // They make no cumulative metering claim for the future production bridge.
    private static func observe(_ name: String, _ body: () throws -> Void) {
        print("JF1_BEGIN \(name)")
        do { try body(); print("JF1_END \(name) OBSERVED") }
        catch { print("JF1_ERROR \(name) \(String(reflecting: type(of: error)))"); print("JF1_END \(name) REJECTED") }
    }

    private static func show(_ label: String, _ value: JSON) throws {
        print("JF1_JSON \(label) \(try JSONWriter().writeString(value))")
    }

    private static func inspect(_ schema: GenerationSchema) throws -> JSON {
        let raw = try JSONValueEncoder().encode(schema)
        try show("native-schema", raw)
        let reference = try JSONParser().parse(JSONEncoder().encode(schema))
        try show("foundation-control", reference)
        print("JF1_ENCODERS_EQUAL \(raw == reference)")
        let document = try JSONSchemaDocument(raw)
        _ = try JSONSchemaCompiler().compile(document)
        print("JF1_NATIVE_COMPILE true")
        return raw
    }

    public static func run() {
        observe("guided-schema") {
            let raw = try inspect(GuidedArguments.generationSchema)
            let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw))
            let cases = [
                ("valid", #"{"query":"test","limit":1,"sort":"date","tags":["a","b"],"note":null}"#),
                ("absent-note", #"{"query":"test","limit":1,"sort":"date","tags":["a","b"]}"#),
                ("range", #"{"query":"test","limit":21,"sort":"date","tags":["a","b"],"note":null}"#),
                ("enum", #"{"query":"test","limit":1,"sort":"other","tags":["a","b"],"note":null}"#),
                ("count", #"{"query":"test","limit":1,"sort":"date","tags":["a"],"note":null}"#),
            ]
            for (label, text) in cases {
                let value = try JSONParser().parse(text)
                let result = try JSONSchemaValidator().validate(value, against: plan)
                print("JF1_VALIDATION \(label) \(result.isValid)")
            }
        }
        observe("dynamic-schema") {
            let root = DynamicGenerationSchema(name: "JF1Dynamic", properties: [
                .init(name: "query", schema: .init(type: String.self)),
                .init(name: "limit", schema: .init(type: Int.self, guides: [.range(1...20)])),
                .init(name: "note", schema: .init(type: String.self), isOptional: true),
            ])
            let schema = try GenerationSchema(root: root, dependencies: [])
            _ = try inspect(schema)
        }
        observe("typed-value") {
            let content = try GeneratedContent(json: #"{"query":"test","limit":2,"sort":"date","tags":["a","b"],"note":null}"#)
            let typed = try GuidedArguments(content)
            let result = try JSONParser().parse(typed.generatedContent.jsonString)
            try show("typed-returned", result)
            print("JF1_TYPED_VALUES \(typed.query == "test" && typed.limit == 2 && typed.tags == ["a", "b"])")
        }
        let values: [(String, String)] = [
            ("ordinary", #"{"a":[true,false,1,"hello"],"b":{}}"#),
            ("explicit-null", #"{"a":null}"#),
            ("absent", #"{}"#),
            ("large-integer", "9007199254740993"),
            ("int64-max", "9223372036854775807"),
            ("decimal", "0.12345678901234567890123456789"),
            ("exponent", "1e100"),
            ("unicode-keys", #"{"\u00e9":1,"e\u0301":2}"#),
            ("unicode-value", #""e\u0301""#),
            ("nested", #"[{"a":[1,null,{"b":2}]}]"#),
        ]
        for (name, input) in values {
            observe(name) {
                let original = try JSONParser().parse(input)
                try show("original", original)
                let content = try GeneratedContent(json: JSONWriter().writeString(original))
                print("JF1_COMPLETE \(content.isComplete)")
                let returned = try JSONParser().parse(content.jsonString)
                try show("returned", returned)
                print("JF1_VALUE_EQUAL \(original == returned)")
            }
        }
        print("JF1_PROBE_COMPLETE")
    }
}
#else
// Intentionally not a functional bridge on an unsupported SDK.
// Its successful compilation only tests packaging isolation.
public enum JF1Unavailable {}
#endif
