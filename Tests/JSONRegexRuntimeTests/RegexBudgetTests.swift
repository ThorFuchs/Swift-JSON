// SPDX-License-Identifier: Apache-2.0
import Testing
#if canImport(os)
import os
#else
import Synchronization
#endif
#if canImport(Dispatch)
import Dispatch
#endif
import JSON
@testable import JSONRegexRuntime

@Test func adversarialRegexPathsExhaustWorkInsteadOfReturningInvalidity() throws {
    var limits = JSONLimits.balanced; limits[.regexSearchWorkUnits] = 10_000
    for pattern in ["^(a+)+$", "^(a|aa)+$", "^(?:(?=a)a?)*b$", #"^(a+)\1+$"#] {
        var meter = try JSONWorkMeter(limits: limits, domain: .schemaEvaluation)
        let program = try RegexCompiler.compile(pattern, meter: &meter)
        #expect(throws: JSONFailure.self) { try program.search(String(repeating: "a", count: 1_000) + "!", meter: &meter) }
    }
}
@Test func regexStateCaptureAndGrammarGrowthAreAdmittedBeforeAllocation() throws {
    var limits = JSONLimits.balanced; limits[.regexCaptureGroups] = 1
    var captures = try JSONWorkMeter(limits: limits, domain: .regex)
    #expect(throws: JSONFailure.self) { try RegexCompiler.compile("(a)(b)", meter: &captures) }
    limits = .balanced; limits[.maxDepth] = 3
    var grammar = try JSONWorkMeter(limits: limits, domain: .regex)
    #expect(throws: JSONFailure.self) { try RegexCompiler.compile("((((a))))", meter: &grammar) }
    limits = .balanced; limits[.regexRetainedBytes] = 200
    var states = try JSONWorkMeter(limits: limits, domain: .regex)
    let program = try RegexCompiler.compile("^(a|aa)+b$", meter: &states)
    #expect(throws: JSONFailure.self) { try program.search("aaaaaa!", meter: &states) }
}
#if canImport(Dispatch)
private final class RegexCancellationProgress: Sendable {
    #if canImport(os)
    let ready = OSAllocatedUnfairLock(initialState: false)
    #else
    let ready = Mutex(false)
    #endif
    let resume = DispatchSemaphore(value: 0)
    func checkpoint(_ work: UInt64) {
        guard work >= 4096 else { return }
        let rendezvous = ready.withLock { ready in
            if ready { return false }; ready = true; return true
        }
        if rendezvous { resume.wait() }
    }
}

#endif

@Test func countedRepetitionHasBoundedProgramSizeAndCancellationIsObservable() async throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    let program = try RegexCompiler.compile("a{1000000000000}", meter: &meter)
    #expect(program.instructions.count < 10)
    #expect(try !program.search("aaa", meter: &meter))
    let pathological = try RegexCompiler.compile("^(a+)+$",meter: &meter)
    #if canImport(Dispatch)
    let progress = RegexCancellationProgress()
    #endif
    let cancelled = Task.detached { () throws -> UInt64 in
        var limits = JSONLimits.offline
        limits[.regexSearchWorkUnits] = 1_000_000_000; limits[.evaluationWorkUnits] = 1_000_000_000
        limits[.workUnits] = 1_000_000_000
        var invocation = try JSONWorkMeter(limits: limits,domain: .regex)
        #if canImport(Dispatch)
        invocation.checkpointObserver = { progress.checkpoint($0) }
        #else
        invocation.checkpointObserver = { if $0 >= 4096 { withUnsafeCurrentTask { $0?.cancel() } } }
        #endif
        do { _ = try pathological.search(String(repeating: "a",count: 1_000)+"!",meter: &invocation) }
        catch is CancellationError { return invocation.used(.regexSearchWorkUnits) }
        return 0
    }
    #if canImport(Dispatch)
    while !progress.ready.withLock({ $0 }) { await Task.yield() }
    cancelled.cancel(); progress.resume.signal()
    #endif
    let charged = try await cancelled.value
    print("Inner cancellation regex: \(charged) charged search units")
    #expect(charged > 1024)
}
