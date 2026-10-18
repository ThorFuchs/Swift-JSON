// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

/// One exact output plus its invocation-owned source reservation.
///
/// Keep this handle while using the accounted alias. JSON copied out of `value`
/// is caller-owned storage. The handle is deliberately not Sendable.
public struct JSONTransformOutput {
    /// The exact native result; null is a legitimate value, never EOF.
    public let value: JSON
    private let lease: TransformValueLease?
    init(_ value: FilterYield) { self.value = value.value; lease = value.lease }
}

// A separate invocation-owned cell is safe to inspect while the VM exclusively
// borrows its context. It is never Sendable and never owns the execution handle.
private final class ExecutionHealth {
    struct Observation {
        let statistics: JSONOperationStatistics
        let remaining: UInt64
        let counters: [UInt64]
    }
    var pulling = false
    var failure: JSONTransformFailure?
    var observation: Observation?
    func latch(_ failure: JSONTransformFailure) {
        if self.failure == nil { self.failure = failure }
    }
    func check(context: inout TransformRuntimeContext) throws {
        if let failure { context.latch(failure); throw failure }
    }
    func observe(context: inout TransformRuntimeContext) throws {
        // Fixed snapshot work/storage is admitted before invoking caller code.
        try context.work(66) // 49 native counters + 16 runtime counters + handoff.
        let cap = min(context.limits.core[.workUnits], context.limits[.totalWorkUnits])
        observation = .init(statistics: context.meter.statistics(),
                            remaining: cap - min(cap, context.used(.totalWorkUnits)),
                            counters: TransformRuntimeMetric.allCases.map { context.used($0) })
    }
}

private struct SuppliedInput: FilterInput {
    var source: (() throws -> JSON?)?
    let health: ExecutionHealth
    var ended = false
    mutating func next(context: inout TransformRuntimeContext) throws -> FilterYield? {
        try health.check(context: &context)
        try context.checkpoint()
        guard !ended, let source else { return nil }
        try health.observe(context: &context)
        defer { health.observation = nil }
        let value: JSON?
        do { value = try source() }
        catch {
            let proposed = error is CancellationError ? JSONTransformFailure(.cancelled, "cancelled") : JSONTransformFailure(.provider, "providerFailed")
            health.latch(proposed)
            try health.check(context: &context)
            throw proposed
        }
        // Re-entry/cancel may have been caught inside the callback. Neither may
        // reopen the ledger, publish a returned value or pull the provider again.
        try health.check(context: &context)
        try context.checkpoint() // Task cancellation after caller-owned work.
        guard let value else { ended = true; self.source = nil; return nil }
        try context.charge(.totalRecords)
        return try FilterValues.produced(value, context: &context)
    }
}

/// A guarded, non-Sendable pull handle borrowed by one synchronous scope.
///
/// Copies share one invocation and cannot reset its cumulative meter. Scope exit
/// releases the provider and VM and invalidates data access through escaped
/// handles. Reports remain observable. Only immutable plans are Sendable.
public final class JSONTransformExecution {
    private var context: TransformRuntimeContext
    private var vm: FilterVM?
    private var input: SuppliedInput
    private var planReservation: UInt64 = 0
    private var bindingReservation: UInt64 = 0
    private var initialBindings: UInt64 = 0
    private let health: ExecutionHealth
    private static var stateReservation: UInt64 { 1152 }
    private var cleanupFailure: JSONTransformFailure?
    private var closed = false

    private init(context: consuming TransformRuntimeContext, source: (() throws -> JSON?)?) {
        self.context = consume context
        let health = ExecutionHealth()
        self.health = health
        input = .init(source: source, health: health)
        vm = nil
    }
    static func make(plan: JSONTransformProgram, input root: JSON, bindings: [String: JSON],
                     limits: JSONTransformLimits, source: (() throws -> JSON?)?) throws -> JSONTransformExecution {
        do {
            var context = try TransformRuntimeContext(limits: limits.runtime)
            try context.domain(.core)
            try context.meter.retain(Self.stateReservation) // Owner + health + fixed observation, before allocation.
            let execution = JSONTransformExecution(context: consume context, source: source)
            try execution.prepare(plan: plan, root: root, bindings: bindings)
            return execution
        } catch { throw JSONTransformFailure.classify(error) }
    }
    private func prepare(plan: JSONTransformProgram, root: JSON, bindings: [String: JSON]) throws {
        do {
            try context.meter.retain(plan.planReservation)
            planReservation = plan.planReservation
            guard bindings.count == plan.variables.count else { throw JSONTransformFailure(.configuration, "invalidBindings") }
            var supplied: [String: FilterYield] = [:]
            for (name, value) in bindings {
                try context.charge(.bindings)
                initialBindings += 1
                let before = context.meter.used(.retainedBytes)
                try JSONAdmission.text(name, key: true, meter: &context.meter, owned: true)
                bindingReservation += context.meter.used(.retainedBytes) - before
                guard plan.variables.contains(name) else { throw JSONTransformFailure(.configuration, "invalidBindings") }
                supplied[name] = try FilterValues.produced(value, context: &context)
            }
            try context.charge(.totalRecords)
            let value = try FilterValues.produced(root, context: &context)
            vm = try FilterVM(program: plan.program, input: value, bindings: supplied, context: &context)
        } catch { throw JSONTransformFailure.classify(error) }
    }

    /// Pulls the next ordered exact output, or nil after completed evaluation.
    ///
    /// A resource, provider or cancellation failure latches and bypasses query
    /// catches. Later pulls cannot create a fresh successful execution.
    public func next() throws -> JSONTransformOutput? {
        // Check before touching the exclusively borrowed context. Caller callbacks
        // can reach this handle; same-thread re-entry must throw, never trap.
        guard !health.pulling else {
            let failure = JSONTransformFailure(.configuration, "reentrantExecution")
            health.latch(failure)
            throw health.failure ?? failure
        }
        health.pulling = true
        defer { health.pulling = false }
        do {
            try health.check(context: &context)
            try context.checkpoint()
            guard !closed else { throw JSONTransformFailure(.configuration, "scopeClosed") }
            guard var active = vm else { return nil }
            vm = nil
            defer { vm = active }
            guard let value = try active.next(input: &input, context: &context) else { return nil }
            try context.charge(.totalResults)
            return .init(value)
        } catch {
            let failed = JSONTransformFailure.classify(error)
            health.latch(failed)
            try health.check(context: &context)
            throw failed
        }
    }
    /// Current cumulative native statistics, also available after a failed pull.
    /// During an input callback this is the snapshot taken at callback entry.
    public var statistics: JSONOperationStatistics {
        health.observation?.statistics ?? context.meter.statistics()
    }
    /// Remaining shared owned work; this is not a caller instruction quota.
    public var remainingWorkUnits: UInt64 {
        if let observation = health.observation { return observation.remaining }
        let cap = min(context.limits.core[.workUnits], context.limits[.totalWorkUnits])
        return cap - min(cap, context.used(.totalWorkUnits))
    }
    /// Reads a transform counter without exposing its mutable meter.
    /// - Parameter metric: The cumulative or live transform counter.
    public func used(_ metric: JSONTransformLimits.Metric) -> UInt64 {
        if let observation = health.observation { return observation.counters[metric.runtime.index] }
        return context.used(metric.runtime)
    }
    /// Latches cancellation. The next pull and scope completion both throw.
    public func cancel() {
        guard !closed else { return }
        let cancelled = JSONTransformFailure(.cancelled, "cancelled")
        health.latch(cancelled)
        // During a provider callback context is loaned to the VM. The adapter
        // observes this cell before accepting another value or reporting EOF.
        if !health.pulling { context.latch(cancelled) }
    }
    func checkCompletion() throws {
        try context.checkpoint()
        try health.check(context: &context)
        if let cleanupFailure { throw cleanupFailure }
    }
    func recordCleanupFailure(_ error: any Error) { cleanupFailure = .classify(error) }
    func close() throws {
        guard !closed else { return }
        closed = true
        input.source = nil
        if var active = vm { vm = nil; try active.close(context: &context) }
        try context.reclaimValueLeases()
        // Remaining compilation/binding reservations end with the owner scope;
        // returned output handles retain their own deferred lease reservations.
        try context.meter.release(planReservation + bindingReservation + Self.stateReservation)
        try context.release(.bindings, initialBindings)
        planReservation = 0; bindingReservation = 0; initialBindings = 0
    }
}
