// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming
@Test(arguments: [#"{"é":[true,null,-1.234e+5,"\uD834\uDD1E"]}"#, "1e-10", #"["a\"b\\c",{}]"#])
func streamEverySplitAgreesWithNativeParser(text: String) async throws {
    let expected = try JSONParser().parse(text)
    for split in 0...text.utf8.count {
        var values = JSONValueSequence(Chunks(text, split: split)).makeAsyncIterator()
        let value = try await values.next(); #expect(value == expected)
        let end = try await values.next(); #expect(end == nil)
        var completion = 0, scalars = 0
        for try await event in JSONEventSequence(Chunks(text, split: split)) {
            switch event { case .documentCompleted: completion += 1; case .scalar: scalars += 1; default: break }
        }
        #expect(completion == 1 && scalars > 0)
    }
}
