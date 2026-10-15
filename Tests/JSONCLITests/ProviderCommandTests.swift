// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema
@testable import JSONFilterRuntime
@testable import JSONCLIEngine

private let providerSource = ##"{"type":"object","properties":{"value":{"type":"integer","minimum":9007199254740993}},"required":["value"],"additionalProperties":false}"##
private func providerDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("cli-provider-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    return url
}
@Test func cliSchemaProviderFormatAndToolUsePublicNativeExactHelpers() throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), output = root.appendingPathComponent("fragment.json")
    try Data(providerSource.utf8).write(to: input)
    for command in ["openai-format", "openai-tool"] {
        var context = try CLIJobContext()
        let args = try CLIArguments(["schema", "provider", command, input.path, "--name", "exact", "--description", "a 🦊", "--output", output.path, "--overwrite"], context: &context)
        #expect(try CLISchemaCommand.run(args, context: &context) == 0)
        let data = try Data(contentsOf: output), value = try JSONParser().parse(data)
        let field = command == "openai-format" ? "schema" : "parameters"
        #expect(try value.objectValue?[JSONKey(field)] == JSONParser().parse(providerSource))
        #expect(String(decoding: data, as: UTF8.self).contains("9007199254740993"))
        #expect(value.objectValue?[JSONKey("strict")] == .boolean(true))
        #expect(context.committedResults == 1)
    }
}
@Test func cliSchemaProviderOptionalityIsCompletedIncompatibilityWithoutCandidate() throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), output = root.appendingPathComponent("result.json")
    let source = ##"{"type":"object","properties":{"0":{"type":"integer"}},"additionalProperties":false}"##
    try Data(source.utf8).write(to: input)
    var context = try CLIJobContext()
    let args = try CLIArguments(["schema", "provider", "openai-format", input.path, "--name", "x", "--output", output.path], context: &context)
    #expect(try CLISchemaCommand.run(args, context: &context) == 1)
    let result = try JSONParser().parse(Data(contentsOf: output))
    #expect(result.objectValue?[JSONKey("compatible")] == .boolean(false))
    #expect(result.objectValue?[JSONKey("schema")] == nil)
    #expect(try JSONPointer(parsing: "/issues/0/code").resolve(in: result) == .string("allPropertiesRequired"))
    #expect(try JSONPointer(parsing: "/issues/0/path/0/kind").resolve(in: result) == .string("key"))
    #expect(try Data(contentsOf: input) == Data(source.utf8))
    #expect(context.committedResults == 1)
}
@Test func cliSchemaProviderMetadataAndUnqualifiedAppleRejectBeforeInputPull() throws {
    let vectors = [
        ["schema", "provider", "openai-format", "not-opened.json"],
        ["schema", "provider", "openai-tool", "not-opened.json", "--name", "bad name"],
        ["schema", "provider", "openai-format", "not-opened.json", "--name", String(repeating: "x", count: 65)],
        ["schema", "provider", "apple-check", "not-opened.json"],
        ["schema", "provider", "unknown", "not-opened.json"]
    ]
    for vector in vectors {
        var context = try CLIJobContext()
        let args = try CLIArguments(vector, context: &context)
        do { _ = try CLISchemaCommand.run(args, context: &context); Issue.record("Expected early usage error") }
        catch { #expect(CLIDiagnostics.classify(error).exit == 2) }
        #expect(context.used(.totalInputBytes) == 0)
    }
}
@Test func cliSchemaProviderMalformedSchemaAndUnknownReferenceStayOperational() throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), output = root.appendingPathComponent("result.json")
    for source in [##"{"type":"object","required":1}"##, ##"{"type":"object","properties":{"x":{"$ref":"https://example.invalid/missing"}},"required":["x"],"additionalProperties":false}"##] {
        try Data(source.utf8).write(to: input)
        var context = try CLIJobContext()
        let args = try CLIArguments(["schema", "provider", "openai-format", input.path, "--name", "x", "--output", output.path], context: &context)
        do { _ = try CLISchemaCommand.run(args, context: &context); Issue.record("Expected operational schema error") }
        catch { #expect(CLIDiagnostics.classify(error).exit == 5) }
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }
}
@Test func cliSchemaProviderCumulativeParseCompileEnvelopeAndWriteCannotResetWork() throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), output = root.appendingPathComponent("result.json")
    try Data(providerSource.utf8).write(to: input)
    let vector = ["schema", "provider", "openai-format", input.path, "--name", "x", "--output", output.path, "--overwrite"]
    var measured = try CLIJobContext()
    let args = try CLIArguments(vector, context: &measured)
    #expect(try CLISchemaCommand.run(args, context: &measured) == 0)
    let original = try Data(contentsOf: output), work = measured.used(.totalWorkUnits)
    var limits = CLILimits(); limits[.totalWorkUnits] = work - 1
    var bounded = try CLIJobContext(limits: limits)
    let retry = try CLIArguments(vector, context: &bounded)
    do { _ = try CLISchemaCommand.run(retry, context: &bounded); Issue.record("Expected cumulative quota error") }
    catch { #expect(CLIDiagnostics.classify(error).exit == 6) }
    #expect(try bounded.committedResults == 0 && Data(contentsOf: output) == original)
}
@Test func cliSchemaProviderCancellationInsideCompilationPreservesAtomicOutput() async throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), output = root.appendingPathComponent("result.json")
    try Data(providerSource.utf8).write(to: input); try Data("original".utf8).write(to: output)
    let task = Task {
        var context = try CLIJobContext()
        let args = try CLIArguments(["schema", "provider", "openai-format", input.path, "--name", "x", "--output", output.path, "--overwrite"], context: &context)
        context.meter.checkpointObserver = { work in if work > 1_000 { withUnsafeCurrentTask { $0?.cancel() } } }
        do { _ = try CLISchemaCommand.run(args, context: &context); Issue.record("Expected cancellation") }
        catch { #expect(CLIDiagnostics.classify(error).exit == 130) }
        let work = context.used(.totalWorkUnits)
        #expect(throws: CancellationError.self) { try context.checkpoint() }
        #expect(context.used(.totalWorkUnits) == work && context.committedResults == 0)
    }
    try await task.value
    #expect(try Data(contentsOf: output) == Data("original".utf8))
}
@Test func cliSchemaProviderExplicitExternalResourceIsResolvedButNeverBundled() throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), external = root.appendingPathComponent("external.json"), output = root.appendingPathComponent("result.json")
    try Data(##"{"type":"object","properties":{"value":{"$ref":"https://example.invalid/value"}},"required":["value"],"additionalProperties":false}"##.utf8).write(to: input)
    try Data(##"{"type":"integer"}"##.utf8).write(to: external)
    var context = try CLIJobContext()
    let args = try CLIArguments(["schema", "provider", "openai-tool", input.path, "--name", "x", "--resource", "https://example.invalid/value=" + external.path, "--output", output.path], context: &context)
    #expect(try CLISchemaCommand.run(args, context: &context) == 1)
    let result = try JSONParser().parse(Data(contentsOf: output))
    #expect(try JSONPointer(parsing: "/issues/0/code").resolve(in: result) == .string("externalReference"))
    #expect(result.objectValue?[JSONKey("parameters")] == nil)
}
@Test func cliSchemaProviderMalformedTailCannotPublishAValidPrefix() throws {
    let root = try providerDirectory(); defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("schema.json"), output = root.appendingPathComponent("result.json")
    try Data((providerSource + " false").utf8).write(to: input)
    try Data("original".utf8).write(to: output)
    var context = try CLIJobContext()
    let args = try CLIArguments(["schema", "provider", "openai-format", input.path, "--name", "x", "--output", output.path, "--overwrite"], context: &context)
    do { _ = try CLISchemaCommand.run(args, context: &context); Issue.record("Expected strict trailing syntax failure") }
    catch { #expect(CLIDiagnostics.classify(error).exit == 5) }
    #expect(try Data(contentsOf: output) == Data("original".utf8))
    #expect(context.committedResults == 0)
}
