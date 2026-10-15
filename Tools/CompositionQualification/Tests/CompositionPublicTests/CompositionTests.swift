// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema

private enum AuditError: Error { case workTrace, retentionTrace, caller }
private let source = Data(##"{"n":9007199254740993,"adjacent":9007199254740992,"long":123456789012345678901234567890.01234567890123456789,"fraction":0.01,"negative":-0,"é":true,"e\u0301":false,"a/b":{"~":null},"items":[false],"type":["string","null"],"$dynamicRef":"#node","$schema":"https://unknown.invalid/dialect"}"##.utf8)

// Independent audited-adapter ledger, not derived from operation statistics.
// Three bounded buffer fills: one frame visit and one unit per written byte;
// 32 logical header bytes per buffer. Final native receipt copies 49 slots and
// settles its aggregate slot (50 work), retaining 32 + 49*8 logical bytes.
private let goldenWork: UInt64 = 197
private let goldenBytes: UInt64 = 664
private func fill(_ scope: borrowing JSONCompositionScope, count: Int, first: Bool, mutation: String?) throws -> [UInt8] {
    let reservation = count - (first && mutation == "reservation" ? 1 : 0)
    try scope.reserveExternalLogicalBytes(1, count: UInt64(reservation), overhead: 32)
    try scope.chargeExternalWork(1)
    var bytes: [UInt8] = []
    bytes.reserveCapacity(count)
    for i in 0..<count {
        if !(first && i == 0 && mutation == "work") { try scope.chargeExternalWork(1) }
        bytes.append(UInt8(i))
    }
    return bytes
}
private func traceAdapter(_ limits: JSONLimits = .balanced, extra: UInt64 = 0) throws -> JSONOperationReport<([UInt8], [UInt8], [UInt8])> {
    let mutation = ProcessInfo.processInfo.environment["JCOMP_TRACE_MUTATION"]
    return try JSON.withComposition(limits: limits) { scope in
        let queue = try fill(scope, count: 64, first: true, mutation: mutation)
        let scratch = try fill(scope, count: 32, first: false, mutation: mutation)
        let output = try fill(scope, count: 48, first: false, mutation: mutation)
        try scope.chargeExternalWork(extra)
        return (queue, scratch, output)
    }
}
private func audit(_ report: JSONOperationReport<([UInt8], [UInt8], [UInt8])>) throws {
    guard report.statistics[.workUnits] == goldenWork else { throw AuditError.workTrace }
    guard report.statistics[.retainedBytes] == goldenBytes,
          report.statistics.peakLogicalRetainedBytes == goldenBytes else { throw AuditError.retentionTrace }
}
private func capture(_ body: () throws -> Void) -> (any Error)? {
    do { try body(); Issue.record("expected an error"); return nil } catch { return error }
}

@Test func externalTraceMatchesIndependentLedger() throws {
    let report = try traceAdapter()
    #expect(report.result.0.count == 64 && report.result.1.count == 32 && report.result.2.count == 48)
    try audit(report)
    if let directory = ProcessInfo.processInfo.environment["JCOMP_TRACE_DIRECTORY"] {
        let trace = "owner\twork\tlogical_bytes\nqueue\t65\t96\nscratch\t33\t64\nresult\t49\t80\nreceipt\t50\t424\n"
        try trace.write(toFile: directory + "/owned-events.tsv", atomically: true, encoding: .utf8)
    }
}

@Test func exactWorkAndRetentionLimitsAreActive() throws {
    var exact = JSONLimits.balanced
    exact[.workUnits] = goldenWork; exact[.retainedBytes] = goldenBytes
    try audit(traceAdapter(exact))
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var below = exact; below[metric] -= 1
        let failure = capture { _ = try traceAdapter(below) } as? JSONFailure
        #expect(failure?.category == .resource && failure?.resource?.metric == metric)
    }
    #expect(throws: JSONFailure.self) { _ = try traceAdapter(exact, extra: 1) }
}

@Test func reportOverlapIsAdmittedByFinalizer() throws {
    var limits = JSONLimits.balanced
    limits[.retainedBytes] = 424; limits[.workUnits] = 50
    let report = try JSON.withComposition(limits: limits) { _ in 7 }
    #expect(report.result == 7 && report.statistics[.retainedBytes] == 424)
    #expect(report.statistics[.workUnits] == 50 && report.statistics.peakLogicalRetainedBytes == 424)
    limits[.retainedBytes] = 423
    #expect(throws: JSONFailure.self) { try JSON.withComposition(limits: limits) { _ in 7 } }
    limits[.retainedBytes] = 424; limits[.workUnits] = 49
    #expect(throws: JSONFailure.self) { try JSON.withComposition(limits: limits) { _ in 7 } }
}

@Test func finiteMaximumWorkDoesNotOverflowCompletion() throws {
    var limits = JSONLimits.balanced; limits[.workUnits] = UInt64.max - 1
    let report = try JSON.withComposition(limits: limits) { scope in try scope.chargeExternalWork(UInt64.max - 51) }
    #expect(report.statistics[.workUnits] == UInt64.max - 1)
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition(limits: limits) { scope in try scope.chargeExternalWork(UInt64.max - 50) }
    }
}

@Test func checkedProductAndOverheadFailBeforeGrowth() throws {
    for mode in 0..<2 {
        var growth = false
        let error = capture {
            _ = try JSON.withComposition { scope in
                do {
                    if mode == 0 { try scope.reserveExternalLogicalBytes(UInt64.max, count: 2) }
                    else { try scope.reserveExternalLogicalBytes(1, overhead: UInt64.max) }
                    growth = true
                } catch let failure as JSONFailure { #expect(failure.code == .counterOverflow) }
                return 0
            }
        } as? JSONFailure
        #expect(!growth && error?.code == .counterOverflow)
    }
}

@Test func zeroReservationAndZeroQuotaHaveDistinctMeaning() throws {
    let report = try JSON.withComposition { try $0.reserveExternalLogicalBytes(0, count: 0) }
    #expect(report.statistics[.retainedBytes] == 424)
    var none = JSONLimits.balanced; none[.workUnits] = 0
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition(limits: none) { scope in do { try scope.chargeExternalWork(1) } catch { } }
    }
}

@Test func firstQuotaFailureSurvivesCatchCleanupAndCallerError() throws {
    var limits = JSONLimits.balanced; limits[.workUnits] = 1
    let error = capture {
        _ = try JSON.withComposition(limits: limits) { scope in
            do { try scope.chargeExternalWork(2) } catch { }
            do { try scope.reserveExternalLogicalBytes(UInt64.max, count: 2) } catch { }
            throw AuditError.caller
        }
    } as? JSONFailure
    #expect(error?.code == .limitExceeded && error?.resource?.metric == .workUnits)
    #expect(error?.resource?.attemptedUsage == 2)
}

@Test func firstOverflowSurvivesLaterCalls() throws {
    let error = capture {
        _ = try JSON.withComposition { scope in
            try scope.chargeExternalWork(1)
            do { try scope.chargeExternalWork(UInt64.max) } catch { }
            do { _ = try scope.parseDocument(Data("{".utf8)) } catch { }
            return 7
        }
    } as? JSONFailure
    #expect(error?.code == .counterOverflow && error?.resource?.metric == .workUnits)
}

@Test func freshInvocationHasFreshLedgerAfterFailure() throws {
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { try $0.reserveExternalLogicalBytes(UInt64.max, count: 2) }
    }
    try audit(traceAdapter())
}

@Test func preCopyCapacityFailurePrecedesAnyCopyWork() throws {
    var limits = JSONLimits.balanced; limits[.workUnits] = 0
    limits[.inputBytes] = UInt64(source.count - 1)
    let input = capture { _ = try JSON.withComposition(limits: limits) { try $0.parseDocument(source) } } as? JSONFailure
    #expect(input?.resource?.metric == .inputBytes && input?.resource?.attemptedUsage == UInt64(source.count))
    limits[.inputBytes] = UInt64(source.count); limits[.retainedBytes] = UInt64(source.count - 1)
    let bytes = capture { _ = try JSON.withComposition(limits: limits) { try $0.parseDocument(source) } } as? JSONFailure
    #expect(bytes?.resource?.metric == .retainedBytes && bytes?.resource?.attemptedUsage == UInt64(source.count))
}

@Test func sourceLexemesScalarKeysAndSpansArePreserved() throws {
    let report = try JSON.withComposition { try $0.parseDocument(source) }
    let doc = report.result; let ordinary = try JSONParser().parseDocument(source)
    #expect(doc.root == ordinary.root && doc.sourceBytes == source)
    #expect(doc.root.objectValue?["n"]?.numberValue?.originalLexeme == "9007199254740993")
    #expect(doc.root.objectValue?["adjacent"]?.numberValue?.originalLexeme == "9007199254740992")
    #expect(doc.root.objectValue?["long"]?.numberValue?.originalLexeme == "123456789012345678901234567890.01234567890123456789")
    #expect(doc.root.objectValue?["fraction"]?.numberValue?.originalLexeme == "0.01")
    #expect(doc.root.objectValue?["negative"]?.numberValue?.originalLexeme == "-0")
    #expect(doc.root.objectValue?["é"] == true && doc.root.objectValue?["e\u{301}"] == false)
    #expect(doc.sourceMap?.entries.count == ordinary.sourceMap?.entries.count)
    #expect(report.statistics[.numericWorkUnits] > 0 && report.statistics[.sourceMapEntries] > 0)
}

@Test func perDocumentInputBoundAndCumulativeResources() throws {
    let bytes = Data("null".utf8)
    var limits = JSONLimits.balanced; limits[.inputBytes] = 4
    let report = try JSON.withComposition(limits: limits) { scope in
        let entry = try scope.parseDocument(bytes)
        let a = try scope.parseDocument(bytes)
        let b = try scope.parseDocument(bytes)
        return (entry, a, b)
    }
    #expect(report.result.0.sourceBytes == bytes && report.result.1.sourceBytes == bytes && report.result.2.sourceBytes == bytes)
    #expect(report.statistics[.inputBytes] == 12)
    // Independent ownership lower bound: 3*(source+copy+node+map) + receipt.
    #expect(report.statistics[.retainedBytes] >= 3 * (8 + 32 + 32) + 424)
    limits[.inputBytes] = 3
    #expect(throws: JSONFailure.self) { try JSON.withComposition(limits: limits) { try $0.parseDocument(bytes) } }
}

@Test func emptyAndLongSourceRemainStrictAndBounded() throws {
    for bytes in [Data(), Data(" ".utf8), Data("null true".utf8)] {
        #expect(throws: JSONFailure.self) { try JSON.withComposition { try $0.parseDocument(bytes) } }
    }
    let bytes = Data(("\"" + String(repeating: "x", count: 8192) + "\"").utf8)
    let doc = try JSON.withComposition { try $0.parseDocument(bytes) }.result
    #expect(doc.sourceBytes == bytes && doc.root.stringValue?.utf8.count == 8192)
}

@Test func decodedDuplicateKeysStillFail() throws {
    let bytes = Data(#"{"é":0,"\u00e9":1}"#.utf8)
    #expect(throws: JSONFailure.self) { try JSON.withComposition { try $0.parseDocument(bytes) } }
}

@Test func nativePointerEscapesAndScalarIdentity() throws {
    try JSON.withComposition { scope in
        let doc = try scope.parseDocument(source)
        let root = try scope.pointer(parsing: "")
        #expect(try scope.resolve(root, in: doc.root) == doc.root)
        let path = try scope.pointer(tokens: ["a/b", "~"])
        #expect(try scope.resolve(path, in: doc.root) == .null)
        let scalar = try scope.pointer(uriFragment: "#/%C3%A9")
        #expect(try scope.resolve(scalar, in: doc.root) == true)
        let decomposed = try scope.appending(root, key: "e\u{301}")
        #expect(try scope.resolve(decomposed, in: doc.root) == false)
    }
}

@Test func nativePointerIndexAndPercentGrammarAreNotPermissive() throws {
    for text in ["/01", "/-", "/-1", "/999999999999999999999999"] {
        #expect(throws: JSONFailure.self) {
            try JSON.withComposition { scope in try scope.resolve(scope.pointer(parsing: text), in: .array([.null])) }
        }
    }
    for text in ["#/%", "#/%FF", "#/%7E2"] {
        #expect(throws: JSONFailure.self) { try JSON.withComposition { try $0.pointer(uriFragment: text) } }
    }
    let pointer = try JSON.withComposition { try $0.pointer(uriFragment: "#/%252F") }.result
    #expect(pointer.tokens.first?.string == "%2F")
}

@Test func nativeURICompositionUsesCoreRatherThanCompiledPlanQuota() throws {
    var limits = JSONLimits.balanced; limits[.compiledPlanBytes] = 0; limits[.compileWorkUnits] = 0
    let report = try JSON.withComposition(limits: limits) { scope in
        let base = try scope.uri("https://EXAMPLE.invalid/a/../api.json#part")
        let relative = try scope.uri("schemas.json#/n", relativeTo: base)
        let resource = try scope.removingFragment(relative)
        #expect(resource.string == "https://example.invalid/schemas.json")
        return relative
    }
    let ordinary = try JSONSchemaURI("schemas.json#/n", relativeTo: JSONSchemaURI("https://EXAMPLE.invalid/a/../api.json#part"))
    #expect(report.result == ordinary)
    #expect(report.statistics[.compiledPlanBytes] == 0 && report.statistics[.compileWorkUnits] == 0)
    #expect(report.statistics.domain == .core)
}

@Test func URIDataFailureIsStickyAndNeverFetches() throws {
    #expect(throws: (any Error).self) {
        try JSON.withComposition { scope in do { _ = try scope.uri("https://example.invalid/%ZZ") } catch { }; return 0 }
    }
}

@Test func acceptedInputHistorySurvivesRestriction() throws {
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            _ = try scope.parseDocument(source)
            var lower = JSONLimits.balanced; lower[.inputBytes] = UInt64(source.count - 1)
            do { try scope.restrict(to: lower) } catch { }
            return 0
        }
    }
}

@Test func independentNestedInvocationCannotRestoreOuterHealth() throws {
    var limits = JSONLimits.balanced; limits[.workUnits] = 0
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition(limits: limits) { outer in
            do { try outer.chargeExternalWork(1) } catch { }
            _ = try JSON.withComposition { _ in 0 }
            return 0
        }
    }
}

@Test func publicScopeCancellationCannotBeCaughtIntoSuccess() async throws {
    let task = Task.detached {
        try JSON.withComposition { scope in
            withUnsafeCurrentTask { $0?.cancel() }
            do { try scope.checkpoint() } catch is CancellationError { }
            return 9
        }
    }
    do { _ = try await task.value; Issue.record("cancelled scope finalized") } catch is CancellationError { }
}

@Test func firstQuotaCauseWinsOverLaterCancellation() async throws {
    let task = Task.detached {
        var limits = JSONLimits.balanced; limits[.workUnits] = 0
        return try JSON.withComposition(limits: limits) { scope in
            do { try scope.chargeExternalWork(1) } catch { }
            withUnsafeCurrentTask { $0?.cancel() }
            do { try scope.checkpoint() } catch { }
            return 9
        }
    }
    do { _ = try await task.value; Issue.record("terminal scope finalized") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .workUnits && failure.resource?.attemptedUsage == 1) }
}

@Test func independentConcurrentSessionsHaveDeterministicReports() async throws {
    try await withThrowingTaskGroup(of: JSONOperationStatistics.self) { group in
        for _ in 0..<16 { group.addTask { try traceAdapter().statistics } }
        for try await report in group { #expect(report[.workUnits] == goldenWork && report.peakLogicalRetainedBytes == goldenBytes) }
    }
}

@Test func callerErrorsAndForgedReportsAreNotCertificates() throws {
    #expect(throws: AuditError.self) { try JSON.withComposition { _ in throw AuditError.caller } }
    let genuine = try traceAdapter()
    let forged = JSONOperationReport(result: "not the audited result", statistics: genuine.statistics)
    #expect(forged.result == "not the audited result")
    #expect(forged.statistics[.workUnits] == goldenWork)
}


@Test func multiResourceSourceAndFinalOutputOverlap() throws {
    // Independent native weight ledger for each scalar document:
    // 4 copied bytes + 4 preserved source bytes + 32 value + 32 source-map entry.
    // All three documents remain in the returned tuple, alongside two buffers.
    // 3*72 + (64+32) + (48+32) + 424 report = 816 logical bytes.
    let expected: UInt64 = 816
    for ceiling in [expected, expected - 1] {
        var limits = JSONLimits.balanced; limits[.inputBytes] = 4; limits[.retainedBytes] = ceiling
        do {
            let report = try JSON.withComposition(limits: limits) { scope in
                let entry = try scope.parseDocument(Data("null".utf8))
                let resourceA = try scope.parseDocument(Data("null".utf8))
                let resourceB = try scope.parseDocument(Data("null".utf8))
                let queue = try fill(scope, count: 64, first: false, mutation: nil)
                let output = try fill(scope, count: 48, first: false, mutation: nil)
                return (entry, resourceA, resourceB, queue, output)
            }
            #expect(ceiling == expected)
            #expect(report.statistics[.retainedBytes] == expected)
            #expect(report.statistics.peakLogicalRetainedBytes == expected)
            #expect(report.result.0.sourceBytes == Data("null".utf8) && report.result.4.count == 48)
        } catch let failure as JSONFailure {
            #expect(ceiling == expected - 1 && failure.resource?.metric == .retainedBytes)
            #expect(failure.resource?.attemptedUsage == expected)
        }
    }
}
