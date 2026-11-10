// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming

private enum ImportError: Error, Equatable { case source }
private actor ImportSource {
    let texts: [String], failAt: Int?, cancelAt: Int?
    var pulls = 0
    init(_ texts: [String], failAt: Int? = nil, cancelAt: Int? = nil) {
        self.texts = texts; self.failAt = failAt; self.cancelAt = cancelAt
    }
    func next() throws -> JSONByteChunk? {
        pulls += 1
        if pulls == failAt { throw ImportError.source }
        // Test-only current-task handle stays inside its standard-library callback.
        // Only this invocation is cancelled; no unsafe handle escapes or is shared.
        if pulls == cancelAt { unsafe withUnsafeCurrentTask { unsafe $0?.cancel() } }
        return pulls <= texts.count ? .init(Array(texts[pulls - 1].utf8)) : nil
    }
    func count() -> Int { pulls }
}
private struct Source: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let state: ImportSource
    func makeAsyncIterator() -> Iterator { .init(state: state) }
    struct Iterator: AsyncIteratorProtocol {
        let state: ImportSource
        mutating func next() async throws -> JSONByteChunk? { try await state.next() }
    }
}
private struct ImportOutcome: Sendable {
    var accepted: [JSON] = [], committed: [JSON] = [], completions = 0
    var error: (any Error)?, terminal = false, statistics: JSONOperationStatistics?
}
// Atomic publication belongs to this test application. Earlier accepted values
// remain visible here even when the enclosing document can never be committed.
private func arrayImport(_ state: ImportSource, limits: JSONLimits = .balanced) async -> ImportOutcome {
    var result = ImportOutcome()
    var iterator = JSONTopLevelArraySequence(Source(state: state), options: .init(limits: limits)).makeAsyncIterator()
    do {
        while let event = try await iterator.next() {
            switch event {
            case .element(let index, let value):
                #expect(index == UInt64(result.accepted.count)); result.accepted.append(value)
            case .documentCompleted(let summary):
                result.completions += 1; result.statistics = summary.statistics
            }
        }
        if result.completions == 1 { result.committed = result.accepted }
    } catch { result.error = error }
    do { result.terminal = try await iterator.next() == nil } catch { result.terminal = false }
    return result
}
private func ndjsonImport(_ state: ImportSource, limits: JSONLimits = .balanced) async -> ImportOutcome {
    var result = ImportOutcome()
    var iterator = NDJSONValueSequence(Source(state: state), options: .init(limits: limits)).makeAsyncIterator()
    do {
        while let value = try await iterator.next() { result.accepted.append(value) }
        // Only normal exhaustive iteration certifies the NDJSON input for this caller.
        result.committed = result.accepted
    } catch { result.error = error }
    do { result.terminal = try await iterator.next() == nil } catch { result.terminal = false }
    return result
}
@Test func qaE2ERootImportCommitsOnlyAfterCertifiedCompletion() async {
    let source = ImportSource(["[1,", "2]", " \r\n"])
    let result = await arrayImport(source)
    #expect(result.error == nil && result.terminal && result.completions == 1)
    #expect(result.accepted == [1,2] && result.committed == [1,2])
    #expect(result.statistics?[.totalInputBytes] == 8 && result.statistics?[.totalRecords] == 2)
    #expect(await source.count() == 4)
}
@Test func qaE2ERootImportMalformedTailDoesNotCommitAcceptedElements() async throws {
    let source = ImportSource(["[1,", "2]", " false", "unused"])
    let result = await arrayImport(source)
    let failure = try #require(result.error as? JSONFailure)
    #expect(failure.category == .syntax && failure.code == .trailingData && failure.location?.byteOffset == 6)
    #expect(result.accepted == [1,2] && result.committed.isEmpty && result.completions == 0 && result.statistics == nil && result.terminal)
    #expect(await source.count() == 3)
}
@Test func qaE2ERootImportQuotaStopsBeforeCommitAndFurtherPulls() async throws {
    let source = ImportSource(["[1,", "2]", "unused"])
    var limits = JSONLimits.balanced; limits[.totalRecords] = 1
    let result = await arrayImport(source, limits: limits)
    let failure = try #require(result.error as? JSONFailure)
    #expect(failure.category == .resource && failure.resource?.metric == .totalRecords)
    #expect(failure.resource?.limit == 1 && failure.resource?.attemptedUsage == 2)
    #expect(result.accepted == [1] && result.committed.isEmpty && result.completions == 0 && result.terminal)
    #expect(await source.count() == 2)
}
@Test func qaE2ERootImportCancellationAfterProvisionalAcceptanceIsTerminal() async {
    let source = ImportSource(["[1,", "2]", "unused"], cancelAt: 2)
    let result = await Task { await arrayImport(source) }.value
    #expect(result.error is CancellationError && result.accepted == [1] && result.committed.isEmpty)
    #expect(result.completions == 0 && result.terminal && result.statistics == nil)
    #expect(await source.count() == 2)
}
@Test func qaE2ENDJSONImportStrictFramingCommitsOnlyAtEOF() async {
    let source = ImportSource(["1\r", "\n2", "\n"])
    let result = await ndjsonImport(source)
    #expect(result.error == nil && result.accepted == [1,2] && result.committed == [1,2] && result.terminal)
    #expect(await source.count() == 4)
}
@Test func qaE2ENDJSONImportFailuresKeepAcceptedPrefixWithoutCommit() async throws {
    for fault in 0..<4 {
        let source = ImportSource(fault == 0 ? ["1\n", "2 3\n", "unused"] : ["1\n", "2\n", "unused"], failAt: fault == 1 ? 2 : nil, cancelAt: fault == 2 ? 2 : nil)
        var limits = JSONLimits.balanced; if fault == 3 { limits[.totalRecords] = 1 }
        let result = await Task { await ndjsonImport(source, limits: limits) }.value
        switch fault {
        case 0:
            let failure = try #require(result.error as? JSONFailure)
            #expect(failure.category == .syntax && failure.code == .trailingData)
        case 1: #expect(result.error as? ImportError == .source)
        case 2: #expect(result.error is CancellationError)
        default:
            let failure = try #require(result.error as? JSONFailure)
            #expect(failure.category == .resource && failure.resource?.metric == .totalRecords)
        }
        #expect(result.accepted == [1] && result.committed.isEmpty && result.terminal)
        #expect(await source.count() == 2)
    }
}
