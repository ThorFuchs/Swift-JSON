// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

package enum CLIStreamCommand {
    package static func run(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> Int32 {
        guard let mode = arguments.positionals.first, ["check", "cat", "array"].contains(mode) else {
            throw CLIError(.usage, "invalidStreamCommand")
        }
        let paths = Array(arguments.positionals.dropFirst())
        let files = paths.isEmpty ? ["-"] : paths
        let framing: CLIInputFraming
        if mode == "array" {
            guard arguments.options["framing"] == nil else { throw CLIError(.usage, "arrayFramingConflict") }
            framing = .array
        } else {
            guard let selected = CLIInputFraming(rawValue: arguments.options["framing"] ?? "values"),
                  [.document, .values, .ndjson].contains(selected) else { throw CLIError(.usage, "invalidInputFraming") }
            framing = selected
        }
        let inputs = files + [arguments.options["limits-file"]].compactMap { $0 }
        let output = try CLIOutput(destination: arguments.options["output"], overwrite: arguments.overwrite, inputs: inputs, context: &context)
        var cursor = CLIInputCursor(files: files, framing: framing)
        defer { try? cursor.close(context: &context) }
        while var value = try cursor.next(context: &context) {
            if mode != "check" { try CLIEngine.emit(value.value, arguments: arguments, output: output, compact: true, context: &context) }
            try value.release(context: &context)
        }
        // Cursor completion includes each file's closing syntax, whitespace and EOF.
        if mode == "check" {
            let records = context.used(.totalRecords)
            let summary = try CLIEngine.object([("completed", .boolean(true)), ("inputRecords", .number(JSONNumber(integer: records)))], context: &context)
            try CLIEngine.emit(summary, arguments: arguments, output: output, compact: true, context: &context)
        }
        try output.finish(inputs: inputs, context: &context)
        return 0
    }
}
