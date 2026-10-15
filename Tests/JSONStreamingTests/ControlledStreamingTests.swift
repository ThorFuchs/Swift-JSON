// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming

private enum ControlledError: Error, Equatable { case source, sink, overlappingPull }
private enum SourceReply: Sendable { case bytes(JSONByteChunk), eof, failure }
private struct SourceSnapshot: Sendable {
    let pulls: Int
    let held: Bool
    let finished: Bool
    let values: [JSON]
    let documentCompletions: Int
    let recordCompletions: Int
    let summary: JSONStreamSummary?
}
private actor SourceGate {
    let initial: [JSONByteChunk]
    var pulls = 0, finished = false, closed = false
    var pending: CheckedContinuation<JSONByteChunk?, any Error>?
    var observer: CheckedContinuation<Void, Never>?
    var values: [JSON] = []
    var documents = 0, records = 0
    var summary: JSONStreamSummary?
    init(_ texts: [String]) { initial = texts.map { JSONByteChunk(Array($0.utf8)) } }
    func notify() { if pending != nil || finished { observer?.resume(); observer = nil } }
    func next() async throws -> JSONByteChunk? {
        pulls += 1
        guard pending == nil else { throw ControlledError.overlappingPull }
        if closed { return nil }
        if pulls <= initial.count { return initial[pulls-1] }
        if pulls == initial.count+1 {
            guard pending == nil else { throw ControlledError.overlappingPull }
            return try await withCheckedThrowingContinuation { pending = $0; notify() }
        }
        return nil
    }
    func waitForHeldOrFinished() async {
        if pending != nil || finished { return }
        await withCheckedContinuation { observer = $0 }
    }
    func reply(_ reply: SourceReply) {
        let continuation = pending; pending = nil
        switch reply {
        case .bytes(let bytes): continuation?.resume(returning:bytes)
        case .eof: continuation?.resume(returning:nil)
        case .failure: continuation?.resume(throwing:ControlledError.source)
        }
    }
    func close() { closed = true; reply(.eof) }
    func done() { finished = true; notify() }
    func value(_ value: JSON) { values.append(value) }
    func completed(_ summary: JSONStreamSummary, document: Bool) {
        if document { documents += 1 } else { records += 1 }; self.summary = summary
    }
    func snapshot() -> SourceSnapshot {
        .init(pulls:pulls,held:pending != nil,finished:finished,values:values,
              documentCompletions:documents,recordCompletions:records,summary:summary)
    }
}
private struct ControlledSource: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let gate: SourceGate
    func makeAsyncIterator() -> Iterator { .init(gate:gate) }
    struct Iterator: AsyncIteratorProtocol {
        let gate: SourceGate
        mutating func next() async throws -> JSONByteChunk? { try await gate.next() }
    }
}
private struct ReadOutcome: Sendable { let error: (any Error)?; let terminalNil: Bool }
private func arrayTask(_ gate: SourceGate) -> Task<ReadOutcome,Never> {
    Task {
        var iterator = JSONTopLevelArraySequence(ControlledSource(gate:gate)).makeAsyncIterator()
        var failure: (any Error)?
        do {
            while let event = try await iterator.next() {
                switch event {
                case .element(let index,let value):
                    #expect(index == UInt64(await gate.snapshot().values.count)); await gate.value(value)
                case .documentCompleted(let summary): await gate.completed(summary,document:true)
                }
            }
        } catch { failure = error }
        let terminal: Bool
        do { terminal = try await iterator.next() == nil } catch { terminal = false }
        await gate.done()
        return .init(error:failure,terminalNil:terminal)
    }
}

@Test(StreamingTestPolicy.deadline) func qaStreamingRootCompletionWaitsForEOF() async throws {
    let gate = SourceGate(["[0] \r\n"]), task = arrayTask(gate)
    await gate.waitForHeldOrFinished()
    let before = await gate.snapshot()
    #expect(before.held && !before.finished && before.pulls == 2)
    #expect(before.values == [0] && before.documentCompletions == 0)
    await gate.reply(.eof)
    let result = await task.value; await gate.close()
    let after = await gate.snapshot()
    #expect(result.error == nil && result.terminalNil)
    #expect(after.documentCompletions == 1 && after.pulls == 2)
    #expect(after.summary?.records == 1 && after.summary?.statistics[.totalScannedNodes] == 2)
}
@Test(StreamingTestPolicy.deadline) func qaStreamingClosingSyntaxAndWhitespacePrecedeCompletion() async {
    let gate = SourceGate(["[0"]), task = arrayTask(gate)
    await gate.waitForHeldOrFinished()
    let before = await gate.snapshot()
    #expect(before.held && before.values.isEmpty && before.documentCompletions == 0)
    await gate.reply(.bytes(.init(Array("] \t\r\n".utf8))))
    let result = await task.value; await gate.close()
    let after = await gate.snapshot()
    #expect(result.error == nil && result.terminalNil && after.values == [0])
    #expect(after.documentCompletions == 1 && after.pulls == 3)
}
@Test(StreamingTestPolicy.deadline) func qaStreamingMalformedTailNeverCompletesAndStopsPulling() async throws {
    // An invalid token fails lexing; a valid second JSON root fails framing.
    // Keep both exact diagnoses rather than accepting any JSONFailure.
    for (tail, code) in [(" garbage", JSONFailure.Code.invalidSyntax), (" false", .trailingData)] {
        let gate = SourceGate(["[0]"]), task = arrayTask(gate)
        await gate.waitForHeldOrFinished()
        #expect(await gate.snapshot().values == [0])
        await gate.reply(.bytes(.init(Array(tail.utf8))))
        let result = await task.value; await gate.close()
        let failure = try #require(result.error as? JSONFailure)
        #expect(failure.category == .syntax && failure.code == code && failure.resource == nil)
        #expect(failure.location?.byteOffset == 4)
        let final = await gate.snapshot()
        #expect(result.terminalNil && final.documentCompletions == 0 && final.pulls == 2)
    }
}
@Test(StreamingTestPolicy.deadline) func qaStreamingSourceErrorAfterElementRemainsOperationalAndTerminal() async {
    let gate = SourceGate(["[0]"]), task = arrayTask(gate)
    await gate.waitForHeldOrFinished(); await gate.reply(.failure)
    let result = await task.value; await gate.close()
    #expect(result.error as? ControlledError == .source && result.terminalNil)
    let final = await gate.snapshot()
    #expect(final.values == [0] && final.documentCompletions == 0 && final.pulls == 2)
}
@Test(StreamingTestPolicy.deadline) func qaStreamingCancellationWhileEOFHeldSuppressesCompletion() async {
    let gate = SourceGate(["[0]"]), task = arrayTask(gate)
    await gate.waitForHeldOrFinished(); task.cancel(); await gate.reply(.eof)
    let result = await task.value; await gate.close()
    #expect(result.error is CancellationError && result.terminalNil)
    let final = await gate.snapshot()
    #expect(final.values == [0] && final.documentCompletions == 0 && final.pulls == 2)
}
@Test(StreamingTestPolicy.deadline) func qaStreamingFirstElementReturnDoesNotAwaitAnotherSourceChunk() async {
    let gate = SourceGate(["[0,"])
    let task = Task {
        var iterator = JSONTopLevelArraySequence(ControlledSource(gate:gate)).makeAsyncIterator()
        var yielded = false
        do { if case .element(let index,let value) = try await iterator.next() { yielded = index == 0 && value == 0 } }
        catch { }
        await gate.done(); return yielded
    }
    await gate.waitForHeldOrFinished()
    let state = await gate.snapshot()
    #expect(state.finished && !state.held && state.pulls == 1)
    await gate.close(); #expect(await task.value)
}
@Test(StreamingTestPolicy.deadline) func qaStreamingSeparatedEventsFinishAtEOFExactlyOnce() async {
    for text in ["false", "17", "{}"] {
        let gate = SourceGate([text])
        let task = Task {
            var iterator = JSONEventSequence(ControlledSource(gate:gate),options:.init(framing:.whitespaceSeparatedValues)).makeAsyncIterator()
            var succeeded = true
            do {
                while let event = try await iterator.next() {
                    switch event {
                    case .scalar(let value): await gate.value(value)
                    case .recordCompleted(let s): await gate.completed(s,document:false)
                    case .documentCompleted(let s): await gate.completed(s,document:true)
                    default: break
                    }
                }
                #expect(try await iterator.next() == nil)
            } catch { succeeded = false }
            await gate.done(); return succeeded
        }
        await gate.waitForHeldOrFinished()
        let before = await gate.snapshot()
        #expect(before.held && !before.finished && before.recordCompletions == 0 && before.documentCompletions == 0)
        await gate.reply(.eof); #expect(await task.value); await gate.close()
        let final = await gate.snapshot()
        #expect(final.recordCompletions == 1 && final.documentCompletions == 0 && final.pulls == 2)
        #expect(final.summary?.records == 1)
    }
}
@Test(StreamingTestPolicy.deadline) func qaStreamingSingleValueAndFinalNDJSONRecordWaitForEOF() async {
    for ndjson in [false,true] {
        let gate = SourceGate([ndjson ? "1\n2" : "2"])
        let task = Task {
            var succeeded = true
            do {
                if ndjson {
                    for try await value in NDJSONValueSequence(ControlledSource(gate:gate)) { await gate.value(value) }
                } else {
                    for try await value in JSONValueSequence(ControlledSource(gate:gate)) { await gate.value(value) }
                }
            } catch { succeeded = false }
            await gate.done(); return succeeded
        }
        await gate.waitForHeldOrFinished()
        let before = await gate.snapshot()
        #expect(before.held && !before.finished && before.values == (ndjson ? [1] : []))
        await gate.reply(.eof); #expect(await task.value); await gate.close()
        #expect(await gate.snapshot().values == (ndjson ? [1,2] : [2]))
    }
}

private enum SinkReply: Sendable { case accept, reject }
private struct SinkSnapshot: Sendable { let calls:Int; let bytes:[UInt8]; let held:Bool; let finished:Bool }
private actor SinkGate {
    let holdAt:Int
    var calls=0, bytes:[UInt8]=[], finished=false
    var pending:CheckedContinuation<Void,any Error>?
    var observer:CheckedContinuation<Void,Never>?
    init(holdAt:Int=1) { self.holdAt=holdAt }
    func notify() { if pending != nil || finished { observer?.resume(); observer=nil } }
    func accept(_ chunk:JSONByteChunk) async throws {
        calls += 1
        if calls == holdAt { try await withCheckedThrowingContinuation { pending=$0; notify() } }
        bytes.append(contentsOf:chunk.bytes)
    }
    func waitForHeldOrFinished() async {
        if pending != nil || finished { return }; await withCheckedContinuation { observer=$0 }
    }
    func reply(_ value:SinkReply) {
        let p=pending;pending=nil
        switch value { case .accept:p?.resume();case .reject:p?.resume(throwing:ControlledError.sink) }
    }
    func done() { finished=true;notify() }
    func snapshot() -> SinkSnapshot { .init(calls:calls,bytes:bytes,held:pending != nil,finished:finished) }
}
private struct WriteOutcome: Sendable { let error:(any Error)?; let report:JSONOperationStatistics? }
private func writerTask(_ gate:SinkGate,limits:JSONLimits = .balanced) -> Task<WriteOutcome,Never> {
    Task {
        let outcome:WriteOutcome
        do {
            let report=try await JSONAsyncWriter(options:.init(limits:limits),chunkSize:2).writeWithReport(.array([1,2,3])) { try await gate.accept($0) }
            outcome = .init(error:nil,report:report)
        } catch { outcome = .init(error:error,report:nil) }
        await gate.done();return outcome
    }
}
@Test(StreamingTestPolicy.deadline) func qaStreamingHeldSinkHasOneOutstandingHandoffUntilAcceptance() async {
    let gate=SinkGate(),task=writerTask(gate)
    await gate.waitForHeldOrFinished()
    let held=await gate.snapshot()
    #expect(held.held && !held.finished && held.calls == 1 && held.bytes.isEmpty)
    await gate.reply(.accept);let result=await task.value
    let final=await gate.snapshot()
    #expect(result.error == nil && final.bytes == Array("[1,2,3]".utf8) && final.calls == 4)
    #expect(result.report?[.outputBytes] == 7 && result.report?.domain == .writing)
}
@Test(StreamingTestPolicy.deadline) func qaStreamingHeldSinkFailureKeepsAcceptedPrefixAndStopsHandoffs() async {
    let gate=SinkGate(holdAt:2),task=writerTask(gate)
    await gate.waitForHeldOrFinished()
    let held=await gate.snapshot()
    #expect(held.calls == 2 && held.bytes == Array("[1".utf8) && !held.finished)
    await gate.reply(.reject);let result=await task.value
    let final=await gate.snapshot()
    #expect(result.error as? ControlledError == .sink && result.report == nil)
    #expect(final.calls == 2 && final.bytes == Array("[1".utf8))
}
@Test(StreamingTestPolicy.deadline) func qaStreamingCancellationAfterHeldAcceptanceKeepsOnlyAcceptedBytes() async {
    let gate=SinkGate(),task=writerTask(gate)
    await gate.waitForHeldOrFinished();task.cancel();await gate.reply(.accept)
    let result=await task.value;let final=await gate.snapshot()
    #expect(result.error is CancellationError && result.report == nil)
    #expect(final.calls == 1 && final.bytes == Array("[1".utf8))
}
@Test(StreamingTestPolicy.deadline) func qaStreamingOutputQuotaRefusalFollowsHeldChunkAcceptance() async throws {
    var limits=JSONLimits.balanced;limits[.outputBytes]=2
    let gate=SinkGate(),task=writerTask(gate,limits:limits)
    await gate.waitForHeldOrFinished()
    let held=await gate.snapshot()
    #expect(held.calls == 1 && held.held && !held.finished && held.bytes.isEmpty)
    await gate.reply(.accept);let result=await task.value
    let failure=try #require(result.error as? JSONFailure),resource=try #require(failure.resource)
    #expect(failure.category == .resource && failure.code == .limitExceeded)
    #expect(resource.domain == .writing && resource.metric == .outputBytes && resource.limit == 2)
    #expect(resource.attemptedUsage == 3 && !resource.overflow && result.report == nil)
    let final=await gate.snapshot()
    #expect(final.calls == 1 && final.bytes == Array("[1".utf8))
}
