// SPDX-License-Identifier: Apache-2.0
import Foundation
import CryptoKit
import JSON
import JSONSchema
import JSONPatch
import JSONStreaming

public enum ProbeFailure: Error { case assertion(String) }
public func verify(_ condition: Bool, _ name: String) throws { if !condition { throw ProbeFailure.assertion(name) } }
public struct FrozenFixtures: Decodable {
    public struct Item: Decodable {
        public let id: String
        public let inner_json: String
        public let inner_utf8_sha256: String
    }
    public let cases: [Item]
    public static func load() throws -> Self {
        guard let url = Bundle.module.url(forResource: "version1", withExtension: "json") else { throw ProbeFailure.assertion("fixture resource") }
        let value = try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
        try verify(value.cases.count == 8, "eight pinned fixtures")
        for item in value.cases {
            let hash = SHA256.hash(data: Data(item.inner_json.utf8)).map { String(format: "%02x", $0) }.joined()
            try verify(hash == item.inner_utf8_sha256, "fixture SHA-256")
        }
        return value
    }
}
public func exactBytes(_ value: JSON) throws -> Data { try JSONWriter(options: .init(numberStyle: .preserved)).write(value) }
public func publicBehavior() throws {
    let value = try JSONParser().parse(#"{"count":9007199254740993,"é":1,"é":2,"items":[0.1,null]}"#)
    let report = try value.readWithReport { root in
        try verify(root["count"].requiredInteger(as: UInt64.self) == 9007199254740993, "exact integer")
        try verify(root["é"].requiredInteger(as: Int.self) == 1 && root["é"].requiredInteger(as: Int.self) == 2, "scalar key identity")
        do { _ = try root["items"][0].requiredDouble(policy: .exact); throw ProbeFailure.assertion("exact binary refusal") }
        catch let error as JSONAccessFailure { try verify(error.cause.category == .conversion, "conversion classification") }
        try verify(root["items"][0].requiredDouble(policy: .rounded) == 0.1, "finite rounded binary bridge")
    }
    try verify(report.statistics[.workUnits] > 0 && report.statistics[.numericWorkUnits] > 0, "public cumulative counts")
    let registry = try JSONSchemaRegistry.draft2020_12()
    try verify(registry.documents.count == 9, "packaged pinned schemas with CryptoKit")
    let schema = try JSONSchemaDocument(JSONParser().parse(#"{"type":"object","properties":{"count":{"minimum":9007199254740993},"é":{"type":"integer"}},"required":["count","é"],"propertyNames":{"pattern":"^.+$"}}"#))
    let plan = try JSONSchemaCompiler().compile(schema)
    try verify(JSONSchemaValidator().validate(value, against: plan).isValid, "offline plan/native regex valid")
    try verify(!JSONSchemaValidator().validate(.null, against: plan).isValid, "ordinary invalid verdict")
    let patch = try JSONPatch(json: JSONParser().parse(#"[{"op":"test","path":"/count","value":9007199254740993},{"op":"replace","path":"/é","value":3}]"#))
    guard case .document(let changed) = try patch.applying(to: value) else { throw ProbeFailure.assertion("unexpected removed root") }
    try verify(changed.read { try $0["é"].requiredInteger(as: Int.self) } == 3 && value.read { try $0["é"].requiredInteger(as: Int.self) } == 1, "staged Patch")
    try verify(JSONMergePatch(.null).applying(to: value).isNull, "Merge Patch null")
    for fixture in try FrozenFixtures.load().cases {
        let payload = try JSONCodablePayload(preserving: JSONParser().parse(fixture.inner_json))
        let reopened = try PropertyListDecoder().decode(JSONCodablePayload.self, from: PropertyListEncoder().encode(payload))
        try verify(exactBytes(reopened.value()) == Data(fixture.inner_json.utf8), "opaque payload fidelity")
    }
}
private struct Chunks: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let text: String
    func makeAsyncIterator() -> Iterator { .init(bytes: Array(text.utf8)) }
    struct Iterator: AsyncIteratorProtocol {
        let bytes: [UInt8]; var offset = 0
        mutating func next() async -> JSONByteChunk? {
            guard offset < bytes.count else { return nil }
            defer { offset += 1 }; return .init([bytes[offset]])
        }
    }
}
private actor Sink {
    var bytes: [UInt8] = []
    func accept(_ chunk: JSONByteChunk) async { await Task.yield(); bytes.append(contentsOf: chunk.bytes) }
}
public func streamAndCancellation() async throws {
    var elements = 0, completed = 0
    for try await event in JSONTopLevelArraySequence(Chunks(text: "[0.1,null] \n")) {
        switch event { case .element(let index, _): try verify(index == UInt64(elements), "stream order"); elements += 1
        case .documentCompleted(let summary): try verify(summary.records == 2, "certified record count"); completed += 1 }
    }
    try verify(elements == 2 && completed == 1, "explicit completion")
    var bad = JSONTopLevelArraySequence(Chunks(text: "[0]x")).makeAsyncIterator()
    do {
        while let event = try await bad.next() { if case .documentCompleted = event { throw ProbeFailure.assertion("premature completion") } }
        throw ProbeFailure.assertion("trailing grammar accepted")
    } catch let error as JSONFailure { try verify(error.category == .syntax, "operational syntax error") }
    let end = try await bad.next(); try verify(end == nil, "terminal pull")
    let sink = Sink(), value = try JSONParser().parse(#"{"x":[0.1,null,"é"]}"#)
    let statistics = try await JSONAsyncWriter(chunkSize: 3).writeWithReport(value) { await sink.accept($0) }
    let written = await sink.bytes
    try verify(written == Array(JSONWriter().write(value)) && statistics[.outputBytes] == UInt64(written.count), "awaited sink")
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try value.read { _ in true }
    }
    do { _ = try await task.value; throw ProbeFailure.assertion("cancelled read succeeded") }
    catch is CancellationError { }
}
