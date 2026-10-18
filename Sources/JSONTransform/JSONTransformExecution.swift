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

private struct SuppliedInput: FilterInput {
    var source: (() throws -> JSON?)?
    var ended = false
    mutating func next(context: inout TransformRuntimeContext) throws -> FilterYield? {
        try context.checkpoint()
        guard !ended, let source else { return nil }
        let value: JSON?
        do { value = try source() }
        catch {
            let failure = error is CancellationError ? JSONTransformFailure(.cancelled, "cancelled") : JSONTransformFailure(.provider, "providerFailed")
            context.latch(failure); throw failure
        }
        try context.checkpoint() // Cancellation after caller-owned work.
        guard let value else { ended = true; self.source = nil; return nil }
        try context.charge(.totalRecords)
        return try FilterValues.produced(value, context: &context)
    }
}

/// A borrowed noncopyable, non-Sendable pull facade for one execution scope.
///
/// The private state owns one cumulative meter. A borrowing callback cannot swap
/// or replace this facade with another invocation. Only plans are Sendable.
public struct JSONTransformExecution: ~Copyable {
    private let state: TransformExecutionState
    private init(state: TransformExecutionState) { self.state = state }
    static func make(plan: JSONTransformProgram, input: JSON, bindings: [String: JSON],
                     limits: JSONTransformLimits, source: (() throws -> JSON?)?) throws -> Self {
        .init(state: try TransformExecutionState.make(plan: plan, input: input, bindings: bindings, limits: limits, source: source))
    }
    /// Pulls the next ordered output, or nil at completed evaluation.
    ///
    /// Resource, provider and cancellation failures latch and bypass language
    /// catches. A present output containing JSON null is distinct from EOF.
    public func next() throws -> JSONTransformOutput? { try state.next() }
    /// Current native cumulative statistics, including after a failed pull.
    public var statistics: JSONOperationStatistics { state.statistics }
    /// Remaining shared work; arbitrary caller instructions are not capped.
    public var remainingWorkUnits: UInt64 { state.remainingWorkUnits }
    /// Reads a live or cumulative transform counter without exporting a meter.
    /// - Parameter metric: The counter whose usage to inspect.
    public func used(_ metric: JSONTransformLimits.Metric) -> UInt64 { state.used(metric) }
    /// Latches cancellation for later pulls and scope completion.
    public func cancel() { state.cancel() }
    func checkCompletion() throws { try state.checkCompletion() }
    func close() throws { try state.close() }
    func recordCleanupFailure(_ error: any Error) { state.recordCleanupFailure(error) }
}

private final class TransformExecutionState {
    private var context: TransformRuntimeContext
    private var vm: FilterVM?
    private var input: SuppliedInput
    private var planReservation: UInt64 = 0
    private var bindingReservation: UInt64 = 0
    private var initialBindings: UInt64 = 0
    private var failure: JSONTransformFailure?
    private var cleanupFailure: JSONTransformFailure?
    private var closed = false

    private init(context: consuming TransformRuntimeContext, source: (() throws -> JSON?)?) {
        self.context = consume context
        input = .init(source: source)
        vm = nil
    }
    static func make(plan: JSONTransformProgram, input root: JSON, bindings: [String: JSON],
                     limits: JSONTransformLimits, source: (() throws -> JSON?)?) throws -> TransformExecutionState {
        do {
            var context = try TransformRuntimeContext(limits: limits.runtime)
            try context.meter.retain(128) // Fixed invocation state, before allocation.
            let execution = TransformExecutionState(context: consume context, source: source)
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
    func next() throws -> JSONTransformOutput? {
        do {
            try context.checkpoint()
            if let failure { throw failure }
            guard !closed else { throw JSONTransformFailure(.configuration, "scopeClosed") }
            guard var active = vm else { return nil }
            vm = nil
            defer { vm = active }
            guard let value = try active.next(input: &input, context: &context) else { return nil }
            try context.charge(.totalResults)
            return .init(value)
        } catch {
            let failed = JSONTransformFailure.classify(error)
            if failure == nil { failure = failed }
            context.latch(failed)
            throw failed
        }
    }
    /// Current cumulative native statistics, also available after a failed pull.
    var statistics: JSONOperationStatistics { context.meter.statistics() }
    /// Remaining shared owned work; this is not a caller instruction quota.
    var remainingWorkUnits: UInt64 {
        let cap = min(context.limits.core[.workUnits], context.limits[.totalWorkUnits])
        return cap - min(cap, context.used(.totalWorkUnits))
    }
    /// Reads a transform counter without exposing its mutable meter.
    /// - Parameter metric: The cumulative or live transform counter.
    func used(_ metric: JSONTransformLimits.Metric) -> UInt64 { context.used(metric.runtime) }
    /// Latches cancellation. The next pull and scope completion both throw.
    func cancel() {
        let cancelled = JSONTransformFailure(.cancelled, "cancelled")
        if failure == nil { failure = cancelled }
        context.latch(cancelled)
    }
    func checkCompletion() throws {
        try context.checkpoint()
        if let failure { throw failure }
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
        try context.meter.release(planReservation + bindingReservation + 128)
        try context.release(.bindings, initialBindings)
        planReservation = 0; bindingReservation = 0; initialBindings = 0
    }
}
