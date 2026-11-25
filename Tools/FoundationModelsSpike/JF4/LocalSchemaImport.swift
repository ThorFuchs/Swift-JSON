// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// Explicit opt-in for importing the actual, reference-bearing schema of a
/// Generable type. This is NOT a reverse projection policy and does not widen
/// the reference-free input accepted by project(_:metadata:).
public enum JSONGenerationSchemaImportPolicy: Sendable, Equatable {
    case referenceFree
    case allowLocalObjectDefinitions
}

// Check every effective schema position in the actual imported graph. Do not
// materialize an expanded document or invent an earlier source declaration.
// The only validation authority is the original graph compiled by Swift-JSON.
struct JF42LocalImport {
    typealias Path = JF3SchemaProfile.Path
    private let definitions: JSONObject?
    private var used: [Bool]
    private var active: [Bool]

    static func check(_ raw: JSON, meter: inout JSONWorkMeter) throws {
        guard let root = raw.objectValue else {
            throw JF3SchemaProfile.failure(.unsupportedShape, [])
        }
        let defsPath: Path = [.key(JSONKey("$defs"))]
        var definitions: JSONObject?
        if let value = try root.lookup("$defs", meter: &meter) {
            guard let table = value.objectValue, !table.isEmpty, table.count <= 128 else {
                throw JF3SchemaProfile.failure(.unsupportedShape, defsPath)
            }
            for member in table {
                try meter.work()
                guard !member.key.string.isEmpty else {
                    throw JF3SchemaProfile.failure(.invalidLocalReference, defsPath)
                }
            }
            definitions = table
        }
        let count = definitions?.count ?? 0
        try meter.retain(64 + UInt64(count) * 2)
        var check = Self(definitions: definitions, used: Array(repeating: false, count: count),
                         active: Array(repeating: false, count: count))
        try check.node(raw, at: [], depth: 1, root: true, meter: &meter)
        if let definitions {
            for i in definitions.indices {
                try meter.work()
                guard check.used[i] else {
                    throw JF3SchemaProfile.failure(.unusedDefinition,
                        try JF3SchemaProfile.path(defsPath, definitions[i].key, meter: &meter))
                }
            }
        }
        try meter.checkpoint()
    }

    private mutating func node(_ raw: JSON, at path: Path, depth: Int, root: Bool = false,
                               allowReference: Bool = true, meter: inout JSONWorkMeter) throws {
        try meter.checkpoint(); try meter.work(); try meter.retain(64)
        guard depth <= 16, let object = raw.objectValue else {
            throw JF3SchemaProfile.failure(.unsupportedShape, path)
        }
        if let reference = try object.lookup("$ref", meter: &meter) {
            let field = try JF3SchemaProfile.path(path, JSONKey("$ref"), meter: &meter)
            guard !root, allowReference, object.count == 1, let fragment = reference.stringValue,
                  let definitions else {
                throw JF3SchemaProfile.failure(.invalidLocalReference, field)
            }
            let pointer: JSONPointer
            do { pointer = try JSONPointer.uriFragment(fragment, meter: &meter) }
            catch let error as JSONFailure where error.category == .pointer {
                throw JF3SchemaProfile.failure(.invalidLocalReference, field)
            }
            guard pointer.tokens.count == 2,
                  try JSONComparison.textEquals(pointer.tokens[0].string, "$defs", meter: &meter) else {
                throw JF3SchemaProfile.failure(.invalidLocalReference, field)
            }
            var index: Int?
            for i in definitions.indices {
                try meter.work()
                if try JSONComparison.textEquals(definitions[i].key.string, pointer.tokens[1].string, meter: &meter) {
                    index = i; break
                }
            }
            guard let index else { throw JF3SchemaProfile.failure(.invalidLocalReference, field) }
            guard !active[index] else { throw JF3SchemaProfile.failure(.cyclicLocalReference, field) }
            let target = definitions[index].value
            guard let concrete = target.objectValue, let kind = try concrete.lookup("type", meter: &meter)?.stringValue,
                  try JSONComparison.textEquals(kind, "object", meter: &meter),
                  try concrete.lookup("$ref", meter: &meter) == nil else {
                throw JF3SchemaProfile.failure(.invalidLocalReference, field)
            }
            used[index] = true; active[index] = true
            try node(target, at: path, depth: depth, allowReference: false, meter: &meter)
            active[index] = false
            return
        }
        // Share the exact JF3 local keyword, shape and name policy. Only root
        // definitions are special, and every definition must be reached.
        try JF3SchemaProfile.check(raw, at: path, depth: depth, descend: false,
                                   allowRootDefinitions: root, meter: &meter)
        if let props = try object.lookup("properties", meter: &meter)?.objectValue {
            let base = try JF3SchemaProfile.path(path, JSONKey("properties"), meter: &meter)
            for prop in props {
                try meter.work()
                let child = try JF3SchemaProfile.path(base, prop.key, meter: &meter)
                try node(prop.value, at: child, depth: depth + 1, meter: &meter)
            }
        }
        if let item = try object.lookup("items", meter: &meter) {
            let child = try JF3SchemaProfile.path(path, JSONKey("items"), meter: &meter)
            try node(item, at: child, depth: depth + 1, meter: &meter)
        }
    }
}

enum JF42SchemaImport {
    static func importSchema<T: Encodable>(_ schema: T, policy: JSONGenerationSchemaImportPolicy,
                                           limits: JSONLimits) throws -> JSONOperationReport<CompiledJSONSchema> {
        if policy == .referenceFree {
            return try JF3SchemaBoundary.importSchema(schema, limits: limits)
        }
        let state = try JF3SchemaBoundary.state(limits)
        let raw = try JSONValueEncoder.encode(schema, state: state)
        let doc = try JSONSchemaDocument(raw, meter: &state.meter)
        // Check the closed local graph before compilation. The compiler remains
        // the authority for declaration validity and actual reference resolution.
        try state.meter.operationDomain(.core)
        try JF42LocalImport.check(raw, meter: &state.meter)
        try state.check()
        try state.meter.operationDomain(.schemaCompilation)
        let plan = try JSONSchemaCompiler(options: .init(limits: state.meter.limits))
            .compile(doc, registry: .empty, meter: &state.meter)
        try state.meter.operationDomain(.core)
        try state.check()
        return .init(result: plan, statistics: try state.meter.compositionStatistics())
    }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

@available(macOS 27.0, iOS 27.0, *)
extension JSONGenerationSchemaBridge {
    /// Imports the actual schema without rewriting its reference graph.
    public func importSchema(_ schema: GenerationSchema,
                             policy: JSONGenerationSchemaImportPolicy) throws -> CompiledJSONSchema {
        try importSchemaWithReport(schema, policy: policy).result
    }

    public func importSchemaWithReport(_ schema: GenerationSchema,
                                       policy: JSONGenerationSchemaImportPolicy) throws -> JSONOperationReport<CompiledJSONSchema> {
        try JF42SchemaImport.importSchema(schema, policy: policy, limits: limits)
    }
}
#endif
