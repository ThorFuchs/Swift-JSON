// SPDX-License-Identifier: Apache-2.0
// Shared authored consumer, compiled once in tests and again in an independent package.
#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels
import JSON
import JSONSchema
import JSONFoundationModels

@available(macOS 27.0, iOS 27.0, *)
@Generable
struct JF42Filter {
    var query: String
    @Guide(.range(1...20)) var limit: Int
}

@available(macOS 27.0, iOS 27.0, *)
@Generable
struct JF42Request {
    var primary: JF42Filter
    @Guide(.count(2)) var alternatives: [JF42Filter]
    var fallback: JF42Filter?
}

struct JF42TypedReceipt: Encodable {
    let id: String
    let source: String
    let returned: String
}

struct JF42Diagnostic: Encodable, Equatable {
    let keyword: String
    let keywordLocation: String
    let instanceLocation: String
}

struct JF42InvalidReceipt: Encodable {
    let id: String
    let route: String
    let issue: JF42Diagnostic
}

struct JF42NestedReceipt: Encodable {
    let schema: String
    let typed: [JF42TypedReceipt]
    let invalid: [JF42InvalidReceipt]
}

enum JF42ExampleFailure: Error {
    case preparation, fidelity, invalidity, diagnostics, unexpectedAcceptance
}

@available(macOS 27.0, iOS 27.0, *)
enum JF42Example {
    static let positives = [
        ("absent", #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}]}"#),
        ("present", #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}],"fallback":{"query":"Docs","limit":3}}"#),
    ]
    static let negatives = [
        ("primary-range", #"{"primary":{"query":"Swift","limit":21},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}]}"#, "maximum", "/primary/limit"),
        ("array-range", #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":0}]}"#, "minimum", "/alternatives/1/limit"),
        ("array-count", #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20}]}"#, "minItems", "/alternatives"),
        ("fallback-null", #"{"primary":{"query":"Swift","limit":1},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}],"fallback":null}"#, "type", "/fallback"),
        ("extra", #"{"primary":{"query":"Swift","limit":1,"extra":true},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}]}"#, "", "/primary/extra"),
        ("required", #"{"primary":{"query":"Swift"},"alternatives":[{"query":"JSON","limit":20},{"query":"MCP","limit":2}]}"#, "required", "/primary"),
    ]

    static func prepare() throws -> JSONGenerableCodec<JF42Request> {
        let report = try JSONGenerableCodec<JF42Request>.prepareWithReport(
            importPolicy: .allowLocalObjectDefinitions)
        let codec = report.result
        let raw = try JSONValueEncoder().encode(codec.prepared.schema)
        guard report.statistics[.workUnits] > 0,
              codec.prepared.additions.isEmpty, codec.prepared.rewrites.isEmpty,
              try JSONComparison.equals(raw, codec.prepared.canonical.document.raw),
              try JSONComparison.equals(raw, codec.prepared.roundtripped.raw) else {
            throw JF42ExampleFailure.preparation
        }
        return codec
    }

    static func typed(_ codec: JSONGenerableCodec<JF42Request>) throws -> [JF42TypedReceipt] {
        var receipts: [JF42TypedReceipt] = []
        for (id, source) in positives {
            let original = try JSONParser().parse(source)
            let report = try codec.decodeWithReport(original)
            let request = report.result
            guard report.statistics[.workUnits] > 0,
                  request.primary.query == "Swift", request.primary.limit == 1,
                  request.alternatives.map(\.query) == ["JSON","MCP"],
                  request.alternatives.map(\.limit) == [20,2],
                  request.fallback?.query == (id == "present" ? "Docs" : nil),
                  request.fallback?.limit == (id == "present" ? 3 : nil) else {
                throw JF42ExampleFailure.fidelity
            }
            let encoded = try codec.encodeWithReport(request)
            let content = try codec.prepared.generatedContent(from: original)
            let fromContent = try codec.decode(content)
            guard encoded.statistics[.workUnits] > 0,
                  try JSONComparison.equals(original, encoded.result),
                  try JSONComparison.equals(original, codec.encode(fromContent)),
                  try JSONComparison.equals(original, codec.prepared.json(from: content)) else {
                throw JF42ExampleFailure.fidelity
            }
            receipts.append(.init(id: id, source: source, returned: try JSONWriter().writeString(encoded.result)))
        }
        return receipts
    }

    private static func diagnostic(_ result: JSONValidationResult) throws -> JF42Diagnostic {
        guard !result.isValid, result.diagnosticsComplete, result.issues.count == 1,
              let issue = result.issues.first else { throw JF42ExampleFailure.diagnostics }
        return .init(keyword: issue.keyword.string, keywordLocation: issue.keywordLocation.string,
                     instanceLocation: issue.instanceLocation.string)
    }

    private static func reject(_ id: String, route: String, expected: JF42Diagnostic,
                               work: () throws -> Void) throws -> JF42InvalidReceipt {
        do { try work(); throw JF42ExampleFailure.unexpectedAcceptance }
        catch let failure as JSONGenerationArgumentFailure {
            guard case .invalidArguments(let result) = failure,
                  try diagnostic(result) == expected else { throw JF42ExampleFailure.diagnostics }
            return .init(id: id, route: route, issue: expected)
        }
    }

    static func invalid(_ codec: JSONGenerableCodec<JF42Request>) throws -> [JF42InvalidReceipt] {
        var receipts: [JF42InvalidReceipt] = []
        for (id, source, keyword, location) in negatives {
            let original = try JSONParser().parse(source)
            let expected = try diagnostic(codec.prepared.validate(original))
            guard expected.keyword == keyword, expected.instanceLocation == location else {
                throw JF42ExampleFailure.diagnostics
            }
            // Use the actual complete framework representation, not a simulated codec.
            let content = try GeneratedContent(json: source)
            receipts.append(try reject(id, route: "decodeJSON", expected: expected) { _ = try codec.decode(original) })
            receipts.append(try reject(id, route: "decodeContent", expected: expected) { _ = try codec.decode(content) })
            receipts.append(try reject(id, route: "export", expected: expected) { _ = try codec.prepared.generatedContent(from: original) })
            receipts.append(try reject(id, route: "import", expected: expected) { _ = try codec.prepared.json(from: content) })
        }
        return receipts
    }

    static func run() throws -> JF42NestedReceipt {
        let codec = try prepare()
        return try .init(schema: JSONWriter().writeString(codec.prepared.canonical.document.raw),
                         typed: typed(codec), invalid: invalid(codec))
    }
}
#endif
