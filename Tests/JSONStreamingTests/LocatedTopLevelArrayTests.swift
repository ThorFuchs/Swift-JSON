// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming

/// Everything one located iterator produced, in pull order.
private struct LocatedRun {
    var elements: [(index: UInt64, value: JSON, span: JSONSourceSpan)] = []
    var completions: [JSONStreamSummary] = []
    var failure: JSONFailure?
}
/// Everything one value-only iterator produced, in pull order.
private struct PlainRun {
    var elements: [(index: UInt64, value: JSON)] = []
    var completions: [JSONStreamSummary] = []
    var failure: JSONFailure?
}
private func locate<S: AsyncSequence>(_ source: S, limits: JSONLimits = .balanced) async -> LocatedRun where S.Element == JSONByteChunk {
    var run = LocatedRun()
    var iterator = JSONLocatedTopLevelArraySequence(source, options: .init(limits: limits)).makeAsyncIterator()
    do {
        while let event = try await iterator.next() {
            switch event {
            case .element(let index, let value, let span): run.elements.append((index, value, span))
            case .documentCompleted(let summary): run.completions.append(summary)
            }
        }
    } catch let failure as JSONFailure { run.failure = failure } catch { Issue.record("Unexpected error \(error)") }
    // A finished or failed iterator stays terminal.
    #expect((try? await iterator.next()) == nil)
    return run
}
private func plain<S: AsyncSequence>(_ source: S, limits: JSONLimits = .balanced) async -> PlainRun where S.Element == JSONByteChunk {
    var run = PlainRun()
    var iterator = JSONTopLevelArraySequence(source, options: .init(limits: limits)).makeAsyncIterator()
    do {
        while let event = try await iterator.next() {
            switch event {
            case .element(let index, let value): run.elements.append((index, value))
            case .documentCompleted(let summary): run.completions.append(summary)
            }
        }
    } catch let failure as JSONFailure { run.failure = failure } catch { Issue.record("Unexpected error \(error)") }
    #expect((try? await iterator.next()) == nil)
    return run
}
private func slice(_ text: String, _ span: JSONSourceSpan) -> String {
    String(decoding: Array(text.utf8)[Int(span.start)..<Int(span.end)], as: UTF8.self)
}

@Test func locatedSpansCoverExactElementTokensAtEverySplitAndByteChunk() async throws {
    // Leading/trailing document whitespace, tabs, CRLF and separator spacing are
    // never inside a span; nested containers span their whole subtree.
    let text = " \r\n[ 1 ,\"a\",\ttrue , null,-2.5e3 ,{ \"k\" : [ 1, {} ] , \"z\":\"\" } ,[ [ ], [\"x\"] ]\n]\t "
    let expected = ["1", "\"a\"", "true", "null", "-2.5e3", "{ \"k\" : [ 1, {} ] , \"z\":\"\" }", "[ [ ], [\"x\"] ]"]
    let values = try JSONParser().parse(text).arrayValue!
    let bytes = Array(text.utf8)
    var sources: [Chunks] = [Chunks(text)]
    for split in 0...bytes.count { sources.append(Chunks(text, split: split)) }
    for source in sources {
        let run = await locate(source)
        #expect(run.failure == nil && run.completions.count == 1)
        #expect(run.elements.map(\.index) == Array(0..<UInt64(expected.count)))
        #expect(run.elements.map(\.value) == values)
        #expect(run.elements.map { slice(text, $0.span) } == expected)
        for element in run.elements {
            #expect(try JSONParser().parse(slice(text, element.span)) == element.value)
            #expect(bytes[Int(element.span.start)] != 0x20 && bytes[Int(element.span.end) - 1] != 0x20)
        }
        #expect(run.completions.first?.records == UInt64(expected.count))
    }
}

@Test func locatedSpansCountUTF8BytesNotCharactersOrScalars() async throws {
    // Raw two-, three- and four-byte scalars, escapes and a combining sequence.
    let text = "[\"ä\", \"€\" ,\"𝄞\",\"\\uD834\\uDD1E\",{\"ключ\":\"é\u{301}\"},\"\\u00e4\"]"
    let run = await locate(Chunks(text))
    #expect(run.failure == nil && run.completions.count == 1)
    let spans = run.elements.map { [$0.span.start, $0.span.end] }
    #expect(spans == [[1, 5], [7, 12], [14, 20], [21, 35], [36, 55], [56, 64]])
    #expect(run.elements.map { slice(text, $0.span) } == ["\"ä\"", "\"€\"", "\"𝄞\"", "\"\\uD834\\uDD1E\"", "{\"ключ\":\"é\u{301}\"}", "\"\\u00e4\""])
    // Decoded scalar identity is preserved; escaped and raw forms decode equally.
    #expect(run.elements[2].value == run.elements[3].value)
    #expect(run.elements[0].value == run.elements[5].value)
}

@Test func locatedEmptyArrayOnlyCompletes() async throws {
    for text in ["[]", " [ \n ] ", "\t[\r\n]\n"] {
        let run = await locate(Chunks(text))
        #expect(run.elements.isEmpty && run.failure == nil)
        #expect(run.completions.count == 1 && run.completions.first?.records == 0)
    }
}

@Test(arguments: [
    "[1", "[1,]", "[1 2]", "[1]x", "[1,{}", "{}", "", " ", "1", "[01]", "[\"\\x\"]", "[1] [2]",
    "[{\"a\":1,\"a\":2}]", "[\"\u{7F}\"]", "[1,\"\\uD800\"]", "[tru]", "[1]\n", "[[1,2],{\"a\":[null]}, \"é\"]",
])
func locatedAndValueOnlyFacadesAgreeOnEveryOutcome(text: String) async throws {
    for split in [nil] + (0...text.utf8.count).map(Optional.some) {
        let located = await locate(Chunks(text, split: split))
        let values = await plain(Chunks(text, split: split))
        #expect(located.failure == values.failure)
        #expect(located.elements.map(\.index) == values.elements.map(\.index))
        #expect(located.elements.map(\.value) == values.elements.map(\.value))
        #expect(located.completions.map(\.records) == values.completions.map(\.records))
        #expect(located.completions.map(\.statistics) == values.completions.map(\.statistics))
        if located.failure != nil { #expect(located.completions.isEmpty) }
    }
}

@Test func locatedLimitsMatchValueOnlyLimits() async throws {
    var cases: [(JSONLimits, String)] = []
    var limits = JSONLimits.balanced; limits[.maxDepth] = 1; cases.append((limits, "[[]]"))
    limits = .balanced; limits[.totalRecords] = 3; cases.append((limits, "[0,0,0,0]"))
    limits = .balanced; limits[.nodes] = 1; cases.append((limits, "[0,[1]]"))
    limits = .balanced; limits[.arrayItems] = 1; cases.append((limits, "[[1,2]]"))
    limits = .balanced; limits[.chunkBytes] = 1; cases.append((limits, "[1,2]"))
    for (limits, text) in cases {
        for split in [nil, 1] {
            let located = await locate(Chunks(text, split: split), limits: limits)
            let values = await plain(Chunks(text, split: split), limits: limits)
            // One-byte chunks satisfy chunkBytes = 1; every other case must refuse.
            #expect((located.failure != nil) == (split != nil || limits[.chunkBytes] != 1), "\(text)")
            #expect(located.failure == values.failure)
            #expect(located.elements.map(\.value) == values.elements.map(\.value))
            #expect(located.completions.isEmpty == values.completions.isEmpty)
        }
    }
    // Per-element quotas are retired and lifetime quotas stay cumulative, as in the value-only reader.
    limits = .balanced; limits[.inputBytes] = 2; limits[.nodes] = 1; limits[.arrayItems] = 1; limits[.retainedBytes] = 1024
    var count: UInt64 = 0
    for try await event in JSONLocatedTopLevelArraySequence(GeneratedArray(count: 10_000), options: .init(limits: limits)) {
        switch event {
        case .element(let index, _, let span):
            // GeneratedArray emits "[0" then ",0" chunks: element i occupies byte 2i+1.
            #expect(index == count && span.start == 2 * index + 1 && span.end == span.start + 1); count += 1
        case .documentCompleted(let summary): #expect(summary.records == 10_000 && summary.statistics[.totalScannedNodes] == 10_001)
        }
    }
    #expect(count == 10_000)
}

@Test func valueOnlyRootArraySequenceIsUnchangedBySharedDriver() async throws {
    let text = #"[{},[1,2],"\uD834\uDD1E",1e3,null,false]"#
    let expected = try JSONParser().parse(text).arrayValue!
    let run = await plain(Chunks(text))
    #expect(run.failure == nil && run.elements.map(\.value) == expected)
    #expect(run.elements.map(\.index) == Array(0..<6))
    #expect(run.completions.count == 1 && run.completions[0].records == 6 && run.completions[0].statistics[.totalScannedNodes] == 9)
    let located = await locate(Chunks(text))
    #expect(located.completions.map(\.statistics) == run.completions.map(\.statistics))
}
