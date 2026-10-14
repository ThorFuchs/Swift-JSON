// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONFilterRuntime

package enum CLISchemaCommand {
    package static func run(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> Int32 {
        if arguments.positionals.first == "provider" {
            guard arguments.positionals.count >= 2, ["openai-format", "openai-tool", "apple-check"].contains(arguments.positionals[1]) else { throw CLIError(.usage, "unknownSchemaCommand") }
            throw CLIError(.usage, "capabilityUnavailable")
        }
        guard arguments.positionals.count == 2, arguments.positionals[0] == "check" else { throw CLIError(.usage, "invalidSchemaCommand") }
        guard arguments.options["name"] == nil && arguments.options["description"] == nil else { throw CLIError(.usage, "invalidSchemaOption") }
        let schemaPath = arguments.positionals[1]
        let resourcePaths = try arguments.repeated.map { pair -> String in
            let parts = pair.1.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.0 == "resource", parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else { throw CLIError(.usage, "invalidResource") }
            try context.work(UInt64(pair.1.utf8.count)); return String(parts[1])
        }
        let inputs = [schemaPath] + resourcePaths + [arguments.options["limits-file"]].compactMap { $0 }
        guard inputs.filter({ $0 == "-" }).count <= 1 else { throw CLIError(.usage, "repeatedStdin") }
        let output = try CLIOutput(destination: arguments.options["output"], overwrite: arguments.overwrite, inputs: inputs, context: &context)
        let raw = try CLIInput(path: schemaPath).document(context: &context)
        try context.domain(.schemaCompilation)
        var documents: [JSONSchemaDocument] = []
        for pair in arguments.repeated {
            let parts = pair.1.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            try context.meter.resetValueBounds()
            let resource = try CLIInput(path: String(parts[1])).document(context: &context)
            try context.domain(.schemaCompilation)
            let uri = try JSONSchemaURI.parse(String(parts[0]), relativeTo: nil, meter: &context.meter)
            try context.meter.retain(32)
            documents.append(try JSONSchemaDocument(resource, retrievalURI: uri, meter: &context.meter))
        }
        let registry = try JSONSchemaRegistry.checked(documents, meter: &context.meter)
        let plan = try JSONSchemaCompiler(options: .init(limits: context.meter.limits)).compile(raw, registry: registry, meter: &context.meter)
        var metadata: [(String, JSON)] = [("completed", .boolean(true)), ("dialect", .string("https://json-schema.org/draft/2020-12/schema")), ("schemaKind", .string(plan.document.raw.isBooleanSchema ? "boolean" : "object")), ("documents", .number(JSONNumber(integer: plan.plan.documents.count))), ("compiledNodes", .number(JSONNumber(integer: plan.plan.nodes.count))), ("resources", .number(JSONNumber(integer: plan.plan.resources.count)))]
        if let uri = plan.document.retrievalURI { metadata.append(("retrievalURI", .string(uri.string))) }
        let value = try CLIEngine.object(metadata, context: &context)
        try CLIEngine.emit(value, arguments: arguments, output: output, compact: true, context: &context)
        try output.finish(inputs: inputs, context: &context)
        return 0
    }
}
private extension JSON { var isBooleanSchema: Bool { if case .boolean = self { return true }; return false } }
