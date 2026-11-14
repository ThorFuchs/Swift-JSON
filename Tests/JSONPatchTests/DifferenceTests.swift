// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONPatch

private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }

/// Applies the difference and returns the operations, recording any mismatch.
@discardableResult
private func roundTrip(_ source: JSON, _ target: JSON, sourceLocation: SourceLocation = #_sourceLocation) throws -> [JSONPatchOperation] {
    let patch = try JSONPatch.difference(from: source, to: target)
    let result = try patch.applying(to: source)
    #expect(result == .document(target), sourceLocation: sourceLocation)
    return patch.operations
}

@Test func differenceOfEqualValuesIsEmpty() throws {
    for text in ["null", "true", "0", "\"é\"", "[]", "{}", #"{"a":[1,{"b":null}],"c":"x"}"#] {
        #expect(try roundTrip(parse(text), parse(text)).isEmpty)
    }
    // Exact equality: equal decimals and a different member order are not changes.
    #expect(try roundTrip(parse(#"{"n":1.0,"m":[2e1],"a":1,"b":2}"#), parse(#"{"b":2,"a":1,"n":1,"m":[20]}"#)).isEmpty)
}

@Test func differenceProducesExpectedObjectOperations() throws {
    let source = try parse(#"{"keep":1,"drop":2,"change":{"x":1,"y":[1,2]},"kind":[1]}"#)
    let target = try parse(#"{"keep":1,"change":{"x":2,"y":[1,2]},"kind":{"a":1},"new":null}"#)
    let operations = try roundTrip(source, target)
    #expect(operations == [
        .remove(path: try JSONPointer(parsing: "/drop")),
        .replace(path: try JSONPointer(parsing: "/change/x"), value: 2),
        .replace(path: try JSONPointer(parsing: "/kind"), value: try parse(#"{"a":1}"#)),
        .add(path: try JSONPointer(parsing: "/new"), value: .null),
    ])
}

@Test func differenceKeepsArrayPrefixAndSuffix() throws {
    // Insertion in the middle: prefix [1,2] and suffix [9] stay, one add.
    #expect(try roundTrip(parse("[1,2,9]"), parse("[1,2,3,9]")) == [.add(path: try JSONPointer(parsing: "/2"), value: 3)])
    // Removal in the middle.
    #expect(try roundTrip(parse("[1,2,3,9]"), parse("[1,2,9]")) == [.remove(path: try JSONPointer(parsing: "/2"))])
    // Several removals run from the highest index down.
    #expect(try roundTrip(parse("[0,1,2,3,4]"), parse("[0,4]")) == [
        .remove(path: try JSONPointer(parsing: "/3")), .remove(path: try JSONPointer(parsing: "/2")),
        .remove(path: try JSONPointer(parsing: "/1")),
    ])
    // A changed element in place is compared recursively.
    #expect(try roundTrip(parse(#"[{"a":1},{"a":2}]"#), parse(#"[{"a":1},{"a":3}]"#)) ==
            [.replace(path: try JSONPointer(parsing: "/1/a"), value: 3)])
    // Pairwise comparison, then surplus adds; no moves are produced.
    try roundTrip(parse("[1,2,3]"), parse("[3,2,1,0]"))
    try roundTrip(parse("[[1],[2]]"), parse("[[2],[1],[]]"))
    try roundTrip(parse("[1,1,1]"), parse("[1,1]"))
    try roundTrip(parse("[]"), parse("[1,[2],{}]"))
    try roundTrip(parse("[1,[2],{}]"), parse("[]"))
}

@Test func differenceEscapesKeysAndHandlesRootAndUnicode() throws {
    let source = try parse(#"{"a/b":1,"m~n":2,"":3,"é":4}"#)
    let target = try parse(#"{"a/b":5,"m~n":2,"":6,"é":4}"#)
    let operations = try roundTrip(source, target)
    #expect(operations.map(\.path.string) == ["/a~1b", "/", "/é", "/e\u{301}"])
    // Decoded scalars are distinct keys, even when canonically equivalent.
    #expect(operations[2] == .remove(path: try JSONPointer(tokens: ["é"])))
    // Root kind changes replace the root through the empty Pointer.
    #expect(try roundTrip(parse("[1]"), parse(#"{"a":1}"#)) == [.replace(path: try JSONPointer(parsing: ""), value: try parse(#"{"a":1}"#))])
    #expect(try roundTrip(parse("1"), parse("null")) == [.replace(path: try JSONPointer(parsing: ""), value: .null)])
    #expect(try roundTrip(parse("\"é\""), parse("\"e\u{301}\"")).count == 1)
}

/// A deterministic generator over small nested values, so the property runs on a fixed corpus.
private struct Generator {
    var state: UInt64
    mutating func next(_ bound: Int) -> Int {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Int((state >> 33) % UInt64(bound))
    }
    mutating func value(depth: Int) throws -> JSON {
        switch next(depth > 2 ? 4 : 6) {
        case 0: return .null
        case 1: return .boolean(next(2) == 0)
        case 2: return .number(try JSONNumber(parsing: ["0", "1", "1.0", "-2", "3e2", "0.5"][next(6)]))
        case 3: return .string(["", "a", "b", "é", "a/b", "~"][next(6)])
        case 4: return .array(try (0..<next(4)).map { _ in try value(depth: depth + 1) })
        default:
            var members: [JSONMember] = []
            for key in ["a", "b", "c", "d/e"] where next(2) == 0 { members.append(.init(key, value: try value(depth: depth + 1))) }
            return .object(try JSONObject(members: members))
        }
    }
}

@Test func differenceAppliesToTargetOnAGeneratedCorpus() throws {
    var generator = Generator(state: 0x5eed_1_10)
    var nonEmpty = 0
    for _ in 0..<600 {
        let source = try generator.value(depth: 0), target = try generator.value(depth: 0)
        let operations = try roundTrip(source, target)
        if !operations.isEmpty { nonEmpty += 1 }
        #expect(try roundTrip(source, source).isEmpty)
        // No operation reaches into a value that is unchanged at its own level.
        #expect(!operations.contains { if case .move = $0 { true } else if case .copy = $0 { true } else if case .test = $0 { true } else { false } })
    }
    #expect(nonEmpty > 500)
}

@Test func differenceIsBoundedReportedAndCancellable() async throws {
    let source = try parse(#"{"a":[1,2,3],"b":{"c":"x"}}"#), target = try parse(#"{"a":[1,3],"b":{"c":"y"},"d":true}"#)
    let report = try JSONPatch.differenceWithReport(from: source, to: target)
    #expect(report.result.operations.count == 3)
    #expect(report.statistics.domain == .patch)
    #expect(report.statistics[.workUnits] > 0)
    var limits = JSONLimits.balanced; limits[.operations] = 2
    do { _ = try JSONPatch.difference(from: source, to: target, options: .init(limits: limits)); Issue.record("Expected an operation limit failure") }
    catch let failure as JSONFailure { #expect(failure.code == .limitExceeded && failure.resource?.metric == .operations) }
    limits[.operations] = 3
    #expect(try JSONPatch.difference(from: source, to: target, options: .init(limits: limits)).operations.count == 3)
    limits = .balanced; limits[.workUnits] = 10
    do { _ = try JSONPatch.difference(from: source, to: target, options: .init(limits: limits)); Issue.record("Expected a work limit failure") }
    catch let failure as JSONFailure { #expect(failure.category == .resource) }
    // Inputs are values; the difference never changes them.
    #expect(source == (try parse(#"{"a":[1,2,3],"b":{"c":"x"}}"#)))

    let wide = JSON.array((0..<20_000).map { .number(JSONNumber(integer: $0)) })
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        _ = try JSONPatch.difference(from: wide, to: .array([]))
    }
    task.cancel()
    do { try await task.value; Issue.record("Cancelled difference must throw") }
    catch { #expect(error is CancellationError) }
}
