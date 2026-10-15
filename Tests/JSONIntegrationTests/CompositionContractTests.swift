// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import Testing

private let compositionInput = Data(##"{"é":true,"e\u0301":false,"n":9007199254740993,"fraction":0.01,"type":["string","integer"],"$schema":"https://unknown.invalid/dialect","refs":[{"$ref":"#/n"},{"$ref":"#/fraction"}]}"##.utf8)

private struct CompositionFixture {
    let source: JSONDocument
    let resource: JSONDocument
    let targets: [JSON]
}
private let compositionResource = Data(#"{"type":"integer"}"#.utf8)

private func composedImport(limits: JSONLimits = .balanced, extra: UInt64 = 0) throws -> JSONOperationReport<CompositionFixture> {
    try JSON.withComposition(limits: limits) { scope in
        let document = try scope.parseDocument(compositionInput)
        let resource = try scope.parseDocument(compositionResource)
        _ = try scope.admitTrusted(.boolean(true))
        try scope.reserveExternalLogicalBytes(64, count: 3) // Result, descriptors, diagnostics.
        try scope.chargeExternalWork(7 + extra)
        let base = try scope.uri("https://EXAMPLE.invalid/a/../api.json#root")
        let relative = try scope.uri("schemas.json#/n", relativeTo: base)
        _ = try scope.removingFragment(relative)
        try scope.reserveExternalLogicalBytes(16, count: 2)
        var targets: [JSON] = []
        let refs = try scope.pointer(tokens: ["refs"])
        for index in ["0", "1"] {
            let item = try scope.appending(refs, key: index)
            let ref = try scope.appending(item, key: "$ref")
            let spelling = try scope.resolve(ref, in: document.root).stringValue!
            let target = try scope.pointer(uriFragment: spelling)
            targets.append(try scope.resolve(target, in: document.root))
        }
        return CompositionFixture(source: document, resource: resource, targets: targets)
    }
}

@Test func composedWorkThresholdAndOneAdditionalUnit() throws {
    let probe = try composedImport()
    #expect(probe.statistics.accountingVersion == 1)
    #expect(probe.statistics.domain == .core)
    #expect(probe.statistics[.numericWorkUnits] > 0)
    #expect(probe.statistics[.numericWorkUnits] < probe.statistics[.workUnits])
    var exact = JSONLimits.balanced
    exact[.workUnits] = probe.statistics[.workUnits]
    #expect(try composedImport(limits: exact).statistics == probe.statistics)
    #expect(throws: JSONFailure.self) { try composedImport(limits: exact, extra: 1) }
    exact[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { try composedImport(limits: exact) }
    let charged = try composedImport(extra: 1)
    #expect(charged.statistics[.workUnits] == probe.statistics[.workUnits] + 1)
    #expect(charged.statistics[.numericWorkUnits] == probe.statistics[.numericWorkUnits])
}

@Test func caughtOperationalFailureCannotComplete() throws {
    var zero = JSONLimits.balanced
    zero[.workUnits] = 0
    do {
        _ = try JSON.withComposition(limits: zero) { scope in
            do { try scope.chargeExternalWork(1) } catch { }
            do { try scope.reserveExternalLogicalBytes(0) } catch { }
            return 42
        }
        Issue.record("caught quota produced success")
    } catch let failure as JSONFailure {
        #expect(failure.category == .resource)
        #expect(failure.resource?.attemptedUsage == 1)
        #expect(failure.resource?.metric == .workUnits)
    }
}

@Test func composedRetentionAndURIUseSameScope() throws {
    let probe = try composedImport()
    let peak = probe.statistics.peakLogicalRetainedBytes
    #expect(peak > UInt64(compositionInput.count * 2 + 192))
    #expect(probe.statistics[.retainedBytes] > UInt64(compositionInput.count * 2 + 192))
    var exact = JSONLimits.balanced
    exact[.retainedBytes] = peak
    #expect(try composedImport(limits: exact).statistics == probe.statistics)
    exact[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try composedImport(limits: exact) }

    // Two reservations with disjoint local lifetimes still overlap the result in
    // the monotone ledger. Refunding an alias or summing independent stage peaks
    // would incorrectly accept the following N-1 threshold.
    let one = try JSON.withComposition { scope in try scope.reserveExternalLogicalBytes(64); return 0 }
    let two = try JSON.withComposition { scope in
        try scope.reserveExternalLogicalBytes(64)
        try scope.reserveExternalLogicalBytes(64)
        return 0
    }
    #expect(two.statistics.peakLogicalRetainedBytes == 128)
    #expect(two.statistics[.retainedBytes] == 128)
    #expect(one.statistics.peakLogicalRetainedBytes == 64)
    var belowOverlap = JSONLimits.balanced
    belowOverlap[.retainedBytes] = 127
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition(limits: belowOverlap) { scope in
            try scope.reserveExternalLogicalBytes(64)
            try scope.reserveExternalLogicalBytes(64)
            return 0
        }
    }
    #expect(try JSON.withComposition { try $0.admitTrusted(.null) }.statistics[.retainedBytes] == 32)
    // Independent stage peaks are not a composition oracle: the parser's scratch
    // peak and a later URI peak need not be simultaneously live.
    let parse = try JSON.withComposition { try $0.parseDocument(compositionInput) }
    let uri = try JSON.withComposition { try $0.uri("https://example.invalid/a") }
    let combined = try JSON.withComposition { scope in
        let document = try scope.parseDocument(compositionInput)
        _ = try scope.uri("https://example.invalid/a")
        return document
    }
    #expect(combined.statistics.peakLogicalRetainedBytes != parse.statistics.peakLogicalRetainedBytes + uri.statistics.peakLogicalRetainedBytes)
}

@Test func compositionExactSourceAndNativeErrors() throws {
    let result = try composedImport().result
    let document = result.source
    #expect(result.resource.sourceBytes == compositionResource)
    #expect(result.targets.count == 2)
    #expect(document.sourceBytes == compositionInput)
    #expect(document.root.objectValue?["é"] == true)
    #expect(document.root.objectValue?["e\u{301}"] == false)
    #expect(document.root.objectValue?["n"]?.numberValue?.originalLexeme == "9007199254740993")
    #expect(document.root.objectValue?["fraction"]?.numberValue?.originalLexeme == "0.01")
    #expect(document.root.objectValue?["type"]?.arrayValue?.count == 2)
    #expect(document.root.objectValue?["$schema"]?.stringValue == "https://unknown.invalid/dialect")
    do {
        _ = try JSON.withComposition { scope in
            let pointer = try scope.pointer(parsing: "/01")
            return try scope.resolve(pointer, in: .array([.null]))
        }
        Issue.record("invalid array index accepted")
    } catch let error as JSONFailure {
        #expect(error.category == .pointer)
        #expect(error.code == .invalidIndex)
    }
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            do { _ = try scope.parseDocument(Data("{".utf8)) } catch { }
            return 1
        }
    }
}

@Test func compositionInputAndCopyAdmissionBeforeAllocation() throws {
    for cap in [UInt64(0), UInt64(compositionInput.count - 1)] {
        var limits = JSONLimits.balanced
        limits[.inputBytes] = cap
        #expect(throws: JSONFailure.self) {
            try JSON.withComposition(limits: limits) { try $0.parseDocument(compositionInput) }
        }
    }
    var exact = JSONLimits.balanced
    exact[.inputBytes] = UInt64(compositionInput.count)
    _ = try JSON.withComposition(limits: exact) { try $0.parseDocument(compositionInput) }
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition(limits: exact) { try $0.parseDocument(compositionInput + Data([32])) }
    }
    exact[.retainedBytes] = UInt64(compositionInput.count - 1)
    do {
        _ = try JSON.withComposition(limits: exact) { try $0.parseDocument(compositionInput) }
        Issue.record("copy reservation accepted")
    } catch let error as JSONFailure {
        #expect(error.resource?.metric == .retainedBytes)
        #expect(error.resource?.attemptedUsage == UInt64(compositionInput.count))
    }
}

@Test func compositionMonotoneAliasesAndNoPlanPollution() throws {
    let root = try JSONParser().parse(#"{"a":[1,2,3]}"#)
    let one = try JSON.withComposition { try $0.admitTrusted(root) }
    let two = try JSON.withComposition { scope in
        let alias = try scope.admitTrusted(root)
        _ = try scope.admitTrusted(alias)
        return alias
    }
    #expect(two.statistics[.retainedBytes] == one.statistics[.retainedBytes] * 2)
    var limits = JSONLimits.balanced
    limits[.compiledPlanBytes] = 0
    limits[.compileWorkUnits] = 0
    let report = try JSON.withComposition(limits: limits) { scope in
        _ = try scope.uri("https://example.invalid/a#b")
        try scope.reserveExternalLogicalBytes(128)
    }
    #expect(report.statistics[.compiledPlanBytes] == 0)
    #expect(report.statistics[.compileWorkUnits] == 0)
    #expect(report.statistics[.workUnits] > 0)
}

@Test func compositionCheckedArithmeticAndStickyUnderflow() throws {
    for multiply in [false, true] {
        #expect(throws: JSONFailure.self) {
            try JSON.withComposition { scope in
                do {
                    if multiply { try scope.reserveExternalLogicalBytes(UInt64.max, count: 2) }
                    else { try scope.chargeExternalWork(1); try scope.chargeExternalWork(UInt64.max) }
                } catch let failure as JSONFailure { #expect(failure.code == .counterOverflow) }
                return 1
            }
        }
    }
    // A package-owned invariant error must also latch at the facade boundary.
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            do { try scope.withMeter { try $0.release(1) } } catch { }
            return 1
        }
    }
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            try scope.reserveExternalLogicalBytes(8)
            do { try scope.reserveExternalLogicalBytes(UInt64.max) } catch let failure as JSONFailure {
                #expect(failure.code == .counterOverflow)
            }
            return 1
        }
    }
}

@Test func compositionRestrictionPreservesCapacityHistory() throws {
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            _ = try scope.parseDocument(compositionInput)
            var smaller = JSONLimits.balanced
            smaller[.inputBytes] = UInt64(compositionInput.count - 1)
            do { try scope.restrict(to: smaller) } catch { }
            return 1
        }
    }
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            var invalid = JSONLimits.balanced
            invalid[.cancellationQuantum] = 0
            do { try scope.restrict(to: invalid) } catch { }
            return 1
        }
    }
}

@Test func compositionCancellationInsideOwnedScansIsSticky() async throws {
    for stage in 0..<6 {
        let task = Task.detached { () throws -> Int in
            var limits = JSONLimits.offline
            limits[.cancellationQuantum] = 16
            _ = try JSON.withComposition(limits: limits) { scope in
                try scope.withMeter { meter in
                    meter.checkpointObserver = { work in
                        if work >= (stage == 5 ? 4200 : 32) { withUnsafeCurrentTask { $0?.cancel() } }
                    }
                }
                do {
                    switch stage {
                    case 0, 5: _ = try scope.parseDocument(Data(("\"" + String(repeating: "a", count: 4096) + "\"").utf8))
                    case 1: _ = try scope.pointer(parsing: "/" + String(repeating: "a", count: 4096))
                    case 2: _ = try scope.uri("https://example.invalid/" + String(repeating: "a", count: 4096))
                    case 3: _ = try scope.admitTrusted(.string(String(repeating: "a", count: 4096)))
                    default:
                        for _ in 0..<4096 { try scope.chargeExternalWork(1); try scope.reserveExternalLogicalBytes(1) }
                    }
                    Issue.record("scan completed after deterministic native cancellation")
                } catch is CancellationError { }
                return 42
            }
            return 42
        }
        do { _ = try await task.value; Issue.record("caught cancellation finalized") }
        catch is CancellationError { }
    }
}

@Test func compositionIndependentScopesCanBeSharedAcrossTasks() async throws {
    let expected = try composedImport().statistics
    try await withThrowingTaskGroup(of: JSONOperationStatistics.self) { group in
        for _ in 0..<16 { group.addTask { try composedImport().statistics } }
        for try await statistics in group { #expect(statistics == expected) }
    }
}

@Test func compositionCallerErrorAndReportProvenance() throws {
    enum CallerError: Error { case intentional }
    #expect(throws: CallerError.self) { try JSON.withComposition { _ in throw CallerError.intentional } }
    do {
        _ = try JSON.withComposition { scope in
            do { try scope.chargeExternalWork(UInt64.max) } catch { }
            throw CallerError.intentional
        }
        Issue.record("caller error concealed native failure")
    } catch let failure as JSONFailure { #expect(failure.category == .resource) }
    let genuine = try JSON.withComposition { scope in try scope.chargeExternalWork(3); return "original" }
    let forged = JSONOperationReport(result: "substituted", statistics: genuine.statistics)
    #expect(forged.result != genuine.result)
    #expect(forged.statistics == genuine.statistics) // Type alone supplies no provenance.
}

@Test func compositionNestedScopesHaveExplicitIndependentBudgets() throws {
    let report = try JSON.withComposition { outer in
        try outer.chargeExternalWork(3)
        let inner = try JSON.withComposition { inner in
            try inner.chargeExternalWork(5)
            return 0
        }
        #expect(inner.statistics[.workUnits] == 5)
        return 0
    }
    #expect(report.statistics[.workUnits] == 3)
    // Substitution of the borrowed facade is rejected by the external compiler
    // fixture Substitute.swift.txt, including swap/use/restore. Independent
    // nested invocations are explicitly outside the outer report's claim.
}
