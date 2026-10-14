// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing

@testable import JSONCLIEngine
@testable import JSONFilterRuntime

@Test(arguments: [
    ["render", "--layout", "bad"], ["render", "--string-preview", "-1"],
    ["render", "--string-preview", "4611686018427387904"],
    ["render", "--string-preview", "0", "--full-values"],
    ["render", "--inline-formatting", "markdown"], ["render", "--value-previews", "remote"],
    ["render", "--format", "text", "--layout", "structured"],
    ["render", "--format", "markdown", "--full-values"],
    ["render", "--format", "text", "--string-preview", "0"],
    ["render", "--format", "text", "--inline-formatting", "off"],
    ["render", "--format", "text", "--value-previews", "off"],
])
func cliHTMLPreviewFlagsRejectUsageBeforeInput(argv: [String]) throws {
    var context = try CLIJobContext()
    do {
        _ = try CLIArguments(argv, context: &context)
        Issue.record("Expected usage failure")
    } catch let error as CLIError { #expect(error.exit == 2) }
    #expect(context.used(.totalInputBytes) == 0 && context.committedResults == 0)
}
@Test func cliHTMLPreviewZeroCompleteAndSyntaxShareAtomicOutput() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "html-preview-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: false)
    defer { try? FileManager.default.removeItem(at: root) }
    let input = root.appendingPathComponent("input.json")
    let output = root.appendingPathComponent("output.html")
    try Data("\"**bold** $x_i^2$ TAIL\"".utf8).write(to: input)
    for flags in [
        ["--string-preview", "0"], ["--full-values"], ["--layout", "syntax"],
        ["--inline-formatting", "off", "--value-previews", "off"],
    ] {
        var context = try CLIJobContext()
        let args = try CLIArguments(
            ["render", input.path, "--output", output.path, "--overwrite"] + flags,
            context: &context)
        #expect(try CLIEngine.execute(args, context: &context) == 0)
        let html = String(decoding: try Data(contentsOf: output), as: UTF8.self)
        #expect(!html.contains("<script>"))
        if flags.first == "--string-preview" { #expect(html.contains("first 0 decoded scalars")) }
        if flags.first == "--layout" {
            #expect(!html.contains("<math ") && !html.contains("<strong>"))
        }
        if flags.first == "--full-values" { #expect(!html.contains("String preview ·")) }
        #expect(context.committedResults == 1)
    }
    let prior = try Data(contentsOf: output)
    var limits = CLILimits()
    limits.core[.workUnits] = 1_000
    var failing = try CLIJobContext(limits: limits)
    let args = try CLIArguments(
        ["render", input.path, "--output", output.path, "--overwrite"], context: &failing)
    #expect(throws: (any Error).self) { _ = try CLIEngine.execute(args, context: &failing) }
    #expect(try Data(contentsOf: output) == prior && failing.committedResults == 0)
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == [
            "input.json", "output.html",
        ])
}
