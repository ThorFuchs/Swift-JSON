// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema
@testable import JSONFilterRuntime
@testable import JSONCLIEngine

private func integrationDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cli-integration-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    return url
}
@Test func cliStreamArrayCompletionIsRequiredBeforeAtomicInstallation() throws {
    let root = try integrationDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("input.json"), output = root.appendingPathComponent("output.json")
    try Data("[1,{\"n\":9007199254740993},null]".utf8).write(to: input)
    var context = try CLIJobContext()
    let arguments = try CLIArguments(["stream", "array", input.path, "--output", output.path], context: &context)
    #expect(try CLIStreamCommand.run(arguments, context: &context) == 0)
    #expect(try Data(contentsOf: output) == Data("1\n{\"n\":9007199254740993}\nnull\n".utf8))
    #expect(context.used(.totalRecords) == 3 && context.committedResults == 3)
    #expect(context.used(.collectionValues) == 0)
    try Data("[1,2] garbage".utf8).write(to: input)
    var failed = try CLIJobContext()
    let retry = try CLIArguments(["stream", "array", input.path, "--output", output.path, "--overwrite"], context: &failed)
    #expect(throws: JSONFailure.self) { _ = try CLIStreamCommand.run(retry, context: &failed) }
    #expect(failed.committedResults == 0 && failed.used(.totalResults) == 2)
    #expect(try Data(contentsOf: output) == Data("1\n{\"n\":9007199254740993}\nnull\n".utf8))
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["input.json", "output.json"])
}
@Test func cliStreamCheckRequiresStrictPhysicalLinesAndWholeFileEOF() throws {
    let root = try integrationDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("records.ndjson"), output = root.appendingPathComponent("summary.json")
    try Data("1\r\n{\"a\":null}\n".utf8).write(to: input)
    var context = try CLIJobContext()
    let arguments = try CLIArguments(["stream", "check", input.path, "--framing", "ndjson", "--output", output.path], context: &context)
    #expect(try CLIStreamCommand.run(arguments, context: &context) == 0)
    let summary = try JSONParser().parse(Array(Data(contentsOf: output)))
    #expect(summary == (try JSONParser().parse(#"{"completed":true,"inputRecords":2}"#)))
    for text in ["1\n\n2\n", "1\n{", "1\n2 x\n"] {
        try Data(text.utf8).write(to: input)
        var failed = try CLIJobContext()
        let retry = try CLIArguments(["stream", "check", input.path, "--framing", "ndjson", "--output", output.path, "--overwrite"], context: &failed)
        #expect(throws: JSONFailure.self) { _ = try CLIStreamCommand.run(retry, context: &failed) }
        #expect(failed.used(.totalResults) == 0 && failed.committedResults == 0)
    }
}
@Test func cliSchemaCheckCompilesOfflineResourcesAndDoesNotValidateAnInstance() throws {
    let root = try integrationDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let schema = root.appendingPathComponent("schema.json"), resource = root.appendingPathComponent("resource.json"), output = root.appendingPathComponent("metadata.json")
    try Data(#"{"$ref":"https://example.test/integer"}"#.utf8).write(to: schema)
    try Data(#"{"type":"integer"}"#.utf8).write(to: resource)
    var context = try CLIJobContext()
    let arguments = try CLIArguments(["schema", "check", schema.path, "--resource", "https://example.test/integer=" + resource.path, "--output", output.path], context: &context)
    #expect(try CLISchemaCommand.run(arguments, context: &context) == 0)
    guard case .object(let metadata) = try JSONParser().parse(Array(Data(contentsOf: output))) else { Issue.record("Missing completed metadata"); return }
    #expect(metadata[JSONKey("completed")] == .boolean(true) && metadata[JSONKey("schemaKind")] == .string("object"))
    #expect(metadata[JSONKey("valid")] == nil)
    var missing = try CLIJobContext()
    let missingArguments = try CLIArguments(["schema", "check", schema.path, "--output", output.path, "--overwrite"], context: &missing)
    #expect(throws: JSONSchemaCompilationFailure.self) { _ = try CLISchemaCommand.run(missingArguments, context: &missing) }
    try Data("false".utf8).write(to: schema)
    var boolean = try CLIJobContext()
    let booleanArguments = try CLIArguments(["schema", "check", schema.path, "--output", output.path, "--overwrite"], context: &boolean)
    #expect(try CLISchemaCommand.run(booleanArguments, context: &boolean) == 0)
}
@Test func cliStreamNestedCodecWorkIsCumulativeAcrossRecordsAndEncoding() throws {
    let root = try integrationDirectory()
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("input.jsons"), output = root.appendingPathComponent("output.jsons")
    try Data("1 2 3 4".utf8).write(to: input)
    var measured = try CLIJobContext()
    let arguments = try CLIArguments(["stream", "cat", input.path, "--output", output.path], context: &measured)
    #expect(try CLIStreamCommand.run(arguments, context: &measured) == 0)
    let work = measured.used(.totalWorkUnits)
    var limits = CLILimits(); limits[.totalWorkUnits] = work - 1
    var bounded = try CLIJobContext(limits: limits)
    let retry = try CLIArguments(["stream", "cat", input.path, "--output", output.path, "--overwrite"], context: &bounded)
    do { _ = try CLIStreamCommand.run(retry, context: &bounded); Issue.record("Expected cumulative exhaustion") }
    catch { #expect(CLIDiagnostics.classify(error).exit == 6) }
    #expect(bounded.committedResults == 0)
    #expect(try Data(contentsOf: output) == Data("1\n2\n3\n4\n".utf8))
}
@Test func cliHelpVersionAndProviderAvailabilityAreTruthful() throws {
    for argv in [["render", "--presentation", "bogus"], ["render", "--format", "text", "--theme", "dark"], ["query", "--input-framing", "bogus", "("]] {
        var context = try CLIJobContext()
        #expect(throws: CLIError.self) { _ = try CLIArguments(argv, context: &context) }
        #expect(context.used(.totalInputBytes) == 0)
    }
    #expect(try CLIHelp.text(for: "stream").contains("closing syntax"))
    #expect(try CLIHelp.text(for: "schema").contains("openai-format"))
    #expect(throws: CLIError.self) { _ = try CLIHelp.text(for: "server") }
    var context = try CLIJobContext()
    let arguments = try CLIArguments(["schema", "provider", "apple-check", "not-opened.json", "--name", "sample"], context: &context)
    do { _ = try CLISchemaCommand.run(arguments, context: &context); Issue.record("Prerequisite is not integrated") }
    catch let error as CLIError { #expect(error.exit == 2 && error.code == "capabilityUnavailable") }
    #expect(context.used(.totalInputBytes) == 0)
    let version = try JSONParser().parse(CLIHelp.versionJSON)
    guard case .object(let metadata) = version else { Issue.record("Expected native JSON metadata"); return }
    #expect(metadata[JSONKey("revision")] == .string("unknown"))
    #expect(metadata[JSONKey("platform")] != nil && metadata[JSONKey("architecture")] != nil)
}

@Test func cliAwaitedSinkHandlesShortWritesNoProgressAndCancellationBeforeFurtherHandoffs() async throws {
    var context = try CLIJobContext()
    let source = Array("exact 🦊 bytes".utf8)
    var accepted: [UInt8] = [], calls = 0
    try CLISinkTransfer.writeAll(count: source.count, context: &context) { range, _ in
        calls += 1
        if calls == 1 { return nil } // readiness retry precedes the first handoff.
        let count = min(2, range.count)
        accepted.append(contentsOf: source[range.lowerBound..<(range.lowerBound + count)])
        return count
    }
    #expect(accepted == source && calls > 2)
    var failed = try CLIJobContext(), failedCalls = 0
    do {
        try CLISinkTransfer.writeAll(count: 5, context: &failed) { _, _ in
            failedCalls += 1
            return failedCalls == 1 ? 2 : 0
        }
        Issue.record("Expected no-progress failure")
    } catch let error as CLIError { #expect(error.exit == 7 && error.code == "noProgress") }
    #expect(failedCalls == 2)
    #expect(throws: CLIError.self) { try failed.checkpoint() }
    let task = Task {
        var context = try CLIJobContext(), calls = 0
        do {
            try CLISinkTransfer.writeAll(count: 10, context: &context) { _, _ in
                calls += 1
                withUnsafeCurrentTask { $0?.cancel() }
                return 1
            }
            Issue.record("Expected cancellation")
        } catch is CancellationError { }
        #expect(calls == 1)
        #expect(throws: CancellationError.self) { try context.checkpoint() }
    }
    try await task.value
}
