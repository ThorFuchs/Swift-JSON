// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing

private func rootLookups(_ value: JSON, count: Int, limits: JSONLimits = .balanced) throws -> JSONOperationReport<Int> {
    try JSON.withComposition(limits: limits) { scope in
        let pointer = try scope.pointer(tokens: ["0"])
        return try scope.withAdmittedRoot(value) { root in
            for _ in 0..<count { _ = try scope.resolve(pointer, in: root) }
            return count
        }
    }
}

private func observeRootCancellation(_ scope: borrowing JSONCompositionScope) throws {
    try scope.withMeter { meter in
        let threshold = meter.used(.workUnits) + 32
        meter.checkpointObserver = { work in
            if work >= threshold { withUnsafeCurrentTask { $0?.cancel() } }
        }
    }
}

@Test func compositionRootAdmissionIsOnceAndPlainOverloadRemainsConservative() throws {
    let value = JSON.array(Array(repeating: .null, count: 50_000))
    let zero = try rootLookups(value, count: 0)
    let one = try rootLookups(value, count: 1)
    let two = try rootLookups(value, count: 2)
    let many = try rootLookups(value, count: 1_000)
    #expect(many.result == 1_000)
    #expect(zero.statistics[.nodes] == 50_001)
    #expect(many.statistics[.nodes] == 51_001)
    #expect(many.statistics[.workUnits] == zero.statistics[.workUnits] + 1_000 * (one.statistics[.workUnits] - zero.statistics[.workUnits]))
    #expect(two.statistics[.retainedBytes] - one.statistics[.retainedBytes] == one.statistics[.retainedBytes] - zero.statistics[.retainedBytes])
    #expect(many.statistics[.retainedBytes] < 3_000_000)
    // The arbitrary-JSON overload still cannot presume prior admission.
    do {
        _ = try JSON.withComposition { scope in
            let admitted = try scope.admitTrusted(value)
            let pointer = try scope.pointer(tokens: ["0"])
            for _ in 0..<19 { _ = try scope.resolve(pointer, in: admitted) }
        }
        Issue.record("plain root unexpectedly bypassed repeated admission")
    } catch let failure as JSONFailure {
        #expect(failure.resource?.metric == .nodes)
        #expect(failure.resource?.attemptedUsage == 1_000_001)
    }
}

@Test func compositionRootParsedDocumentSharesAdmissionAndExactSnapshot() throws {
    let data = Data(#"{"é":9007199254740993,"e\u0301":0.01}"#.utf8)
    let ordinary = try JSON.withComposition { try $0.parseDocument(data) }
    let parsed = try JSON.withComposition { scope in
        try scope.withParsedDocument(data) { document, root in
            let number = try scope.resolve(scope.pointer(tokens: ["é"]), in: root)
            let fraction = try scope.resolve(scope.pointer(tokens: ["e\u{301}"]), in: root)
            #expect(number.numberValue?.originalLexeme == "9007199254740993")
            #expect(fraction.numberValue?.originalLexeme == "0.01")
            return document
        }
    }
    #expect(parsed.result.sourceBytes == data)
    #expect(parsed.result.sourceMap?.entries.count == ordinary.result.sourceMap?.entries.count)
    #expect(parsed.statistics[.nodes] == ordinary.statistics[.nodes] + 2)
    var callerValue = JSON.array([.boolean(true)])
    _ = try JSON.withComposition { scope in
        try scope.withAdmittedRoot(callerValue) { root in
            callerValue = .null
            let selected = try scope.resolve(scope.pointer(tokens: ["0"]), in: root)
            #expect(selected == true)
        }
    }
    #expect(callerValue == .null)
}

@Test func compositionRootThresholdsAndTerminalFailures() throws {
    let value = JSON.array(Array(repeating: .null, count: 32))
    let probe = try rootLookups(value, count: 8)
    var limits = JSONLimits.balanced
    limits[.workUnits] = probe.statistics[.workUnits]
    limits[.retainedBytes] = probe.statistics.peakLogicalRetainedBytes
    #expect(try rootLookups(value, count: 8, limits: limits).statistics == probe.statistics)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var below = limits
        below[metric] -= 1
        #expect(throws: JSONFailure.self) { try rootLookups(value, count: 8, limits: below) }
    }
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition { scope in
            try scope.withAdmittedRoot(value) { root in
                do { _ = try scope.resolve(scope.pointer(tokens: ["99"]), in: root) } catch { }
                return 0
            }
        }
    }
}

@Test func compositionRootOwnerIdentityAndNestedRoots() throws {
    let report = try JSON.withComposition { outer in
        let pointer = try outer.pointer(tokens: ["0"])
        return try outer.withAdmittedRoot(.array([true])) { root in
            do {
                _ = try JSON.withComposition { inner in
                    do { _ = try inner.resolve(pointer, in: root) } catch let failure as JSONFailure {
                        #expect(failure.category == .configuration)
                        #expect(failure.code == .invalidOperation)
                    }
                    return 0
                }
                Issue.record("caught wrong-owner failure finalized")
            } catch let failure as JSONFailure { #expect(failure.code == .invalidOperation) }
            try outer.withAdmittedRoot(.array([false])) { other in
                let innerValue = try outer.resolve(pointer, in: other)
                let outerValue = try outer.resolve(pointer, in: root)
                #expect(innerValue == false)
                #expect(outerValue == true)
            }
            return try outer.resolve(pointer, in: root)
        }
    }
    #expect(report.result == true)
    #expect(report.statistics[.nodes] == 7) // Two roots and three selected scalars.
}

@Test func compositionRootOutputReservationsAndDeadHandlesStayCharged() throws {
    let value = JSON.array([.null, .null])
    let admitted = try JSON.withComposition { scope in try scope.withAdmittedRoot(value) { _ in 0 } }
    let selected = try JSON.withComposition { scope in
        let pointer = try scope.pointer(tokens: [])
        return try scope.withAdmittedRoot(value) { root in try scope.resolve(pointer, in: root) }
    }
    let graphBytes = try JSON.withComposition { try $0.admitTrusted(value) }.statistics[.retainedBytes]
    #expect(selected.statistics[.retainedBytes] == admitted.statistics[.retainedBytes] + graphBytes)
    #expect(selected.statistics[.nodes] == 6)
    var below = JSONLimits.balanced
    below[.retainedBytes] = admitted.statistics[.retainedBytes]
    #expect(throws: JSONFailure.self) {
        try JSON.withComposition(limits: below) { scope in
            _ = try scope.withAdmittedRoot(value) { _ in 0 }
            // Ending the handle callback cannot refund the reserved graph/slot.
            try scope.reserveExternalLogicalBytes(1)
        }
    }
    let aliases = try JSON.withComposition { scope in
        _ = try scope.withAdmittedRoot(value) { _ in 0 }
        return try scope.withAdmittedRoot(value) { _ in 0 }
    }
    #expect(aliases.statistics[.retainedBytes] == admitted.statistics[.retainedBytes] * 2)
}

@Test func compositionRootRestrictionsRememberAdmission() throws {
    for metric in [JSONResourceMetric.nodes, .retainedBytes, .maxDepth] {
        #expect(throws: JSONFailure.self) {
            try JSON.withComposition { scope in
                _ = try scope.withAdmittedRoot(.array([.null])) { _ in 0 }
                var smaller = JSONLimits.balanced
                smaller[metric] = 0
                do { try scope.restrict(to: smaller) } catch { }
                return 0
            }
        }
    }
    enum CallerFailure: Error { case expected }
    #expect(throws: CallerFailure.self) {
        try JSON.withComposition { scope in
            try scope.withAdmittedRoot(.null) { _ in throw CallerFailure.expected }
        }
    }
}

@Test func compositionRootCancellationIsTerminal() async throws {
    for duringSelection in [false, true] {
        let task = Task.detached {
            _ = try JSON.withComposition { scope in
                let value = JSON.array(Array(repeating: .null, count: 4_096))
                if !duringSelection { try observeRootCancellation(scope) }
                do {
                    try scope.withAdmittedRoot(value) { root in
                        if duringSelection { try observeRootCancellation(scope) }
                        do { _ = try scope.resolve(scope.pointer(tokens: []), in: root) } catch is CancellationError { }
                    }
                } catch is CancellationError { }
                return 0
            }
        }
        do { try await task.value; Issue.record("cancelled admitted root finalized") }
        catch is CancellationError { }
    }
}

@Test func compositionRootIndependentScopesCanBeSharedAcrossTasks() async throws {
    let value = JSON.array(Array(repeating: .null, count: 256))
    let expected = try rootLookups(value, count: 64).statistics
    try await withThrowingTaskGroup(of: JSONOperationStatistics.self) { group in
        for _ in 0..<16 { group.addTask { try rootLookups(value, count: 64).statistics } }
        for try await statistics in group { #expect(statistics == expected) }
    }
}
