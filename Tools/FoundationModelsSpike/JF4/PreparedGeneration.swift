// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// Schema-invalid arguments are distinct from conversion loss and operational failure.
/// Native issues contain keyword and instance locations, not rejected value payloads.
public enum JSONGenerationArgumentFailure: Error, Sendable {
    case invalidArguments(JSONValidationResult)
    case typedValueChanged
}

// One invocation = one native ledger, including validation, JF2 conversion,
// typed decoding and the exact typed roundtrip check. No nested public reports.
// The synchronous foreign callbacks themselves remain outside native accounting.
enum JF4ArgumentBoundary {
    static func requireValid(_ value: JSON, plan: CompiledJSONSchema,
                             scope: borrowing JSONCompositionScope) throws {
        let result = try scope.withMeter(domain: .schemaEvaluation) { meter in
            try JSONSchemaValidator(options: .init(limits: meter.limits))
                .validate(value, against: plan, meter: &meter)
        }
        guard result.isValid else { throw JSONGenerationArgumentFailure.invalidArguments(result) }
    }

    static func export<Content>(_ value: JSON, plan: CompiledJSONSchema, limits: JSONLimits,
                                make: (String) throws -> Content, read: (Content) throws -> String
    ) throws -> JSONOperationReport<Content> {
        try JSON.withComposition(limits: limits) { scope in
            try requireValid(value, plan: plan, scope: scope)
            return try JF2ValueBoundary.export(value, scope: scope, make: make, read: read)
        }
    }

    static func importValue<Content>(_ content: Content, plan: CompiledJSONSchema, limits: JSONLimits,
                                     read: (Content) throws -> String) throws -> JSONOperationReport<JSON> {
        try JSON.withComposition(limits: limits) { scope in
            let value = try JF2ValueBoundary.importValue(scope: scope) { try read(content) }
            try requireValid(value, plan: plan, scope: scope)
            return value
        }
    }

    static func decodeJSON<Content, Value>(_ source: JSON, plan: CompiledJSONSchema, limits: JSONLimits,
        make: (String) throws -> Content, read: (Content) throws -> String,
        decode: (Content) throws -> Value, render: (Value) throws -> Content
    ) throws -> JSONOperationReport<Value> {
        try JSON.withComposition(limits: limits) { scope in
            try requireValid(source, plan: plan, scope: scope)
            let content = try JF2ValueBoundary.export(source, scope: scope, make: make, read: read)
            return try typed(source, content: content, scope: scope, read: read, decode: decode, render: render)
        }
    }

    static func decodeContent<Content, Value>(_ content: Content, plan: CompiledJSONSchema, limits: JSONLimits,
        read: (Content) throws -> String, decode: (Content) throws -> Value, render: (Value) throws -> Content
    ) throws -> JSONOperationReport<Value> {
        try JSON.withComposition(limits: limits) { scope in
            let source = try JF2ValueBoundary.importValue(scope: scope) { try read(content) }
            try requireValid(source, plan: plan, scope: scope)
            return try typed(source, content: content, scope: scope, read: read, decode: decode, render: render)
        }
    }

    private static func typed<Content, Value>(_ source: JSON, content: Content,
        scope: borrowing JSONCompositionScope, read: (Content) throws -> String,
        decode: (Content) throws -> Value, render: (Value) throws -> Content
    ) throws -> Value {
        try scope.checkpoint()
        let result: Value
        do { result = try decode(content) }
        catch { try scope.checkpoint(); throw error }
        try scope.checkpoint()
        let returned = try JF2ValueBoundary.importValue(scope: scope) {
            try read(render(result))
        }
        // Equality against an already validated original suffices for the same
        // immutable canonical schema. No normalization or repair is permitted.
        guard try scope.withMeter({ meter in
            try JSONComparison.equals(source, returned, meter: &meter)
        }) else { throw JSONGenerationArgumentFailure.typedValueChanged }
        return result
    }

    static func encode<Value, Content>(_ value: Value, plan: CompiledJSONSchema, limits: JSONLimits,
        render: (Value) throws -> Content, read: (Content) throws -> String
    ) throws -> JSONOperationReport<JSON> {
        try JSON.withComposition(limits: limits) { scope in
            let raw = try JF2ValueBoundary.importValue(scope: scope) { try read(render(value)) }
            try requireValid(raw, plan: plan, scope: scope)
            return raw
        }
    }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

/// Prepare once, then validate and convert many independent argument values.
/// The immutable canonical plan is always authoritative, not Apple's projected schema.
/// This candidate deliberately has no Sendable conformance for framework-held state.
@available(macOS 27.0, iOS 27.0, *)
public struct JSONPreparedGeneration {
    public let schema: GenerationSchema
    public let canonical: CompiledJSONSchema
    public let roundtripped: JSONSchemaDocument
    public let additions: [JSONGenerationSchemaAnnotationAddition]
    public let rewrites: [JSONGenerationSchemaStructuralRewrite]
    public let limits: JSONLimits

    fileprivate init(schema: GenerationSchema, canonical: CompiledJSONSchema, roundtripped: JSONSchemaDocument,
                     additions: [JSONGenerationSchemaAnnotationAddition], rewrites: [JSONGenerationSchemaStructuralRewrite],
                     limits: JSONLimits) {
        self.schema = schema; self.canonical = canonical; self.roundtripped = roundtripped
        self.additions = additions; self.rewrites = rewrites; self.limits = limits
    }

    /// Works directly with documents from JSONSchemaDSL without importing that DSL.
    public static func prepare(_ document: JSONSchemaDocument, metadata: JSONGenerationSchemaMetadataPolicy = .exact,
                               limits: JSONLimits = .balanced) throws -> Self {
        try prepareWithReport(document, metadata: metadata, limits: limits).result
    }

    public static func prepareWithReport(_ document: JSONSchemaDocument, metadata: JSONGenerationSchemaMetadataPolicy = .exact,
                                         limits: JSONLimits = .balanced) throws -> JSONOperationReport<Self> {
        let report = try JSONGenerationSchemaBridge(limits: limits).projectWithReport(document, metadata: metadata)
        let p = report.result
        return .init(result: .init(schema: p.schema, canonical: p.canonical, roundtripped: p.roundtripped,
                                   additions: p.additions, rewrites: p.rewrites, limits: limits),
                     statistics: report.statistics)
    }

    /// Ordinary invalidity returns a completed native verdict; operational errors throw.
    public func validate(_ value: JSON) throws -> JSONValidationResult {
        try validateWithReport(value).result
    }
    public func validateWithReport(_ value: JSON) throws -> JSONOperationReport<JSONValidationResult> {
        try JSONSchemaValidator(options: .init(limits: limits)).validateWithReport(value, against: canonical)
    }

    public func generatedContent(from value: JSON) throws -> GeneratedContent {
        try generatedContentWithReport(from: value).result
    }
    public func generatedContentWithReport(from value: JSON) throws -> JSONOperationReport<GeneratedContent> {
        try JF4ArgumentBoundary.export(value, plan: canonical, limits: limits,
                                       make: JSONGeneratedContentBridge.makeContent, read: JSONGeneratedContentBridge.completedJSON)
    }

    public func json(from content: GeneratedContent) throws -> JSON {
        try jsonWithReport(from: content).result
    }
    public func jsonWithReport(from content: GeneratedContent) throws -> JSONOperationReport<JSON> {
        try JF4ArgumentBoundary.importValue(content, plan: canonical, limits: limits,
                                            read: JSONGeneratedContentBridge.completedJSON)
    }
}

/// A prepared codec binds its schema to the actual Generable type. There is no
/// initializer that associates an arbitrary caller schema with a Swift type.
/// The default import profile is reference-free; nested local object definitions
/// require the explicit JF4.2 import policy.
@available(macOS 27.0, iOS 27.0, *)
public struct JSONGenerableCodec<Value: Generable> {
    public let prepared: JSONPreparedGeneration

    private init(prepared: JSONPreparedGeneration) { self.prepared = prepared }

    public static func prepare(limits: JSONLimits = .balanced) throws -> Self {
        try prepareWithReport(limits: limits).result
    }

    public static func prepareWithReport(limits: JSONLimits = .balanced) throws -> JSONOperationReport<Self> {
        try prepareWithReport(importPolicy: .referenceFree, limits: limits)
    }

    public static func prepare(importPolicy: JSONGenerationSchemaImportPolicy,
                               limits: JSONLimits = .balanced) throws -> Self {
        try prepareWithReport(importPolicy: importPolicy, limits: limits).result
    }

    public static func prepareWithReport(importPolicy: JSONGenerationSchemaImportPolicy,
                                         limits: JSONLimits = .balanced) throws -> JSONOperationReport<Self> {
        try Task.checkCancellation()
        let schema = Value.generationSchema
        try Task.checkCancellation()
        let report = try JSONGenerationSchemaBridge(limits: limits).importSchemaWithReport(schema, policy: importPolicy)
        let plan = report.result
        let prepared = JSONPreparedGeneration(schema: schema, canonical: plan, roundtripped: plan.document,
                                               additions: [], rewrites: [], limits: limits)
        return .init(result: .init(prepared: prepared), statistics: report.statistics)
    }

    public func decode(_ value: JSON) throws -> Value {
        try decodeWithReport(value).result
    }

    public func decodeWithReport(_ value: JSON) throws -> JSONOperationReport<Value> {
        try JF4ArgumentBoundary.decodeJSON(value, plan: prepared.canonical, limits: prepared.limits,
            make: JSONGeneratedContentBridge.makeContent, read: JSONGeneratedContentBridge.completedJSON,
            decode: { try Value($0) }, render: { $0.generatedContent })
    }

    public func decode(_ content: GeneratedContent) throws -> Value {
        try decodeWithReport(content).result
    }

    public func decodeWithReport(_ content: GeneratedContent) throws -> JSONOperationReport<Value> {
        try JF4ArgumentBoundary.decodeContent(content, plan: prepared.canonical, limits: prepared.limits,
            read: JSONGeneratedContentBridge.completedJSON, decode: { try Value($0) }, render: { $0.generatedContent })
    }

    /// Validate the exposed typed JSON representation; no hidden Swift state or
    /// original pre-framework value is claimed recoverable by this direction.
    public func encode(_ value: Value) throws -> JSON {
        try encodeWithReport(value).result
    }

    public func encodeWithReport(_ value: Value) throws -> JSONOperationReport<JSON> {
        try JF4ArgumentBoundary.encode(value, plan: prepared.canonical, limits: prepared.limits,
            render: { $0.generatedContent }, read: JSONGeneratedContentBridge.completedJSON)
    }
}
#endif
