// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONPatch
import JSONSchema
import JSONHTML
@testable import JSONFilterRuntime
@testable import JSONCLIEngine

@Test func cliNativeStagesShareCumulativeWorkAndLatchFailure() throws {
    var first = try CLIJobContext()
    let value = try JSONParser().parse(Array("[9007199254740993,0.10]".utf8), meter: &first.meter)
    let parseWork = first.used(.totalWorkUnits)
    try first.domain(.writing)
    _ = try JSONWriter().write(value, meter: &first.meter)
    let total = first.used(.totalWorkUnits)
    #expect(total > parseWork && parseWork > 0)
    var limits = CLILimits(); limits[.totalWorkUnits] = total - 1
    var bounded = try CLIJobContext(limits: limits)
    let admitted = try JSONParser().parse(Array("[9007199254740993,0.10]".utf8), meter: &bounded.meter)
    try bounded.domain(.writing)
    do { _ = try JSONWriter().write(admitted, meter: &bounded.meter); Issue.record("Expected cumulative failure") }
    catch let error as JSONFailure { #expect(error.category == .resource && error.resource?.metric == .workUnits) }
    #expect(throws: JSONFailure.self) { try bounded.work() }
}
@Test func cliPatchKeepsOuterReservationAndExactRootAbsence() throws {
    var context = try CLIJobContext()
    let patchJSON = try JSONParser().parse(Array("[{\"op\":\"remove\",\"path\":\"\"}]".utf8), meter: &context.meter)
    try context.domain(.patch)
    let patch = try JSONPatch(json: patchJSON, meter: &context.meter)
    try context.meter.retain(123)
    let outer = context.meter.used(.retainedBytes)
    let result = try patch.applying(to: .document(.null), meter: &context.meter)
    #expect(result == .removed)
    #expect(context.meter.used(.retainedBytes) == outer)
    #expect(context.meter.used(.patchWorkUnits) > 0)
}
@Test func cliSchemaAndNativeProjectionConsumeTheSameLedger() throws {
    var context = try CLIJobContext()
    let raw = try JSONParser().parse(Array("{\"type\":\"integer\",\"minimum\":3}".utf8), meter: &context.meter)
    try context.domain(.schemaCompilation)
    let plan = try JSONSchemaCompiler().compile(raw, meter: &context.meter)
    let compiled = context.used(.totalWorkUnits)
    try context.domain(.schemaEvaluation)
    let invalid = try JSONSchemaValidator().validate(.number(2), against: plan, meter: &context.meter)
    #expect(!invalid.isValid)
    let evaluated = context.used(.totalWorkUnits)
    #expect(evaluated > compiled)
    let exact = try JSONNumber.parse(Array("9007199254740993".utf8), meter: &context.meter)
    #expect(try exact.integer(as: Int64.self, meter: &context.meter) == 9007199254740993)
    #expect(context.used(.totalWorkUnits) > evaluated)
}
@Test(arguments: [["format", "--compact", "--indent=2"], ["format", "--indent=9"], ["format", "--output=a", "--output=b"], ["format", "--unknown"]])
func cliConflictingAndUnknownOptionsReject(argv: [String]) throws {
    var context = try CLIJobContext()
    #expect(throws: CLIError.self) { _ = try CLIArguments(argv, context: &context) }
}
@Test func cliArgumentTerminatorAndShortGroupsAreExplicit() throws {
    var context = try CLIJobContext()
    let parsed = try CLIArguments(["format", "-cS", "--", "--literal-file"], context: &context)
    #expect(parsed.options["compact"] == "true" && parsed.options["sort-keys"] == "true")
    #expect(parsed.positionals == ["--literal-file"])
    #expect(context.used(.argvBytes) > 0 && context.used(.totalWorkUnits) >= context.used(.argvBytes))
}
@Test func cliAllProfilesHaveExactlySixteenFiniteCaps() throws {
    #expect(CLIResourceMetric.allCases.count == 16)
    for profile in [JSONResourceProfile.conservative, .balanced, .offline] {
        let limits = CLILimits(profile: profile)
        try limits.validate()
        for metric in CLIResourceMetric.allCases { #expect(limits[metric] > 0 && limits[metric] < UInt64.max) }
    }
}
@Test func cliLimitConfigurationDoesNotRefundEarlierWork() throws {
    var context = try CLIJobContext(limits: .init(profile: .offline))
    try context.work(30)
    var limits = CLILimits(); limits[.totalWorkUnits] = 30
    try context.configure(limits)
    #expect(context.used(.totalWorkUnits) == 30)
    #expect(throws: CLIError.self) { try context.work() }
    #expect(throws: CLIError.self) { try context.checkpoint() }
}
@Test func cliAtomicOutputPreservesExistingFileAndRejectsAliases() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("json-cli-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let path = root.appendingPathComponent("result.json").path
    try Data("old".utf8).write(to: URL(fileURLWithPath: path))
    var context = try CLIJobContext()
    #expect(throws: CLIError.self) { _ = try CLIOutput(destination: path, overwrite: false, inputs: [], context: &context) }
    #expect(throws: CLIError.self) { _ = try CLIOutput(destination: path, overwrite: true, inputs: [path], context: &context) }
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data("old".utf8))
}
@Test func cliFailedStagingCannotReplaceDestinationOrLeaveTemporary() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("json-cli-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let path = root.appendingPathComponent("result.json").path
    try Data("old".utf8).write(to: URL(fileURLWithPath: path))
    var limits = CLILimits(); limits[.totalOutputBytes] = 2
    var context = try CLIJobContext(limits: limits)
    do {
        let output = try CLIOutput(destination: path, overwrite: true, inputs: [], context: &context)
        #expect(throws: CLIError.self) { try output.write([1,2,3], context: &context) }
    }
    #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data("old".utf8))
    #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["result.json"])
}
@Test func cliCancellationIsOperationalAndTerminal() async throws {
    let task = Task {
        var context = try CLIJobContext()
        withUnsafeCurrentTask { $0?.cancel() }
        #expect(throws: CancellationError.self) { try context.checkpoint() }
        #expect(throws: CancellationError.self) { try context.work() }
    }
    try await task.value
}

@Test func cliPointerAbsenceDoesNotSuppressMalformedIndicesOrNull() throws {
    var context = try CLIJobContext()
    let missing = try JSONPointer.parse("/0", meter: &context.meter)
    #expect(try missing.resolveIfPresent(in: .array([]), meter: &context.meter) == nil)
    #expect(try missing.resolveIfPresent(in: .array([.null]), meter: &context.meter) == .null)
    let malformed = try JSONPointer.parse("/01", meter: &context.meter)
    #expect(throws: JSONFailure.self) { _ = try malformed.resolveIfPresent(in: .array([]), meter: &context.meter) }
    #expect(throws: JSONFailure.self) { _ = try missing.resolveIfPresent(in: .null, meter: &context.meter) }
}

@Test func cliSubsystemQuotasAndSchemaErrorsRemainOperational() {
    #expect(CLIDiagnostics.classify(JSONHTMLFailure.limitExceeded(.documentBytes, limit: 1, attempted: 2)).exit == 6)
    #expect(CLIDiagnostics.classify(JSONHTMLFailure.counterOverflow(.domNodes)).exit == 6)
    #expect(CLIDiagnostics.classify(JSONHTMLFailure.invalidConfiguration).exit == 2)
    #expect(CLIDiagnostics.classify(JSONSchemaCompilationFailure(.missingResource)).exit == 5)
    #expect(CLIDiagnostics.classify(JSONSchemaEvaluationFailure(.nonproductiveReference)).exit == 5)
}
