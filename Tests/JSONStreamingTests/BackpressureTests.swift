// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming
@Test func earlyStopDoesNotPullAheadAndChunkAdmissionIsImmediate() async throws {
    let pulls = Pulls()
    var iterator = JSONTopLevelArraySequence(ObservedChunks(pulls: pulls)).makeAsyncIterator()
    _ = try await iterator.next()
    let count = await pulls.count; #expect(count == 1)
    var limits = JSONLimits.balanced; limits[.chunkBytes] = 1
    var tooBig = JSONEventSequence(Chunks("{}", split: 2), options: .init(limits: limits)).makeAsyncIterator()
    await #expect(throws: JSONFailure.self) { try await tooBig.next() }
}
@Test func awaitedSinkProducesIdenticalBytesAndStatistics() async throws {
    let value = try JSONParser().parse(#"{"é":"controls\n\t","array":[1e3,true,null]}"#)
    let sink = SinkBytes()
    let stats = try await JSONAsyncWriter(chunkSize: 3).writeWithReport(value) { try await sink.accept($0) }
    let bytes = await sink.bytes, calls = await sink.calls
    #expect(bytes == Array(try JSONWriter().write(value)))
    #expect(stats[.outputBytes] == UInt64(bytes.count) && calls == (bytes.count + 2) / 3)
}
@Test func sinkFailureAndCancelledEntryStopFurtherHandoffs() async throws {
    let sink = FailingSink()
    await #expect(throws: SinkFailure.self) { try await JSONAsyncWriter(chunkSize: 1).write(.array([1,2,3])) { try await sink.accept($0) } }
    let count = await sink.calls; #expect(count == 1)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        var iterator = JSONValueSequence(Chunks("1")).makeAsyncIterator()
        await #expect(throws: CancellationError.self) { try await iterator.next() }
    }
    await task.value
}
@Test func infiniteEmptyChunksConsumeLifetimeWork() async throws {
    var limits = JSONLimits.balanced; limits[.totalWorkUnits] = 4
    var iterator = JSONValueSequence(EmptyChunks(), options: .init(limits: limits)).makeAsyncIterator()
    await #expect(throws: JSONFailure.self) { try await iterator.next() }
}
