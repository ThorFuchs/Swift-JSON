// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONPatch
import JSONHTML
import JSONFilterRuntime

/// Executable-only engine. This is a package declaration, not a sixth library API.
package enum CLIEngine {
    package static func runCommandLine() -> Int32 {
        do {
            var context = try CLIJobContext(limits: .init(profile: .offline))
            var diagnostics = try CLIDiagnostics(context: &context)
            var arguments: CLIArguments?
            var preferences = (json: false, report: false)
            do {
                let argv = try CLIProcessArguments.read(context: &context)
                preferences = try CLIProcessArguments.preferences(argv, context: &context)
                if preferences.report { try diagnostics.reserve(8192, context: &context) }
                let parsed = try CLIArguments(argv, admitted: true, context: &context); arguments = parsed
                let limits: CLILimits
                do { limits = try resolveLimits(parsed, context: &context) }
                catch let failure as JSONFailure where failure.category != .resource {
                    // Strict grammar/conversion errors in a configuration file are usage errors.
                    // Resource exhaustion, cancellation and I/O retain their operational category.
                    throw CLIError(.usage, "invalidLimitsFile")
                }
                try context.configure(limits)
                context.limitsFileApplied = parsed.options["limits-file"] != nil
                try diagnostics.reserve(min(parsed.options["report"] == "json" ? 8192 : 256, limits[.diagnosticBytes]), context: &context)
                let exit = try execute(parsed, context: &context)
                diagnostics.emit(error: nil, completed: true, wantsReport: parsed.options["report"] == "json", json: parsed.options["diagnostics"] == "json", context: &context)
                return exit
            } catch {
                let error = CLIDiagnostics.classify(error); context.latch(error)
                diagnostics.emit(error: error, completed: false, wantsReport: arguments?.options["report"] == "json" || preferences.report, json: arguments?.options["diagnostics"] == "json" || preferences.json, context: &context)
                return error.exit
            }
        } catch { return CLIDiagnostics.classify(error).exit }
    }
    package static func resolveLimits(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> CLILimits {
        let profile: JSONResourceProfile
        switch arguments.options["limits"] ?? "balanced" {
        case "conservative": profile = .conservative
        case "balanced": profile = .balanced
        case "offline": profile = .offline
        default: throw CLIError(.usage, "invalidProfile")
        }
        var result = CLILimits(profile: profile)
        if let path = arguments.options["limits-file"] {
            let input = try CLIInput(path: path)
            let value = try input.document(context: &context)
            guard case .object(let object) = value else { throw CLIError(.usage, "invalidLimitsFile") }
            for member in object {
                try context.work()
                switch member.key.string {
                case "version": guard case .number(let number) = member.value, try number.integer(as: Int.self, meter: &context.meter) == 1 else { throw CLIError(.usage, "invalidLimitsVersion") }
                case "cli", "json":
                    guard case .object(let caps) = member.value else { throw CLIError(.usage, "invalidLimitsFile") }
                    for cap in caps {
                        try context.work()
                        guard case .number(let number) = cap.value, number.isInteger, !number.isNegative else { throw CLIError(.usage, "invalidLimitsFile") }
                        let maximum = try number.integer(as: UInt64.self, meter: &context.meter)
                        if member.key.string == "cli" {
                            guard let metric = CLIResourceMetric(rawValue: cap.key.string) else { throw CLIError(.usage, "unknownLimit") }; result[metric] = maximum
                        } else {
                            guard let metric = JSONResourceMetric(rawValue: cap.key.string) else { throw CLIError(.usage, "unknownLimit") }; result.core[metric] = maximum
                        }
                    }
                default: throw CLIError(.usage, "unknownLimitsField")
                }
            }
            try context.meter.resetValueBounds()
        }
        return result
    }
    private static func execute(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> Int32 {
        if ["help", "--help", "-h"].contains(arguments.command) || arguments.hasHelp {
            let selected = arguments.hasHelp ? arguments.command : arguments.positionals.first
            guard arguments.hasHelp || arguments.positionals.count <= 1 else { throw CLIError(.usage, "helpArity") }
            return try text(CLIHelp.text(for: selected), arguments: arguments, context: &context)
        }
        if arguments.command == "--version" {
            guard arguments.positionals.isEmpty || arguments.positionals == ["--json"] else { throw CLIError(.usage, "invalidVersionOption") }
            let version = arguments.positionals.isEmpty ? "swift-json 1.4.0-dev\n" : CLIHelp.versionJSON
            return try text(version, arguments: arguments, context: &context)
        }
        if arguments.command == "query" { return try CLIQueryCommand.run(arguments, context: &context) }
        if arguments.command == "stream" { return try CLIStreamCommand.run(arguments, context: &context) }
        if arguments.command == "schema" { return try CLISchemaCommand.run(arguments, context: &context) }
        let inputPath: String
        let pointerText: String?
        if arguments.command == "pointer" {
            guard (1...2).contains(arguments.positionals.count) else { throw CLIError(.usage, "pointerArity") }
            pointerText = arguments.positionals[0]; inputPath = arguments.positionals.count == 2 ? arguments.positionals[1] : "-"
        } else {
            guard arguments.positionals.count <= 1 else { throw CLIError(.usage, "inputArity") }
            pointerText = nil; inputPath = arguments.positionals.first ?? "-"
        }
        let auxiliary = [arguments.options["schema"], arguments.options["patch"], arguments.options["limits-file"]].compactMap { $0 }
        let inputs = [inputPath] + auxiliary + arguments.repeated.compactMap { name, value in name == "resource" ? value.split(separator: "=", maxSplits: 1).last.map(String.init) : nil }
        guard inputs.filter({ $0 == "-" }).count <= 1 else { throw CLIError(.usage, "repeatedStdin") }
        if arguments.command == "patch", arguments.options["patch"] == nil { throw CLIError(.usage, "missingPatch") }
        let output = try CLIOutput(destination: arguments.options["output"] ?? arguments.options["html"], overwrite: arguments.overwrite, inputs: inputs, context: &context)
        let input = try CLIInput(path: inputPath)
        let value = try input.document(context: &context)
        var exit: Int32 = 0
        switch arguments.command {
        case "format": try emit(value, arguments: arguments, output: output, context: &context)
        case "pointer":
            let pointer = try JSONPointer.parse(pointerText!, meter: &context.meter)
            if arguments.options["allow-missing"] != nil {
                if let selected = try pointer.resolveIfPresent(in: value, meter: &context.meter) {
                    try emit(selected, arguments: arguments, output: output, context: &context)
                } else { exit = 4 }
            } else { try emit(pointer.resolve(in: value, meter: &context.meter), arguments: arguments, output: output, context: &context) }
        case "patch":
            try context.meter.resetValueBounds()
            let patchJSON = try CLIInput(path: arguments.options["patch"]!).document(context: &context)
            try context.domain(.patch)
            let patch = try JSONPatch(json: patchJSON, meter: &context.meter)
            let result = try patch.applying(to: .document(value), meter: &context.meter)
            if case .document(let updated) = result { try emit(updated, arguments: arguments, output: output, context: &context) }
        case "validate":
            if let schemaPath = arguments.options["schema"] {
                try context.meter.resetValueBounds()
                let schema = try CLIInput(path: schemaPath).document(context: &context)
                try context.domain(.schemaCompilation)
                var documents: [JSONSchemaDocument] = []
                for (name, resource) in arguments.repeated where name == "resource" {
                    let pair = resource.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
                    guard pair.count == 2 else { throw CLIError(.usage, "invalidResource") }
                    try context.meter.resetValueBounds()
                    let raw = try CLIInput(path: String(pair[1])).document(context: &context)
                    try context.domain(.schemaCompilation)
                    let uri = try JSONSchemaURI.parse(String(pair[0]), relativeTo: nil, meter: &context.meter)
                    documents.append(try JSONSchemaDocument(raw, retrievalURI: uri, meter: &context.meter))
                }
                let registry = try JSONSchemaRegistry.checked(documents, meter: &context.meter)
                var options = JSONSchemaOptions(limits: context.meter.limits)
                if let count = arguments.options["max-issues"] {
                    guard let maximum = UInt64(count), maximum <= context.meter.limits[.issues] else { throw CLIError(.usage, "invalidMaxIssues") }
                    options.limits[.issues] = maximum
                    context.maxIssues = maximum
                    options.diagnosticPolicy = .bestEffort
                }
                let plan = try JSONSchemaCompiler(options: options).compile(schema, registry: registry, meter: &context.meter)
                try context.domain(.schemaEvaluation); try context.meter.resetValueBounds()
                try context.meter.configure(options.limits)
                let result = try JSONSchemaValidator(options: options).validate(value, against: plan, meter: &context.meter)
                var issues: [JSON] = []
                for issue in result.issues {
                    try context.work(); issues.append(try object([("instanceLocation", .string(issue.instanceLocation.string)), ("keywordLocation", .string(issue.keywordLocation.string))], context: &context))
                }
                let verdict = try object([("valid", .boolean(result.isValid)), ("issues", .array(issues)), ("truncated", .boolean(!result.diagnosticsComplete))], context: &context)
                try emit(verdict, arguments: arguments, output: output, context: &context); exit = result.isValid ? 0 : 1
            } else {
                let verdict = try object([("valid", .boolean(true)), ("issues", .array([])), ("truncated", .boolean(false))], context: &context)
                try emit(verdict, arguments: arguments, output: output, context: &context)
            }
        case "render":
            let format = arguments.options["html"] == nil ? arguments.options["format"] ?? "html" : "html"
            guard arguments.options["html"] == nil || arguments.options["format"] == nil && arguments.options["output"] == nil else { throw CLIError(.usage, "conflictingHTMLOutput") }
            if format == "html" {
                let presentation: JSONHTMLPresentation
                switch arguments.options["presentation"] ?? "static" {
                case "static": presentation = .formatted
                case "interactive": presentation = .interactive
                default: throw CLIError(.usage, "invalidPresentation")
                }
                let theme: JSONHTMLTheme
                switch arguments.options["theme"] ?? "system" {
                case "system": theme = .automatic
                case "light": theme = .light
                case "dark": theme = .dark
                default: throw CLIError(.usage, "invalidTheme")
                }
                try context.domain(.writing); try context.meter.resetValueBounds()
                let options = JSONHTMLRenderingOptions(title: arguments.options["title"] ?? "JSON", theme: theme, limits: .init(core: context.meter.limits), presentation: presentation)
                let html = try JSONHTMLRenderer(options: options).render(value, meter: &context.meter)
                try context.charge(.totalResults); try output.write(html.bytes, context: &context); output.resultAccepted(context: &context)
            } else if format == "text" || format == "markdown" {
                if format == "markdown" { try output.write(Array("```json\n".utf8), context: &context) }
                try emit(value, arguments: arguments, output: output, tabs: true, context: &context)
                if format == "markdown" { try output.write(Array("```\n".utf8), context: &context) }
            } else { throw CLIError(.usage, "capabilityUnavailable") }
        default: throw CLIError(.usage, "unknownCommand")
        }
        try output.finish(inputs: inputs, context: &context)
        return exit
    }
    package static func emit(_ value: JSON, arguments: CLIArguments, output: CLIOutput, tabs: Bool = false, compact: Bool = false, context: inout CLIJobContext) throws {
        try context.domain(.writing); try context.meter.resetValueBounds()
        let options = compact ? JSONWritingOptions(limits: context.meter.limits) : arguments.writingOptions(limits: context.meter.limits, tabs: tabs)
        let writer = JSONWriter(options: options)
        var bytes = try writer.write(value, meter: &context.meter)
        try context.meter.charge(.outputBytes); try context.meter.retain(1); bytes.append(10)
        try context.charge(.totalResults); try output.write(bytes, context: &context); output.resultAccepted(context: &context)
        try context.meter.release(UInt64(bytes.count))
    }
    package static func object(_ pairs: [(String, JSON)], context: inout CLIJobContext) throws -> JSON {
        var members: [JSONMember] = []
        for (key, value) in pairs { try context.work(); try context.meter.retain(JSONLogicalWeights.member); members.append(.init(try JSONKey(key, meter: &context.meter), value: value)) }
        return .object(try JSONObject.indexed(admitted: members, meter: &context.meter))
    }
    private static func text(_ value: String, arguments: CLIArguments, context: inout CLIJobContext) throws -> Int32 {
        let output = try CLIOutput(destination: arguments.options["output"], overwrite: arguments.overwrite, inputs: [], context: &context)
        try context.meter.retain(UInt64(value.utf8.count)); try output.write(Array(value.utf8), context: &context)
        try output.finish(inputs: [], context: &context); return 0
    }
}
