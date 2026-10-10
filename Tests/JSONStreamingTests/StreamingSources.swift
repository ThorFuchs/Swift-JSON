// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming
struct Chunks: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let chunks: [JSONByteChunk]
    init(_ text: String, split: Int? = nil) {
        let bytes = Array(text.utf8)
        if let split { chunks = [.init(Array(bytes.prefix(split))), .init(Array(bytes.dropFirst(split)))] }
        else { chunks = bytes.map { .init([$0]) } }
    }
    func makeAsyncIterator() -> Iterator { .init(chunks: chunks) }
    struct Iterator: AsyncIteratorProtocol {
        let chunks: [JSONByteChunk]; var index = 0
        mutating func next() async -> JSONByteChunk? {
            guard index < chunks.count else { return nil }; defer { index += 1 }; return chunks[index]
        }
    }
}
struct GeneratedArray: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let count: Int
    func makeAsyncIterator() -> Iterator { .init(count: count) }
    struct Iterator: AsyncIteratorProtocol {
        let count: Int; var index = -1
        mutating func next() async -> JSONByteChunk? {
            defer { index += 1 }
            if index == -1 { return .init([91]) }
            if index < count { return .init(index == 0 ? [48] : [44,48]) }
            if index == count { return .init([93]) }; return nil
        }
    }
}
actor Pulls { var count = 0; func pull() { count += 1 } }
struct ObservedChunks: AsyncSequence {
    typealias Element = JSONByteChunk
    let pulls: Pulls
    func makeAsyncIterator() -> Iterator { .init(pulls: pulls) }
    struct Iterator: AsyncIteratorProtocol {
        let pulls: Pulls; var index = 0
        mutating func next() async -> JSONByteChunk? { await pulls.pull(); index += 1; return index == 1 ? .init([91,48,44,49,93]) : nil }
    }
}
actor SinkBytes {
    var bytes: [UInt8] = [], calls = 0
    func accept(_ chunk: JSONByteChunk) async throws {
        calls += 1; await Task.yield(); bytes.append(contentsOf: chunk.bytes)
    }
}
enum SinkFailure: Error { case expected }
actor FailingSink { var calls = 0; func accept(_ chunk: JSONByteChunk) throws { calls += 1; throw SinkFailure.expected } }
struct EmptyChunks: AsyncSequence {
    typealias Element = JSONByteChunk
    func makeAsyncIterator() -> Iterator { Iterator() }
    struct Iterator: AsyncIteratorProtocol { mutating func next() async -> JSONByteChunk? { JSONByteChunk([]) } }
}
