// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
@testable import JSONSchemaExamples
import Testing

private func lifecycleGenerator(_ source: String, options: JSONSchemaExampleOptions = .init()) throws -> JSONSchemaExampleGenerator {
    try .init(document: JSONSchemaDocument(JSONParser().parse(source)), options: options)
}
private func lifecycleMeter(_ options: JSONSchemaExampleOptions = .init()) throws -> JSONWorkMeter {
    try .init(limits: options.limits.intersection(options.validationOptions.limits), domain: .core)
}
private func expectResource(_ error: any Error, metric: JSONResourceMetric, code: JSONFailure.Code = .limitExceeded) {
    guard let failure = error as? JSONFailure else { Issue.record("Expected a native resource failure: \(error)"); return }
    #expect(failure.category == .resource && failure.code == code && failure.resource?.metric == metric)
}

@Test func g5TraceFinalizationReleasesOnlyItsActualTransportReservation() throws {
    var meter = try lifecycleMeter()
    try meter.retain(91)
    var trace = try SchemaExampleTrace(snapshot: "s", corpus: "c", policy: "p", seed: 0, profile: .minimal, meter: &meter)
    try trace.event(4, 1, 1, meter: &meter)
    #expect(meter.used(.retainedBytes) == 91 + trace.retainedByteCount)
    #expect(try trace.digest(meter: &meter).count == 64)
    #expect(trace.retainedByteCount == 0 && meter.used(.retainedBytes) == 91 + 64)
    // Misuse is terminal even when caught; unrelated work cannot resume.
    let failure = JSONFailure(.configuration, code: .invalidOperation)
    #expect(throws: failure) { try trace.event(1, 0, 0, meter: &meter) }
    #expect(throws: failure) { try meter.work() }
}

@Test func g5SuccessTransfersResultsAndReleasesInvocationReservations() throws {
    var options = JSONSchemaExampleOptions(); options.validationOptions.collectAnnotations = true
    let prepared = try lifecycleGenerator(#"{"type":"object","required":["a"],"properties":{"a":{"type":"integer","default":7}}}"#, options: options)
    var meter = try lifecycleMeter(options)
    try meter.retain(73); try meter.work(19)
    let result = try prepared.generate(meter: &meter)
    #expect(result.validation.isValid && result.value.objectValue?.count == 1)
    #expect(result.statistics[.workUnits] == meter.used(.workUnits))
    #expect(result.statistics[.retainedBytes] > 73)
    #expect(meter.used(.retainedBytes) == 73 && meter.used(.annotationBytes) == 0 && meter.used(.regexRetainedBytes) == 0)
    try meter.work()
    #expect(meter.used(.workUnits) == result.statistics[.workUnits] + 1)
}

@Test func g5RepeatedSuccessDoesNotAccumulateLiveInvocationStateOrResetWork() throws {
    let prepared = try lifecycleGenerator(#"{"enum":[0,"ok"],"type":"string"}"#)
    let expected = try prepared.generate()
    var meter = try lifecycleMeter()
    for index: UInt64 in 1...12 {
        let result = try prepared.generate(meter: &meter)
        #expect(result.value == expected.value && result.traceDigest == expected.traceDigest)
        #expect(meter.used(.retainedBytes) == 0 && meter.used(.annotationBytes) == 0)
        #expect(meter.used(.workUnits) == expected.statistics[.workUnits] * index)
        #expect(meter.used(.evaluationWorkUnits) == expected.statistics[.evaluationWorkUnits] * index)
    }
}

@Test func g5ReturnedCertificateOutlivesPreparedSourceAndRegistryScope() throws {
    func scoped() throws -> JSONSchemaExampleResult {
        let root = try JSONSchemaDocument(JSONParser().parse(##"{"$ref":"https://e.test/value"}"##))
        let external = try JSONSchemaDocument(JSONParser().parse(#"{"const":{"é":9007199254740993,"e\u0301":null}}"#), retrievalURI: JSONSchemaURI("https://e.test/value"))
        return try JSONSchemaExampleGenerator(document: root, registry: .init(documents: [external])).generate()
    }
    let result = try scoped()
    #expect(result.validation.isValid && result.value.objectValue?.count == 2)
    #expect(try JSONParser().parse(JSONWriter().write(result.value)) == result.value)
    let large = try JSONNumber(parsing: "9007199254740993")
    #expect(result.value.objectValue?["é"]?.numberValue == large)
}

@Test func g5InvalidVerdictsConsumeDiagnosticsAndAllCompletedEvaluationWork() throws {
    let source = #"{"enum":[1,2,"ok"],"type":"string"}"#
    let prepared = try lifecycleGenerator(source)
    let result = try prepared.generate()
    let plan = try JSONSchemaCompiler().compile(prepared.document)
    var evaluation: UInt64 = 0, issues: UInt64 = 0, diagnostics: UInt64 = 0
    // Compare the same normalized parsed representation the generator certifies;
    // native integer construction does not retain the parser's number lexeme.
    for value in [try JSONParser().parse("1"), try JSONParser().parse("2"), .string("ok")] {
        let report = try JSONSchemaValidator().validateWithReport(value, against: plan)
        evaluation += report.statistics[.evaluationWorkUnits]
        issues += report.statistics[.issues]; diagnostics += report.statistics[.diagnosticBytes]
    }
    #expect(result.attempts == 3 && result.statistics[.evaluationWorkUnits] == evaluation)
    #expect(result.statistics[.issues] == issues && issues > 0)
    #expect(result.statistics[.diagnosticBytes] > diagnostics) // Includes complete abstract trace.
}

@Test func g5ExactCumulativeQuotaAndRetentionBoundaries() throws {
    let source = #"{"default":0,"type":"string","pattern":"^[a-z]{3}$"}"#
    let measured = try lifecycleGenerator(source).generate()
    for metric: JSONResourceMetric in [.workUnits, .numericWorkUnits, .evaluationWorkUnits, .aggregateRegexWorkUnits, .diagnosticBytes, .issues, .retainedBytes] {
        var options = JSONSchemaExampleOptions()
        let cap = metric == .retainedBytes ? measured.statistics.peakLogicalRetainedBytes : measured.statistics[metric]
        #expect(cap > 0)
        options.limits[metric] = cap
        let exact = try lifecycleGenerator(source, options: options).generate()
        #expect(exact.validation.isValid)
        options.limits[metric] = cap - 1
        var meter = try lifecycleMeter(options)
        do { _ = try lifecycleGenerator(source, options: options).generate(meter: &meter); Issue.record("One-unit-short \(metric) returned a certificate") }
        catch { expectResource(error, metric: metric) }
        #expect(meter.used(.retainedBytes) == 0 && meter.used(.annotationBytes) == 0 && meter.used(.regexRetainedBytes) == 0)
        let used = meter.statistics()
        do { try meter.work(); Issue.record("Exhausted ledger resumed") } catch { expectResource(error, metric: metric) }
        #expect(meter.statistics() == used)
    }
}

@Test func g5OperationalEvaluationFailureIsLatchedWithoutRetryOrReport() throws {
    var options = JSONSchemaExampleOptions(); options.validationOptions.limits[.evaluationWorkUnits] = 0
    let prepared = try lifecycleGenerator(#"{"enum":[1,2,3]}"#, options: options)
    var meter = try lifecycleMeter(options)
    do { _ = try prepared.generate(meter: &meter); Issue.record("Operational failure returned success") }
    catch { expectResource(error, metric: .evaluationWorkUnits) }
    #expect(meter.domain == .schemaEvaluation && meter.used(.evaluationWorkUnits) == 0)
    #expect(meter.used(.retainedBytes) == 0)
    let stopped = meter.statistics()
    do { _ = try prepared.generate(meter: &meter); Issue.record("Invocation restarted after error") }
    catch { expectResource(error, metric: .evaluationWorkUnits) }
    #expect(meter.statistics() == stopped)
}

@Test func g5NativeNonproductiveReferenceFailureIsTerminalRatherThanSearchExhaustion() throws {
    let prepared = try lifecycleGenerator(##"{"$ref":"#","default":0}"##)
    var meter = try lifecycleMeter()
    let expected = JSONSchemaEvaluationFailure(.nonproductiveReference)
    #expect(throws: expected) { try prepared.generate(meter: &meter) }
    #expect(meter.used(.retainedBytes) == 0 && meter.used(.annotationBytes) == 0)
    let stopped = meter.statistics()
    #expect(throws: expected) { try prepared.generate(meter: &meter) }
    #expect(meter.statistics() == stopped)
}

@Test func g5ExhaustedBranchesReleaseScratchWithoutClaimingUnsatisfiability() throws {
    var options = JSONSchemaExampleOptions(maximumAttempts: 3)
    options.validationOptions.collectAnnotations = true
    let prepared = try lifecycleGenerator(#"{"type":"array","minItems":2,"maxItems":2,"uniqueItems":true,"items":{"enum":[0]}}"#, options: options)
    var meter = try lifecycleMeter(options)
    let expected = JSONSchemaExampleFailure.searchExhausted(attempts: 3)
    #expect(throws: expected) { try prepared.generate(meter: &meter) }
    #expect(meter.used(.evaluationWorkUnits) > 0 && meter.used(.issues) >= 3)
    #expect(meter.used(.retainedBytes) == 0 && meter.used(.annotationBytes) == 0)
    let stopped = meter.statistics()
    #expect(throws: expected) { try prepared.generate(meter: &meter) }
    #expect(meter.statistics() == stopped)
}

@Test func g5NestedCyclicConstructionAndProofFailuresReleaseAndLatch() throws {
    let cases: [(String, JSONSchemaExampleFailure)] = [
        (##"{"type":"object","required":["a"],"properties":{"a":{"$ref":"#/$defs/loop"}},"$defs":{"loop":{"allOf":[{"$ref":"#/$defs/loop"}]}}}"##, .unsupportedFeature(.cyclicReference)),
        ("false", .provenUnsatisfiable(.falseSchema)),
        (#"{"not":true}"#, .provenUnsatisfiable(.notTrue))]
    for (source, expected) in cases {
        let prepared = try lifecycleGenerator(source)
        var meter = try lifecycleMeter()
        #expect(throws: expected) { try prepared.generate(meter: &meter) }
        #expect(meter.used(.retainedBytes) == 0 && meter.used(.regexRetainedBytes) == 0)
        let stopped = meter.statistics()
        #expect(throws: expected) { try meter.work() }
        #expect(meter.statistics() == stopped)
    }
}

@Test func g5OverflowAndRetiredAdmissionCannotWrapOrRefundWork() throws {
    var meter = try lifecycleMeter()
    try meter.work(7)
    do { _ = try meter.adding(.workUnits, UInt64.max, 1); Issue.record("Overflow admitted") }
    catch { expectResource(error, metric: .workUnits, code: .counterOverflow) }
    #expect(meter.used(.workUnits) == 7)
    do { try meter.resetValueBounds(); try meter.work(); Issue.record("Overflow ledger resumed") }
    catch { expectResource(error, metric: .workUnits, code: .counterOverflow) }
    var retired = try lifecycleMeter()
    try retired.work(11); try retired.charge(.nodes, 3); try retired.resetValueBounds()
    try retired.charge(.nodes, 2)
    #expect(retired.used(.workUnits) == 11 && retired.used(.nodes) == 2 && retired.statistics()[.nodes] == 5)
}

@Test func g5CancellationAcrossDiscoveryConstructionEvaluationAndTraceIsTerminal() async throws {
    let source = #"{"default":0,"type":"string","pattern":"^(a|aa)+b$","minLength":80,"maxLength":80}"#
    var options = JSONSchemaExampleOptions(maximumAttempts: 2)
    options.limits[.cancellationQuantum] = 1
    let prepared = try lifecycleGenerator(source, options: options)
    // Each threshold is charged work, independent of clocks/scheduling. This
    // reaches discovery, construction and native regex, then checks terminal state.
    var observedRegexCancellation = false
    for trigger: UInt64 in [1, 300, 900, 1800, 3000, 5000, 10000, 20000] {
        let regex = try await Task { @Sendable [options, prepared, trigger] in
            var meter = try lifecycleMeter(options)
            meter.checkpointObserver = { work in if work >= trigger { withUnsafeCurrentTask { $0?.cancel() } } }
            #expect(throws: CancellationError.self) { try prepared.generate(meter: &meter) }
            #expect(meter.used(.retainedBytes) == 0 && meter.used(.annotationBytes) == 0 && meter.used(.regexRetainedBytes) == 0)
            let stopped = meter.statistics()
            #expect(throws: CancellationError.self) { try prepared.generate(meter: &meter) }
            #expect(meter.statistics() == stopped)
            return meter.domain == .schemaEvaluation && meter.used(.aggregateRegexWorkUnits) > 0
        }.value
        observedRegexCancellation = observedRegexCancellation || regex
    }
    #expect(observedRegexCancellation)
}

@Test func g5CancellationInsideLongDecimalDivisionLatchesItsSharedLedger() async throws {
    let bound = try JSONNumber(parsing: String(repeating: "9", count: 128))
    let step = try JSONNumber(parsing: "7")
    try await Task {
        var options = JSONSchemaExampleOptions(); options.limits[.cancellationQuantum] = 1
        var meter = try lifecycleMeter(options)
        meter.checkpointObserver = { work in if work >= 500 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { try SchemaExampleDecimal.rounded(bound, step: step, up: true, open: true, variation: 1, meter: &meter) }
        #expect(meter.used(.numericWorkUnits) >= 500)
        let stopped = meter.statistics()
        #expect(throws: CancellationError.self) { try meter.work() }
        #expect(meter.statistics() == stopped)
    }.value
}

@Test func g5CancellationDuringFinalTraceHashNeverPublishesACertificate() async throws {
    let prepared = try lifecycleGenerator("true")
    let measured = try prepared.generate()
    let trigger = measured.statistics[.workUnits] - 1000
    try await Task {
        var meter = try lifecycleMeter()
        meter.checkpointObserver = { work in if work >= trigger { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { try prepared.generate(meter: &meter) }
        #expect(meter.domain == .core && meter.used(.evaluationWorkUnits) == measured.statistics[.evaluationWorkUnits])
        #expect(meter.used(.retainedBytes) == 0)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
    }.value
    // Separate calls are independent; cancellation never mutates preparation.
    #expect(try prepared.generate().traceDigest == measured.traceDigest)
}

@Test func g5ZeroWorkAndPreparationQuotaFailureDoNotReturnPartialObjects() throws {
    var options = JSONSchemaExampleOptions(); options.limits[.workUnits] = 0
    var meter = try lifecycleMeter(options)
    do { _ = try lifecycleGenerator("true", options: options).generate(meter: &meter); Issue.record("Zero-work success") }
    catch { expectResource(error, metric: .workUnits) }
    #expect(meter.used(.workUnits) == 0 && meter.used(.retainedBytes) == 0)
    options = .init()
    let measured = try lifecycleGenerator("true").preparationStatistics[.workUnits]
    options.compilationOptions.limits[.workUnits] = measured
    #expect(try lifecycleGenerator("true", options: options).preparationStatistics[.workUnits] == measured)
    options.compilationOptions.limits[.workUnits] -= 1
    do { _ = try lifecycleGenerator("true", options: options); Issue.record("Preparation quota reset for snapshot/corpus/policy") }
    catch { expectResource(error, metric: .workUnits) }
}

@Test func g5SharedPreparationSeparatesConcurrentFailureAndSuccessHealth() async throws {
    let prepared = try lifecycleGenerator(#"{"type":"integer","minimum":9007199254740993}"#)
    let expected = try prepared.generate()
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for index in 0..<32 {
            group.addTask {
                if index.isMultiple(of: 2) {
                    withUnsafeCurrentTask { $0?.cancel() }
                    do { _ = try prepared.generate(); return false } catch is CancellationError { return true }
                }
                let result = try prepared.generate()
                return result.value == expected.value && result.statistics == expected.statistics && result.traceDigest == expected.traceDigest
            }
        }
        var count = 0
        for try await passed in group { #expect(passed); count += 1 }
        #expect(count == 32)
    }
    #expect(try prepared.generate().value == expected.value)
}

@Test func g5PolicyDigestReleasesAllTemporaryArrayReservations() throws {
    var meter = try lifecycleMeter()
    try meter.retain(41)
    #expect(try SchemaExampleDigests.policy(.init(), meter: &meter).count == 64)
    #expect(meter.used(.retainedBytes) == 41 + 64)
    #expect(meter.used(.workUnits) > 0 && meter.used(.compiledPlanBytes) == 0)
}
