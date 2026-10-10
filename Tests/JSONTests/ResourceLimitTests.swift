// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import Synchronization
import Dispatch
@testable import JSON

@Test(arguments: [UInt64(2), 3, 4])
func inclusiveAdmission(attempt: UInt64) throws {
    var limits = JSONLimits.balanced
    limits[.nodes] = 3
    var meter = try JSONWorkMeter(limits: limits, domain: .parsing)
    do {
        try meter.charge(.nodes, attempt)
        #expect(attempt <= 3)
        #expect(meter.used(.nodes) == attempt)
    } catch let failure as JSONFailure {
        #expect(attempt == 4)
        #expect(failure.resource?.metric == .nodes)
        #expect(failure.resource?.attemptedUsage == 4)
        #expect(meter.used(.nodes) == 0)
    }
}

@Test func overflowIsStructured() throws {
    let meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    do {
        _ = try meter.adding(.nodes, UInt64.max, 1)
        Issue.record("Overflow must throw")
    } catch let failure as JSONFailure {
        #expect(failure.code == .counterOverflow)
        #expect(failure.resource?.overflow == true)
        #expect(failure.resource?.attemptedUsage == nil)
    }
}

@Test func refundsPreserveWorkAndPeak() throws {
    var limits = JSONLimits.balanced
    limits[.retainedBytes] = 10
    var meter = try JSONWorkMeter(limits: limits, domain: .core)
    try meter.retain(10)
    try meter.work(5)
    try meter.release(10)
    try meter.retain(7)
    let stats = meter.statistics()
    #expect(stats[.retainedBytes] == 7)
    #expect(stats[.workUnits] == 5)
    #expect(stats.peakLogicalRetainedBytes == 10)
    #expect(stats.accountingVersion == 1)
}

@Test func nestedWorkUsesOneCumulativeBudget() throws {
    func child(_ meter: inout JSONWorkMeter) throws { try meter.work(3, subsystem: .numericWorkUnits) }
    var limits = JSONLimits.balanced
    limits[.patchWorkUnits] = 5
    var meter = try JSONWorkMeter(limits: limits, domain: .patch)
    try child(&meter)
    do {
        try child(&meter)
        Issue.record("Nested helper must exhaust the parent budget")
    } catch let failure as JSONFailure {
        #expect(failure.resource?.metric == .patchWorkUnits)
        #expect(meter.used(.workUnits) == 3)
        #expect(meter.used(.numericWorkUnits) == 3)
    }
}

@Test(arguments: [UInt64(0), 1025, UInt64.max])
func invalidCancellationConfiguration(quantum: UInt64) {
    var limits = JSONLimits.balanced
    limits[.cancellationQuantum] = quantum
    #expect(throws: JSONFailure.self) { try limits.validate() }
}

@Test func cancelledEntryUsesCancellationError() async {
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        _ = try JSONWorkMeter(limits: .balanced, domain: .core)
    }
    task.cancel()
    do { try await task.value; Issue.record("Cancelled entry must throw") }
    catch { #expect(error is CancellationError) }
}

private final class OwnedCancellationProgress: Sendable {
    let ready = Mutex(false)
    let resume = DispatchSemaphore(value: 0)
    func checkpoint(_ work: UInt64) {
        guard work >= 4096 else { return }
        let rendezvous = ready.withLock { ready in
            if ready { return false }; ready = true; return true
        }
        if rendezvous { resume.wait() }
    }
}

@Test func cancellationReachesOwnedWork() async throws {
    // Returning the interrupted meter's counters proves cancellation happened
    // after real owned numeric/lexer work, rather than only at a facade entry.
    for numeric in [true,false] {
        let progress = OwnedCancellationProgress()
        let bytes = numeric ? Array(repeating: UInt8(55),count: 4_000_000) : [34] + Array(repeating: UInt8(97),count: 4_000_000) + [34]
        let task = Task.detached { () throws -> UInt64 in
            var limits = JSONLimits.offline
            limits[.cancellationQuantum] = 1
            limits[.numberDigits] = 4_000_000; limits[.numberTokenBytes] = 4_000_000
            limits[.numericWorkUnits] = 200_000_000; limits[.workUnits] = 200_000_000
            var meter = try JSONWorkMeter(limits: limits,domain: numeric ? .core : .parsing)
            meter.checkpointObserver = { progress.checkpoint($0) }
            do {
                if numeric { _ = try JSONNumber.parse(bytes,meter: &meter) }
                else { _ = try JSONParser().parse(bytes,meter: &meter) }
            } catch is CancellationError {
                return meter.used(numeric ? .numericWorkUnits : .inputBytes)
            }
            return 0
        }
        while !progress.ready.withLock({ $0 }) { await Task.yield() }
        task.cancel(); progress.resume.signal()
        let charged = try await task.value
        print("Inner cancellation \(numeric ? "number" : "codec"): \(charged) charged units")
        #expect(charged > 1024)
    }
}

@Test func everyResourcePolicyMatchesNativeProfilesAndInclusiveOverflowBoundaries() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let policy = try JSONParser().parse(Data(contentsOf: root.appendingPathComponent("Documentation/Architecture/ResourceProfiles.json"))).objectValue!
    var observed: Set<JSONResourceMetric> = []
    for section in policy {
        guard let rows = section.value.arrayValue else { continue }
        for row in rows {
            guard let fields = row.objectValue,let name = (fields["metric"] ?? fields["id"])?.stringValue else { continue }
            let metric = try #require(JSONResourceMetric(rawValue: name))
            #expect(observed.insert(metric).inserted)
            for (profile,column) in [(JSONLimits.conservative,"conservative"),(JSONLimits.balanced,"balanced"),(JSONLimits.offline,"offline")] {
                let limit = try #require(fields[column]?.numberValue).integer(as: UInt64.self)
                #expect(profile[metric] == limit && limit > 0 && limit < UInt64(Int.max))
                let meter = try JSONWorkMeter(limits: profile,domain: .core)
                #expect(try meter.adding(metric,limit-1,1) == limit)
                do { _ = try meter.adding(metric,limit,1); Issue.record("Inclusive ceiling exceeded: \(name)") }
                catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == metric && failure.resource?.attemptedUsage == limit+1) }
                do { _ = try meter.adding(metric,UInt64.max,1); Issue.record("Counter wrapped: \(name)") }
                catch let failure as JSONFailure { #expect(failure.resource?.overflow == true && failure.resource?.attemptedUsage == nil) }
            }
        }
    }
    #expect(observed.count == 49 && observed == Set(JSONResourceMetric.allCases))
}
