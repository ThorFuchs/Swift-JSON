// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming
@Test func rootArrayAllElementsCompleteOnceAtEverySplit() async throws {
    let text = #"[{},[1,2],"\uD834\uDD1E",1e3,null,false]"#
    let expected = try JSONParser().parse(text).arrayValue!
    for split in 0...text.utf8.count {
        var values: [JSON] = [], completed = 0
        for try await event in JSONTopLevelArraySequence(Chunks(text, split: split)) {
            switch event {
            case .element(let index, let value): #expect(index == UInt64(values.count)); values.append(value)
            case .documentCompleted(let summary): completed += 1; #expect(summary.records == 6 && summary.statistics[.totalScannedNodes] == 9)
            }
        }
        #expect(values == expected && completed == 1)
    }
    var empty = 0
    for try await event in JSONTopLevelArraySequence(Chunks("[]")) { if case .documentCompleted(let s) = event { empty += 1; #expect(s.records == 0) } }
    #expect(empty == 1)
}
@Test(arguments: ["[1", "[1,]", "[1 2]", "[1]x", "[1,{}", "{}"])
func malformedRootArrayNeverCompletes(text: String) async throws {
    var completed = false
    var iterator = JSONTopLevelArraySequence(Chunks(text)).makeAsyncIterator()
    await #expect(throws: JSONFailure.self) {
        while let event = try await iterator.next() { if case .documentCompleted = event { completed = true } }
    }
    #expect(!completed)
    let end = try await iterator.next(); #expect(end == nil)
}
