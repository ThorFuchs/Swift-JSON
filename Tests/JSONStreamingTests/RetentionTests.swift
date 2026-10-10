// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming
@Test func generatedArrayResetsElementBudgetsAndKeepsLifetimeLimits() async throws {
    var limits = JSONLimits.balanced
    limits[.inputBytes] = 2; limits[.nodes] = 1; limits[.arrayItems] = 1; limits[.retainedBytes] = 1024
    var count = 0, peak: UInt64 = 0
    for try await event in JSONTopLevelArraySequence(GeneratedArray(count: 10_000), options: .init(limits: limits)) {
        switch event { case .element: count += 1; case .documentCompleted(let s): peak = s.statistics.peakLogicalRetainedBytes; #expect(s.statistics[.totalScannedNodes] == 10_001) }
    }
    #expect(count == 10_000 && peak < 1024)
    limits[.totalRecords] = 3
    var iterator = JSONTopLevelArraySequence(GeneratedArray(count: 4), options: .init(limits: limits)).makeAsyncIterator()
    await #expect(throws: JSONFailure.self) { while try await iterator.next() != nil {} }
    limits = .balanced; limits[.maxDepth] = 1
    var depth = JSONTopLevelArraySequence(Chunks("[[]]"), options: .init(limits: limits)).makeAsyncIterator()
    await #expect(throws: JSONFailure.self) { while try await depth.next() != nil {} }
}
