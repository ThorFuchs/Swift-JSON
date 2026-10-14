// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

package struct CLIArguments: Sendable {
    package let command: String
    package var positionals: [String] = []
    package var options: [String: String] = [:]
    package var repeated: [(String, String)] = []
    package var hasHelp = false
    package var capturedArguments: [String]?
    package var captureJSONArguments = false
    private static let commonValues: Set<String> = ["limits", "limits-file", "output", "diagnostics", "report"]
    private static let values: [String: Set<String>] = [
        "format": ["indent", "number-style"], "validate": ["schema", "resource", "max-issues"],
        "pointer": [], "patch": ["patch"], "stream": ["framing"], "schema": ["resource", "name", "description"],
        "render": ["format", "presentation", "theme", "title", "html"],
        "query": ["filter-file", "input-framing", "indent", "number-style", "arg", "argjson", "rawfile", "slurpfile", "division-scale", "rounding"]
    ]
    private static let booleans: [String: Set<String>] = [
        "format": ["compact", "tab", "sort-keys"], "validate": [], "pointer": ["allow-missing"], "patch": [],
        "stream": [], "schema": [], "render": [],
        "query": ["null-input", "slurp", "raw-input", "compact", "tab", "sort-keys", "raw-output", "raw-output0", "join-output", "ascii-output", "exit-status", "unbuffered", "args", "jsonargs"]
    ]
    package init(_ argv: [String], admitted: Bool = false, context: inout CLIJobContext) throws {
        var bytes: UInt64 = 0
        for argument in argv {
            let (next, overflow) = bytes.addingReportingOverflow(UInt64(argument.utf8.count) + 1)
            guard !overflow else { throw CLIError(.resource, "counterOverflow", metric: "argvBytes") }
            bytes = next
        }
        if !admitted { try context.charge(.argvBytes, bytes); try context.work(bytes); try context.charge(.retainedBytes, bytes + UInt64(argv.count)*8) }
        guard let first = argv.first else { throw CLIError(.usage, "missingCommand") }
        if ["help", "--help", "-h", "--version"].contains(first) {
            command = first; positionals = Array(argv.dropFirst()); return
        }
        guard Self.values[first] != nil else { throw CLIError(.usage, "unknownCommand") }
        command = first
        var i = 1, terminated = false
        let shorts: [Character: String] = ["c":"compact", "S":"sort-keys", "n":"null-input", "s":"slurp", "R":"raw-input", "r":"raw-output", "j":"join-output", "a":"ascii-output", "e":"exit-status", "f":"filter-file", "h":"help"]
        func install(_ name: String, _ value: String) throws {
            if name == "help" { hasHelp = true; return }
            guard options[name] == nil else { throw CLIError(.usage, "duplicateOption") }
            options[name] = value
        }
        while i < argv.count {
            try context.work(); let argument = argv[i]; i += 1
            if terminated || argument == "-" || !argument.hasPrefix("-") { positionals.append(argument); continue }
            if argument == "--" { terminated = true; continue }
            if argument.hasPrefix("--") {
                let pair = argument.dropFirst(2).split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                let name = String(pair[0]) == "compact-output" ? "compact" : String(pair[0]); let inline = pair.count == 2 ? String(pair[1]) : nil
                if name == "help" || name == "overwrite" || Self.booleans[first]!.contains(name) {
                    guard inline == nil else { throw CLIError(.usage, "booleanValue") }
                    try install(name, "true")
                    if name == "args" || name == "jsonargs" {
                        capturedArguments = Array(argv[i...]); captureJSONArguments = name == "jsonargs"; i = argv.count
                    }
                    continue
                }
                guard Self.commonValues.contains(name) || Self.values[first]!.contains(name) else { throw CLIError(.usage, "unknownOption") }
                let value: String
                if let inline { value = inline }
                else { guard i < argv.count else { throw CLIError(.usage, "missingOptionValue") }; value = argv[i]; i += 1 }
                if name == "resource" { repeated.append((name, value)) }
                else if ["arg", "argjson", "rawfile", "slurpfile"].contains(name) {
                    guard i < argv.count else { throw CLIError(.usage, "missingBindingValue") }
                    repeated.append((name, value)); repeated.append(("bindingValue", argv[i])); i += 1
                } else { try install(name, value) }
            } else {
                for short in argument.dropFirst() {
                    guard let name = shorts[short], name == "help" || Self.booleans[first]!.contains(name) || Self.values[first]!.contains(name) else { throw CLIError(.usage, "unknownOption") }
                    if name == "filter-file" {
                        guard argument == "-f", i < argv.count else { throw CLIError(.usage, "shortValueMustBeSeparate") }
                        try install(name, argv[i]); i += 1
                    } else { try install(name, "true") }
                }
            }
        }
        if let style = options["diagnostics"], !["human", "json"].contains(style) { throw CLIError(.usage, "invalidDiagnostics") }
        if let report = options["report"], !["none", "json"].contains(report) { throw CLIError(.usage, "invalidReport") }
        if options["compact"] != nil && (options["indent"] != nil || options["tab"] != nil) || options["indent"] != nil && options["tab"] != nil { throw CLIError(.usage, "conflictingIndentation") }
        if let indent = options["indent"], Int(indent).map({ (0...8).contains($0) }) != true { throw CLIError(.usage, "invalidIndentation") }
        if let style = options["number-style"], !["preserved", "normalized"].contains(style) { throw CLIError(.usage, "invalidNumberStyle") }
        if command == "render" {
            if options["html"] != nil && (options["format"] != nil || options["output"] != nil) { throw CLIError(.usage, "conflictingHTMLOutput") }
            let format = options["format"] ?? "html"
            guard ["html", "markdown", "text"].contains(format) else { throw CLIError(.usage, "capabilityUnavailable") }
            if let presentation = options["presentation"], !["static", "interactive"].contains(presentation) { throw CLIError(.usage, "invalidPresentation") }
            if let theme = options["theme"], !["system", "light", "dark"].contains(theme) { throw CLIError(.usage, "invalidTheme") }
            if format != "html" && (options["presentation"] != nil || options["theme"] != nil || options["title"] != nil) { throw CLIError(.usage, "htmlOnlyOption") }
        }
        if command == "query" {
            if let framing = options["input-framing"], !["document", "values", "ndjson"].contains(framing) { throw CLIError(.usage, "invalidInputFraming") }
            if options["null-input"] != nil && options["slurp"] != nil { throw CLIError(.usage, "nullSlurpConflict") }
            if options["raw-input"] != nil && options["input-framing"] != nil { throw CLIError(.usage, "rawFramingConflict") }
            let raw = ["raw-output", "raw-output0", "join-output"].filter { options[$0] != nil }
            if raw.count > 1 || !raw.isEmpty && options["ascii-output"] != nil { throw CLIError(.usage, "outputModeConflict") }
            if (options["division-scale"] == nil) != (options["rounding"] == nil) { throw CLIError(.usage, "divisionPolicyPairRequired") }
        }
        if positionals.filter({ $0 == "-" }).count > 1 { throw CLIError(.usage, "repeatedStdin") }
    }
    package var overwrite: Bool { options["overwrite"] != nil }
    package func writingOptions(limits: JSONLimits, tabs: Bool = false) -> JSONWritingOptions {
        let tab = tabs || options["tab"] != nil
        return .init(limits: limits, indentation: options["compact"] != nil ? nil : (tab ? 1 : Int(options["indent"] ?? "2")!),
                     keyOrder: options["sort-keys"] == nil ? .insertion : .scalar,
                     numberStyle: options["number-style"] == "normalized" ? .normalized : .preserved,
                     indentationUnit: tab ? .tabs : .spaces)
    }
}
