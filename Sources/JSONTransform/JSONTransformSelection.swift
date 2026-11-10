// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

/// Finite policy for indexed-selection convention V1, additional to native limits.
public struct JSONTransformSelectionLimits: Sendable {
    /// The shared admission, projection, VM, provider and output policy.
    public var transform: JSONTransformLimits = .init()
    /// Inclusive population count; default 65,536. Zero admits an empty population.
    public var maximumPopulationValues: UInt64 = 65_536
    var checkpointObserver: (@Sendable (UInt64) -> Void)?
    var projectionObserver: (@Sendable (UInt64) -> Void)?
    /// Creates the finite balanced selection policy.
    public init() {}
}

/// A selection-boundary refusal, distinct from language and operational engine errors.
public enum JSONTransformSelectionFailure: Error, Sendable, Equatable {
    /// An output was not an exact nonnegative UInt64 index in the population.
    case invalidPosition
    /// A position belongs to a different invocation, even with identical values.
    case foreignPosition
    /// The caller returned before pulling explicit evaluator EOF.
    case incompleteSelection
}

private final class SelectionIdentity {
    let lease: TransformValueLease
    init(_ lease: TransformValueLease) { self.lease = lease }
}
private final class SelectionPopulation {
    let value: FilterYield
    let identity: SelectionIdentity
    let metadata: TransformValueLease
    init(_ value: FilterYield, identity: SelectionIdentity, metadata: TransformValueLease) {
        self.value = value; self.identity = identity; self.metadata = metadata
    }
}

/// An unforgeable invocation-local ordinal, retaining the population and its accounting.
/// Copies share leases. The handle is deliberately non-Sendable; extracted ordinals
/// and caller mappings are not engine provenance, stable IDs or read grants.
public struct JSONTransformSelectionPosition {
    /// Exact zero-based original population index; order and repeats are preserved.
    public let ordinal: UInt64
    private let population: SelectionPopulation
    private let reservation: TransformValueLease
    fileprivate init(_ ordinal: UInt64, population: SelectionPopulation, reservation: TransformValueLease) {
        self.ordinal = ordinal; self.population = population; self.reservation = reservation
    }
    fileprivate var identity: SelectionIdentity { population.identity }
}

/// An owner-produced EOF witness and successful accounting snapshot; no public initializer.
/// The witness retains only identity/report storage, not the population. Escaped
/// positions retain that population separately. Logical reservations are not RSS.
public struct JSONTransformSelectionCompletion {
    /// Indexed-selection convention revision, independent of query and definition versions.
    public var conventionRevision: UInt32 { 1 }
    /// Completely admitted population count, including duplicate-valued members.
    public let populationCount: UInt64
    /// Successfully published positions, including repeats.
    public let outputCount: UInt64
    /// Successful cumulative native snapshot after closing VM/provider state.
    public let statistics: JSONOperationStatistics
    private let identity: SelectionIdentity
    private let reservation: TransformValueLease
    fileprivate init(identity: SelectionIdentity, reservation: TransformValueLease,
                     populationCount: UInt64, outputCount: UInt64, statistics: JSONOperationStatistics) {
        self.identity = identity; self.reservation = reservation
        self.populationCount = populationCount; self.outputCount = outputCount; self.statistics = statistics
    }
    /// Verifies invocation identity and extracts an ordinal after successful completion.
    /// This constant metadata inspection is caller work, not another VM invocation.
    /// - Parameter position: A position emitted by this invocation.
    /// - Returns: Its exact original population index.
    /// - Throws: ForeignPosition for a handle from another invocation.
    public func ordinal(of position: JSONTransformSelectionPosition) throws -> UInt64 {
        guard identity === position.identity else { throw JSONTransformSelectionFailure.foreignPosition }
        return position.ordinal
    }
}

/// The caller result paired with an unforgeable successful selection completion.
public struct JSONTransformSelectionReport<Result> {
    /// The value returned by the synchronous caller body.
    public let result: Result
    /// Successful EOF, invocation identity and actual native accounting.
    public let completion: JSONTransformSelectionCompletion
    fileprivate init(result: Result, completion: JSONTransformSelectionCompletion) {
        self.result = result; self.completion = completion
    }
}

private final class SelectionHealth {
    struct Observation {
        let statistics: JSONOperationStatistics
        let remaining: UInt64
        let counters: [UInt64]
    }
    var pulling = false
    var failure: (any Error)?
    var observation: Observation?
    func latch(_ error: any Error) {
        if failure == nil {
            failure = error is JSONTransformSelectionFailure ? error : JSONTransformFailure.classify(error)
        }
    }
    func check(context: inout TransformRuntimeContext) throws {
        if let failure { context.latch(failure); throw failure }
    }
    func observe(context: inout TransformRuntimeContext) throws {
        try context.work(66)
        let cap = min(context.limits.core[.workUnits], context.limits[.totalWorkUnits])
        observation = .init(statistics: context.meter.statistics(),
                            remaining: cap - min(cap, context.used(.totalWorkUnits)),
                            counters: TransformRuntimeMetric.allCases.map { context.used($0) })
    }
}
private struct SelectionInput: FilterInput {
    var source: (() throws -> JSON?)?
    let health: SelectionHealth
    var ended = false
    mutating func next(context: inout TransformRuntimeContext) throws -> FilterYield? {
        try health.check(context: &context); try context.checkpoint()
        guard !ended, let source else { return nil }
        try health.observe(context: &context)
        defer { health.observation = nil }
        let value: JSON?
        do { value = try source() }
        catch {
            health.latch(JSONTransformFailure(error is CancellationError ? .cancelled : .provider,
                                              error is CancellationError ? "cancelled" : "providerFailed"))
            try health.check(context: &context); throw error
        }
        try health.check(context: &context); try context.checkpoint()
        guard let value else { ended = true; self.source = nil; return nil }
        try context.charge(.totalRecords)
        return try FilterValues.produced(value, context: &context)
    }
}

/// A guarded, non-Sendable indexed-selection pull scope with one cumulative ledger.
/// V1 input is [0,...,N-1]; `$values` is the complete original population. Additional
/// bindings are explicit. Provider values may influence queries but never enlarge
/// the population. Returning without pulling nil cannot certify a prefix.
public final class JSONTransformSelectionScope {
    private var context: TransformRuntimeContext
    private var vm: FilterVM?
    private var population: SelectionPopulation?
    private var input: SelectionInput
    private let health: SelectionHealth
    private var planBytes: UInt64 = 0, bindingBytes: UInt64 = 0, initialBindings: UInt64 = 0
    private var ended = false, closed = false
    private var published: UInt64 = 0
    private let count: UInt64
    private var cleanupFailure: (any Error)?
    private static var stateBytes: UInt64 { 2048 }
    private init(context: consuming TransformRuntimeContext, count: UInt64, source: (() throws -> JSON?)?) {
        self.context = consume context; self.count = count
        let health = SelectionHealth(); self.health = health
        input = .init(source: source, health: health)
    }
    static func make(plan: JSONTransformProgram, values: [JSON], bindings: [String: JSON],
                     limits: JSONTransformSelectionLimits, source: (() throws -> JSON?)?,
                     observing: ((JSONTransformSelectionScope) -> Void)? = nil) throws -> JSONTransformSelectionScope {
        do {
            guard limits.maximumPopulationValues < UInt64(Int.max) else {
                throw JSONTransformFailure(.configuration, "invalidLimits")
            }
            var context = try TransformRuntimeContext(limits: limits.transform.runtime)
            try context.domain(.core)
            context.meter.checkpointObserver = limits.checkpointObserver
            try context.meter.retain(stateBytes)
            let scope = JSONTransformSelectionScope(context: consume context, count: UInt64(values.count), source: source)
            observing?(scope)
            do {
                try scope.prepare(plan, values: values, bindings: bindings, maximum: limits.maximumPopulationValues, projectionObserver: limits.projectionObserver)
                return scope
            } catch {
                scope.health.latch(error)
                scope.closePreservingFailure()
                throw scope.health.failure ?? error
            }
        } catch {
            if error is JSONTransformSelectionFailure { throw error }
            throw JSONTransformFailure.classify(error)
        }
    }
    private func prepare(_ plan: JSONTransformProgram, values: [JSON], bindings: [String: JSON], maximum: UInt64,
                         projectionObserver: (@Sendable (UInt64) -> Void)?) throws {
        try context.checkpoint()
        guard count <= maximum else {
            throw JSONTransformFailure(.resource, "limitExceeded", metric: "populationValues", limit: maximum, attemptedUsage: count)
        }
        guard plan.variables.contains("values"), bindings.count == plan.variables.count - 1 else {
            throw JSONTransformFailure(.configuration, "invalidBindings")
        }
        try context.meter.retain(plan.planReservation); planBytes = plan.planReservation
        let identity = SelectionIdentity(try makeLease(64))
        let admitted = try FilterValues.array(values, context: &context)
        let metadata = try makeLease(48)
        population = SelectionPopulation(admitted, identity: identity, metadata: metadata)
        var supplied: [String: FilterYield] = [:]
        try admitName("values")
        supplied["values"] = admitted
        for (name, value) in bindings {
            try admitName(name)
            guard name != "values", plan.variables.contains(name) else { throw JSONTransformFailure(.configuration, "invalidBindings") }
            supplied[name] = try FilterValues.produced(value, context: &context)
        }
        var indices: [JSON] = [], scratch: UInt64 = 0, slots: UInt64 = 0
        defer {
            do { try context.meter.release(scratch); try context.release(.collectionValues, slots) }
            catch { recordCleanup(error) }
        }
        for ordinal in values.indices {
            try context.work(20)
            try context.charge(.collectionValues); slots += 1
            try context.meter.retain(64); scratch += 64
            indices.append(.number(JSONNumber(integer: ordinal)))
            projectionObserver?(UInt64(indices.count))
        }
        let root = try FilterValues.array(indices, admittedCollectionCount: true, context: &context)
        slots = 0 // The root's lease owns these slots now.
        indices = []; try context.meter.release(scratch); scratch = 0
        try context.charge(.totalRecords)
        vm = try FilterVM(program: plan.program, input: root, bindings: supplied, context: &context)
    }
    private func makeLease(_ bytes: UInt64) throws -> TransformValueLease {
        try context.meter.retain(bytes)
        do { return try TransformValueLease(ownedRetained: bytes, context: &context) }
        catch { try context.meter.release(bytes); throw error }
    }
    private func admitName(_ name: String) throws {
        try context.charge(.bindings); initialBindings += 1
        var first = true
        for byte in name.utf8 {
            try context.work()
            let letter = byte == 95 || (65...90).contains(byte) || (97...122).contains(byte)
            guard letter || (!first && (48...57).contains(byte)) else { throw JSONTransformFailure(.configuration, "invalidBindings") }
            first = false
        }
        guard !first else { throw JSONTransformFailure(.configuration, "invalidBindings") }
        let before = context.meter.used(.retainedBytes)
        do {
            try JSONAdmission.text(name, key: true, meter: &context.meter, owned: true)
            try context.meter.retain(64)
            bindingBytes += context.meter.used(.retainedBytes) - before
        } catch {
            try context.meter.release(context.meter.used(.retainedBytes) - before); throw error
        }
    }
    /// Pulls the next valid original-population position, or nil at explicit EOF.
    /// Invalid outputs, resource/provider failures, cancellation and reentry latch;
    /// query catches and later caller catches cannot restore successful completion.
    public func next() throws -> JSONTransformSelectionPosition? {
        guard !health.pulling else {
            health.latch(JSONTransformFailure(.configuration, "reentrantSelection"))
            throw health.failure ?? JSONTransformFailure(.configuration, "reentrantSelection")
        }
        health.pulling = true; defer { health.pulling = false }
        do {
            try context.reclaimValueLeases(); try health.check(context: &context)
            try context.checkpoint()
            guard !closed else { throw JSONTransformFailure(.configuration, "scopeClosed") }
            guard !ended, var active = vm else { return nil }
            vm = nil; defer { vm = active }
            guard let raw = try active.next(input: &input, context: &context) else { ended = true; return nil }
            let before = context.meter.used(.retainedBytes)
            do { try context.meter.resetValueBounds(); try JSONAdmission.value(raw.value, meter: &context.meter) }
            catch { try context.meter.release(context.meter.used(.retainedBytes) - before); throw error }
            try context.charge(.totalResults)
            guard case .number(let number) = raw.value else { throw JSONTransformSelectionFailure.invalidPosition }
            let ordinal: UInt64
            do { ordinal = try number.integer(as: UInt64.self, meter: &context.meter) }
            catch let failure as JSONFailure where failure.category == .conversion { throw JSONTransformSelectionFailure.invalidPosition }
            guard let native = Int(exactly: ordinal), native >= 0, ordinal < count, let population else {
                throw JSONTransformSelectionFailure.invalidPosition
            }
            let lease = try makeLease(32)
            published += 1
            return .init(ordinal, population: population, reservation: lease)
        } catch {
            health.latch(error); throw health.failure ?? error
        }
    }
    /// Drains deferred lease refunds and returns actual native accounting, even after failure/close.
    /// During a provider callback this returns its admitted entry snapshot without
    /// borrowing the VM's context. It never reopens data operations or refunds work.
    /// - Throws: An accounting cleanup failure; a prior operational cause takes precedence.
    public func report() throws -> JSONOperationStatistics {
        if health.pulling {
            if let observation = health.observation { return observation.statistics }
            health.latch(JSONTransformFailure(.configuration, "reentrantSelection"))
            throw health.failure ?? JSONTransformFailure(.configuration, "reentrantSelection")
        }
        do { try context.reclaimValueLeases() }
        catch { recordCleanup(error); throw health.failure ?? error }
        if let cleanupFailure { throw health.failure ?? cleanupFailure }
        return context.meter.statistics()
    }
    /// Remaining cumulative owned work; provider entry uses an admitted snapshot.
    public var remainingWorkUnits: UInt64 {
        if health.pulling { return health.observation?.remaining ?? 0 }
        let cap = min(context.limits.core[.workUnits], context.limits[.totalWorkUnits])
        return cap - min(cap, context.used(.totalWorkUnits))
    }
    /// Reads a cumulative/live transform counter; call report to settle deferred refunds.
    /// - Parameter metric: The existing transform counter, without a public mutable meter.
    public func used(_ metric: JSONTransformLimits.Metric) -> UInt64 {
        if health.pulling { return health.observation?.counters[metric.runtime.index] ?? 0 }
        return context.used(metric.runtime)
    }
    /// Latches cancellation without borrowing a context loaned to the provider.
    public func cancel() {
        guard !closed else { return }
        health.latch(JSONTransformFailure(.cancelled, "cancelled"))
        if !health.pulling, let failure = health.failure { context.latch(failure) }
    }
    fileprivate var firstFailure: (any Error)? { health.failure }
    fileprivate func complete() throws -> JSONTransformSelectionCompletion {
        do {
            try context.checkpoint(); try health.check(context: &context)
            if let cleanupFailure { throw cleanupFailure }
            guard ended, let identity = population?.identity else { throw JSONTransformSelectionFailure.incompleteSelection }
            try context.work(50)
            let lease = try makeLease(1024)
            try close()
            return .init(identity: identity, reservation: lease, populationCount: count,
                         outputCount: published, statistics: try report())
        } catch { health.latch(error); throw health.failure ?? error }
    }
    private func recordCleanup(_ error: any Error) {
        if cleanupFailure == nil { cleanupFailure = error }
        health.latch(error)
    }
    fileprivate func closePreservingFailure() {
        do { try close() } catch { recordCleanup(error) }
    }
    private func close() throws {
        guard !closed else { return }; closed = true
        input.source = nil
        if var active = vm { vm = nil; try active.close(context: &context) }
        population = nil
        try context.reclaimValueLeases()
        try context.meter.release(planBytes + bindingBytes + Self.stateBytes)
        try context.release(.bindings, initialBindings)
        planBytes = 0; bindingBytes = 0; initialBindings = 0
    }
}

extension JSONTransformProgram {
    /// Runs indexed-selection convention V1 on one fully admitted finite population.
    /// Input is an owned index array; `$values` is the corresponding value array.
    /// The plan must declare values, and bindings supply exactly the other names.
    /// Provider work/bytes already owned by the caller stay outside engine quotas.
    /// - Parameters:
    ///   - population: Explicit original order, including duplicate-valued members.
    ///   - bindings: Additional declared bindings; values is reserved and cannot be supplied here.
    ///   - limits: One finite ledger for admission, projection, evaluation and outputs.
    ///   - source: Optional explicit input/inputs provider; nil means no extra inputs.
    ///   - body: Synchronous caller work; pull nil to certify complete selection.
    /// - Returns: Caller result and an owner-produced EOF/accounting witness.
    /// - Throws: Selection refusals, typed operational failures or uncaught caller errors.
    public func withSelection<Result>(population: [JSON], bindings: [String: JSON] = [:],
                                      limits: JSONTransformSelectionLimits = .init(), source: (() throws -> JSON?)? = nil,
                                      _ body: (JSONTransformSelectionScope) throws -> Result) throws -> JSONTransformSelectionReport<Result> {
        let scope = try JSONTransformSelectionScope.make(plan: self, values: population, bindings: bindings, limits: limits, source: source)
        let result: Result
        do { result = try body(scope) }
        catch {
            let cause = scope.firstFailure ?? error
            scope.closePreservingFailure(); throw cause
        }
        do { return .init(result: result, completion: try scope.complete()) }
        catch {
            let cause = scope.firstFailure ?? error
            scope.closePreservingFailure(); throw cause
        }
    }
}
