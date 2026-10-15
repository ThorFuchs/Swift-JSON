// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONFilterRuntime

package enum CLISchemaCommand {
    package static func run(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> Int32 {
        let provider = arguments.positionals.first == "provider"
        var purpose: JSONSchemaProviderProfile?
        let schemaPath: String
        if provider {
            guard arguments.positionals.count == 3 else { throw CLIError(.usage, "invalidSchemaCommand") }
            switch arguments.positionals[1] {
            case "openai-format": purpose = .openAIResponsesFormatV1
            case "openai-tool": purpose = .openAIResponsesFunctionV1
            case "apple-check": throw CLIError(.usage, "capabilityUnavailable")
            default: throw CLIError(.usage, "unknownSchemaCommand")
            }
            guard let name = arguments.options["name"], !name.isEmpty else { throw CLIError(.usage, "providerNameRequired") }
            var count: UInt64 = 0
            for byte in name.utf8 {
                try context.work(); count += 1
                guard (65...90).contains(byte) || (97...122).contains(byte) || (48...57).contains(byte) || byte == 95 || byte == 45 else { throw CLIError(.usage, "invalidProviderName") }
            }
            guard count <= 64 else { throw CLIError(.usage, "invalidProviderName") }
            schemaPath = arguments.positionals[2]
        } else {
            guard arguments.positionals.count == 2, arguments.positionals[0] == "check" else { throw CLIError(.usage, "invalidSchemaCommand") }
            guard arguments.options["name"] == nil && arguments.options["description"] == nil else { throw CLIError(.usage, "invalidSchemaOption") }
            schemaPath = arguments.positionals[1]
        }
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
        if let purpose {
            var limits: JSONSchemaProviderLimits = context.limits.profileName == "conservative" ? .conservative : context.limits.profileName == "offline" ? .offline : .balanced
            limits.json = context.meter.limits
            let bridge = OpenAIJSONSchemaBridge(profile: purpose, limits: limits)
            let value: JSON, status: Int32
            do {
                value = try bridge.prepare(raw, name: arguments.options["name"]!, description: arguments.options["description"], registry: registry, purpose: purpose, meter: &context.meter)
                status = 0
            } catch JSONSchemaProviderFailure.incompatible(let compatibility) {
                value = try compatibilityJSON(compatibility, context: &context); status = 1
            }
            try CLIEngine.emit(value, arguments: arguments, output: output, compact: true, context: &context)
            try output.finish(inputs: inputs, context: &context)
            return status
        }
        let plan = try JSONSchemaCompiler(options: .init(limits: context.meter.limits)).compile(raw, registry: registry, meter: &context.meter)
        var metadata: [(String, JSON)] = [("completed", .boolean(true)), ("dialect", .string("https://json-schema.org/draft/2020-12/schema")), ("schemaKind", .string(plan.document.raw.isBooleanSchema ? "boolean" : "object")), ("documents", .number(JSONNumber(integer: plan.plan.documents.count))), ("compiledNodes", .number(JSONNumber(integer: plan.plan.nodes.count))), ("resources", .number(JSONNumber(integer: plan.plan.resources.count)))]
        if let uri = plan.document.retrievalURI { metadata.append(("retrievalURI", .string(uri.string))) }
        let value = try CLIEngine.object(metadata, context: &context)
        try CLIEngine.emit(value, arguments: arguments, output: output, compact: true, context: &context)
        try output.finish(inputs: inputs, context: &context)
        return 0
    }
    private static func compatibilityJSON(_ report: JSONSchemaProviderCompatibility, context: inout CLIJobContext) throws -> JSON {
        var issues: [JSON] = []
        for issue in report.issues {
            try context.work(); try context.meter.retain(32)
            var path: [JSON] = []
            for component in issue.path {
                try context.work(); try context.meter.retain(32)
                switch component {
                case .key(let key): path.append(try CLIEngine.object([("kind", .string("key")), ("key", .string(key.string))], context: &context))
                case .index(let index): path.append(try CLIEngine.object([("kind", .string("index")), ("index", .number(JSONNumber(integer: index)))], context: &context))
                }
            }
            issues.append(try CLIEngine.object([("code", .string(issue.code.rawValue)), ("path", .array(path)), ("unverified", .boolean(issue.unverified)), ("explanation", .string(issue.explanation))], context: &context))
        }
        return try CLIEngine.object([("compatible", .boolean(report.isCompatible)), ("profile", .string(report.profile.rawValue)), ("revision", .string(report.profile.revision)), ("capabilityCategory", .string(report.profile.capabilityCategory)), ("issues", .array(issues)), ("truncated", .boolean(report.truncated))], context: &context)
    }

}
private extension JSON { var isBooleanSchema: Bool { if case .boolean = self { return true }; return false } }
