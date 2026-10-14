// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming

private enum SyntaxObservation: Equatable {
    case objectStart, objectEnd, arrayStart, arrayEnd
    case key(JSONKey), scalar(JSON)
}

@Test(StreamingTestPolicy.deadline) func qaStreamingEveryRootEndingCompletesWithTheSelectedFramingAtEverySplit() async throws {
    let traits = try #require(Test.current).traits
    #if os(WASI)
    #expect(!traits.contains { $0 is TimeLimitTrait })
    #else
    let deadline = try #require(traits.compactMap { $0 as? TimeLimitTrait }.first)
    #expect(deadline.timeLimit == .seconds(60))
    #endif
    // Fixed syntax oracles, rather than comparing two consumers of one parser.
    // Include numbers finalized only by EOF and containers completed by a delimiter.
    let cases: [(String, [SyntaxObservation])] = [
        ("null", [.scalar(.null)]),
        ("true", [.scalar(true)]),
        ("false", [.scalar(false)]),
        ("0", [.scalar(0)]),
        ("-17.25e+2", [.scalar(-1725)]),
        (#""e\u0301""#, [.scalar("e\u{301}")]),
        ("\"😀\"", [.scalar("😀")]),
        ("[]", [.arrayStart, .arrayEnd]),
        ("{}", [.objectStart, .objectEnd]),
        (#"[1,{"k":2}]"#, [.arrayStart, .scalar(1), .objectStart, .key("k"), .scalar(2), .objectEnd, .arrayEnd]),
        (#"{"a":[true]}"#, [.objectStart, .key("a"), .arrayStart, .scalar(true), .arrayEnd, .objectEnd]),
    ]
    var executions = 0
    for framing in [JSONFraming.singleDocument, .whitespaceSeparatedValues] {
        for (root, expected) in cases {
            for suffix in ["", " ", " \t\r\n"] {
                let text = root + suffix
                for split in 0...text.utf8.count {
                    var iterator = JSONEventSequence(Chunks(text, split: split), options: .init(framing: framing)).makeAsyncIterator()
                    var syntax: [SyntaxObservation] = []
                    var documents = 0, records = 0
                    while let event = try await iterator.next() {
                        switch event {
                        case .documentCompleted(let summary):
                            #expect(syntax == expected && summary.records == 1)
                            documents += 1
                        case .recordCompleted(let summary):
                            #expect(syntax == expected && summary.records == 1)
                            records += 1
                        default:
                            #expect(documents == 0 && records == 0)
                            switch event {
                            case .startObject: syntax.append(.objectStart)
                            case .endObject: syntax.append(.objectEnd)
                            case .startArray: syntax.append(.arrayStart)
                            case .endArray: syntax.append(.arrayEnd)
                            case .key(let text): syntax.append(.key(JSONKey(text)))
                            case .scalar(let value): syntax.append(.scalar(value))
                            default: Issue.record("Unexpected completion in syntax branch")
                            }
                        }
                    }
                    #expect(syntax == expected)
                    #expect(documents == (framing == .singleDocument ? 1 : 0))
                    #expect(records == (framing == .whitespaceSeparatedValues ? 1 : 0))
                    #expect(try await iterator.next() == nil)
                    #expect(try await iterator.next() == nil)
                    executions += 1
                }
            }
        }
    }
    #expect(executions == 566)
}
