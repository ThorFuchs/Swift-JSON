// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONStreaming
import JSONPatch
import JSONHTML

public enum ProbeFailure: Error { case assertion(String) }
func require(_ value: Bool, _ message: String) throws {
    guard value else { throw ProbeFailure.assertion(message) }
}
func rejects(_ category: JSONFailure.Category, _ body: () throws -> Void) throws {
    do { try body() } catch let failure as JSONFailure {
        try require(failure.category == category, "Unexpected failure: \(failure)"); return
    }
    throw ProbeFailure.assertion("Expected \(category)")
}

/// Public WASI consumer: package defaults remain finite and unchanged.
public enum Probes {
    public static let limits = JSONLimits.balanced
    public static func parse(_ text: String) throws -> JSON {
        try JSONParser(options: .init(limits: limits)).parse(text)
    }
    public static func profiles() throws {
        print("TARGET int_bits=\(Int.bitWidth)")
        for (name, profile) in [("conservative", JSONLimits.conservative), ("balanced", .balanced), ("offline", .offline)] {
            try profile.validate()
            let value = try JSONParser(options: .init(limits: profile)).parse("9007199254740993")
            try require(try value.numberValue!.integer(as: UInt64.self, limits: profile) == 9_007_199_254_740_993, "Profile exactness")
            print("PROFILE \(name) passed")
        }
        try require(try JSONParser().parse("0") == 0, "Default parser")
        print("DEFAULT_PARSER passed")
    }

    public static func exactNumbers() throws {
        let n = try JSONNumber(parsing: "9007199254740993", limits: limits)
        try require(try n.integer(as: UInt64.self, limits: limits) == 9_007_199_254_740_993, "Lost exact integer")
        try require(try parse("1.0") == parse("1e0"), "Decimal identity")
        try require(try parse("-0") == parse("0"), "Zero identity")
        try rejects(.conversion) { _ = try n.integer(as: Int32.self, limits: limits) }
        let tenth = try JSONNumber(parsing: "0.1", limits: limits)
        try rejects(.conversion) { _ = try tenth.doubleValue(policy: .exact, limits: limits) }
        try require(try tenth.doubleValue(policy: .rounded, limits: limits) == 0.1, "Rounded projection")
        try require(try tenth.decimalValue(policy: .exact, limits: limits) == Decimal(string: "0.1"), "Decimal projection")
    }
    public static func scalarKeysAndOrder() throws {
        let value = try parse(#"{"é":1,"e\u0301":2,"n":null}"#)
        let object = value.objectValue!
        try require(object.count == 3 && object["é"] == 1 && object["e\u{301}"] == 2, "Collapsed scalar keys")
        let reordered = try parse(#"{"n":null,"e\u0301":2,"é":1}"#)
        try require(try JSONComparison.equals(value, reordered, limits: limits), "Order-dependent equality")
        let text = try JSONWriter(options: .init(limits: limits)).writeString(value)
        try require(text.utf8.starts(with: Array(#"{"é":1"#.utf8)), "Changed insertion order")
        try require(object.presence(of: "n") == .null && object.presence(of: "missing") == .absent, "Presence")
    }
    public static func strictCodecAndPointer() throws {
        for text in ["", "01", "[1,]", "{} false", #"{"x":1,"\u0078":2}"#, #""\uD800""#] {
            try rejects(.syntax) { _ = try parse(text) }
        }
        let parser = JSONParser(options: .init(limits: limits))
        try rejects(.syntax) { _ = try parser.parse([UInt8(0xff)]) }
        let value = try parse(#"{"a/b":{"~":[9007199254740993]}}"#)
        let pointer = try JSONPointer(parsing: "/a~1b/~0/0", limits: limits)
        try require(try pointer.resolve(in: value, limits: limits) == parse("9007199254740993"), "Pointer")
    }
    public static func codingAndScope() throws {
        struct Model: Codable, Equatable { let count: UInt64; let bytes: Data }
        let model = Model(count: 9_007_199_254_740_993, bytes: Data([0, 1, 255]))
        let options = JSONCodingOptions(limits: limits)
        let value = try JSONValueEncoder(options: options).encode(model)
        try require(try JSONValueDecoder(options: options).decode(Model.self, from: value) == model, "Native Codable")
        var escaped: JSONReadCursor?
        let report = try value.readWithReport(limits: limits) { root in
            escaped = root
            let integer = try root["count"].requiredInteger(as: UInt64.self)
            let projection = try root.decode(Model.self, coding: options)
            return (integer, projection)
        }
        try require(report.result.0 == model.count && report.result.1 == model, "Scoped projection")
        try require(report.statistics[.workUnits] > 0 && report.statistics[.retainedBytes] == 0, "Cumulative scope accounting")
        try rejects(.configuration) { _ = try escaped!.requiredObject() }
    }
    public static func cumulativeBudgets() throws {
        var constrained = limits; constrained[.workUnits] = 150
        try rejects(.resource) {
            _ = try JSONSchemaBuilder.object(limits: constrained) { builder in
                try builder.append("description", value: .string(String(repeating: "x", count: 100)))
            }
        }
        constrained = limits; constrained[.workUnits] = 2
        try rejects(.resource) { _ = try JSONParser(options: .init(limits: constrained)).parse("[1,2,3]") }
    }
    public static func payloadObservation() throws {
        let value = try parse(#"{"n":9007199254740993}"#)
        let payload = try JSONCodablePayload(preserving: value, limits: limits)
        let encoded = try PropertyListEncoder().encode(payload)
        let opened = try PropertyListDecoder().decode(JSONCodablePayload.self, from: encoded)
        try require(try opened.value(limits: limits) == value, "Persistence envelope")
        print("PERSISTENCE passed")
    }

    public static func resourceRegistry() throws {
        let registry = try JSONSchemaRegistry.draft2020_12(limits: limits)
        try require(registry.documents.count == 9, "Missing pinned resources")
    }
    public static func schemaAndRegex() throws {
        let document = try JSONSchemaDocument(parse(##"{"$defs":{"n":{"type":"integer","minimum":9007199254740993}},"$ref":"#/$defs/n"}"##), limits: limits)
        let compiler = JSONSchemaCompiler(options: .init(limits: limits))
        let plan = try compiler.compile(document)
        let validator = JSONSchemaValidator(options: .init(limits: limits))
        try require(try validator.validate(parse("9007199254740993"), against: plan).isValid, "Exact schema bound")
        try require(try !validator.validate(parse("9007199254740992"), against: plan).isValid, "Invalid versus operational")
        let pattern = try JSONSchemaDocument(parse(#"{"type":"string","pattern":"^(?<a>a+)\\k<a>$"}"#), limits: limits)
        let regexPlan = try compiler.compile(pattern)
        try require(try validator.validate(.string("aaaa"), against: regexPlan).isValid, "Regex backreference")
        try require(try !validator.validate(.string("aaa"), against: regexPlan).isValid, "Regex rejection")
        var exhausted = limits; exhausted[.evaluationWorkUnits] = 1
        try rejects(.resource) { _ = try JSONSchemaValidator(options: .init(limits: exhausted)).validate(parse("9007199254740993"), against: plan) }
    }
    public static func patches() throws {
        let value = try parse(#"{"n":1,"a":[1,2]}"#)
        let patch = try JSONPatch(json: parse(#"[{"op":"replace","path":"/n","value":9007199254740993}]"#), options: .init(limits: limits))
        let changed = try patch.applying(to: value, options: .init(limits: limits))
        try require(changed == .document(parse(#"{"n":9007199254740993,"a":[1,2]}"#)), "RFC 6902")
        let removal = try JSONPatch(json: parse(#"[{"op":"remove","path":""}]"#), options: .init(limits: limits))
        try require(try removal.applying(to: value, options: .init(limits: limits)) == .removed, "Root removal")
        let merged = try JSONMergePatch(parse(#"{"n":null,"a":[3]}"#)).applying(to: value, options: .init(limits: limits))
        try require(merged == parse(#"{"a":[3]}"#), "RFC 7396")
        try require(value == parse(#"{"n":1,"a":[1,2]}"#), "Mutated caller value")
    }
}

private struct Chunks: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let bytes: [UInt8]
    struct AsyncIterator: AsyncIteratorProtocol {
        let bytes: [UInt8]; var offset = 0
        mutating func next() async throws -> JSONByteChunk? {
            try Task.checkCancellation()
            guard offset < bytes.count else { return nil }
            defer { offset += 1 }; return JSONByteChunk([bytes[offset]])
        }
    }
    func makeAsyncIterator() -> AsyncIterator { .init(bytes: bytes) }
}
private actor Sink {
    var bytes: [UInt8] = []; var calls = 0
    func accept(_ chunk: JSONByteChunk) async { await Task.yield(); calls += 1; bytes.append(contentsOf: chunk.bytes) }
}
extension Probes {
    public static func sharedPlan() async throws {
        let schema = try JSONSchemaDocument(parse(#"{"type":"string","pattern":"^a+$"}"#), limits: limits)
        let plan = try JSONSchemaCompiler(options: .init(limits: limits)).compile(schema)
        let count = try await withThrowingTaskGroup(of: Bool.self) { group in
            for index in 0..<8 {
                group.addTask {
                    await Task.yield()
                    let valid = try JSONSchemaValidator(options: .init(limits: limits)).validate(.string(index % 2 == 0 ? "aaa" : "bbb"), against: plan).isValid
                    return valid == (index % 2 == 0)
                }
            }
            var completed = 0
            for try await correct in group { try require(correct, "Shared plan invocation interference"); completed += 1 }
            return completed
        }
        try require(count == 8, "Missing shared plan evaluations")
    }
    public static func streams() async throws {
        var count = 0, complete = false
        for try await event in JSONTopLevelArraySequence(Chunks(bytes: Array("[1,2] \n".utf8)), options: .init(limits: limits)) {
            switch event {
            case .element(let index, _): try require(index == UInt64(count), "Stream index"); count += 1
            case .documentCompleted: complete = true
            }
        }
        try require(count == 2 && complete, "Missing completion")
        count = 0; complete = false
        do {
            for try await event in JSONTopLevelArraySequence(Chunks(bytes: Array("[1,2]x".utf8)), options: .init(limits: limits)) {
                if case .element = event { count += 1 }; if case .documentCompleted = event { complete = true }
            }
            throw ProbeFailure.assertion("Accepted invalid tail")
        } catch let error as JSONFailure { try require(error.category == .syntax, "Operational stream failure") }
        try require(count == 2 && !complete, "Provisional elements certified tail")
        var records = 0
        for try await _ in NDJSONValueSequence(Chunks(bytes: Array("1\r\n2\n".utf8)), options: .init(limits: limits)) { records += 1 }
        try require(records == 2, "NDJSON")
        do {
            for try await _ in NDJSONValueSequence(Chunks(bytes: Array("1\n\n".utf8)), options: .init(limits: limits)) { }
            throw ProbeFailure.assertion("Skipped blank NDJSON record")
        } catch let error as JSONFailure { try require(error.category == .syntax, "NDJSON error") }
    }
    public static func awaitedSink() async throws {
        let sink = Sink(), value = try parse("[1,2,3]")
        let statistics = try await JSONAsyncWriter(options: .init(limits: limits), chunkSize: 2).writeWithReport(value) { await sink.accept($0) }
        let bytes = await sink.bytes, calls = await sink.calls
        try require(try JSONParser(options: .init(limits: limits)).parse(bytes) == value, "Awaited output")
        try require(calls == 4 && statistics[.outputBytes] == 7, "Sink accounting")
    }
    public static func cancellation() async throws {
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do { _ = try JSONParser(options: .init(limits: limits)).parse("0"); return false }
            catch is CancellationError { return true }
        }
        try require(await cancelled.value, "Cancellation not observed")
        let sink = Sink()
        let stopped = Task {
            do {
                try await JSONAsyncWriter(options: .init(limits: limits), chunkSize: 1).write(try parse("[1,2,3]")) { chunk in
                    await sink.accept(chunk); withUnsafeCurrentTask { $0?.cancel() }
                }
                return false
            } catch is CancellationError { return true }
        }
        try require(try await stopped.value, "Writer cancellation not observed")
        try require(await sink.calls == 1, "Writes after cancellation")
    }
}

extension Probes {
    /// Fixed bounded calibration workload; it does not establish an RSS cap.
    public static func benchmark() async throws {
        let bytes = Array(("[" + Array(repeating: "9007199254740993", count: 1000).joined(separator: ",") + "]").utf8)
        var peak: UInt64 = 0, work: UInt64 = 0
        for _ in 0..<10 {
            let report = try JSONParser().parseWithReport(bytes)
            try require(report.result.arrayValue?.count == 1000, "Calibration parse")
            peak = max(peak, report.statistics.peakLogicalRetainedBytes)
            work += report.statistics[.workUnits]
        }
        let framed = Array(Array(repeating: "0", count: 1000).joined(separator: "\n").appending("\n").utf8)
        var records = 0
        for try await _ in NDJSONValueSequence(Chunks(bytes: framed)) { records += 1 }
        try require(records == 1000, "Calibration records")
        print("WASI_CALIBRATION parse_invocations=10 input_bytes=\(bytes.count) records=\(records) parse_logical_peak=\(peak) parse_work=\(work)")
    }
}

extension Probes {
    /// Five-product portable rendering, finite preparation and unavailable PDF boundary.
    public static func htmlRenderingAndExports() async throws {
        let source = #"{"é":9007199254740993,"e\u0301":-0.00e+2,"end":"LAST-CONTENT-SENTINEL</script>"}"#
        let root = try parse(source)
        let formatted = try JSONHTMLRenderer().renderStringWithReport(root)
        try require(formatted.result.contains("9007199254740993") && formatted.result.contains("-0.00e+2")
            && formatted.result.contains("&lt;/script&gt;") && formatted.statistics.operation[.workUnits] > 0, "Static exact HTML")
        print("CASE formatted_html_exact_scalars passed")
        let interactive = try JSONHTMLRenderer(options: .init(presentation: .interactive)).renderString(root)
        try require(interactive.contains("Content-Security-Policy") && interactive.contains("LAST-CONTENT-SENTINEL")
            && interactive.contains("9007199254740993"), "Interactive complete bytes")
        print("CASE interactive_html_complete_csp passed")
        let fence = String(repeating: String(UnicodeScalar(96)), count: 3)
        for value in [JSON.null, true, 1, .string("😀\u{e9}e\u{301}"), .array([]), .object(try JSONObject(members: [])), root] {
            let result = try JSONExportDocument.prepareWithReport(value, options: .init(formats: [.json,.html,.plainText,.markdown,.rtf], compactJSON: true))
            let exact = try JSONWriter(options: .init(numberStyle: .preserved)).write(value)
            try require(try result.result.data(for: .json) == exact, "Native artifact exact bytes")
            try require(result.result.availableFormats.count == 5 && result.operation[.workUnits] > 0, "Five portable artifacts")
            let markdown = String(decoding: try result.result.data(for: .markdown), as: UTF8.self)
            try require(markdown.hasPrefix(fence+"json\n") && markdown.hasSuffix("\n"+fence+"\n"), "Markdown fence")
            try require(String(decoding: try result.result.data(for: .rtf), as: UTF8.self).hasPrefix("{\\rtf1"), "Actual styled RTF")
        }
        print("CASE five_portable_prepared_formats passed")
        var options = JSONHTMLRenderingOptions(); options.limits.maxDocumentBytes = 0
        var exhausted = false
        do { _ = try JSONHTMLRenderer(options: options).render(root) }
        catch let failure as JSONHTMLFailure {
            if case .limitExceeded(.documentBytes, limit: 0, attempted: _) = failure { exhausted = true }
        }
        try require(exhausted, "HTML capacity ignored")
        print("CASE html_finite_capacity passed")
        let gate = ExportCancellationGate()
        let canceled = Task { await gate.wait(); return try JSONExportDocument.prepare(root) }
        canceled.cancel(); await gate.release()
        var canceledCorrectly = false
        do { _ = try await canceled.value } catch is CancellationError { canceledCorrectly = true }
        try require(canceledCorrectly, "Portable cancellation ignored")
        print("CASE export_terminal_cancellation passed")
        let prepared = try JSONExportDocument.prepare(root)
        #if !canImport(WebKit)
        var unavailable = false
        do { _ = try await prepared.preparingPDF() }
        catch JSONPDFFailure.backendUnavailable { unavailable = true }
        try require(unavailable && !prepared.availableFormats.contains(.pdf), "PDF backend fallback")
        #else
        var rejected = false
        do { _ = try JSONExportDocument.prepare(root, options: .init(formats: [.pdf])) }
        catch JSONExportFailure.preparationRequired(.pdf) { rejected = true }
        try require(rejected && !prepared.availableFormats.contains(.pdf), "Implicit PDF rendering")
        #endif
        print("CASE explicit_pdf_platform_boundary passed")
    }
}

private actor ExportCancellationGate {
    var opened = false
    var continuation: CheckedContinuation<Void, Never>?
    func wait() async { if !opened { await withCheckedContinuation { continuation = $0 } } }
    func release() { opened = true; continuation?.resume(); continuation = nil }
}
