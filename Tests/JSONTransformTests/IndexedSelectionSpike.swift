// SPDX-License-Identifier: Apache-2.0
// Test-only ownership experiment. This is not a shipped selection API.
import Testing
import Synchronization
import JSON
import JSONFilterRuntime
@testable import JSONTransform

private enum SelectionSpikeFailure: Error, Equatable {
    case invalidPosition, incomplete, closed, provider, invalidBindings
}
private final class PopulationOwner {
    let population: FilterYield
    let metadata: TransformValueLease
    init(_ population: FilterYield, metadata: TransformValueLease) {
        self.population = population; self.metadata = metadata
    }
}
private struct SpikePosition {
    let ordinal: UInt64
    let owner: PopulationOwner
    let reservation: TransformValueLease
}
private struct SpikeInput: FilterInput {
    var fail = false
    var calls = 0
    mutating func next(context: inout TransformRuntimeContext) throws -> FilterYield? {
        calls += 1
        if fail { throw SelectionSpikeFailure.provider }
        return nil
    }
}
private final class SelectionSpike {
    private var context: TransformRuntimeContext
    private var vm: FilterVM?
    private var owner: PopulationOwner?
    private var input = SpikeInput()
    private var failure: (any Error)?
    private var ended = false, closed = false
    private var planBytes: UInt64 = 0
    private init(_ context: consuming TransformRuntimeContext) { self.context = consume context }

    static func make(_ plan: JSONTransformProgram, population: [JSON],
                     limits: JSONTransformLimits = .init(), providerFailure: Bool = false,
                     observer: (@Sendable (UInt64) -> Void)? = nil,
                     projectionObserver: (@Sendable (Int) -> Void)? = nil,
                     cleanupObserver: (@Sendable (UInt64) -> Void)? = nil) throws -> SelectionSpike {
        var context = try TransformRuntimeContext(limits: limits.runtime)
        try context.meter.retain(128)
        context.meter.checkpointObserver = observer
        let result = SelectionSpike(consume context)
        do {
            guard plan.variables == ["values"] else { throw SelectionSpikeFailure.invalidBindings }
            try result.prepare(plan, population: population, providerFailure: providerFailure, projectionObserver: projectionObserver)
            return result
        } catch {
            let cause = error
            do { try result.close() } catch { Issue.record("Prototype preparation cleanup failed: \(error)") }
            if let cleanupObserver {
                do { cleanupObserver(try result.settlement()[.retainedBytes]) }
                catch { Issue.record("Prototype terminal observation failed: \(error)") }
            }
            throw cause
        }
    }
    private func prepare(_ plan: JSONTransformProgram, population: [JSON], providerFailure: Bool,
                         projectionObserver: (@Sendable (Int) -> Void)?) throws {
        try context.meter.retain(plan.planReservation); planBytes = plan.planReservation
        // A prototype population cap, independent of lexical token counts.
        guard population.count <= 1024 else { throw SelectionSpikeFailure.invalidBindings }
        try context.charge(.bindings)
        let value = try FilterValues.produced(.array(population), context: &context)
        try context.meter.retain(48)
        let metadata = try TransformValueLease(ownedRetained: 48, context: &context)
        owner = PopulationOwner(value, metadata: metadata)
        var indices: [JSON] = [], scratch: UInt64 = 0
        defer {
            do { try context.meter.release(scratch) }
            catch { Issue.record("Prototype projection scratch cleanup failed: \(error)") }
        }
        for ordinal in population.indices {
            try context.work(); try context.meter.retain(64); scratch += 64
            indices.append(.number(JSONNumber(integer: ordinal)))
            projectionObserver?(indices.count)
        }
        let root = try FilterValues.array(indices, context: &context)
        indices = []; try context.meter.release(scratch); scratch = 0
        try context.charge(.totalRecords)
        vm = try FilterVM(program: plan.program, input: root, bindings: ["values": value], context: &context)
        input.fail = providerFailure
    }
    func next() throws -> SpikePosition? {
        do {
            try context.reclaimValueLeases()
            if let failure { throw failure }
            try context.checkpoint()
            guard !closed else { throw SelectionSpikeFailure.closed }
            guard var active = vm else { throw SelectionSpikeFailure.closed }
            vm = nil; defer { vm = active }
            guard let raw = try active.next(input: &input, context: &context) else { ended = true; return nil }
            let before = context.meter.used(.retainedBytes)
            do {
                try context.meter.resetValueBounds()
                try JSONAdmission.value(raw.value, meter: &context.meter)
            } catch {
                try context.meter.release(context.meter.used(.retainedBytes)-before); throw error
            }
            try context.charge(.totalResults)
            guard case .number(let number) = raw.value else { throw SelectionSpikeFailure.invalidPosition }
            let ordinal: UInt64
            do { ordinal = try number.integer(as: UInt64.self, meter: &context.meter) }
            catch let error as JSONFailure where error.category == .conversion { throw SelectionSpikeFailure.invalidPosition }
            guard let native = Int(exactly: ordinal), let owner,
                  case .array(let values) = owner.population.value, native < values.count else {
                throw SelectionSpikeFailure.invalidPosition
            }
            try context.meter.retain(32)
            let slot = try TransformValueLease(ownedRetained: 32, context: &context)
            return .init(ordinal: ordinal, owner: owner, reservation: slot)
        } catch {
            if failure == nil { failure = error; context.latch(error) }
            throw failure ?? error
        }
    }
    func accepts(_ position: SpikePosition) -> Bool { owner === position.owner }
    func finish() throws -> JSONOperationStatistics {
        if failure == nil && !ended { failure = SelectionSpikeFailure.incomplete; context.latch(SelectionSpikeFailure.incomplete) }
        let cause = failure
        try close()
        if let cause { throw cause }
        return try settlement()
    }
    func settlement() throws -> JSONOperationStatistics {
        try context.reclaimValueLeases()
        return context.meter.statistics()
    }
    var providerCalls: Int { input.calls }
    private func close() throws {
        guard !closed else { return }; closed = true
        if var active = vm { vm = nil; try active.close(context: &context) }
        owner = nil
        try context.reclaimValueLeases()
        try context.meter.release(planBytes + 128); planBytes = 0
        try context.release(.bindings, context.used(.bindings))
    }
}
private func spikePlan(_ source: String) throws -> JSONTransformProgram {
    try JSONTransformProgram.compile(source, variables: ["values"])
}

@Test func bindingP01ExplicitIndicesPreserveDuplicatesOrderAndTies() throws {
    let row = try JSON.parse(#"{"score":1}"#)
    for (source, expected) in [(".[] | select(. == 1)", [UInt64(1)]),
                               ("1,0,1", [1,0,1]),
                               ("sort_by([$values[.].score, .])[]", [0,1])] {
        let probe = try SelectionSpike.make(spikePlan(source), population: [row,row])
        var ordinals: [UInt64] = []
        while let position = try probe.next() { ordinals.append(position.ordinal) }
        let report = try probe.finish()
        #expect(ordinals == expected && report[.workUnits] > 0)
    }
    let empty = try SelectionSpike.make(spikePlan("empty"), population: [])
    #expect(try empty.next() == nil); #expect(try empty.finish()[.workUnits] > 0)
}

@Test func bindingP02InvalidOutputAndAbandonedPrefixNeverCertify() throws {
    for bad in ["null", "true", "\"0\"", "-1", "0.1", "18446744073709551616", "9223372036854775808", "1"] {
        let probe = try SelectionSpike.make(spikePlan("try (0, " + bad + ") catch 0"), population: [42])
        #expect(try probe.next()?.ordinal == 0)
        for _ in 0..<2 {
            do { _ = try probe.next(); Issue.record("Invalid position escaped") }
            catch let error as SelectionSpikeFailure { #expect(error == .invalidPosition) }
        }
        do { _ = try probe.finish(); Issue.record("Caught refusal certified selection") }
        catch let error as SelectionSpikeFailure { #expect(error == .invalidPosition) }
    }
    let prefix = try SelectionSpike.make(spikePlan("0,0"), population: [42])
    #expect(try prefix.next()?.ordinal == 0)
    do { _ = try prefix.finish(); Issue.record("Abandoned prefix certified") }
    catch let error as SelectionSpikeFailure { #expect(error == .incomplete) }
}

@Test func bindingP03PopulationLeaseSurvivesCloseAndForeignOwnerRefuses() throws {
    let plan = try spikePlan("0")
    let source: [JSON] = [.string(String(repeating: "x", count: 8192))]
    let a = try SelectionSpike.make(plan, population: source), b = try SelectionSpike.make(plan, population: source)
    var position = try a.next(), alias = position
    #expect(position?.ordinal == 0)
    #expect(position.map { !b.accepts($0) } == true)
    #expect(try a.next() == nil)
    _ = try a.finish()
    let retainedBefore = try withExtendedLifetime(alias) { try a.settlement()[.retainedBytes] }
    #expect(retainedBefore > 8192)
    position = nil
    let retainedAfter = try withExtendedLifetime(alias) { try a.settlement()[.retainedBytes] }
    #expect(retainedAfter > 8192)
    alias = nil
    #expect(try a.settlement()[.retainedBytes] == 0)
    do { _ = try a.next(); Issue.record("Closed handle resumed") }
    catch let error as SelectionSpikeFailure { #expect(error == .closed) }
    #expect(try b.next()?.ordinal == 0); #expect(try b.next() == nil); _ = try b.finish()
    for source in ["0.0", "-0"] {
        let probe = try SelectionSpike.make(spikePlan(source), population: [42])
        #expect(try probe.next()?.ordinal == 0); #expect(try probe.next() == nil); _ = try probe.finish()
    }
}

@Test func bindingP04ResourceAndProviderFailuresStayTerminal() throws {
    var limits = JSONTransformLimits(); limits[.results] = 1
    let probe = try SelectionSpike.make(spikePlan("0,0"), population: [42], limits: limits)
    #expect(try probe.next()?.ordinal == 0)
    for _ in 0..<2 {
        do { _ = try probe.next(); Issue.record("Results cap reset") }
        catch { let e = JSONTransformFailure.classify(error); #expect(e.category == .resource && e.metric == "results") }
    }
    do { _ = try probe.finish(); Issue.record("Failed quota certified") }
    catch { #expect(JSONTransformFailure.classify(error).category == .resource) }
    let provider = try SelectionSpike.make(spikePlan("try input catch 0"), population: [42], providerFailure: true)
    for _ in 0..<2 {
        do { _ = try provider.next(); Issue.record("Provider error was swallowed") }
        catch let error as SelectionSpikeFailure { #expect(error == .provider) }
    }
    #expect(provider.providerCalls == 1)
    do { _ = try provider.finish(); Issue.record("Provider error certified") }
    catch let error as SelectionSpikeFailure { #expect(error == .provider) }
}

@Test func bindingSharedSelectionSpikeReusesOnePlanIndependently() async throws {
    let plan = try spikePlan(".[]")
    let values = try await withThrowingTaskGroup(of: Bool.self) { group in
        for _ in 0..<6 { group.addTask {
            let probe = try SelectionSpike.make(plan, population: [42,42])
            let a = try probe.next()?.ordinal, b = try probe.next()?.ordinal
            guard try probe.next() == nil else { return false }
            return try probe.finish()[.workUnits] > 0 && a == 0 && b == 1
        } }
        var result: [Bool] = []; for try await x in group { result.append(x) }; return result
    }
    #expect(values.count == 6 && values.allSatisfy { $0 })
}

@Test func bindingP05ProjectionEvaluationAndCancellationShareOneLedger() async throws {
    let plan = try spikePlan("0"), population: [JSON] = Array(repeating: .string("row"), count: 64)
    func run(_ limits: JSONTransformLimits) throws -> JSONOperationStatistics {
        let probe = try SelectionSpike.make(plan, population: population, limits: limits)
        do {
            while let position = try probe.next() { #expect(position.ordinal == 0) }
            return try probe.finish()
        } catch {
            let first = error
            do { _ = try probe.finish() } catch { #expect(JSONTransformFailure.classify(error) == JSONTransformFailure.classify(first)) }
            throw first
        }
    }
    let measured = try run(.init())
    var limits = JSONTransformLimits(); limits[.workUnits] = measured[.workUnits]
    #expect(try run(limits)[.workUnits] == measured[.workUnits])
    limits[.workUnits] -= 1
    do { _ = try run(limits); Issue.record("Projection/evaluation restarted work") }
    catch { #expect(JSONTransformFailure.classify(error).category == .resource) }
    let handle = Mutex<Task<Void, any Error>?>(nil), ready = Mutex<CheckedContinuation<Void, Never>?>(nil)
    let observed = Mutex<Int>(0), finalRetained = Mutex<UInt64?>(nil)
    let task = Task<Void, any Error> {
        await withCheckedContinuation { continuation in ready.withLock { $0 = continuation } }
        _ = try SelectionSpike.make(plan, population: population, projectionObserver: { count in
            if count == 4 { observed.withLock { $0 = count }; handle.withLock { $0?.cancel() } }
        }, cleanupObserver: { value in finalRetained.withLock { $0 = value } })
    }
    handle.withLock { $0 = task }
    var continuation: CheckedContinuation<Void, Never>?
    while continuation == nil { continuation = ready.withLock { $0 }; if continuation == nil { await Task.yield() } }
    continuation?.resume()
    do { try await task.value; Issue.record("Projection ignored cancellation") } catch is CancellationError {}
    #expect(observed.withLock { $0 } == 4)
    #expect(finalRetained.withLock { $0 } == 0)
}
