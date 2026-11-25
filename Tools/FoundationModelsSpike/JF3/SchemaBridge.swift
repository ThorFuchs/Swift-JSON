// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// The strict default preserves the complete schema value. The explicit alternative
/// admits only newly added title and x-order annotations at actual schema nodes.
/// Structural equivalence additionally proves the narrow local-reference and
/// required-permutation transformations observed in JF3.2. Explicit opt-in only.
public enum JSONGenerationSchemaMetadataPolicy: Sendable, Equatable {
    case exact
    case allowGeneratedAnnotations
    case allowStructuralEquivalence
}

public enum JSONGenerationSchemaIssue: String, Sendable, Equatable {
    case unsupportedDeclaration, unsupportedShape, changedConstraint
    case changedAnnotation, annotationAdditionDenied
    case invalidLocalReference, cyclicLocalReference, unusedDefinition
}

/// First incompatible declaration, using exact decoded keys rather than String paths.
public struct JSONGenerationSchemaFailure: Error, Sendable, Equatable {
    public let issue: JSONGenerationSchemaIssue
    public let path: [JSONLocationComponent]
}

/// An admitted addition; the actual value remains inspectable in the returned document.
public struct JSONGenerationSchemaAnnotationAddition: Sendable, Equatable {
    public let path: [JSONLocationComponent]
}

// Narrow, versioned profile. Native compilation is necessary but not sufficient.
// Only schema positions are traversed as schemas: a property named title or
// x-order is not annotation metadata. No references or combinators in this profile.
enum JF3SchemaProfile {
    typealias Path = [JSONLocationComponent]

    static func path(_ base: Path, _ key: JSONKey, meter: inout JSONWorkMeter) throws -> Path {
        try meter.require(.pointerTokens, UInt64(base.count) + 1)
        var result: Path = []
        for part in base { try meter.work(); try meter.retain(32); result.append(part) }
        for _ in key.string.utf8 { try meter.work(); try meter.retain(1) }
        try meter.retain(32); result.append(.key(key))
        return result
    }

    static func failure(_ issue: JSONGenerationSchemaIssue, _ path: Path) -> JSONGenerationSchemaFailure {
        .init(issue: issue, path: path)
    }

    static func ascii(_ text: String, meter: inout JSONWorkMeter) throws -> Bool {
        for byte in text.utf8 { try meter.work(); if byte > 127 { return false } }
        return true
    }

    static func check(_ raw: JSON, at location: Path = [], depth: Int = 1,
                      descend: Bool = true, allowRootDefinitions: Bool = false,
                      meter: inout JSONWorkMeter) throws {
        try meter.checkpoint()
        guard depth <= 16, let object = raw.objectValue,
              let type = try object.lookup("type", meter: &meter)?.stringValue,
              try ascii(type, meter: &meter),
              ["object", "array", "string", "integer", "number", "boolean"].contains(type),
              depth != 1 || type == "object" else { throw failure(.unsupportedShape, location) }
        for member in object {
            try meter.work()
            let key = member.key.string
            let field = try path(location, member.key, meter: &meter)
            guard try ascii(key, meter: &meter) else { throw failure(.unsupportedDeclaration, field) }
            switch key {
            case "type": break
            case "$defs":
                guard allowRootDefinitions && depth == 1 else { throw failure(.unsupportedDeclaration, field) }
            case "title", "description":
                guard member.value.stringValue != nil else { throw failure(.unsupportedShape, field) }
            case "properties", "required", "additionalProperties", "x-order":
                guard type == "object" else { throw failure(.unsupportedDeclaration, field) }
            case "items", "minItems", "maxItems":
                guard type == "array" else { throw failure(.unsupportedDeclaration, field) }
            case "enum":
                guard type == "string", let values = member.value.arrayValue, !values.isEmpty, values.count <= 128 else {
                    throw failure(.unsupportedShape, field)
                }
                for value in values { try meter.work(); guard value.stringValue != nil else { throw failure(.unsupportedShape, field) } }
            case "minimum", "maximum":
                guard type == "integer" || type == "number" else { throw failure(.unsupportedDeclaration, field) }
            default: throw failure(.unsupportedDeclaration, field)
            }
        }
        if type == "object" {
            guard let props = try object.lookup("properties", meter: &meter)?.objectValue, props.count <= 128,
                  let required = try object.lookup("required", meter: &meter)?.arrayValue,
                  try object.lookup("additionalProperties", meter: &meter)?.booleanValue == false else {
                throw failure(.unsupportedShape, location)
            }
            let propsPath = try path(location, JSONKey("properties"), meter: &meter)
            for member in props {
                let child = try path(propsPath, member.key, meter: &meter)
                guard !member.key.string.isEmpty, try ascii(member.key.string, meter: &meter) else {
                    throw failure(.unsupportedShape, child)
                }
                if descend { try check(member.value, at: child, depth: depth + 1, meter: &meter) }
            }
            try names(required, properties: props, at: path(location, JSONKey("required"), meter: &meter), meter: &meter)
            if let order = try object.lookup("x-order", meter: &meter) {
                let orderPath = try path(location, JSONKey("x-order"), meter: &meter)
                guard let values = order.arrayValue, values.count == props.count else { throw failure(.unsupportedShape, orderPath) }
                try names(values, properties: props, at: orderPath, meter: &meter)
            }
        } else if type == "array" {
            guard let item = try object.lookup("items", meter: &meter) else { throw failure(.unsupportedShape, location) }
            let child = try path(location, JSONKey("items"), meter: &meter)
            if descend { try check(item, at: child, depth: depth + 1, meter: &meter) }
        }
    }

    private static func names(_ values: [JSON], properties: JSONObject, at location: Path, meter: inout JSONWorkMeter) throws {
        guard values.count <= properties.count else { throw failure(.unsupportedShape, location) }
        for i in values.indices {
            try meter.work()
            guard let name = values[i].stringValue, try properties.lookup(name, meter: &meter) != nil else {
                throw failure(.unsupportedShape, location)
            }
            for j in 0..<i {
                try meter.work()
                guard let previous = values[j].stringValue, try !JSONComparison.textEquals(name, previous, meter: &meter) else {
                    throw failure(.unsupportedShape, location)
                }
            }
        }
    }

    // Both trees have passed native compilation and the profile before comparison.
    static func compare(_ original: JSON, _ returned: JSON, policy: JSONGenerationSchemaMetadataPolicy,
                        at location: Path = [], additions: inout [JSONGenerationSchemaAnnotationAddition],
                        meter: inout JSONWorkMeter) throws {
        try meter.checkpoint()
        guard let a = original.objectValue, let b = returned.objectValue else { throw failure(.changedConstraint, location) }
        for member in a {
            try meter.work()
            let field = try path(location, member.key, meter: &meter)
            let key = member.key.string
            let annotation = ["title", "description", "x-order"].contains(key)
            guard let other = try b.lookup(key, meter: &meter) else { throw failure(annotation ? .changedAnnotation : .changedConstraint, field) }
            if key == "properties" {
                guard let x = member.value.objectValue, let y = other.objectValue, x.count == y.count else { throw failure(.changedConstraint, field) }
                for prop in x {
                    let child = try path(field, prop.key, meter: &meter)
                    guard let target = try y.lookup(prop.key.string, meter: &meter) else { throw failure(.changedConstraint, child) }
                    try compare(prop.value, target, policy: policy, at: child, additions: &additions, meter: &meter)
                }
            } else if key == "items" {
                try compare(member.value, other, policy: policy, at: field, additions: &additions, meter: &meter)
            } else if try !JSONComparison.equals(member.value, other, meter: &meter) {
                throw failure(annotation ? .changedAnnotation : .changedConstraint, field)
            }
        }
        for member in b {
            try meter.work()
            if try a.lookup(member.key.string, meter: &meter) != nil { continue }
            let field = try path(location, member.key, meter: &meter)
            guard member.key.string == "title" || member.key.string == "x-order" else {
                throw failure(member.key.string == "description" ? .changedAnnotation : .changedConstraint, field)
            }
            guard policy == .allowGeneratedAnnotations else { throw failure(.annotationAdditionDenied, field) }
            try meter.charge(.issues); try meter.retain(32)
            for component in field {
                try meter.work(); try meter.charge(.diagnosticBytes, 16)
                if case .key(let key) = component {
                    for _ in key.string.utf8 { try meter.work(); try meter.charge(.diagnosticBytes) }
                }
            }
            additions.append(.init(path: field))
        }
    }
}

struct JF3Projection<Schema> {
    let schema: Schema
    let canonical: CompiledJSONSchema
    let roundtripped: JSONSchemaDocument
    let additions: [JSONGenerationSchemaAnnotationAddition]
    let rewrites: [JSONGenerationSchemaStructuralRewrite]
}

// The coding state owns the single noncopyable native meter for all stages.
// Its opaque Codable callbacks are outside native accounting and preemption.
enum JF3SchemaBoundary {
    static func state(_ limits: JSONLimits) throws -> JSONCodingState {
        let meter = try JSONWorkMeter(limits: limits, domain: .coding)
        return JSONCodingState(options: .init(limits: limits), meter: meter)
    }

    static func compile(_ document: JSONSchemaDocument, state: JSONCodingState) throws -> CompiledJSONSchema {
        try state.check(); try state.meter.operationDomain(.schemaCompilation)
        let plan = try JSONSchemaCompiler(options: .init(limits: state.meter.limits)).compile(document, registry: .empty, meter: &state.meter)
        try state.meter.operationDomain(.core)
        try JF3SchemaProfile.check(document.raw, meter: &state.meter)
        return plan
    }

    static func importSchema<T: Encodable>(_ schema: T, limits: JSONLimits) throws -> JSONOperationReport<CompiledJSONSchema> {
        let state = try state(limits)
        let raw = try JSONValueEncoder.encode(schema, state: state)
        let document = try JSONSchemaDocument(raw, meter: &state.meter)
        let plan = try compile(document, state: state)
        try state.check()
        return .init(result: plan, statistics: try state.meter.compositionStatistics())
    }

    static func project<T: Codable>(_ type: T.Type, document: JSONSchemaDocument, policy: JSONGenerationSchemaMetadataPolicy,
                                    limits: JSONLimits) throws -> JSONOperationReport<JF3Projection<T>> {
        let state = try state(limits)
        let canonical = try compile(document, state: state)
        try state.meter.operationDomain(.coding)
        try JSONAdmission.value(document.raw, meter: &state.meter)
        let schema = try JSONNativeDecoder(value: document.raw, state: state, codingPath: []).decode(type)
        try state.check()
        let raw = try JSONValueEncoder.encode(schema, state: state)
        let returned = try JSONSchemaDocument(raw, meter: &state.meter)
        var additions: [JSONGenerationSchemaAnnotationAddition] = []
        var rewrites: [JSONGenerationSchemaStructuralRewrite] = []
        if policy == .allowStructuralEquivalence {
            // The original has compiled and passed the unchanged reference-free
            // profile. Prove the bounded shape before compiling the actual graph;
            // unsafe references cannot induce an expansion or a recursive compile.
            let proof = try JF33StructuralProof.verify(document.raw, returned.raw, meter: &state.meter)
            additions = proof.additions; rewrites = proof.rewrites
            try state.check(); try state.meter.operationDomain(.schemaCompilation)
            _ = try JSONSchemaCompiler(options: .init(limits: state.meter.limits)).compile(returned, registry: .empty, meter: &state.meter)
            try state.meter.operationDomain(.core)
        } else {
            // Retain JF3.1's existing policies and error order.
            _ = try compile(returned, state: state)
            try JF3SchemaProfile.compare(document.raw, returned.raw, policy: policy, additions: &additions, meter: &state.meter)
        }
        try state.check()
        return .init(result: .init(schema: schema, canonical: canonical, roundtripped: returned, additions: additions, rewrites: rewrites),
                     statistics: try state.meter.compositionStatistics())
    }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

/// Candidate prepared schema. Always validate actual instances against canonical.
@available(macOS 27.0, iOS 27.0, *)
public struct JSONGenerationSchemaProjection {
    public let schema: GenerationSchema
    public let canonical: CompiledJSONSchema
    public let roundtripped: JSONSchemaDocument
    public let additions: [JSONGenerationSchemaAnnotationAddition]
    public let rewrites: [JSONGenerationSchemaStructuralRewrite]
}

/// Candidate bridge with reference-free canonical input; the explicit structural
/// policy accepts only proved SDK rewrites on the returned representation.
/// Neither a general schema equivalence solver nor a guarantee of model behavior.
@available(macOS 27.0, iOS 27.0, *)
public struct JSONGenerationSchemaBridge: Sendable {
    public let limits: JSONLimits
    public init(limits: JSONLimits = .balanced) { self.limits = limits }

    public func importSchema(_ schema: GenerationSchema) throws -> CompiledJSONSchema {
        try importSchemaWithReport(schema).result
    }
    public func importSchemaWithReport(_ schema: GenerationSchema) throws -> JSONOperationReport<CompiledJSONSchema> {
        try JF3SchemaBoundary.importSchema(schema, limits: limits)
    }
    public func project(_ document: JSONSchemaDocument, metadata: JSONGenerationSchemaMetadataPolicy = .exact) throws -> JSONGenerationSchemaProjection {
        try projectWithReport(document, metadata: metadata).result
    }
    public func projectWithReport(_ document: JSONSchemaDocument, metadata: JSONGenerationSchemaMetadataPolicy = .exact) throws -> JSONOperationReport<JSONGenerationSchemaProjection> {
        let report = try JF3SchemaBoundary.project(GenerationSchema.self, document: document, policy: metadata, limits: limits)
        let value = report.result
        return .init(result: .init(schema: value.schema, canonical: value.canonical, roundtripped: value.roundtripped, additions: value.additions, rewrites: value.rewrites), statistics: report.statistics)
    }
}
#endif
