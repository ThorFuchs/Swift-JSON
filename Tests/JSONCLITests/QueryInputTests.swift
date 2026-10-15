// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONCLIEngine
@testable import JSONFilterRuntime

private func withInputFile<T>(_ bytes: [UInt8], _ body: (String) throws -> T) throws -> T {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("json-query-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let path = root.appendingPathComponent("input.json")
    try Data(bytes).write(to: path)
    return try body(path.path)
}
@Test func cliQueryValueFramingRequiresWhitespaceAndIndependentFileEOF() throws {
    try withInputFile(Array("1 2\n{}".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path,path])
        defer { try? cursor.close(context: &context) }
        var values: [JSON] = []
        while var value = try cursor.next(context: &context) { values.append(value.value); try value.release(context: &context) }
        #expect(values.count == 6 && values[0] == .number(1) && values[3] == .number(1))
    }
    try withInputFile(Array("{}[]".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path])
        defer { try? cursor.close(context: &context) }
        #expect(throws: JSONFailure.self) { _ = try cursor.next(context: &context) }
    }
}
@Test func cliQueryDocumentWaitsForEOFAndTailErrorsAreTerminal() throws {
    try withInputFile(Array("1 2".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path], framing: .document)
        defer { try? cursor.close(context: &context) }
        #expect(throws: JSONFailure.self) { _ = try cursor.next(context: &context) }
        #expect(throws: CLIError.self) { _ = try cursor.next(context: &context) }
    }
    try withInputFile(Array("1\n{\"bad\":]".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path])
        defer { try? cursor.close(context: &context) }
        let maybeFirst = try cursor.next(context: &context); var first = try #require(maybeFirst); #expect(first.value == .number(1)); try first.release(context: &context)
        #expect(throws: JSONFailure.self) { try cursor.drain(context: &context) }
    }
}
@Test func cliQueryStrictNDJSONAndRawLinesPreserveTheirDifferentContracts() throws {
    try withInputFile(Array("1\n\n2\n".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path], framing: .ndjson)
        defer { try? cursor.close(context: &context) }
        let maybeFirst = try cursor.next(context: &context); var first = try #require(maybeFirst); #expect(first.value == .number(1)); try first.release(context: &context)
        #expect(throws: JSONFailure.self) { _ = try cursor.next(context: &context) }
    }
    try withInputFile(Array("a\r\n\n🦊".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path], framing: .rawLines)
        defer { try? cursor.close(context: &context) }
        var values: [JSON] = []
        while var value = try cursor.next(context: &context) { values.append(value.value); try value.release(context: &context) }
        #expect(values == [.string("a"), .string(""), .string("🦊")])
    }
}
@Test func cliQueryRootArrayYieldsProvisionallyAndRequiresClosingEOF() throws {
    try withInputFile(Array("[1,2".utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path], framing: .array)
        defer { try? cursor.close(context: &context) }
        let maybeFirst = try cursor.next(context: &context); var first = try #require(maybeFirst); #expect(first.value == .number(1)); try first.release(context: &context)
        let maybeSecond = try cursor.next(context: &context); var second = try #require(maybeSecond); #expect(second.value == .number(2)); try second.release(context: &context)
        #expect(throws: JSONFailure.self) { _ = try cursor.next(context: &context) }
    }
}
@Test(arguments: [2000, 20000]) func cliQueryManyTinyRecordsDoNotRetainTheWholeInputJob(records: Int) throws {
    try withInputFile(Array(String(repeating: "0\n", count: records).utf8)) { path in
        var context = try CLIJobContext(), cursor = CLIInputCursor(files: [path])
        defer { try? cursor.close(context: &context) }
        var count = 0
        while var value = try cursor.next(context: &context) { count += 1; try value.release(context: &context) }
        #expect(count == records)
        #expect(context.meter.used(.retainedBytes) == 0)
        // One 16 KiB syscall buffer may overlap one accepted 16 KiB chunk;
        // the completed scalar/lease has a small fixed reservation. This bound
        // follows the actual adapter, rather than an arbitrary RSS threshold.
        let chunk = min(UInt64(16384), context.limits.core[.chunkBytes])
        #expect(context.meter.statistics().peakLogicalRetainedBytes <= 2 * chunk + 256)
        #expect(context.used(.totalRecords) == UInt64(records) && context.used(.totalWorkUnits) > UInt64(records))
    }
}
