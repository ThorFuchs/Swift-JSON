// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONSchemaExamples
import Testing

private func document(_ text: String, uri: String? = nil) throws -> JSONSchemaDocument {
    try JSONSchemaDocument(JSONParser().parse(text), retrievalURI: uri.map { try JSONSchemaURI($0) })
}
private func generator(_ text: String, options: JSONSchemaExampleOptions = .init()) throws -> JSONSchemaExampleGenerator {
    try JSONSchemaExampleGenerator(document: document(text), options: options)
}

@Test func g1TrueAndEmptySchemasReturnNativeCertifiedNull() throws {
    for text in ["true", "{}"] {
        let prepared = try generator(text)
        let result = try prepared.generate(seed: 42)
        #expect(result.value.isNull)
        #expect(result.validation.isValid && result.validation.diagnosticsComplete)
        #expect(result.attempts == 1 && result.seed == 42)
        #expect(result.statistics[.evaluationWorkUnits] > 0)
        #expect(result.generatorVersion == "s3-candidates-v3")
        let native = try JSONSchemaCompiler().compile(prepared.document).validate(result.value)
        #expect(native.isValid == result.validation.isValid)
    }
}

@Test func g1ExactConstPreservesLargeDecimalAndScalarKeys() throws {
    let prepared = try generator(#"{"const":{"é":9007199254740994.5,"e\u0301":9007199254740993}}"#)
    let result = try prepared.generate()
    let expected = try JSONParser().parse(#"{"é":9007199254740994.5,"e\u0301":9007199254740993}"#)
    #expect(result.value == expected)
    #expect(result.value.objectValue?.count == 2)
    #expect(result.validation.isValid)
}

@Test func g1NullConstIsPresentAndG3TypedStringConstructionIsNativeCertified() throws {
    #expect(try generator(#"{"const":null}"#).generate().value.isNull)
    let typed = try generator(#"{"type":"string"}"#).generate()
    #expect(typed.value == .string("") && typed.validation.isValid)
}

@Test func g1InvalidConstNeverEscapesRootValidation() throws {
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 1)) {
        try generator(#"{"const":1,"type":"string"}"#).generate()
    }
}

@Test func g1InvalidEnumAttemptRemainsInCumulativeLedger() throws {
    let prepared = try generator(#"{"enum":[1,"ok"],"type":"string"}"#)
    let result = try prepared.generate()
    #expect(result.value == .string("ok") && result.attempts == 2)
    let compiled = try JSONSchemaCompiler().compile(prepared.document)
    let finalOnly = try JSONSchemaValidator().validateWithReport(.string("ok"), against: compiled)
    #expect(result.statistics[.evaluationWorkUnits] > finalOnly.statistics[.evaluationWorkUnits])
    let again = try prepared.generate()
    #expect(again.statistics == result.statistics && again.value == result.value)
}

@Test func g1AnnotationsAreCandidatesAndNotRepairs() throws {
    let result = try generator(#"{"type":"string","default":1,"examples":["ok"]}"#).generate()
    #expect(result.value == .string("ok") && result.attempts == 2)
    let authored = try generator(#"{"type":"object","required":["id"],"default":{}}"#)
    let built = try authored.generate()
    #expect(built.value.objectValue?["id"]?.isNull == true && built.attempts == 2)
    #expect(authored.document.raw.objectValue?["default"]?.objectValue?.isEmpty == true)
}

@Test func g1StaticAnchorAndEmbeddedResourceUseCompilerTargets() throws {
    let prepared = try generator(##"{"$id":"https://e.test/root","$defs":{"x":{"$id":"nested","$defs":{"v":{"$anchor":"pick","const":9007199254740993}}}},"$ref":"nested#pick"}"##)
    let result = try prepared.generate()
    #expect(try result.value == JSONParser().parse("9007199254740993"))
    #expect(result.validation.isValid)
}

@Test func g1OfflineRegistryDoesNotGuessFromLastPathComponent() throws {
    let a = try document(#"{"const":"first"}"#, uri: "https://a.test/schema")
    let b = try document(#"{"const":"second"}"#, uri: "https://b.test/schema")
    let registry = try JSONSchemaRegistry(documents: [a,b])
    let prepared = try JSONSchemaExampleGenerator(document: document(#"{"$ref":"https://b.test/schema"}"#), registry: registry)
    #expect(try prepared.generate().value == .string("second"))
    #expect(prepared.registry.documents.count == 2)
}

@Test func g1ReferenceSiblingConstraintsRemainAuthoritative() throws {
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 1)) {
        try generator(##"{"$defs":{"x":{"const":1}},"$ref":"#/$defs/x","type":"string"}"##).generate()
    }
}

@Test func g1MissingResourceRemainsNativeCompilationFailure() throws {
    do {
        _ = try generator(#"{"$ref":"https://missing.test/schema"}"#)
        Issue.record("Unresolved reference was accepted")
    } catch let error as JSONSchemaCompilationFailure {
        #expect(error.category == .missingResource)
    }
}

@Test func g1DynamicNavigationAndCyclesFailExplicitly() throws {
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.dynamicReference)) {
        try generator(##"{"$dynamicAnchor":"node","$dynamicRef":"#node"}"##).generate()
    }
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.cyclicReference)) {
        try generator(##"{"$ref":"#"}"##).generate()
    }
}

@Test func g1UnsatisfiableProofsAreRestrictedToSoundRootForms() throws {
    #expect(throws: JSONSchemaExampleFailure.provenUnsatisfiable(.falseSchema)) { try generator("false").generate() }
    for text in [#"{"not":true}"#, #"{"not":{}}"#] {
        #expect(throws: JSONSchemaExampleFailure.provenUnsatisfiable(.notTrue)) { try generator(text).generate() }
    }
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) {
        try generator(#"{"not":{"type":"string"}}"#).generate()
    }
}

@Test func g1InactiveApplicatorCannotProduceNotTrueProof() throws {
    let meta = try document(#"{"$id":"https://e.test/core-only","$vocabulary":{"https://json-schema.org/draft/2020-12/vocab/core":true}}"#, uri: "https://e.test/core-only")
    let prepared = try JSONSchemaExampleGenerator(document: document(#"{"$schema":"https://e.test/core-only","not":{}}"#), registry: .init(documents: [meta]))
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) { try prepared.generate() }
    let plan = try JSONSchemaCompiler().compile(prepared.document, registry: prepared.registry)
    #expect(try plan.validate(.null).isValid)
}

@Test func g1AttemptLimitAndGeneratorConfigurationAreExact() throws {
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 1)) {
        try generator(#"{"enum":[1,"ok"],"type":"string"}"#, options: .init(maximumAttempts: 1)).generate()
    }
    for limit in [UInt64(0), UInt64.max] {
        #expect(throws: JSONSchemaExampleFailure.invalidConfiguration(.attemptLimit)) {
            try generator("true", options: .init(maximumAttempts: limit))
        }
    }
}

@Test func g1PoliciesRemainSeparateAndRequiredFormatAssertionWins() throws {
    let options = JSONSchemaExampleOptions(compilationOptions: .init(formatAssertion: true), validationOptions: .init(output: .flag))
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 1)) {
        try generator(#"{"format":"date","const":"not-a-date"}"#, options: options).generate()
    }
    let meta = try document(#"{"$id":"https://e.test/assertion","$schema":"https://json-schema.org/draft/2020-12/schema","$vocabulary":{"https://json-schema.org/draft/2020-12/vocab/core":true,"https://json-schema.org/draft/2020-12/vocab/meta-data":true,"https://json-schema.org/draft/2020-12/vocab/format-assertion":true}}"#, uri: "https://e.test/assertion")
    let required = try JSONSchemaExampleGenerator(document: document(#"{"$schema":"https://e.test/assertion","format":"date","default":"not-a-date"}"#), registry: .init(documents: [meta]), options: .init(maximumAttempts: 1))
    let requiredPlan = try JSONSchemaCompiler().compile(required.document, registry: required.registry)
    #expect(try !requiredPlan.validate(.string("not-a-date")).isValid)
    #expect(!required.options.validationOptions.formatAssertion)
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 1)) { try required.generate() }
    let result = try generator(#"{"const":"ok","title":"label"}"#, options: .init(validationOptions: .init(output: .flag, collectAnnotations: true))).generate()
    #expect(result.validation.outputStyle == .flag && result.validationOptions.collectAnnotations)
    #expect(result.validation.annotations.contains { $0.keyword.string == "title" && $0.value == .string("label") })
}

@Test func g1OperationalFailureIsNotAnInvalidCandidateRetry() throws {
    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 0
    do {
        _ = try generator(#"{"enum":[1,2]}"#, options: .init(validationOptions: .init(limits: limits))).generate()
        Issue.record("Evaluation quota was ignored")
    } catch let error as JSONFailure {
        #expect(error.category == .resource)
        #expect(error.resource?.metric == .evaluationWorkUnits)
    }
    var discovery = JSONLimits.balanced; discovery[.schemaNodes] = 0
    do {
        _ = try generator(#"{"const":1}"#, options: .init(limits: discovery)).generate()
        Issue.record("Declaration discovery quota was ignored")
    } catch let error as JSONFailure {
        #expect(error.category == .resource && error.resource?.metric == .schemaNodes)
    }
}

@Test func g1SharedWorkBoundaryIncludesEarlierInvalidVerdict() throws {
    let source = #"{"enum":[1,"ok"],"type":"string"}"#
    let measured = try generator(source).generate()
    var limits = JSONLimits.balanced; limits[.workUnits] = measured.statistics[.workUnits]
    let exact = try generator(source, options: .init(limits: limits)).generate()
    #expect(exact.statistics[.workUnits] == limits[.workUnits])
    limits[.workUnits] -= 1
    do {
        _ = try generator(source, options: .init(limits: limits)).generate()
        Issue.record("One-unit-short ledger returned a result")
    } catch let error as JSONFailure { #expect(error.category == .resource && error.resource?.metric == .workUnits) }
}

@Test func g1SourceDigestNormalizesKeysAndNumbersButRetainsRegistryOrder() throws {
    let a = try generator(#"{"const":{"b":1.0,"a":2}}"#)
    let b = try generator(#"{"const":{"a":2,"b":1}}"#)
    #expect(a.sourceSnapshotDigest == b.sourceSnapshotDigest && a.sourceSnapshotDigest.count == 64)
    #expect(a.preparationStatistics[.compileWorkUnits] > 0)
    let x = try document("true", uri: "https://a.test/x"), y = try document("true", uri: "https://b.test/x")
    let left = try JSONSchemaExampleGenerator(document: a.document, registry: .init(documents: [x,y]))
    let right = try JSONSchemaExampleGenerator(document: a.document, registry: .init(documents: [y,x]))
    #expect(left.sourceSnapshotDigest != right.sourceSnapshotDigest)
    let distinct = try generator(#"{"const":{"e\u0301":2,"b":1}}"#)
    #expect(a.sourceSnapshotDigest != distinct.sourceSnapshotDigest)
}

@Test func g1QualifiedBridgeHasExactLocationsPoliciesAndCheckedEdges() throws {
    let plan = try JSONSchemaCompiler(options: .init(formatAssertion: true)).compile(document(##"{"$id":"https://e.test/root","$defs":{"child":{"$id":"https://e.test/child","const":7}},"$ref":"https://e.test/child"}"##))
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    let root = plan.exampleRoot
    let ref = try root.reference(at: 0, meter: &meter)
    let target = try ref.target.declaration(meter: &meter)
    #expect(target.resourceURI.string == "https://e.test/child")
    #expect(target.documentPointer.tokens.map(\.string) == ["$defs","child"])
    #expect(target.vocabulary.applies(.const) && target.formatAssertion)
    #expect(!ref.requiresDynamicScope && ref.keyword == .ref)
    var found = false
    for index in 0..<root.childCount {
        let child = try root.child(at: index, meter: &meter)
        if child.keyword == .defs { #expect(child.target.identity == ref.target.identity); found = true }
    }
    #expect(found && meter.statistics()[.workUnits] > 0)
    #expect(throws: JSONFailure(.configuration, code: .invalidOperation)) { try root.reference(at: -1, meter: &meter) }
}

@Test func g1CancellationTerminatesAnInvocationWithoutPoisoningPreparation() async throws {
    let prepared = try generator(#"{"const":42}"#)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try prepared.generate()
    }
    do { _ = try await task.value; Issue.record("Cancelled invocation returned a certificate") }
    catch is CancellationError { }
    #expect(try prepared.generate().validation.isValid)
}

@Test func g1SharedPreparedGeneratorHasIndependentConcurrentInvocations() async throws {
    let prepared = try generator(#"{"enum":[1,"ok"],"type":"string"}"#)
    let expected = try prepared.generate()
    try await withThrowingTaskGroup(of: JSONSchemaExampleResult.self) { group in
        for seed in 0..<16 { group.addTask { try prepared.generate(seed: UInt64(seed)) } }
        var count = 0
        for try await result in group {
            #expect(result.value == expected.value && result.validation.isValid)
            #expect(result.statistics == expected.statistics && result.attempts == 2)
            count += 1
        }
        #expect(count == 16)
    }
    let demos = try (0..<16).map { try prepared.generate(seed: UInt64($0), profile: .demonstration) }
    try await withThrowingTaskGroup(of: JSONSchemaExampleResult.self) { group in
        for seed in 0..<16 { group.addTask { try prepared.generate(seed: UInt64(seed), profile: .demonstration) } }
        var count = 0
        for try await result in group {
            let expected = demos[Int(result.seed)]
            #expect(result.value == expected.value && result.traceDigest == expected.traceDigest)
            #expect(result.randomDraws == expected.randomDraws && result.statistics == expected.statistics)
            count += 1
        }
        #expect(count == 16)
    }
}
