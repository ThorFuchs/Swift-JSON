// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// An immutable, offline source snapshot with invocation-owned candidate search.
///
/// The current algorithm offers const, enum, default/examples, true/empty schemas and static reference
/// targets. Every candidate is validated against the original compiled root. Dynamic
/// construction and general numeric/string/object synthesis remain unsupported.
public struct JSONSchemaExampleGenerator: Sendable {
    /// The admitted source document, including any caller-supplied source map.
    public let document: JSONSchemaDocument
    /// The explicit immutable offline registry used during compilation and discovery.
    public let registry: JSONSchemaRegistry
    /// The frozen preparation, generation and evaluation policies.
    public let options: JSONSchemaExampleOptions
    /// The normalized source/registry snapshot digest; policies and corpus have separate identities.
    public let sourceSnapshotDigest: String
    /// The single preparation ledger, covering compilation, serialization and hashing.
    public let preparationStatistics: JSONOperationStatistics
    /// SHA-256 of the versioned, admitted ordered corpus transport.
    public let corpusDigest: String
    /// SHA-256 binding all generation, compilation and evaluation policies.
    public let policyDigest: String
    private let corpus: [JSON]
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
        guard !options.corpus.values.isEmpty else {
            throw JSONSchemaExampleFailure.invalidConfiguration(.emptyCorpus)
        }
        try options.limits.validate(); try options.validationOptions.limits.validate()
        var meter = try JSONWorkMeter(limits: options.compilationOptions.limits, domain: .schemaCompilation)
        let compiled = try JSONSchemaCompiler(options: options.compilationOptions)
            .compile(document, registry: registry, meter: &meter)
        let digest = try SchemaExampleDigests.snapshot(document: document, registry: registry, meter: &meter)
        let normalizedCorpus = try SchemaExampleExact.construct(.array(options.corpus.values), meter: &meter)
        guard let tokens = normalizedCorpus.arrayValue else { throw JSONFailure(.configuration, code: .invalidOperation) }
        corpus = tokens
        corpusDigest = try SchemaExampleDigests.corpus(tokens, meter: &meter)
        policyDigest = try SchemaExampleDigests.policy(options, meter: &meter)
        self.document = document; self.registry = registry; self.options = options
        self.compiled = compiled; sourceSnapshotDigest = digest
        preparationStatistics = meter.statistics()
    }

    /// Offers bounded exact candidates, returning only a completed native valid verdict.
    /// - Parameters:
    ///   - seed: SplitMix64 initial state for demonstration choices; always bound into the trace.
    ///   - profile: Stable minimal order or seeded demonstration candidate selection.
    /// - Returns: The exact certified value and cumulative successful-invocation statistics.
    /// - Throws: Explicit construction failure, native operational error or cancellation.
    public func generate(seed: UInt64 = 0, profile: JSONSchemaExampleProfile = .minimal) throws -> JSONSchemaExampleResult {
        let limits = try options.limits.intersection(options.validationOptions.limits)
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        var random = SchemaExampleRandom(seed: seed)
        var trace = try SchemaExampleTrace(snapshot: sourceSnapshotDigest, corpus: corpusDigest,
                                          policy: policyDigest, seed: seed, profile: profile, meter: &meter)
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
            try trace.event(1, 0, 0, meter: &meter)
            let view = try node.declaration(meter: &meter)
            for offset in 0..<node.referenceCount {
                if try node.reference(at: offset, meter: &meter).requiresDynamicScope {
                    throw JSONSchemaExampleFailure.unsupportedFeature(.dynamicReference)
                }
            }
            if let object = view.raw.objectValue {
                // Exact ASCII keyword order; array order remains semantic.
                for (role, item) in SchemaExampleVersion.keywords.enumerated() {
                    let (keyword, kind) = item
                    try meter.work()
                    guard view.vocabulary.applies(kind),
                          let declared = try object.lookup(keyword, meter: &meter) else { continue }
                    let values: [JSON]
                    if role < 2 { try meter.retain(JSONLogicalWeights.arraySlot); values = [declared] } else { values = declared.arrayValue ?? [] }
                    if let result = try scan(values, role: UInt64(role), seed: seed, profile: profile,
                                             attempts: &attempts, random: &random, trace: &trace, meter: &meter) { return result }
                    if role < 2 { try meter.release(JSONLogicalWeights.arraySlot) }
                }
            }
            if view.raw.booleanValue == true || view.raw.objectValue?.isEmpty == true {
                if profile == .minimal { try meter.retain(JSONLogicalWeights.arraySlot) }
                let values: [JSON] = profile == .minimal ? [.null] : corpus
                if let result = try scan(values, role: 4, seed: seed, profile: profile,
                                         attempts: &attempts, random: &random, trace: &trace, meter: &meter) { return result }
                if profile == .minimal { try meter.release(JSONLogicalWeights.arraySlot) }
            }
            // Reverse push gives exact ASCII order: $dynamicRef, then $ref.
            for kind in SchemaExampleVersion.referencePushOrder {
                for offset in 0..<node.referenceCount {
                    let edge = try node.reference(at: offset, meter: &meter)
                    guard edge.keyword == kind else { continue }
                    try meter.require(.evaluationFrames, UInt64(pending.count) + 1)
                    try meter.retain(JSONLogicalWeights.frame); pending.append(edge.target)
                }
            }
        }
        if sawCycle { throw JSONSchemaExampleFailure.unsupportedFeature(.cyclicReference) }
        if attempts == 0 { throw JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction) }
        throw JSONSchemaExampleFailure.searchExhausted(attempts: attempts)
    }

    private func scan(_ values: [JSON], role: UInt64, seed: UInt64, profile: JSONSchemaExampleProfile,
                      attempts: inout UInt64, random: inout SchemaExampleRandom,
                      trace: inout SchemaExampleTrace, meter: inout JSONWorkMeter) throws -> JSONSchemaExampleResult? {
        guard !values.isEmpty else { return nil }
        var index = profile == .minimal ? 0 : Int(try random.uniform(upperBound: UInt64(values.count), trace: &trace, meter: &meter))
        for _ in values.indices {
            try meter.work()
            try trace.event(2, role, UInt64(index), meter: &meter)
            if let result = try certify(values[index], seed: seed, profile: profile, attempts: &attempts,
                                         random: &random, trace: &trace, meter: &meter) { return result }
            // Avoid start + offset overflow on 32-bit WASI.
            index = index == values.count - 1 ? 0 : index + 1
        }
        return nil
    }

    private func certify(_ value: JSON, seed: UInt64, profile: JSONSchemaExampleProfile,
                         attempts: inout UInt64, random: inout SchemaExampleRandom,
                         trace: inout SchemaExampleTrace, meter: inout JSONWorkMeter) throws -> JSONSchemaExampleResult? {
        try meter.checkpoint()
        guard attempts < options.maximumAttempts else { throw JSONSchemaExampleFailure.searchExhausted(attempts: attempts) }
        // The configured ceiling is strictly below UInt64.max, so this cannot wrap.
        attempts += 1
        try meter.resetValueBounds()
        let retainedBefore = meter.used(.retainedBytes)
        let annotationBefore = meter.used(.annotationBytes)
        let value = try SchemaExampleExact.construct(value, meter: &meter)
        try meter.resetValueBounds()
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
            try trace.event(4, attempts, 0, meter: &meter)
            return nil
        }
        try trace.event(4, attempts, 1, meter: &meter)
        try trace.event(5, attempts, random.draws, meter: &meter)
        let events = trace.events
        let traceDigest = try trace.digest(meter: &meter)
        try meter.retain(512); try meter.checkpoint()
        return .init(value: value, validation: verdict, seed: seed, profile: profile,
                     generatorVersion: SchemaExampleVersion.generator, sourceSnapshotDigest: sourceSnapshotDigest,
                     schemaDigestAlgorithm: SchemaExampleVersion.snapshot,
                     corpusDigestAlgorithm: SchemaExampleVersion.corpus, corpusDigest: corpusDigest,
                     policyDigestAlgorithm: SchemaExampleVersion.policy, policyDigest: policyDigest,
                     rngAlgorithm: SchemaExampleVersion.rng, randomDraws: random.draws,
                     traceDigestAlgorithm: SchemaExampleVersion.trace, traceDigest: traceDigest, traceEventCount: events,
                     validationOptions: options.validationOptions, compilationOptions: options.compilationOptions,
                     attempts: attempts, statistics: meter.statistics())
    }
}
