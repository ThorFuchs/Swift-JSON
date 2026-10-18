// SPDX-License-Identifier: Apache-2.0
// Canonical executable recipes. No private APIs or serialized Foundation bridge.
import JSON
import JSONBridges
import JSONSchema
import JSONSchemaExamples
import JSONStreaming
import JSONNavigation
import JSONPatch
import JSONHTML

struct RecipeFailure: Error { let id: String }
func check(_ id: String, _ condition: Bool) throws {
    guard condition else { throw RecipeFailure(id: id) }
    print("KIT_CHECK \(id) passed")
}

// RECIPE exact-presence
func exactPresence() throws {
    let root = try JSON.parse(#"{"n":9007199254740993,"note":null}"#)
    let report = try root.readWithReport { try $0["n"].requiredInteger(as: UInt64.self) }
    try check("exact-integer", report.result == 9_007_199_254_740_993)
    try check("read-work", report.statistics[.workUnits] > 0)
    let text = String(decoding: try JSONWriter().write(root), as: UTF8.self)
    try check("exact-write", text.contains("9007199254740993"))
    try check("strict-roundtrip", JSON.parse(text) == root)
    try check("null", root.presence(of: "note") == .null)
    try check("absent", root.presence(of: "missing") == .absent)
    let keys = try JSONObject(members: [JSONMember("\u{e9}", value: 1), JSONMember("e\u{301}", value: 2)])
    try check("scalar-keys", keys.count == 2 && keys["\u{e9}"] == 1 && keys["e\u{301}"] == 2)
    do {
        _ = try JSONObject(members: [JSONMember("a", value: 1), JSONMember("a", value: 2)])
        throw RecipeFailure(id: "duplicate-accepted")
    } catch let failure as JSONFailure {
        try check("duplicate-rejected", failure.code == .duplicateKey)
    }
}

// RECIPE native-bridge
func nativeBridge() throws {
    let n: UInt64 = 9_007_199_254_740_993
    try check("integer-bridge", UInt64(jsonNumber: n.jsonNumber()) == n)
    let tenth = try JSONNumber(parsing: "0.1")
    do {
        _ = try Double(jsonNumber: tenth) // Default requires mathematical equality.
        throw RecipeFailure(id: "inexact-accepted")
    } catch let failure as JSONFailure {
        try check("exact-rejected", failure.category == .conversion && failure.code == .inexactConversion)
    }
    let rounded = try Double(jsonNumber: tenth, policy: .rounded) // Explicit caller decision.
    try check("finite-rounding", rounded.isFinite && rounded == 0.1)
    try check("roundtrip-text", rounded.jsonNumberFromRoundTripText() == tenth)
}

// RECIPE schema
func schemaEvaluation() throws {
    let document = try JSONSchemaDocument(JSON.parse(#"{"type":"integer","minimum":0}"#))
    let plan = try JSONSchemaCompiler().compile(document, registry: .empty)
    let validator = JSONSchemaValidator(options: .init(limits: .balanced))
    let valid = try validator.validateWithReport(42, against: plan)
    let invalid = try validator.validate(-1, against: plan)
    try check("schema-valid", valid.result.isValid && valid.result.diagnosticsComplete)
    try check("schema-invalid", !invalid.isValid && invalid.diagnosticsComplete)
    try check("schema-work", valid.statistics[.evaluationWorkUnits] > 0)
    var limits = JSONLimits.balanced
    limits[.evaluationWorkUnits] = 0
    do {
        _ = try JSONSchemaValidator(options: .init(limits: limits)).validate(42, against: plan)
        throw RecipeFailure(id: "exhaustion-accepted")
    } catch let failure as JSONFailure {
        try check("schema-operational", failure.category == .resource && failure.resource?.metric == .evaluationWorkUnits)
    }
    limits = .balanced
    limits[.issues] = 0
    let partial = try JSONSchemaValidator(options: .init(limits: limits, diagnosticPolicy: .bestEffort))
        .validate(-1, against: plan)
    try check("diagnostic-incomplete", !partial.isValid && !partial.diagnosticsComplete && partial.issues.isEmpty)
    let packaged = try JSONSchemaRegistry.draft2020_12()
    try check("packaged-registry", packaged.documents.count == 9)
}

// RECIPE examples
func certifiedExamples() throws {
    let document = try JSONSchemaDocument(JSON.parse(#"{"type":"integer","minimum":9007199254740993}"#))
    let generator = try JSONSchemaExampleGenerator(document: document)
    let first = try generator.generate(seed: 42, profile: .minimal)
    let second = try generator.generate(seed: 42, profile: .minimal)
    try check("example-certified", first.validation.isValid && first.validation.diagnosticsComplete)
    try check("example-repeatable", first.value == second.value && first.traceDigest == second.traceDigest)
    let independent = try JSONSchemaCompiler().compile(document).validate(first.value)
    try check("example-independent-verdict", independent.isValid)
    try check("example-exact", first.value.numberValue == JSONNumber(parsing: "9007199254740993"))
}

struct Chunks: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let bytes: [UInt8]
    struct Iterator: AsyncIteratorProtocol {
        let bytes: [UInt8]
        var offset = 0
        mutating func next() async -> JSONByteChunk? {
            guard offset < bytes.count else { return nil }
            defer { offset += 1 }
            return JSONByteChunk([bytes[offset]]) // Splits tokens and UTF-8 scalars.
        }
    }
    func makeAsyncIterator() -> Iterator { Iterator(bytes: bytes) }
}

// RECIPE streaming
func chunkedNDJSON() async throws {
    var iterator = NDJSONValueSequence(Chunks(bytes: Array("1\r\n\"é\"\nnull".utf8))).makeAsyncIterator()
    var values: [JSON] = []
    while let value = try await iterator.next() { values.append(value) }
    try check("ndjson-final-no-newline", values == [1, .string("é"), .null])
    let afterEOF = try await iterator.next()
    try check("ndjson-terminal-eof", afterEOF == nil)
    var bad = NDJSONValueSequence(Chunks(bytes: Array("1\n{\"x\":".utf8))).makeAsyncIterator()
    let first = try await bad.next()
    try check("ndjson-provisional-record", first == 1)
    do {
        _ = try await bad.next()
        throw RecipeFailure(id: "truncated-accepted")
    } catch let failure as JSONFailure {
        try check("ndjson-truncated", failure.category == .syntax && failure.code == .unexpectedEOF && failure.location?.record == 2)
    }
    let afterError = try await bad.next()
    try check("ndjson-terminal-error", afterError == nil)
    var limits = JSONLimits.balanced
    limits[.totalRecords] = 1
    var bounded = NDJSONValueSequence(Chunks(bytes: Array("1\n2".utf8)), options: .init(limits: limits)).makeAsyncIterator()
    _ = try await bounded.next()
    do {
        _ = try await bounded.next()
        throw RecipeFailure(id: "record-limit-accepted")
    } catch let failure as JSONFailure {
        try check("ndjson-cumulative-limit", failure.resource?.metric == .totalRecords)
    }
    let afterLimit = try await bounded.next()
    try check("ndjson-terminal-limit", afterLimit == nil)
}

// RECIPE navigation
func navigationCoverage() throws {
    let root = try JSON.parse(#"{"items":[1,null],"label":"x"}"#)
    let walk = JSONTraversal(document: JSONDocument(root: root))
    let physical = try walk.collect(scope: .subtree(at: [.key("items")]), maximumRecords: 3)
    try check("physical", physical.result.nodes.count == 3 && physical.result.summary.completion == .complete)
    let virtual = try walk.collect(scope: .virtual(roots: [[.key("label")], [.key("items"), .index(1)]]), maximumRecords: 2)
    try check("virtual", virtual.result.nodes.map(\.kind) == [.string, .null] && virtual.result.summary.completion == .complete)
    let restricted = try walk.collect(options: .init(depthLimit: 0), maximumRecords: 1)
    try check("coverage-restricted", restricted.result.summary.completion == .restricted)
    let stopped = try walk.visit { _, _ in .stop }
    try check("coverage-stopped", stopped.result.completion == .visitorStopped)
    var limits = JSONLimits.balanced
    limits[.workUnits] = physical.statistics[.workUnits] - 1
    do {
        _ = try JSONTraversal(document: walk.document, limits: limits).collect(scope: .subtree(at: [.key("items")]), maximumRecords: 3)
        throw RecipeFailure(id: "navigation-limit-accepted")
    } catch let failure as JSONFailure {
        try check("navigation-cumulative-limit", failure.resource?.metric == .workUnits)
    }
}

// RECIPE patch
func stagedPatch() throws {
    let original = try JSON.parse(#"{"n":1}"#)
    let success = try JSONPatch(json: JSON.parse(#"[{"op":"replace","path":"/n","value":2}]"#))
    try check("patch-success", success.applying(to: original) == .document(JSON.parse(#"{"n":2}"#)))
    let failure = try JSONPatch(json: JSON.parse(#"[{"op":"replace","path":"/n","value":2},{"op":"test","path":"/n","value":3}]"#))
    do {
        _ = try failure.applying(to: original)
        throw RecipeFailure(id: "failed-test-accepted")
    } catch let error as JSONFailure {
        try check("patch-failed-test", error.code == .failedTest)
    }
    try check("patch-caller-preserved", original == JSON.parse(#"{"n":1}"#))
    let remove = try JSONPatch(json: JSON.parse(#"[{"op":"remove","path":""}]"#)).applying(to: original)
    try check("root-removal", remove == .removed && remove != .document(.null))
    try check("merge-patch", JSONMergePatch(.null).applying(to: original) == .null)
}

// RECIPE html
func inertHTML() throws {
    let value = try JSON.buildObject { try $0.append("<img onerror=alert(1)>", value: .string("<script>alert(1)</script>")) }
    let html = try JSONHTMLRenderer().renderString(value)
    try check("html-escaped-value", html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    try check("html-escaped-key", html.contains("&lt;img onerror=alert(1)&gt;"))
    try check("html-inert-data", !html.contains("<script>alert(1)</script>") && !html.contains("<img onerror=alert(1)>"))
}

@main struct Consumer {
    static func main() async throws {
        try exactPresence()
        try nativeBridge()
        try schemaEvaluation()
        try certifiedExamples()
        try await chunkedNDJSON()
        try navigationCoverage()
        try stagedPatch()
        try inertHTML()
        print("KIT_RECIPES passed recipes=8 libraries=8")
    }
}
