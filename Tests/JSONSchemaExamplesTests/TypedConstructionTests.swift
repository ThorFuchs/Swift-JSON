// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
@testable import JSONSchemaExamples
import Testing

private func make(_ text: String, options: JSONSchemaExampleOptions = .init()) throws -> JSONSchemaExampleGenerator {
    try .init(document: .init(JSONParser().parse(text)), options: options)
}
private let fixtureDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/SchemaExamples")
private func fixture(_ name: String) throws -> JSON { try JSONParser().parse(Data(contentsOf: fixtureDirectory.appendingPathComponent(name))) }
private func requireResource(_ error: any Error, _ metric: JSONResourceMetric) {
    guard let failure = error as? JSONFailure else { Issue.record("Expected a resource error"); return }
    #expect(failure.category == .resource && failure.resource?.metric == metric)
}

@Test func g3All24RequiredFixturesAreNativeCertifiedForBothProfilesAndFourSeeds() throws {
    let data = try fixture("S3-integral-correction-v1.json"), manifest = try fixture("Manifest.json")
    let ids = try #require(manifest.objectValue?["g3_must_generate_ids"]?.arrayValue)
    let cases = try #require(data.objectValue?["cases"]?.arrayValue)
    var observed: [String] = [], generated = 0, witnesses = 0
    for value in cases {
        let c = try #require(value.objectValue)
        guard c["acceptanceGate"] == .string("G3"), c["generatorExpectation"] == .string("must-generate") else { continue }
        let id = try #require(c["id"]?.stringValue), schema = try #require(c["schema"])
        let assertion = c["validation"]?.objectValue?["formatAssertion"]?.booleanValue == true
        let options = JSONSchemaExampleOptions(validationOptions: .init(formatAssertion: assertion))
        let generator = try JSONSchemaExampleGenerator(document: .init(schema), options: options)
        let independent = try JSONSchemaCompiler(options: options.compilationOptions).compile(generator.document, registry: generator.registry)
        let validator = JSONSchemaValidator(options: options.validationOptions)
        for witness in try #require(c["witnesses"]?.arrayValue) {
            let instance = try #require(witness.objectValue?["instance"])
            let expected = try #require(witness.objectValue?["valid"]?.booleanValue)
            #expect(try validator.validate(instance, against: independent).isValid == expected, "\(id) witness")
            witnesses += 1
        }
        for profile in [JSONSchemaExampleProfile.minimal, .demonstration] {
            for seed in [UInt64(0), 1, 42, UInt64.max] {
                let result = try generator.generate(seed: seed, profile: profile)
                #expect(result.validation.isValid && result.validation.diagnosticsComplete, "\(id)")
                #expect(try validator.validate(result.value, against: independent).isValid, "\(id)")
                #expect(try JSONParser().parse(JSONWriter().write(result.value)) == result.value, "\(id)")
                #expect(result.statistics[.workUnits] >= result.statistics[.evaluationWorkUnits])
                #expect(result.statistics[.workUnits] <= options.limits[.workUnits])
                generated += 1
            }
        }
        observed.append(id)
        print("G3_FIXTURE passed id=\(id) profiles=2 seeds=4 generated=8")
    }
    #expect(observed.map(JSON.string) == ids && observed.count == 24 && generated == 192)
    #expect(witnesses > 0)
    print("G3_ACCEPTANCE passed cases=\(observed.count) generated=\(generated) witnesses=\(witnesses)")
}

@Test func g3TwoFixtureProofsRemainSeparateFromSearchFailure() throws {
    let cases = try #require(fixture("S3-integral-correction-v1.json").objectValue?["cases"]?.arrayValue)
    var count = 0
    for c in cases where c.objectValue?["acceptanceGate"] == .string("G3") && c.objectValue?["generatorExpectation"] == .string("must-prove-unsatisfiable") {
        let generator = try JSONSchemaExampleGenerator(document: .init(try #require(c.objectValue?["schema"])))
        let proof: JSONSchemaUnsatisfiableProof = c.objectValue?["id"] == .string("boolean-false") ? .falseSchema : .notTrue
        #expect(throws: JSONSchemaExampleFailure.provenUnsatisfiable(proof)) { try generator.generate() }
        count += 1
    }
    #expect(count == 2)
}

@Test func g3NestedScalarKeysAndConjunctivePropertiesNeverOverwrite() throws {
    let source = #"{"type":"object","allOf":[{"properties":{"é":{"type":"integer","minimum":2},"e\u0301":{"const":9}},"required":["é","e\u0301"]},{"properties":{"é":{"maximum":3}},"required":["é"]}]}"#
    let result = try make(source).generate()
    #expect(result.value.objectValue?.count == 2)
    #expect(result.value.objectValue?["é"] == 2 && result.value.objectValue?["e\u{301}"] == 9)
    #expect(result.validation.isValid)
    let incompatible = #"{"type":"object","allOf":[{"properties":{"a":{"type":"integer"}},"required":["a"]},{"properties":{"a":{"type":"string"}},"required":["a"]}]}"#
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) { try make(incompatible).generate() }
}

@Test func g3EachConjunctControlsAdditionalPropertiesIndependently() throws {
    let source = #"{"type":"object","properties":{"a":{"const":1}},"additionalProperties":false,"allOf":[{"required":["b"],"properties":{"b":{"const":2}}}]}"#
    #expect(throws: JSONSchemaExampleFailure.unsupportedFeature(.candidateConstruction)) { try make(source).generate() }
}

@Test func g3NegativeAndOpenExactNumericIntervalsNeverUseEpsilon() throws {
    for (schema, expected) in [
        (#"{"type":"integer","maximum":-1.25}"#, "-2"),
        (#"{"type":"integer","exclusiveMinimum":-2,"maximum":-1}"#, "-1"),
        (#"{"type":"number","exclusiveMinimum":0.000000000000000000000001,"exclusiveMaximum":0.000000000000000000000002}"#, "11e-25"),
        (#"{"type":"number","minimum":-0.049,"maximum":-0.021,"multipleOf":0.01}"#, "-0.04"),
        (#"{"type":"integer","minimum":1,"multipleOf":2.5}"#, "5"),
        (#"{"type":"integer","minimum":123456789012345678901234567890123456789}"#, "123456789012345678901234567890123456789")
    ] {
        let result = try make(schema).generate()
        #expect(try result.value == JSONParser().parse(expected))
        #expect(result.validation.isValid && result.statistics[.numericWorkUnits] > 0)
    }
}

@Test func g3ScalarLengthUsesDecodedScalarsAndPreservesCorpusSpelling() throws {
    let options = JSONSchemaExampleOptions(corpus: .init(values: [.string("e\u{301}")]))
    let result = try make(#"{"type":"string","minLength":2,"maxLength":2}"#, options: options).generate(profile: .demonstration)
    #expect(result.value == .string("e\u{301}") && result.validation.isValid)
}

@Test func g3AssertionPolicyRemainsNativeAndContentMetadataDoesNotExecute() throws {
    let source = #"{"type":"string","format":"email","contentEncoding":"base64","contentMediaType":"text/html"}"#
    #expect(try make(source).generate().value == .string(""))
    let asserted = try make(source, options: .init(validationOptions: .init(formatAssertion: true))).generate()
    #expect(asserted.value == .string("example@example.com") && asserted.validation.isValid)
}

@Test func g3MinimumPropertiesAndUniqueArrayElementsHaveCheckedConstruction() throws {
    let object = try make(#"{"type":"object","minProperties":3,"maxProperties":3,"additionalProperties":{"type":"integer"}}"#).generate()
    #expect(object.value.objectValue?.members.map(\.key.string) == ["p0","p1","p2"])
    let array = try make(#"{"type":"array","minItems":3,"uniqueItems":true,"items":{"type":"integer"}}"#).generate()
    #expect(array.value == .array([0,1,2]) && array.validation.isValid)
}

@Test func g3ConstructedArraysRetainNestedElementsAndDepth() throws {
    let source = #"{"type":"array","minItems":2,"items":{"type":"array","minItems":2,"items":{"type":"integer"}}}"#
    let result = try make(source).generate()
    #expect(result.value == .array([.array([0,0]), .array([0,0])]))
}

@Test func g3TypedConstructionHasAnExactCumulativeWorkBoundary() throws {
    let source = #"{"type":"object","required":["v"],"properties":{"v":{"type":"number","minimum":0.02,"multipleOf":0.01}},"default":{}}"#
    let result = try make(source).generate()
    #expect(result.attempts == 2 && result.validation.isValid)
    var limits = JSONLimits.balanced; limits[.workUnits] = result.statistics[.workUnits]
    #expect(try make(source, options: .init(limits: limits)).generate().statistics[.workUnits] == limits[.workUnits])
    limits[.workUnits] -= 1
    do { _ = try make(source, options: .init(limits: limits)).generate(); Issue.record("Cumulative budget reset") }
    catch { requireResource(error, .workUnits) }
}

@Test func g3TypedStagingChecksDepthCardinalityAndNumericWorkBeforeGrowth() throws {
    for (schema, metric, cap) in [
        (#"{"type":"array","minItems":3,"items":{"type":"integer"}}"#, JSONResourceMetric.arrayItems, UInt64(2)),
        (#"{"type":"object","minProperties":2}"#, .objectMembers, 1),
        (#"{"type":"array","minItems":1,"items":{"type":"array"}}"#, .maxDepth, 1),
        (#"{"type":"number","minimum":0.02,"multipleOf":0.01}"#, .numericWorkUnits, 0),
        (#"{"type":"integer","minimum":9007199254740993}"#, .numberDigits, 3)
    ] {
        var limits = JSONLimits.balanced; limits[metric] = cap
        do { _ = try make(schema, options: .init(limits: limits)).generate(); Issue.record("Staging cap ignored") }
        catch { requireResource(error, metric) }
    }
}

@Test func g3DenseAlignmentFailsFinitelyWithoutApproximation() throws {
    do { _ = try make(#"{"type":"number","exclusiveMinimum":1e10000,"multipleOf":0.01}"#).generate(); Issue.record("Unbounded dense decimal") }
    catch { requireResource(error, .numberDigits) }
}

@Test func g3OperationalValidationFailureNeverAdvancesTypedSearch() throws {
    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 0
    do { _ = try make(#"{"type":"integer"}"#, options: .init(validationOptions: .init(limits: limits))).generate(); Issue.record("Operational error retried") }
    catch { requireResource(error, .evaluationWorkUnits) }
}

@Test func g3CancellationInsideTypedFramesIsTerminal() async throws {
    let generator = try make(#"{"type":"object","required":["a"],"properties":{"a":{"type":"integer"}}}"#)
    let plan = try JSONSchemaCompiler().compile(generator.document)
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        var random = SchemaExampleRandom(seed: 0)
        var trace = try SchemaExampleTrace(snapshot: "s", corpus: "c", policy: "p", seed: 0, profile: .minimal, meter: &meter)
        let trigger = meter.used(.workUnits) + 100
        meter.checkpointObserver = { work in if work >= trigger { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) {
            try SchemaExampleConstructor.construct(nodes: [plan.exampleRoot], variation: 0, profile: .minimal, corpus: [], assertion: false,
                                                    random: &random, trace: &trace, meter: &meter)
        }
        #expect(throws: CancellationError.self) { try meter.work() }
    }
    try await task.value
    #expect(try generator.generate().validation.isValid)
}

@Test func g3OneHundredRepeatedTypedInvocationsHaveNoStateDrift() throws {
    let generator = try make(#"{"type":"object","required":["id","label"],"properties":{"id":{"type":"integer","minimum":9007199254740993},"label":{"type":"string","minLength":2}}}"#)
    let expected = try generator.generate(seed: 42, profile: .demonstration)
    for _ in 0..<100 {
        let result = try generator.generate(seed: 42, profile: .demonstration)
        #expect(result.value == expected.value && result.traceDigest == expected.traceDigest && result.statistics == expected.statistics)
    }
}

@Test func g3SharedTypedGeneratorHasIndependentConcurrentInvocations() async throws {
    let generator = try make(#"{"type":"array","minItems":3,"uniqueItems":true,"items":{"type":"integer","minimum":9007199254740993}}"#)
    let minimal = try (0..<16).map { try generator.generate(seed: UInt64($0)) }
    let demonstration = try (0..<16).map { try generator.generate(seed: UInt64($0), profile: .demonstration) }
    try await withThrowingTaskGroup(of: JSONSchemaExampleResult.self) { group in
        for seed in 0..<16 {
            group.addTask { try generator.generate(seed: UInt64(seed)) }
            group.addTask { try generator.generate(seed: UInt64(seed), profile: .demonstration) }
        }
        var count = 0
        for try await result in group {
            let expected = result.profile == .minimal ? minimal[Int(result.seed)] : demonstration[Int(result.seed)]
            #expect(result.value == expected.value && result.traceDigest == expected.traceDigest && result.statistics == expected.statistics)
            count += 1
        }
        #expect(count == 32)
    }
}

@Test func g3PrefixIndicesAboveNineRemainPositionalDecimalText() throws {
    var members: [JSON] = []
    for index in 0..<12 { members.append(.object(try JSONObject(members: [.init("const", value: .number(JSONNumber(integer: index)))]))) }
    let schema = try JSONObject(members: [.init("type", value: .string("array")), .init("minItems", value: 12), .init("prefixItems", value: .array(members)), .init("items", value: false)])
    let result = try JSONSchemaExampleGenerator(document: .init(.object(schema))).generate()
    #expect(result.value == .array((0..<12).map { .number(JSONNumber(integer: $0)) }))
}

@Test func g3SignedRoundingMatchesIndependentIntegerArithmeticGrid() throws {
    var meter = try JSONWorkMeter(limits: .offline, domain: .core)
    var observed = 0
    for numerator in -17...17 {
        for divisor in 1...7 {
            for up in [false, true] {
                for open in [false, true] {
                    for variation in [UInt64(0),1,2] {
                        var quotient = numerator / divisor
                        let remainder = numerator % divisor
                        if up && remainder > 0 { quotient += 1 }
                        if !up && remainder < 0 { quotient -= 1 }
                        if open && remainder == 0 { quotient += up ? 1 : -1 }
                        quotient += (up ? 1 : -1) * Int(variation)
                        let result = try SchemaExampleDecimal.rounded(JSONNumber(integer: numerator), step: JSONNumber(integer: divisor),
                                                                      up: up, open: open, variation: variation, meter: &meter)
                        #expect(result == JSONNumber(integer: quotient * divisor))
                        observed += 1
                    }
                }
            }
        }
    }
    #expect(observed == 2940 && meter.used(.numericWorkUnits) > 0)
}

@Test func g3RepeatedStaticTargetsAreDAGSharingAndRecursiveBaseCasesRemainFinite() throws {
    let dag = ##"{"$defs":{"x":{"type":"integer"}},"allOf":[{"$ref":"#/$defs/x"},{"$ref":"#/$defs/x"}]}"##
    #expect(try make(dag).generate().value == 0)
    let recursive = ##"{"$defs":{"x":{"type":"array","items":{"$ref":"#/$defs/x"}}},"$ref":"#/$defs/x"}"##
    #expect(try make(recursive).generate().value == .array([]))
}
