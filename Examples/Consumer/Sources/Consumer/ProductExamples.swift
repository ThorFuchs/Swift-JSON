// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONPatch
import JSONSchema
import JSONStreaming
private struct ConsumerModel: Codable, Equatable {
    let count: UInt64
    let text: String
    let data: Data
}
private struct ConsumerChunks: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let bytes: [UInt8]
    func makeAsyncIterator() -> Iterator { .init(bytes: bytes) }
    struct Iterator: AsyncIteratorProtocol {
        let bytes: [UInt8]; var offset = 0
        mutating func next() async -> JSONByteChunk? {
            guard offset < bytes.count else { return nil }; defer { offset += 1 }; return JSONByteChunk([bytes[offset]])
        }
    }
}
private actor ConsumerSink {
    var bytes: [UInt8] = []
    func accept(_ chunk: JSONByteChunk) { bytes.append(contentsOf: chunk.bytes) }
}
func runProductExamples() async throws {
    let model = ConsumerModel(count: .max, text: "e\u{301}", data: Data([0,255]))
    let encoded = try JSONWriter().encode(model)
    let decoded = try JSONParser().decode(ConsumerModel.self, from: encoded)
    precondition(decoded == model)
    let value = try JSONParser().parse(#"{"list":[1,2],"present":null}"#)
    let pointer = try JSONPointer(tokens: ["list"]).appending(index: 1)
    let selected = try pointer.resolve(in: value)
    precondition(selected == 2)
    let patch = try JSONPatch(operations: [.remove(path: JSONPointer(parsing: "/present")), .add(path: JSONPointer(parsing: "/list/-"), value: 3)])
    let expected = try JSONParser().parse(#"{"list":[1,2,3]}"#)
    let patched = try patch.applying(to: value)
    precondition(patched == .document(expected))
    let merged = try JSONMergePatch(.null).applying(to: value)
    precondition(merged == .null)
    let report = try JSONWriter().writeWithReport(expected)
    precondition(report.statistics[.outputBytes] == UInt64(report.result.count))
    let resource = try JSONSchemaDocument(true, retrievalURI: JSONSchemaURI("https://example.test/schema"))
    let registry = try JSONSchemaRegistry(documents: [resource])
    requireSendable(resource); requireSendable(registry)
    precondition(registry.documents.count == 1)
    let declaration = try JSONSchemaDocument(JSONParser().parse(#"{"type":"object","properties":{"list":{"type":"array","items":{"type":"integer"}}},"required":["list"],"unevaluatedProperties":false}"#))
    let plan = try JSONSchemaCompiler().compile(declaration,registry: registry)
    requireSendable(plan)
    let result = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(expected,against: plan)
    requireSendable(result)
    precondition(result.isValid && result.diagnosticsComplete && !result.annotations.isEmpty)
    let schemaOutput = try result.output()
    precondition(schemaOutput.objectValue?["valid"] == true)
    let view = try plan.node()
    requireSendable(view)
    precondition(view.raw == declaration.raw)
    var values: [JSON] = []
    for try await record in NDJSONValueSequence(ConsumerChunks(bytes: Array("1\nfalse\n".utf8))) { values.append(record) }
    precondition(values == [1,false])
    var count = 0, complete = false
    for try await event in JSONTopLevelArraySequence(ConsumerChunks(bytes: Array("[1,2]".utf8))) {
        switch event { case .element: count += 1; case .documentCompleted: complete = true }
    }
    precondition(count == 2 && complete)
    let readmeCount = try await inspectArray(ConsumerChunks(bytes: Array("[1,2]".utf8)))
    precondition(readmeCount == 2)
    let sink = ConsumerSink()
    try await JSONAsyncWriter(chunkSize: 3).write(expected) { await sink.accept($0) }
    let sinkBytes = await sink.bytes
    precondition(sinkBytes == Array(report.result))
}
