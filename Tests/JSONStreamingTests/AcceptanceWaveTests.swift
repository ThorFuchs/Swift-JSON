// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONStreaming

@Test func qaWideStreamEverySplitPreservesPayloadLexemesAndScalarKeys() async throws {
    let fields = (0..<33).map { "\"k\($0)\":\($0)" }.joined(separator: ",")
    let text = "{\(fields),\"é\":9007199254740993,\"é\":-0.00e+2,\"🚀\":0.1}"
    let expected = Data(text.utf8)
    for split in 0...text.utf8.count {
        var iterator = JSONValueSequence(Chunks(text + " \r\n", split: split)).makeAsyncIterator()
        let value = try #require(await iterator.next())
        let restored = try JSONCodablePayload(preserving: value).value()
        #expect(try JSONWriter(options: .init(numberStyle: .preserved)).write(restored) == expected)
        #expect(try restored.read { try $0["é"].requiredInteger(as: UInt64.self) } == 9_007_199_254_740_993)
        #expect(try await iterator.next() == nil)
    }
}

@Test func qaWideDuplicateFailureHasStableLocationAtEverySplit() async throws {
    let fields = (0..<33).map { "\"k\($0)\":null" }.joined(separator: ",")
    let prefix = "[{\(fields),"
    let text = prefix + "\"k0\" ???}]"
    for split in 0...text.utf8.count {
        var iterator = JSONTopLevelArraySequence(Chunks(text, split: split)).makeAsyncIterator()
        do {
            while let event = try await iterator.next() {
                if case .documentCompleted = event { Issue.record("Malformed document completed") }
            }
            Issue.record("Duplicate accepted")
        } catch let failure as JSONFailure {
            #expect(failure.code == .duplicateKey)
            #expect(failure.location?.byteOffset == UInt64(prefix.utf8.count))
        }
        #expect(try await iterator.next() == nil)
    }
}

private actor QACancellingSink {
    var accepted: [UInt8] = []
    func accept(_ chunk: JSONByteChunk) {
        accepted.append(contentsOf: chunk.bytes)
        if accepted.count == 3 { withUnsafeCurrentTask { $0?.cancel() } }
    }
}
@Test func qaSinkCancellationAfterAcceptanceKeepsPrefixAndStopsHandoffs() async throws {
    let value = try JSONParser().parse(#"{"é":[9007199254740993,0.1,null]}"#)
    let expected = Array(try JSONWriter().write(value))
    let task = Task {
        let sink = QACancellingSink()
        do {
            try await JSONAsyncWriter(chunkSize: 1).write(value) { chunk in
                await sink.accept(chunk)
            }
            Issue.record("Cancelled writer completed")
        } catch is CancellationError { }
        #expect(await sink.accepted == Array(expected.prefix(3)))
    }
    try await task.value
}
