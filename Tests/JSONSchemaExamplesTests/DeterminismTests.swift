// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
@testable import JSONSchemaExamples
import Testing

private func prepared(_ text: String, options: JSONSchemaExampleOptions = .init()) throws -> JSONSchemaExampleGenerator {
    try .init(document: JSONSchemaDocument(JSONParser().parse(text)), options: options)
}
private func testTrace(meter: inout JSONWorkMeter) throws -> SchemaExampleTrace {
    try .init(snapshot: "s", corpus: "c", policy: "p", seed: 3, profile: .demonstration, meter: &meter)
}
private func resource(_ error: any Error, _ metric: JSONResourceMetric) -> Bool {
    guard let error = error as? JSONFailure else { return false }
    return error.category == .resource && error.resource?.metric == metric
}

@Test func g2MeteredSplitMixMatchesAllReferenceGoldenDraws() throws {
    let vectors: [(UInt64, [UInt64])] = [
        (0, [0xe220a8397b1dcdaf, 0x6e789e6aa1b965f4, 0x06c45d188009454f, 0xf88bb8a8724c81ec]),
        (1, [0x910a2dec89025cc1, 0xbeeb8da1658eec67, 0xf893a2eefb32555e, 0x71c18690ee42c90b]),
        (42, [0xbdd732262feb6e95, 0x28efe333b266f103, 0x47526757130f9f52, 0x581ce1ff0e4ae394]),
        (UInt64.max, [0xe4d971771b652c20, 0xe99ff867dbf682c9, 0x382ff84cb27281e9, 0x6d1db36ccba982d2])]
    for (seed, expected) in vectors {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        var rng = SchemaExampleRandom(seed: seed)
        for golden in expected { #expect(try rng.next(meter: &meter) == golden) }
        #expect(rng.draws == 4 && meter.used(.workUnits) == 40)
    }
}

@Test func g2UniformSelectionsStayInRangeAtUInt64Boundaries() throws {
    for bound in [UInt64(1), 2, 7, 128, UInt64.max] {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        var trace = try testTrace(meter: &meter), rng = SchemaExampleRandom(seed: 42)
        for _ in 0..<128 { #expect(try rng.uniform(upperBound: bound, trace: &trace, meter: &meter) < bound) }
        #expect(trace.events == rng.draws && rng.draws >= 128)
    }
}

@Test func g2RejectedUniformDrawsChargeWorkAndTraceBeforeRetry() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    var trace = try testTrace(meter: &meter), rng = SchemaExampleRandom(seed: 3)
    let before = meter.used(.workUnits), diagnosticBefore = meter.used(.diagnosticBytes)
    let selected = try rng.uniform(upperBound: 0x8000000000000001, trace: &trace, meter: &meter)
    #expect(selected == 0x33466f8a7b81a988 && rng.draws == 2 && trace.events == 2)
    #expect(meter.used(.workUnits) - before == 3 + 2 * 29)
    #expect(meter.used(.diagnosticBytes) - diagnosticBefore == 34)
}

@Test func g2UniformZeroBoundFailsAndLatchesTheLedger() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    var trace = try testTrace(meter: &meter), rng = SchemaExampleRandom(seed: 3)
    let failure = JSONFailure(.configuration, code: .invalidOperation)
    #expect(throws: failure) { try rng.uniform(upperBound: 0, trace: &trace, meter: &meter) }
    #expect(throws: failure) { try rng.next(meter: &meter) }
    #expect(rng.draws == 0)
}

@Test func g2WorkExhaustionAfterRejectedDrawCannotResetOrAdvanceRandomState() throws {
    var measure = try JSONWorkMeter(limits: .balanced, domain: .core)
    let measuredTrace = try testTrace(meter: &measure)
    _ = consume measuredTrace
    var limits = JSONLimits.balanced; limits[.workUnits] = measure.used(.workUnits) + 3 + 29 + 9
    var meter = try JSONWorkMeter(limits: limits, domain: .core)
    var trace = try testTrace(meter: &meter), rng = SchemaExampleRandom(seed: 3)
    do { _ = try rng.uniform(upperBound: 0x8000000000000001, trace: &trace, meter: &meter); Issue.record("Rejected-draw work cap ignored") }
    catch { #expect(resource(error, .workUnits)) }
    #expect(rng.draws == 1 && trace.events == 1)
    do { _ = try rng.next(meter: &meter); Issue.record("Failed RNG ledger resumed") }
    catch { #expect(resource(error, .workUnits)) }
    #expect(rng.draws == 1)
}

@Test func g2CancellationDuringRandomSearchIsTerminal() async throws {
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        var trace = try testTrace(meter: &meter), rng = SchemaExampleRandom(seed: 3)
        let trigger = meter.used(.workUnits) + 3 + 5
        meter.checkpointObserver = { work in if work >= trigger { withUnsafeCurrentTask { $0?.cancel() } } }
        do { _ = try rng.uniform(upperBound: 0x8000000000000001, trace: &trace, meter: &meter); Issue.record("Cancellation ignored") }
        catch is CancellationError { }
        #expect(throws: CancellationError.self) { try rng.next(meter: &meter) }
        #expect(rng.draws == 0)
    }
    try await task.value
}

@Test func g2ConstructionNormalizesOrderAndLexemesWithoutLosingExactValues() throws {
    let a = try prepared(#"{"const":{"z":[[9007199254740993]],"é":1.0,"e\u0301":9007199254740994.5}}"#).generate(seed: 42)
    let b = try prepared(#"{"const":{"e\u0301":9007199254740994.5,"é":1,"z":[[9007199254740993]]}}"#).generate(seed: 42)
    let text = try JSONWriter().writeString(a.value)
    #expect(text.utf8.elementsEqual(#"{"é":90071992547409945e-1,"z":[[9007199254740993]],"é":1}"#.utf8))
    #expect(try JSONWriter().write(b.value) == JSONWriter().write(a.value))
    #expect(a.sourceSnapshotDigest == b.sourceSnapshotDigest && a.traceDigest == b.traceDigest)
    #expect(a.value.objectValue?.count == 3 && a.validation.isValid && b.validation.isValid)
}

@Test func g2ConstructionUsesIterativeCodecForDeepNesting() throws {
    var value: JSON = .number(try JSONNumber(parsing: "9007199254740993"))
    for _ in 0..<100 { value = .array([value]) }
    let document = try JSONSchemaDocument(.object(JSONObject(members: [.init("const", value: value)])))
    let result = try JSONSchemaExampleGenerator(document: document).generate()
    #expect(result.value == value && result.validation.isValid)
}

@Test func g2ConstructionChecksDepthAndNumericCapsBeforeCertification() throws {
    var limits = JSONLimits.balanced; limits[.maxDepth] = 2
    do { _ = try prepared(#"{"const":[[[0]]]}"#, options: .init(limits: limits)).generate(); Issue.record("Depth cap ignored") }
    catch { #expect(resource(error, .maxDepth)) }
    limits = .balanced; limits[.numberDigits] = 3
    do { _ = try prepared(#"{"const":9007199254740993}"#, options: .init(limits: limits)).generate(); Issue.record("Numeric cap ignored") }
    catch { #expect(resource(error, .numberDigits)) }
}

@Test func g2CorpusIsAdmittedExactOrderedAndImmutable() throws {
    let one = try JSONParser().parse(#"{"é":1.0,"e\u0301":9007199254740993}"#)
    let two = try JSONParser().parse(#"{"e\u0301":9007199254740993,"é":1}"#)
    let a = try prepared("true", options: .init(corpus: .init(values: [one, .null])))
    let b = try prepared("true", options: .init(corpus: .init(values: [two, .null])))
    let reversed = try prepared("true", options: .init(corpus: .init(values: [.null, two])))
    #expect(a.corpusDigest == b.corpusDigest && a.corpusDigest != reversed.corpusDigest)
    let result = try a.generate(seed: 2, profile: .demonstration)
    #expect(result.value == one && result.value.objectValue?.count == 2 && result.validation.isValid)
    #expect(result.corpusDigest == a.corpusDigest)
}

@Test func g2EmptyOrOversizedCorpusFailsDuringPreparation() throws {
    #expect(throws: JSONSchemaExampleFailure.invalidConfiguration(.emptyCorpus)) {
        try prepared("true", options: .init(corpus: .init(values: [])))
    }
    var limits = JSONLimits.balanced; limits[.stringBytes] = 4096
    #expect(try prepared("true", options: .init(corpus: .init(values: [.null]), compilationOptions: .init(limits: limits))).generate().validation.isValid)
    do { _ = try prepared("true", options: .init(corpus: .init(values: [.string(String(repeating: "x", count: 4097))]), compilationOptions: .init(limits: limits))); Issue.record("Corpus bypassed admission") }
    catch { #expect(resource(error, .stringBytes)) }
}

@Test func g2SnapshotCorpusAndPolicyMatchIndependentTransportGoldens() throws {
    let g = try prepared("true")
    #expect(g.sourceSnapshotDigest == "a69f2db52526c6c09592bc65478664deb370ef9d834aff678fa3f9879ae555aa")
    #expect(g.corpusDigest == "c8cfba87987771a2ae30e1e9d9f345ea45cb7a1e93eb69a5e2a7643881bf6847")
    #expect(g.policyDigest == "f9440e6af33f0e80bea2ae4dad4e532259bf722044d4ad0d925ae14d87ed3ff3")
}

@Test func g2All49GenerationCapsContributeToPolicyIdentity() throws {
    var meter = try JSONWorkMeter(limits: .offline, domain: .core)
    let base = try SchemaExampleDigests.policy(.init(), meter: &meter)
    var count = 0
    for metric in JSONResourceMetric.allCases {
        var options = JSONSchemaExampleOptions(); options.limits[metric] -= 1
        #expect(try SchemaExampleDigests.policy(options, meter: &meter) != base)
        count += 1
    }
    #expect(count == 49)
}

@Test func g2AllPolicyFlagsAndCompilationEvaluationCapsHaveDistinctIdentity() throws {
    var meter = try JSONWorkMeter(limits: .offline, domain: .core)
    let base = try SchemaExampleDigests.policy(.init(), meter: &meter)
    for slot in 0..<11 {
        var o = JSONSchemaExampleOptions()
        switch slot {
        case 0: o.maximumAttempts = 17
        case 1: o.compilationOptions.formatAssertion = true
        case 2: o.compilationOptions.output = .flag
        case 3: o.compilationOptions.diagnosticPolicy = .bestEffort
        case 4: o.compilationOptions.collectAnnotations = true
        case 5: o.validationOptions.formatAssertion = true
        case 6: o.validationOptions.output = .flag
        case 7: o.validationOptions.diagnosticPolicy = .bestEffort
        case 8: o.validationOptions.collectAnnotations = true
        case 9: o.compilationOptions.limits[.workUnits] -= 1
        default: o.validationOptions.limits[.workUnits] -= 1
        }
        #expect(try SchemaExampleDigests.policy(o, meter: &meter) != base)
    }
}

@Test func g2CompleteTraceGoldensBindSeedProfileSourceCorpusAndPolicy() throws {
    let g = try prepared("true"), minimal = try g.generate(seed: 42)
    let demo = try g.generate(seed: 42, profile: .demonstration)
    #expect(minimal.traceDigest == "72d4fb7da0b20ade2b52e1ad59313358eaff17a0de7f630ee3bf8b4a81e7cd53")
    #expect(demo.traceDigest == "e234604da7c2aa9a321fcd7d1ee9acd7e0fffea8e7f556fda6557e15deb3f029")
    #expect(minimal.randomDraws == 0 && minimal.traceEventCount == 4)
    #expect(demo.randomDraws == 1 && demo.traceEventCount == 5 && demo.value == .boolean(false))
    #expect(minimal.schemaDigestAlgorithm == "swift-json-schema-snapshot-v1")
    #expect(demo.rngAlgorithm == "splitmix64-v1" && demo.traceDigestAlgorithm == "swift-json-example-trace-v1")
    #expect(try g.generate(seed: 43).traceDigest != minimal.traceDigest)
    #expect(try prepared("{}").generate(seed: 42).traceDigest != minimal.traceDigest)
    #expect(try prepared("true", options: .init(maximumAttempts: 17)).generate(seed: 42).traceDigest != minimal.traceDigest)
    #expect(try prepared("true", options: .init(corpus: .init(values: [.null]))).generate(seed: 42).traceDigest != minimal.traceDigest)
}

@Test func g2TraceBytesHaveExactFiniteBoundaryWithoutTruncation() throws {
    var limits = JSONLimits.balanced; limits[.diagnosticBytes] = 344
    let exact = try prepared("true", options: .init(limits: limits)).generate(seed: 42)
    #expect(exact.statistics[.diagnosticBytes] == 344 && exact.traceEventCount == 4)
    limits[.diagnosticBytes] = 343
    do { _ = try prepared("true", options: .init(limits: limits)).generate(seed: 42); Issue.record("Truncated trace returned success") }
    catch { #expect(resource(error, .diagnosticBytes)) }
}

@Test func g2DemonstrationCircularScanKeepsRejectedNativeVerdictAndAttemptCeiling() throws {
    let source = #"{"enum":[1,"ok"],"type":"string"}"#
    let result = try prepared(source).generate(seed: 2, profile: .demonstration)
    #expect(result.value == .string("ok") && result.attempts == 2 && result.randomDraws == 1 && result.traceEventCount == 7)
    #expect(result.statistics[.evaluationWorkUnits] > 0)
    #expect(throws: JSONSchemaExampleFailure.searchExhausted(attempts: 1)) {
        try prepared(source, options: .init(maximumAttempts: 1)).generate(seed: 2, profile: .demonstration)
    }
}

@Test func g2KeywordDiscoveryIsIndependentOfObjectInsertionOrder() throws {
    let a = try prepared(#"{"examples":["last"],"enum":["enum","default"],"default":"default","type":"string"}"#).generate()
    let b = try prepared(#"{"type":"string","default":"default","enum":["enum","default"],"examples":["last"]}"#).generate()
    #expect(a.value == .string("default") && a.attempts == 1)
    #expect(a.sourceSnapshotDigest == b.sourceSnapshotDigest && a.traceDigest == b.traceDigest)
}

@Test func g2TraceFinalizationIsSingleUse() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    var trace = try testTrace(meter: &meter)
    try trace.event(4, 1, 1, meter: &meter)
    #expect(try trace.digest(meter: &meter).count == 64)
    let failure = JSONFailure(.configuration, code: .invalidOperation)
    #expect(throws: failure) { try trace.event(5, 1, 0, meter: &meter) }
    #expect(throws: failure) { try trace.digest(meter: &meter) }
}

@Test func g2CancellationDuringExactConstructionCannotReturnACandidate() async throws {
    let value: JSON = .array((0..<200).map { .string("token-\($0)") })
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        meter.checkpointObserver = { work in if work >= 100 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { try SchemaExampleExact.construct(value, meter: &meter) }
        #expect(throws: CancellationError.self) { try meter.work() }
    }
    try await task.value
}

@Test func g2StaticReferenceKindsUseStableScalarOrderWithOriginalRootValidation() throws {
    let a = try prepared(##"{"$ref":"#/$defs/a","$dynamicRef":"#/$defs/b","$defs":{"a":{"enum":[1,"ok"]},"b":{"const":"ok"}}}"##).generate(seed: 42)
    let b = try prepared(##"{"$defs":{"b":{"const":"ok"},"a":{"enum":[1,"ok"]}},"$dynamicRef":"#/$defs/b","$ref":"#/$defs/a"}"##).generate(seed: 42)
    #expect(a.value == .string("ok") && a.attempts == 1 && a.validation.isValid)
    #expect(a.sourceSnapshotDigest == b.sourceSnapshotDigest && a.traceDigest == b.traceDigest)
}
