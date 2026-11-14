// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONStreaming

private let rs = "\u{1E}"
private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }
/// Reads every value and the skip count; `split` nil delivers one byte per chunk.
private func read(_ text: String, split: Int? = nil, skip: Bool = false, limits: JSONLimits = .balanced) async throws -> (values: [JSON], skipped: Int) {
    let sequence = JSONTextSequence(Chunks(text, split: split), options: .init(limits: limits, malformedTexts: skip ? .skip : .fail))
    var iterator = sequence.makeAsyncIterator(), values: [JSON] = []
    while let value = try await iterator.next() { values.append(value) }
    return (values, iterator.skippedTexts)
}
private func failure(_ text: String, skip: Bool = false, limits: JSONLimits = .balanced) async -> JSONFailure? {
    do { _ = try await read(text, skip: skip, limits: limits); return nil } catch { return error as? JSONFailure }
}

@Test func textSequenceReadsRecordsAcrossEveryChunkSplit() async throws {
    let text = rs + "{\"a\":[1,2]}\n" + rs + "\"x\\u001e\"\n" + rs + "1.50\n" + rs + "  [\n  true\n]\r\n" + rs + "null\n"
    let expected = [try parse(#"{"a":[1,2]}"#), .string("x\u{1E}"), try parse("1.50"), .array([.boolean(true)]), .null]
    #expect(try await read(text).values == expected)
    for split in 0...text.utf8.count { #expect(try await read(text, split: split).values == expected) }
    // Consecutive, leading and final RS bytes are not empty texts; empty input is an empty sequence.
    #expect(try await read(rs + rs + "1\n" + rs + rs + rs + "2\n" + rs).values == [1, 2])
    #expect(try await read("").values.isEmpty)
    #expect(try await read(rs + rs).values.isEmpty)
    // Containers and strings need no trailing LF.
    #expect(try await read(rs + "[1]" + rs + "\"s\"").values == [.array([1]), .string("s")])
}

@Test func textSequenceTreatsUnterminatedScalarsAsTruncated() async throws {
    // RFC 7464 section 2.4: "123" before the next RS may be a truncated "1234".
    let truncated = await failure(rs + "123" + rs + "true\n")
    #expect(truncated?.code == .unexpectedEOF && truncated?.category == .syntax)
    #expect(truncated?.location?.byteOffset == 4 && truncated?.location?.record == 1)
    for scalar in ["true", "false", "null", "-0.5", "42"] {
        #expect(await failure(rs + scalar)?.code == .unexpectedEOF)
        #expect(try await read(rs + scalar + " ").values.count == 1)
    }
    let skipped = try await read(rs + "123" + rs + "true\n" + rs + "7", skip: true)
    #expect(skipped.values == [true] && skipped.skipped == 2)
}

@Test func textSequenceRejectsOrSkipsMalformedTexts() async throws {
    // Bytes before the first RS are a malformed text.
    let leading = await failure("1\n" + rs + "2\n")
    #expect(leading?.code == .invalidSyntax && leading?.location?.byteOffset == 0 && leading?.location?.record == 1)
    // A syntax failure reports the absolute offset and the text number.
    let broken = await failure(rs + "1\n" + rs + "{\"a\":}\n")
    #expect(broken?.category == .syntax && broken?.location?.record == 2)
    #expect((broken?.location?.byteOffset ?? 0) >= 4)
    #expect(await failure(rs + "\n") != nil)
    #expect(await failure(rs + "1 2\n")?.category == .syntax)
    // The skip policy continues after each malformed text, as RFC 7464 recommends.
    let recovered = try await read("junk" + rs + "{\"a\":" + rs + "[1]\n" + rs + "\u{FF}\n" + rs + "\"ok\"\n", skip: true)
    #expect(recovered.values == [.array([1]), .string("ok")] && recovered.skipped == 3)
    #expect(try await read(rs + "1\n").skipped == 0)
}

@Test func textSequenceResourceFailuresAreNeverSkipped() async throws {
    var limits = JSONLimits.balanced; limits[.inputBytes] = 8
    #expect(try await read(rs + "[1,2,3]\n" + rs + "[4]\n", limits: limits).values.count == 2)
    let oversized = await failure(rs + "[1,2,3,4,5]\n" + rs + "1\n", skip: true, limits: limits)
    #expect(oversized?.category == .resource && oversized?.resource?.metric == .inputBytes)
    limits = .balanced; limits[.totalRecords] = 2
    #expect(await failure(rs + "1\n" + rs + "2\n" + rs + "3\n", limits: limits)?.resource?.metric == .totalRecords)
}

@Test func textSequenceWriterProducesRFC7464Texts() async throws {
    let values: [JSON] = [1, .string("x\u{1E}"), try parse(#"{"a":[],"n":1.50}"#)]
    let data = try JSONTextSequenceWriter().encode(values)
    // RS, the strict writer's exact bytes, then LF, per text.
    #expect(String(decoding: data, as: UTF8.self) == (try values.map { rs + (try JSONWriter().writeString($0)) + "\n" }.joined()))
    #expect(String(decoding: data, as: UTF8.self).hasPrefix(rs + "1\n" + rs + "\"x\\u001e\"\n" + rs + "{"))
    #expect(try JSONTextSequenceWriter().encode([]).isEmpty)
    // Indented texts round-trip because their LF bytes are JSON whitespace.
    let pretty = try JSONTextSequenceWriter(options: .init(indentation: 2)).encode(values)
    #expect(try await read(String(decoding: pretty, as: UTF8.self)).values == values)
    let report = try JSONTextSequenceWriter().encodeWithReport(values)
    #expect(report.statistics[.outputBytes] == UInt64(report.result.count))

    // The awaited writer emits the same bytes in bounded chunks.
    actor Collected { var chunks: [[UInt8]] = []; func add(_ chunk: JSONByteChunk) { chunks.append(chunk.bytes) } }
    let collected = Collected()
    for value in values { try await JSONTextSequenceWriter(chunkSize: 3).write(value) { await collected.add($0) } }
    let chunks = await collected.chunks
    #expect(chunks.allSatisfy { (1...3).contains($0.count) })
    #expect(Data(chunks.flatMap { $0 }) == data)
    await #expect(throws: JSONFailure.self) { try await JSONTextSequenceWriter(chunkSize: 0).write(1) { _ in } }
}

@Test func cancelledTextSequenceReadingThrowsCancellation() async {
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        for try await _ in JSONTextSequence(Chunks(String(repeating: rs + "1\n", count: 200))) {}
    }
    task.cancel()
    do { try await task.value; Issue.record("Cancelled reading must throw") }
    catch { #expect(error is CancellationError) }
}
