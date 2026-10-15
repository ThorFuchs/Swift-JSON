// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
@testable import JSONSchemaExamples
import Testing

private func prepared(_ source: String, options: JSONSchemaExampleOptions = .init()) throws -> JSONSchemaExampleGenerator {
    try .init(document: .init(JSONParser().parse(source)), options: options)
}
private func cases() throws -> [JSON] {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/SchemaExamples/S3-integral-correction-v1.json")
    return try #require(JSONParser().parse(Data(contentsOf: url)).objectValue?["cases"]?.arrayValue)
}
private func registry(_ c: JSONObject) throws -> JSONSchemaRegistry {
    var documents: [JSONSchemaDocument] = []
    if let resources = c["resources"]?.objectValue {
        for member in resources { documents.append(try .init(member.value, retrievalURI: JSONSchemaURI(member.key.string))) }
    }
    return try .init(documents: documents)
}
private func resource(_ error: any Error, _ metric: JSONResourceMetric) -> Bool {
    guard let error = error as? JSONFailure else { return false }
    return error.category == .resource && error.resource?.metric == metric
}

@Test func g4AllTenRequiredAndEightIncompleteFixturesHaveHonestNativeOutcomes() throws {
    var required: [String] = [], incomplete: [String] = [], successes = 0, failures = 0, witnesses = 0, mustSuccesses = 0
    for value in try cases() {
        let c = try #require(value.objectValue)
        guard c["acceptanceGate"] == .string("G4") else { continue }
        let id = try #require(c["id"]?.stringValue)
        let must = c["generatorExpectation"] == .string("must-generate")
        let options = JSONSchemaExampleOptions(validationOptions: .init(formatAssertion: c["validation"]?.objectValue?["formatAssertion"]?.booleanValue == true))
        let generator = try JSONSchemaExampleGenerator(document: .init(try #require(c["schema"])), registry: registry(c), options: options)
        let plan = try JSONSchemaCompiler(options: options.compilationOptions).compile(generator.document, registry: generator.registry)
        let validator = JSONSchemaValidator(options: options.validationOptions)
        for witness in try #require(c["witnesses"]?.arrayValue) {
            #expect(try validator.validate(#require(witness.objectValue?["instance"]), against: plan).isValid == #require(witness.objectValue?["valid"]?.booleanValue as Bool?))
            witnesses += 1
        }
        var valid = 0, unsupported = 0, exhausted = 0
        for profile in [JSONSchemaExampleProfile.minimal, .demonstration] {
            for seed in [UInt64(0),1,42,UInt64.max] {
                do {
                    let result = try generator.generate(seed: seed, profile: profile)
                    #expect(result.validation.isValid && result.validation.diagnosticsComplete)
                    #expect(try validator.validate(result.value, against: plan).isValid)
                    #expect(try JSONParser().parse(JSONWriter().write(result.value)) == result.value)
                    #expect(result.statistics[.workUnits] <= options.limits[.workUnits])
                    successes += 1; valid += 1; if must { mustSuccesses += 1 }
                } catch let failure as JSONSchemaExampleFailure {
                    #expect(!must, "Required G4 fixture failed: \(id)")
                    switch failure {
                    case .unsupportedFeature: unsupported += 1
                    case .searchExhausted(let attempts): #expect(attempts > 0 && attempts <= options.maximumAttempts); exhausted += 1
                    default: Issue.record("Incomplete search became a proof/configuration error: \(id)")
                    }
                    failures += 1
                }
                // Native operational errors/cancellation escape and fail the test.
            }
        }
        if must { required.append(id) } else { incomplete.append(id) }
        print("G4_FIXTURE id=\(id) must=\(must) valid=\(valid) unsupported=\(unsupported) exhausted=\(exhausted)")
    }
    #expect(required == ["array-contains","condition-then-else","dependent-required","dependent-schema","pattern-properties","property-names","unevaluated-properties-composition","simple-regex","mincontains-with-prefixitems","array-mixed-evaluation"])
    #expect(incomplete == ["oneof-overlap","recursive-tree","dynamic-ref","conflicting-allof","unfulfillable-unique-enum","external-offline-ref","not-string","oneof-overlap-limited"])
    #expect(mustSuccesses == 80 && successes + failures == 144 && witnesses == 59)
    print("G4_ACCEPTANCE passed required=10 incomplete=8 must_valid=80 valid=\(successes) explicit=\(failures) witnesses=59")
}

@Test func g4AnchoredLiteralRangeAndExactRepeatProposalsAreNativeCertified() throws {
    for (pattern, expected) in [("^SKU-[0-9]{4}$","SKU-0000"), ("^[A-C]{2}X$","AAX"), (#"^a\+b\?$"#,"a+b?"), ("^$","")] {
        let raw = try JSONObject(members: [.init("type",value: .string("string")),.init("pattern",value: .string(pattern))])
        let result = try JSONSchemaExampleGenerator(document: .init(.object(raw))).generate()
        #expect(result.value == .string(expected) && result.validation.isValid)
    }
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    #expect(try SchemaExamplePattern.propose("^[A-C]{2}X$", variation: 2, minimum: 0, maximum: 4, meter: &meter) == "CCX")
}

@Test func g4UnsupportedRegexSyntaxNeverPretendsToBeAnInverter() throws {
    var count = 0
    for pattern in ["SKU-[0-9]{4}","^(a|b)$","^(a+)+$",#"^(a)\1$"#,"^(?=a)a$","^[^a]$","^[ab]$","^a{1,3}$","^a?$","^é$"] {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        #expect(try SchemaExamplePattern.propose(pattern, variation: 0, minimum: 0, maximum: 1024, meter: &meter) == nil)
        #expect(meter.used(.workUnits) > 0); count += 1
    }
    #expect(count == 10)
}

@Test func g4UnsupportedPatternsCanStillUseAdmittedCorpusWithoutFallbackEngine() throws {
    let source = #"{"type":"string","pattern":"^(ab)+$"}"#
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 3)) { try prepared(source, options: .init(maximumAttempts: 3)).generate() }
    let generated = try prepared(source, options: .init(corpus: .init(values: [.string("ab")]))).generate(profile: .demonstration)
    #expect(generated.value == .string("ab") && generated.validation.isValid)
    let unicode = try prepared(#"{"type":"string","pattern":"^é$"}"#, options: .init(corpus: .init(values: [.string("é")]))).generate(profile: .demonstration)
    #expect(unicode.value == .string("é") && unicode.validation.isValid)
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"pattern":"^é$"}"#)))
    #expect(try !JSONSchemaValidator().validate(.string("e\u{301}"), against: plan).isValid)
}

@Test func g4ConjunctivePatternsAreNeverOverwrittenOrLocallyCertified() throws {
    let conflict = #"{"type":"string","allOf":[{"pattern":"^A[0-9]$"},{"pattern":"^B[0-9]$"}]}"#
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 3)) { try prepared(conflict, options: .init(maximumAttempts: 3)).generate() }
    let compatible = #"{"type":"string","allOf":[{"pattern":"^A[0-9]$"},{"pattern":"^A0$"}]}"#
    #expect(try prepared(compatible).generate().value == .string("A0"))
}

@Test func g4ContainsDefaultZeroAndInactiveSiblingLimitsRemainDistinct() throws {
    #expect(try prepared(#"{"type":"array","items":{"type":"integer"},"contains":{"multipleOf":2}}"#).generate().value == .array([0]))
    #expect(try prepared(#"{"type":"array","contains":false,"minContains":0,"maxContains":0}"#).generate().value == .array([]))
    #expect(try prepared(#"{"type":"array","minContains":1000,"maxContains":0}"#).generate().value == .array([]))
}

@Test func g4ContainsPrefixAndUniqueConstraintsShareTheRootCertificate() throws {
    let source = #"{"type":"array","prefixItems":[{"const":2}],"items":{"type":"integer"},"minItems":2,"uniqueItems":true,"contains":{"multipleOf":2},"minContains":2,"maxContains":2}"#
    let result = try prepared(source).generate()
    #expect(result.value == .array([2,4]) && result.attempts == 2 && result.validation.isValid)
    let conjuncts = #"{"type":"array","items":{"type":"integer"},"allOf":[{"contains":{"minimum":2},"minContains":2},{"contains":{"multipleOf":2},"minContains":2}]}"#
    #expect(try prepared(conjuncts).generate().value == .array([2,2]))
    let evaluated = #"{"type":"array","contains":{"const":1},"minContains":2,"unevaluatedItems":false}"#
    #expect(try prepared(evaluated).generate().value == .array([1,1]))
}

@Test func g4ExtraContainsMatchesRemainHonestSearchExhaustion() throws {
    let source = #"{"type":"array","minItems":3,"items":{"const":2},"contains":{"type":"integer"},"minContains":1,"maxContains":1}"#
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 3)) { try prepared(source, options: .init(maximumAttempts: 3)).generate() }
    let falseContains = #"{"type":"array","contains":false}"#
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) { try prepared(falseContains).generate() }
    let unevaluated = #"{"type":"array","prefixItems":[{"const":2}],"minItems":2,"unevaluatedItems":false}"#
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 3)) { try prepared(unevaluated, options: .init(maximumAttempts: 3)).generate() }
}

@Test func g4ContainsCardinalityIsCheckedBeforeItemStaging() throws {
    var limits = JSONLimits.balanced; limits[.arrayItems] = 1
    do { _ = try prepared(#"{"type":"array","contains":true,"minContains":2}"#, options: .init(limits: limits)).generate(); Issue.record("Contains count bypassed array cap") }
    catch { #expect(resource(error,.arrayItems)) }
}

@Test func g4RegexOperationalFailureIsTerminalRatherThanAnInvalidCandidate() throws {
    do { _ = try prepared(#"{"pattern":"["}"#); Issue.record("Malformed regex reached proposal construction") }
    catch let failure as JSONSchemaCompilationFailure { #expect(failure.category == .schemaSyntax) }
    var limits = JSONLimits.balanced; limits[.regexSearchWorkUnits] = 0
    do { _ = try prepared(#"{"type":"string","pattern":"^SKU-[0-9]{4}$"}"#, options: .init(validationOptions: .init(limits: limits))).generate(); Issue.record("Regex operation retried or certified") }
    catch { #expect(resource(error,.regexSearchWorkUnits)) }
    limits = .balanced; limits[.regexCompileWorkUnits] = 0
    do { _ = try prepared(#"{"pattern":"a"}"#, options: .init(compilationOptions: .init(limits: limits))); Issue.record("Regex compile error became search failure") }
    catch { #expect(resource(error,.regexCompileWorkUnits)) }
}

@Test func g4PatternScannerHasExactWorkAndPreallocationBoundaries() throws {
    var measure = try JSONWorkMeter(limits: .balanced, domain: .core)
    #expect(try SchemaExamplePattern.propose("^SKU-[0-9]{4}$", variation: 0, minimum: 0, maximum: 100, meter: &measure) == "SKU-0000")
    var limits = JSONLimits.balanced; limits[.workUnits] = measure.used(.workUnits)
    var exact = try JSONWorkMeter(limits: limits, domain: .core)
    #expect(try SchemaExamplePattern.propose("^SKU-[0-9]{4}$", variation: 0, minimum: 0, maximum: 100, meter: &exact) == "SKU-0000")
    limits[.workUnits] -= 1
    var short = try JSONWorkMeter(limits: limits, domain: .core)
    do { _ = try SchemaExamplePattern.propose("^SKU-[0-9]{4}$", variation: 0, minimum: 0, maximum: 100, meter: &short); Issue.record("Scanner work reset") }
    catch { #expect(resource(error,.workUnits)) }
    for metric in [JSONResourceMetric.stringBytes,.regexPatternBytes] {
        limits = .balanced; limits[metric] = 3
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        do { _ = try SchemaExamplePattern.propose("^A{4}$", variation: 0, minimum: 0, maximum: 100, meter: &meter); Issue.record("Scanner growth cap ignored") }
        catch { #expect(resource(error,metric)) }
    }
}

@Test func g4CancellationDuringPatternScanningLatchesTheInvocation() async throws {
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        meter.checkpointObserver = { work in if work >= 10 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { try SchemaExamplePattern.propose("^" + String(repeating: "a",count: 256) + "$", variation: 0, minimum: 0, maximum: 1024, meter: &meter) }
        #expect(throws: CancellationError.self) { try meter.work() }
    }
    try await task.value
}

@Test func g4ConditionalFalseVerdictConsumesTheCumulativeEvaluationBudget() throws {
    let c = try #require(cases().first { $0.objectValue?["id"] == .string("condition-then-else") }?.objectValue)
    let document = try JSONSchemaDocument(#require(c["schema"])), generator = try JSONSchemaExampleGenerator(document: document)
    let result = try generator.generate(), plan = try JSONSchemaCompiler().compile(document)
    let rejected = try JSONSchemaValidator().validateWithReport(JSONParser().parse(#"{"age":0,"kind":"adult"}"#), against: plan)
    let accepted = try JSONSchemaValidator().validateWithReport(result.value, against: plan)
    #expect(!rejected.result.isValid && accepted.result.isValid && result.attempts == 2)
    #expect(result.value.objectValue?["kind"] == .string("child"))
    #expect(result.statistics[.evaluationWorkUnits] == rejected.statistics[.workUnits] + accepted.statistics[.workUnits])
    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = result.statistics[.evaluationWorkUnits]
    #expect(try JSONSchemaExampleGenerator(document: document, options: .init(validationOptions: .init(limits: limits))).generate().validation.isValid)
    limits[.evaluationWorkUnits] -= 1
    do { _ = try JSONSchemaExampleGenerator(document: document, options: .init(validationOptions: .init(limits: limits))).generate(); Issue.record("False conditional verdict work refunded") }
    catch { #expect(resource(error,.evaluationWorkUnits)) }
}

@Test func g4ExternalReferencesKeepResourceBasesAndAnchorsQualified() throws {
    let a = try JSONSchemaDocument(JSONParser().parse(##"{"$id":"urn:catalog:a","$defs":{"item":{"$anchor":"entry","const":"A"}}}"##), retrievalURI: JSONSchemaURI("urn:catalog:a"))
    let b = try JSONSchemaDocument(JSONParser().parse(##"{"$id":"urn:catalog:b","$defs":{"item":{"$id":"urn:catalog:nested","$anchor":"entry","const":"B"}}}"##), retrievalURI: JSONSchemaURI("urn:catalog:b"))
    let root = try JSONSchemaDocument(JSONParser().parse(##"{"type":"object","required":["a","b"],"properties":{"a":{"$ref":"urn:catalog:a#entry"},"b":{"$ref":"urn:catalog:nested#entry"}}}"##))
    let generator = try JSONSchemaExampleGenerator(document: root, registry: .init(documents: [a,b]))
    let result = try generator.generate()
    #expect(result.value.objectValue?["a"] == .string("A") && result.value.objectValue?["b"] == .string("B"))
    #expect(result.validation.isValid)
}

@Test func g4MissingOfflineResourceRemainsACompilationError() throws {
    do { _ = try prepared(#"{"$ref":"urn:not-supplied"}"#); Issue.record("Missing resource became candidate search") }
    catch let failure as JSONSchemaCompilationFailure { #expect(failure.category == .missingResource) }
}

@Test func g4ReachedDynamicScopeIsUnsupportedAndRecursiveGrowthIsBounded() throws {
    let dynamic = ##"{"$dynamicAnchor":"node","type":"array","minItems":1,"items":{"$dynamicRef":"#node"}}"##
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.dynamicReference)) { try prepared(dynamic).generate() }
    var limits = JSONLimits.balanced; limits[.maxDepth] = 8
    let recursive = ##"{"type":"array","minItems":1,"items":{"$ref":"#"}}"##
    do { _ = try prepared(recursive, options: .init(limits: limits)).generate(); Issue.record("Recursive instance growth escaped depth cap") }
    catch { #expect(resource(error,.maxDepth)) }
}

@Test func g4IncompletenessNeverBecomesAnUnsatisfiabilityProof() throws {
    let overlap = try prepared(#"{"oneOf":[{"type":"number"},{"type":"integer"}]}"#).generate()
    #expect(overlap.value == .number(try JSONNumber(parsing: "0.1")) && overlap.attempts == 3)
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) { try prepared(#"{"not":{"type":"string"}}"#).generate() }
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) { try prepared(#"{"allOf":[{"type":"string"},{"type":"integer"}]}"#).generate() }
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 3)) { try prepared(#"{"type":"array","minItems":3,"maxItems":3,"uniqueItems":true,"items":{"enum":["a","b"]}}"#, options: .init(maximumAttempts: 3)).generate() }
    let triggered = #"{"type":"object","required":["a"],"dependentRequired":{"a":["b"]}}"#
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 3)) { try prepared(triggered, options: .init(maximumAttempts: 3)).generate() }
}

@Test func g4SharedAdvancedGeneratorHasIndependentConcurrentInvocations() async throws {
    let generator = try prepared(#"{"type":"array","minItems":2,"uniqueItems":true,"items":{"type":"string"},"contains":{"pattern":"^SKU-[0-9]{4}$"},"minContains":2,"maxContains":2}"#)
    let expected = try generator.generate(seed: 42, profile: .demonstration)
    try await withThrowingTaskGroup(of: JSONSchemaExampleResult.self) { group in
        for _ in 0..<32 { group.addTask { try generator.generate(seed: 42, profile: .demonstration) } }
        var count = 0
        for try await result in group {
            #expect(result.value == expected.value && result.traceDigest == expected.traceDigest && result.statistics == expected.statistics)
            count += 1
        }
        #expect(count == 32)
    }
}
