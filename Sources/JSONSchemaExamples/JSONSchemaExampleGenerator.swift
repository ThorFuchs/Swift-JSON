// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// An immutable, offline source snapshot with invocation-owned candidate search.
///
/// G1 offers const, enum, default/examples, true/empty schemas and static reference
/// targets. Every candidate is validated against the original compiled root. Dynamic
/// construction and general numeric/string/object synthesis remain unsupported.
public struct JSONSchemaExampleGenerator: Sendable {
    /// The admitted source document, including any caller-supplied source map.
    public let document: JSONSchemaDocument
    /// The explicit immutable offline registry used during compilation and discovery.
    public let registry: JSONSchemaRegistry
    /// The frozen preparation, generation and evaluation policies.
    public let options: JSONSchemaExampleOptions
    /// The normalized source/registry snapshot digest; policies are retained separately.
    public let sourceSnapshotDigest: String
    /// The single preparation ledger, covering compilation, serialization and hashing.
    public let preparationStatistics: JSONOperationStatistics
    private let compiled: CompiledJSONSchema

    /// Compiles once and prepares a bounded source snapshot without online resolution.
    /// - Parameters:
    ///   - document: The already admitted root schema.
    ///   - registry: Explicit immutable resources, including any custom meta-schemas.
    ///   - options: Finite preparation/search/evaluation policies retained unchanged.
    /// - Throws: Generator configuration, native compilation/resource errors or cancellation.
    public init(document: JSONSchemaDocument, registry: JSONSchemaRegistry = .empty,
                options: JSONSchemaExampleOptions = .init()) throws {
        try Task.checkCancellation()
        guard options.maximumAttempts > 0, options.maximumAttempts < UInt64.max else {
            throw JSONSchemaExampleFailure.invalidConfiguration(.attemptLimit)
        }
        try options.limits.validate(); try options.validationOptions.limits.validate()
        var meter = try JSONWorkMeter(limits: options.compilationOptions.limits, domain: .schemaCompilation)
        let compiled = try JSONSchemaCompiler(options: options.compilationOptions)
            .compile(document, registry: registry, meter: &meter)
        let digest = try SchemaExampleSnapshot.digest(document: document, registry: registry, meter: &meter)
        self.document = document; self.registry = registry; self.options = options
        self.compiled = compiled; sourceSnapshotDigest = digest
        preparationStatistics = meter.statistics()
    }

    /// Offers bounded exact candidates, returning only a completed native valid verdict.
    /// - Parameters:
    ///   - seed: Recorded provenance; this G1 algorithm performs no random draws.
    ///   - profile: Candidate preference; currently only minimal is implemented.
    /// - Returns: The exact certified value and cumulative successful-invocation statistics.
    /// - Throws: Explicit construction failure, native operational error or cancellation.
    public func generate(seed: UInt64 = 0, profile: JSONSchemaExampleProfile = .minimal) throws -> JSONSchemaExampleResult {
        let limits = try options.limits.intersection(options.validationOptions.limits)
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        let root = compiled.exampleRoot
        let declaration = try root.declaration(meter: &meter)
        if declaration.raw.booleanValue == false {
            throw JSONSchemaExampleFailure.provenUnsatisfiable(.falseSchema)
        }
        if declaration.vocabulary.applies(.not),
           let negated = try declaration.raw.objectValue?.lookup("not", meter: &meter),
           negated.booleanValue == true || negated.objectValue?.isEmpty == true {
            throw JSONSchemaExampleFailure.provenUnsatisfiable(.notTrue)
        }
        try meter.retain(JSONLogicalWeights.frame)
        var pending = [root], visited: [Int] = []
        var attempts: UInt64 = 0, sawCycle = false
        while let node = pending.popLast() {
            try meter.checkpoint(); try meter.work(); try meter.release(JSONLogicalWeights.frame)
            var seen = false
            for identity in visited { try meter.work(); if identity == node.identity { seen = true; break } }
            if seen { sawCycle = true; continue }
            try meter.charge(.schemaNodes)
            try meter.retain(JSONLogicalWeights.indexSlot); visited.append(node.identity)
            let view = try node.declaration(meter: &meter)
            for offset in 0..<node.referenceCount {
                if try node.reference(at: offset, meter: &meter).requiresDynamicScope {
                    throw JSONSchemaExampleFailure.unsupportedFeature(.dynamicReference)
                }
            }
            if let object = view.raw.objectValue {
                if view.vocabulary.applies(.const), let value = try object.lookup("const", meter: &meter),
                   let result = try certify(value, seed: seed, profile: profile, attempts: &attempts, meter: &meter) { return result }
                if view.vocabulary.applies(.enum), let values = try object.lookup("enum", meter: &meter)?.arrayValue {
                    for value in values {
                        try meter.work()
                        if let result = try certify(value, seed: seed, profile: profile, attempts: &attempts, meter: &meter) { return result }
                    }
                }
                if view.vocabulary.applies(.default), let value = try object.lookup("default", meter: &meter),
                   let result = try certify(value, seed: seed, profile: profile, attempts: &attempts, meter: &meter) { return result }
                if view.vocabulary.applies(.examples), let values = try object.lookup("examples", meter: &meter)?.arrayValue {
                    for value in values {
                        try meter.work()
                        if let result = try certify(value, seed: seed, profile: profile, attempts: &attempts, meter: &meter) { return result }
                    }
                }
            }
            if view.raw.booleanValue == true || view.raw.objectValue?.isEmpty == true {
                if let result = try certify(.null, seed: seed, profile: profile, attempts: &attempts, meter: &meter) { return result }
            }
            for offset in (0..<node.referenceCount).reversed() {
                let edge = try node.reference(at: offset, meter: &meter)
                try meter.require(.evaluationFrames, UInt64(pending.count) + 1)
                try meter.retain(JSONLogicalWeights.frame); pending.append(edge.target)
            }
        }
        if sawCycle { throw JSONSchemaExampleFailure.unsupportedFeature(.cyclicReference) }
        if attempts == 0 { throw JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction) }
        throw JSONSchemaExampleFailure.searchExhausted(attempts: attempts)
    }

    private func certify(_ value: JSON, seed: UInt64, profile: JSONSchemaExampleProfile,
                         attempts: inout UInt64, meter: inout JSONWorkMeter) throws -> JSONSchemaExampleResult? {
        try meter.checkpoint()
        guard attempts < options.maximumAttempts else { throw JSONSchemaExampleFailure.searchExhausted(attempts: attempts) }
        // The configured ceiling is strictly below UInt64.max, so this cannot wrap.
        attempts += 1
        try meter.resetValueBounds()
        let retainedBefore = meter.used(.retainedBytes)
        let annotationBefore = meter.used(.annotationBytes)
        try meter.operationDomain(.schemaEvaluation)
        let verdict = try JSONSchemaValidator(options: options.validationOptions).validate(value, against: compiled, meter: &meter)
        try meter.operationDomain(.core)
        guard verdict.isValid else {
            // Nothing from this verdict escapes. Release only this attempt's live
            // ownership; work, diagnostics and lifetime admission counts stay charged.
            let (retained, badRetained) = meter.used(.retainedBytes).subtractingReportingOverflow(retainedBefore)
            let (annotations, badAnnotations) = meter.used(.annotationBytes).subtractingReportingOverflow(annotationBefore)
            guard !badRetained, !badAnnotations else { throw JSONFailure(.configuration, code: .invalidOperation) }
            try meter.releaseAnnotationState(annotations)
            try meter.release(retained)
            return nil
        }
        try meter.retain(128); try meter.checkpoint()
        return .init(value: value, validation: verdict, seed: seed, profile: profile,
                     generatorVersion: "s3-g1-candidates-v1", sourceSnapshotDigest: sourceSnapshotDigest,
                     schemaDigestAlgorithm: "swift-json-schema-snapshot-g1-v1",
                     validationOptions: options.validationOptions, compilationOptions: options.compilationOptions,
                     attempts: attempts, statistics: meter.statistics())
    }
}

private enum SchemaExampleSnapshot {
    static func appendByte(_ byte: UInt8, to bytes: inout [UInt8], meter: inout JSONWorkMeter) throws {
        try meter.work(); try meter.require(.inputBytes, UInt64(bytes.count) + 1)
        try meter.retain(1); bytes.append(byte)
    }
    static func append<C: Collection>(_ field: C, to bytes: inout [UInt8], meter: inout JSONWorkMeter) throws where C.Element == UInt8 {
        var length: UInt64 = 0
        for _ in field { try meter.work(); length = try meter.adding(.inputBytes, length, 1) }
        for shift in stride(from: 56, through: 0, by: -8) {
            try appendByte(UInt8(truncatingIfNeeded: length >> shift), to: &bytes, meter: &meter)
        }
        for byte in field {
            try appendByte(byte, to: &bytes, meter: &meter)
        }
    }
    static func digest(document: JSONSchemaDocument, registry: JSONSchemaRegistry, meter: inout JSONWorkMeter) throws -> String {
        var bytes: [UInt8] = []
        for byte in "SwiftJSON-schema-snapshot-g1-v1\n".utf8 { try appendByte(byte, to: &bytes, meter: &meter) }
        let count = try meter.adding(.schemaDocuments, UInt64(registry.documents.count), 1)
        for shift in stride(from: 56, through: 0, by: -8) { try appendByte(UInt8(truncatingIfNeeded: count >> shift), to: &bytes, meter: &meter) }
        for index in 0..<Int(count) {
            try meter.work()
            let entry = index == 0 ? document : registry.documents[index - 1]
            try appendByte(entry.retrievalURI == nil ? 0 : 1, to: &bytes, meter: &meter)
            try append((entry.retrievalURI?.string ?? "").utf8, to: &bytes, meter: &meter)
            try meter.resetValueBounds()
            let encoded = try JSONWriter(options: .init(keyOrder: .scalar, numberStyle: .normalized)).write(entry.raw, meter: &meter)
            try append(encoded, to: &bytes, meter: &meter)
            try meter.release(UInt64(encoded.count))
        }
        let result = try JSONSHA256Core.hexadecimal(bytes, accounting: &meter)
        try meter.release(UInt64(bytes.count))
        return result
    }
}
