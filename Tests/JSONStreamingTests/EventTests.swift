// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONStreaming
@Test func provisionalEventsNeverCertifyMalformedTail() async throws {
    var iterator = JSONEventSequence(Chunks("[true] garbage")).makeAsyncIterator()
    var observed = 0, completed = false, failed = false
    do {
        while let event = try await iterator.next() {
            observed += 1; if case .documentCompleted = event { completed = true }
        }
    } catch is JSONFailure { failed = true }
    #expect(failed && observed >= 3 && !completed)
    let end = try await iterator.next(); #expect(end == nil)
    var values = JSONValueSequence(Chunks("[true] garbage")).makeAsyncIterator()
    await #expect(throws: JSONFailure.self) { try await values.next() }
}
@Test func separatedRecordsRequireWhitespaceAndAcceptTrailingWhitespace() async throws {
    var values: [JSON] = []
    for try await value in JSONValueSequence(Chunks("{} \n1\ttrue  "), options: .init(framing: .whitespaceSeparatedValues)) { values.append(value) }
    #expect(values == [try JSONParser().parse("{}"), 1, true])
    for text in ["{}{}", "truefalse", "1true", "1 2garbage"] {
        var iterator = JSONValueSequence(Chunks(text), options: .init(framing: .whitespaceSeparatedValues)).makeAsyncIterator()
        await #expect(throws: JSONFailure.self) { while try await iterator.next() != nil {} }
    }
}
@Test func strictNDJSONPreservesPhysicalBoundariesAndLocations() async throws {
    var values: [JSON] = []
    for try await value in NDJSONValueSequence(Chunks("1\r\n\"escaped\\nline\"\nfalse")) { values.append(value) }
    #expect(values == [1, "escaped\nline", false])
    for text in ["\n", " \t\n", "1\n\n", "[1,\n2]\n", "1\n[", "\"raw\nline\"\n"] {
        var iterator = NDJSONValueSequence(Chunks(text)).makeAsyncIterator()
        await #expect(throws: JSONFailure.self) { while try await iterator.next() != nil {} }
    }
    var iterator = NDJSONValueSequence(Chunks("1\n[}")).makeAsyncIterator()
    _ = try await iterator.next()
    do { _ = try await iterator.next(); Issue.record("Malformed record accepted") }
    catch let error as JSONFailure { #expect(error.location?.record == 2 && error.location?.byteOffset == 3) }
}
