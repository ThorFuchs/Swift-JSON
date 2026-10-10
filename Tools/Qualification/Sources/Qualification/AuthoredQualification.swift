// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONStreaming
import JSONPatch

struct ByteSource: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let bytes: [UInt8]
    let chunkSize: Int
    func makeAsyncIterator() -> Iterator { .init(bytes: bytes, chunkSize: chunkSize) }
    struct Iterator: AsyncIteratorProtocol {
        let bytes: [UInt8], chunkSize: Int
        var offset = 0
        mutating func next() async -> JSONByteChunk? {
            guard offset < bytes.count else { return nil }
            let end = Swift.min(bytes.count, offset + chunkSize)
            defer { offset = end }
            return .init(Array(bytes[offset..<end]))
        }
    }
}
private func verdict(_ bytes: [UInt8]) throws -> JSON? {
    do { return try JSONParser().parse(bytes) }
    catch let error as JSONFailure where error.category == .syntax { return nil }
}
private func streamVerdict(_ bytes: [UInt8], chunkSize: Int) async throws -> JSON? {
    var iterator = JSONValueSequence(ByteSource(bytes: bytes, chunkSize: chunkSize)).makeAsyncIterator()
    do {
        let result = try await iterator.next()
        guard try await iterator.next() == nil else { throw HarnessFailure("More than one root") }
        return result
    } catch let error as JSONFailure where error.category == .syntax { return nil }
}
private func isResource(_ operation: () throws -> Void, metric: JSONResourceMetric) -> Bool {
    do { try operation(); return false }
    catch let failure as JSONFailure { return failure.category == .resource && failure.resource?.metric == metric }
    catch { return false }
}
func qualifyAuthored(root: URL) async throws -> [AuthoredReceipt] {
    let url = root.appendingPathComponent("Tests/Fixtures/core-regressions.json"), data = try Data(contentsOf: url)
    let fixture = try JSONParser().parse(data)
    var semantics = AuthoredReceipt(name: "authored_public_semantics", input_sha256: digest(data))
    for item in try fixture["codec"].array() {
        let text = try item["utf8_text"].text(), id = try item["id"].text(), expected = try item["expected"].text()
        let result = try verdict(Array(text.utf8))
        semantics.check((result != nil) == expected.hasPrefix("accept"), id)
        if let result { semantics.check(try JSONParser().parse(JSONWriter().write(result)) == result, id + ":roundtrip") }
    }
    for item in try fixture["invalid_utf8"].array() {
        let hex = Array(try item["hex"].text().utf8)
        var bytes: [UInt8] = []
        for index in stride(from: 0, to: hex.count, by: 2) { bytes.append(UInt8(String(decoding: hex[index..<index+2], as: UTF8.self), radix: 16)!) }
        semantics.check(try verdict(bytes) == nil, try item["id"].text())
    }
    for row in try fixture["number_equivalence"].array() {
        let numbers = try row.array().map { try JSONNumber(parsing: $0.text()) }
        semantics.check(numbers.dropFirst().allSatisfy { $0 == numbers[0] }, "number-equivalence")
    }
    for row in try fixture["number_distinction"].array() {
        let numbers = try row.array().map { try JSONNumber(parsing: $0.text()) }
        semantics.check(numbers[0] != numbers[1], "number-distinction")
    }
    let distinct = try JSONParser().parse(#"{"é":1,"e\u0301":2}"#)
    semantics.check(distinct.objectValue?.count == 2, "scalar-key-identity")
    let reordered = try JSONParser().parse(#"{"e\u0301":2,"é":1}"#)
    semantics.check(distinct == reordered, "unordered-object-equality")
    for item in try fixture["pointer"].array() {
        let text = try item["text"].text()
        if item["decoded_tokens"].arrayValue != nil {
            let pointer = try JSONPointer(parsing: text)
            semantics.check(pointer.tokens.map(\.string) == (try item["decoded_tokens"].array().map { try $0.text() }), "pointer:" + text)
        } else {
            do { _ = try JSONPointer(parsing: text); semantics.check(false,"pointer:" + text) }
            catch let error as JSONFailure { semantics.check(error.category == .pointer,"pointer:" + text) }
        }
    }
    for item in try fixture["merge_patch"].array() {
        semantics.check(try JSONMergePatch(item["patch"]).applying(to: item["target"]) == item["expected"], "merge-patch")
    }
    let original = try JSONParser().parse(#"{"list":[1,2,3],"x":true}"#)
    let patch = try JSONPatch(json: JSONParser().parse(#"[{"op":"test","path":"/x","value":true},{"op":"move","from":"/list/0","path":"/list/2"},{"op":"copy","from":"/list","path":"/saved"},{"op":"replace","path":"/x","value":null},{"op":"add","path":"/list/-","value":4},{"op":"remove","path":"/list/0"}]"#))
    semantics.check(try patch.applying(to: original) == .document(JSONParser().parse(#"{"list":[3,1,4],"saved":[2,3,1],"x":null}"#)), "six-patch-operations")
    semantics.check(try JSONPatch(json: JSONParser().parse(#"[{"op":"remove","path":""}]"#)).applying(to: .null) == .removed, "root-removal-distinct-from-null")
    for value in try fixture["writer_control_scalars"].array() {
        let scalar = Unicode.Scalar(try value.integer())!, text = String(scalar)
        semantics.check(try JSONParser().parse(JSONWriter().write(.string(text))) == .string(text), "writer-control:\(scalar.value)")
    }
    for item in try fixture["array_stream"].array() {
        var count = 0, completed = false, failed = false
        do {
            for try await event in JSONTopLevelArraySequence(ByteSource(bytes: Array(try item["text"].text().utf8),chunkSize: 1)) {
                switch event { case .element: count += 1; case .documentCompleted: completed = true }
            }
        } catch let error as JSONFailure where error.category == .syntax { failed = true }
        let expectedComplete = item["completed"].booleanValue ?? false
        semantics.check(completed == expectedComplete && failed != expectedComplete, "root-array-completion")
        if expectedComplete { semantics.check(count == (try item["elements"].integer()), "root-array-elements") }
    }
    var budget = AuthoredReceipt(name: "public_budget_and_counter_boundaries")
    var limits = JSONLimits.balanced
    limits[.inputBytes] = 4
    budget.check(try JSONParser(options: .init(limits: limits)).parse("null").isNull,"input-inclusive")
    budget.check(isResource({ _ = try JSONParser(options: .init(limits: limits)).parse("null ") },metric: .inputBytes),"input-limit-plus-one")
    limits = .balanced; limits[.nodes] = 2
    budget.check(try JSONParser(options: .init(limits: limits)).parse("[0]") == .array([0]),"node-inclusive")
    budget.check(isResource({ _ = try JSONParser(options: .init(limits: limits)).parse("[0,1]") },metric: .nodes),"node-limit-plus-one")
    limits = .balanced; limits[.operations] = 0
    budget.check(isResource({ _ = try patch.applying(to: original,options: .init(limits: limits)) },metric: .operations),"operation-zero")
    let bytes = Array("[1,2]".utf8), parseReport = try JSONParser().parseWithReport(bytes)
    budget.check(parseReport.statistics[.inputBytes] == UInt64(bytes.count) && parseReport.statistics[.nodes] == 3 && parseReport.statistics[.workUnits] > 0,"parser-report-counts")
    let writeReport = try JSONWriter().writeWithReport(parseReport.result)
    budget.check(writeReport.statistics[.outputBytes] == UInt64(writeReport.result.count),"writer-report-counts")
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"type":"integer","minimum":9007199254740993}"#)))
    budget.check(try JSONSchemaValidator().validate(.number(JSONNumber(parsing: "9007199254740992")),against: plan).isValid == false,"exact-schema-bound")
    let cancellation = Task { () throws -> Void in
        while !Task.isCancelled { await Task.yield() }
        _ = try JSONParser().parse("null")
    }
    cancellation.cancel()
    do { try await cancellation.value; budget.check(false,"cancelled-entry") }
    catch is CancellationError { budget.check(true,"cancelled-entry") }
    return [semantics,budget,try await qualifyReplay()]
}
private struct ReplayRandom {
    var state: UInt64 = 0x53574946544a534f
    mutating func next() -> UInt64 { state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state }
}
private func qualifyReplay() async throws -> AuthoredReceipt {
    var random = ReplayRandom(), report = AuthoredReceipt(name: "deterministic_malformed_utf8_replay", seed: "0x53574946544a534f")
    let bases = [#"{"a":[true,null,9007199254740993,"é","\uD834\uDD1E"]}"#,"[{},[1,2],-0.1e-5]", "true", #""e\u0301""#]
    for index in 0..<4096 {
        var bytes = Array(bases[Int(random.next() % UInt64(bases.count))].utf8)
        let position = Int(random.next() % UInt64(bytes.count))
        switch random.next() % 4 {
        case 0: bytes[position] = UInt8(truncatingIfNeeded: random.next())
        case 1: bytes.remove(at: position)
        case 2: bytes.insert(UInt8(truncatingIfNeeded: random.next()),at: position)
        default: bytes = Array(bytes.prefix(position))
        }
        let native = try verdict(bytes), streamed = try await streamVerdict(bytes,chunkSize: Int(random.next() % 7) + 1)
        let id = "seed=0x53574946544a534f case=\(index) bytes=" + bytes.map { String(format: "%02x",$0) }.joined()
        report.check(native == streamed,id)
        if let native { report.check(try JSONParser().parse(JSONWriter().write(native)) == native,id + " roundtrip") }
    }
    return report
}
