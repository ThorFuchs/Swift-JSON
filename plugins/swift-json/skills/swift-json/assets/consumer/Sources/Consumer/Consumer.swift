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
import JSONInspection
import JSONTransform
import JSONValueDSL
import JSONSchemaDSL

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

// RECIPE located-stream
func locatedRootArray() async throws {
    let text = Array(#" [9007199254740993, {"k":"é"} ,null]"#.utf8)
    var spans: [(UInt64, JSONSourceSpan)] = []
    var completed = false
    for try await event in JSONLocatedTopLevelArraySequence(Chunks(bytes: text)) {
        switch event {
        case .element(let index, _, let span): spans.append((index, span)) // Provisional until completion.
        case .documentCompleted: completed = true
        }
    }
    let slices = spans.map { String(decoding: text[Int($0.1.start)..<Int($0.1.end)], as: UTF8.self) }
    try check("located-byte-spans", spans.map(\.0) == [0, 1, 2] && slices == ["9007199254740993", #"{"k":"é"}"#, "null"])
    try check("located-completed", completed)
    var truncated = JSONLocatedTopLevelArraySequence(Chunks(bytes: Array("[1,2".utf8))).makeAsyncIterator()
    var provisional = 0
    do {
        while let event = try await truncated.next() {
            if case .element = event { provisional += 1 }
            if case .documentCompleted = event { throw RecipeFailure(id: "truncated-array-completed") }
        }
        throw RecipeFailure(id: "truncated-array-accepted")
    } catch let failure as JSONFailure {
        try check("located-truncated", provisional == 2 && failure.code == .unexpectedEOF) // Yields did not certify.
    }
}

// RECIPE shape-snapshot
func shapeAndSnapshot() throws {
    let document = JSONDocument(root: try JSON.parse(#"[{"id":1,"note":null},{"id":2},{"id":"x","extra":true}]"#))
    let complete = try JSONShapeInspector(document: document).inspectArray()
    let id = complete.result.firstSeenColumns.first { $0.key == "id" }
    let note = complete.result.firstSeenColumns.first { $0.key == "note" }
    try check("shape-complete", complete.result.rowCoverage == .complete && complete.result.totalRows == 3)
    try check("shape-observed-kinds", id?.present == 3 && id?.kinds.numbers == 2 && id?.kinds.strings == 1)
    try check("shape-null-vs-missing", note?.explicitNull == 1 && note?.missing == 2)
    let prefix = try JSONShapeInspector(document: document).inspectArray(sampling: .prefix(maximumRows: 1))
    try check("shape-prefix-not-complete", prefix.result.rowCoverage == .prefix(examined: 1, total: 3))
    let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
    try check("snapshot-root", snapshot.record(at: 0).kind == .array && snapshot.record(at: 0).childCount == 3)
    try check("snapshot-value", snapshot.value(for: 1).result == document.root.arrayValue?[0])
}

// RECIPE batch
func orderedBatch() throws {
    let document = JSONDocument(root: try JSON.parse(#"{"n":9007199254740993,"note":null,"list":[1]}"#))
    let batch = JSONInspectionBatch(document: document)
    let paths: [[JSONLocationComponent]] = [[.key("n")], [.key("note")], [.key("n")]]
    let values = try batch.values(at: paths)
    try check("batch-ordered-repeats", values.result == [.number(try JSONNumber(parsing: "9007199254740993")), .null, .number(try JSONNumber(parsing: "9007199254740993"))])
    try check("batch-one-ledger", values.statistics[.workUnits] > 0)
    let optional = try batch.optionalValues(at: [[.key("note")], [.key("missing")], [.key("list"), .index(5)]])
    try check("optional-null-is-value", optional.result[0] == .some(.null))
    try check("optional-missing-is-nil", optional.result[1] == .none && optional.result[2] == .none)
    do {
        _ = try batch.values(at: [[.key("missing")]])
        throw RecipeFailure(id: "batch-missing-accepted")
    } catch let failure as JSONAccessFailure {
        try check("batch-missing-throws", failure.cause.code == .missingMember)
    }
    do {
        _ = try batch.optionalValues(at: [[.key("n"), .key("x")]])
        throw RecipeFailure(id: "optional-wrong-kind-accepted")
    } catch is JSONAccessFailure {
        try check("optional-wrong-kind-throws", true)
    }
    do {
        _ = try batch.values(at: paths, maximumRequests: 2)
        throw RecipeFailure(id: "batch-capacity-accepted")
    } catch let failure as JSONInspectionBatchFailure {
        try check("batch-request-limit", failure == .requestLimitExceeded(limit: 2, actual: 3))
    }
}

// RECIPE store
func configuredStore() throws {
    let document = JSONDocument(root: try JSON.parse(#"""
        {"users":[{"id":9007199254740993,"boss":null},{"id":7.0,"boss":{"collection":"users","id":9007199254740993}}],
         "tags":[{"id":"é"},{"id":"é"}]}
        """#))
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [], collections: [
        .init(name: "users", recordsAt: [.key("users")], idKey: "id", idKind: .integer,
              referenceFields: [.init(key: "boss", presence: .required, nullable: true)]),
        .init(name: "tags", recordsAt: [.key("tags")], idKey: "id", referenceFields: [])
    ], references: .strict(marker: .v1))
    let store = try JSONStoreBuilder(document: document, profile: profile).build().result
    try check("store-built", store.recordCount == 4 && store.collectionIndex(named: "tags") == 1)
    guard let seven = try store.lookup(collection: "users", id: 7).result,
          let big = try store.lookup(collection: "users", id: .integer(JSONNumber(parsing: "9007199254740993"))).result
    else { throw RecipeFailure(id: "store-lookup-missing") }
    try check("store-integer-exact", seven.row == 1 && big.row == 0)
    try check("store-no-kind-conversion", try store.lookup(collection: "users", id: "7").result == nil)
    let composed = try store.lookup(collection: "tags", id: "é").result
    let decomposed = try store.lookup(collection: "tags", id: "e\u{301}").result
    try check("store-scalar-ids", composed != nil && decomposed != nil && composed != decomposed)
    try check("store-follow-complete", try store.follow(from: seven).result == [seven, big])
    let values = try store.values(at: [big, seven, big])
    try check("store-batch", values.result.count == 3 && values.result[0] == values.result[2])
    var bounds = JSONStoreFollowLimits()
    bounds.maximumResults = 1
    do {
        _ = try store.follow(from: seven, bounds: bounds)
        throw RecipeFailure(id: "store-follow-truncated")
    } catch let failure as JSONStoreFailure {
        try check("store-follow-capacity", failure.code == .capacityExceeded && failure.capacity == .maximumResults)
    }
    let rebuilt = try JSONStoreBuilder(document: document, profile: profile).build().result
    do {
        _ = try rebuilt.value(at: seven)
        throw RecipeFailure(id: "store-foreign-position")
    } catch let failure as JSONStoreFailure {
        try check("store-owner-bound", failure.code == .invalidPosition)
    }
    let dangling = JSONDocument(root: try JSON.parse(#"{"users":[{"id":1,"boss":{"collection":"users","id":2}}],"tags":[]}"#))
    do {
        _ = try JSONStoreBuilder(document: dangling, profile: profile).build()
        throw RecipeFailure(id: "store-dangling-accepted")
    } catch let failure as JSONStoreFailure {
        try check("store-dangling-refused", failure.code == .referenceDanglingID)
    }
}

// RECIPE transform
func boundedTransform() throws {
    let program = try JSONTransformProgram.compile(".[] | .amount")
    let input = try JSON.parse(#"[{"amount":9007199254740993},{"amount":0.10000000000000001}]"#)
    let output = try program.withExecution(input: input) { execution in
        var values: [JSON] = []
        while let next = try execution.next() { values.append(next.value) } // Pull to EOF.
        return values
    }
    let text = String(decoding: try JSONWriter(options: .init(numberStyle: .preserved)).write(.array(output.result)), as: UTF8.self)
    try check("transform-exact", text == "[9007199254740993,0.10000000000000001]")
    var limits = JSONTransformLimits()
    limits[.results] = 1
    do {
        _ = try program.withExecution(input: input, limits: limits) { execution in
            while try execution.next() != nil {}
        }
        throw RecipeFailure(id: "transform-limit-accepted")
    } catch let failure as JSONTransformFailure {
        try check("transform-terminal-limit", failure.category == .resource && failure.metric == "results")
    }
    let selection = try JSONTransformProgramDefinition.prepare(
        source: ".[] | select($values[.].enabled)", variables: ["values"]).result.compile().result
    let row = try JSON.parse(#"{"enabled":true}"#)
    let off = try JSON.parse(#"{"enabled":false}"#)
    let indices = try selection.selectIndices(in: [row, off, row])
    try check("select-indices", indices.result == [0, 2] && indices.completion.populationCount == 3)
    do {
        _ = try selection.withSelection(population: [row, row]) { scope in try scope.next() }
        throw RecipeFailure(id: "selection-prefix-accepted")
    } catch let failure as JSONTransformSelectionFailure {
        try check("selection-incomplete", failure == .incompleteSelection)
    }
}

// RECIPE dsl
func authoredDSL() throws {
    let tenth = try JSONNumber(parsing: "0.1")
    let value = try JSONValueDSL.object {
        Field("id", UInt64(9_007_199_254_740_993))
        Field("amount", exactNumber: tenth)
        Field("é", 1)
        Field("e\u{301}", 2)
    }
    try check("dsl-exact-keys", value.objectValue?.count == 4 && value.objectValue?["é"] == 1)
    let schema = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties {
            Property("id") { Schema.type(.integer) }
            Property("amount") { Schema.type(.number); Schema.multipleOf(tenth) }
        }
        Schema.required("id", "amount")
    }
    let plan = try JSONSchemaCompiler().compile(schema)
    try check("dsl-valid", try JSONSchemaValidator().validate(value, against: plan).isValid)
    let missing = try JSONValueDSL.object { Field("id", 1) }
    try check("dsl-invalid", !(try JSONSchemaValidator().validate(missing, against: plan).isValid))
    let reference = try JSONSchemaDSL.document { Schema.reference("https://not-supplied.invalid/schema") }
    do {
        _ = try JSONSchemaCompiler().compile(reference)
        throw RecipeFailure(id: "dsl-network-fetch")
    } catch let failure as JSONSchemaCompilationFailure {
        try check("dsl-offline-missing-resource", failure.category == .missingResource)
    }
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
        try await locatedRootArray()
        try shapeAndSnapshot()
        try orderedBatch()
        try configuredStore()
        try boundedTransform()
        try authoredDSL()
        print("KIT_RECIPES passed recipes=14 libraries=12")
    }
}
