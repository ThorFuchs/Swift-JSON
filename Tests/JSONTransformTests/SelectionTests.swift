// SPDX-License-Identifier: Apache-2.0
import Testing
import Synchronization
import JSON
@testable import JSONTransform

private func selectionPlan(_ source: String, extra: Set<String> = []) throws -> JSONTransformProgram {
    try .compile(source, variables: extra.union(["values"]))
}
private func select(_ source: String, _ values: [JSON], limits: JSONTransformSelectionLimits = .init()) throws -> JSONTransformSelectionReport<[JSONTransformSelectionPosition]> {
    try selectionPlan(source).withSelection(population: values, limits: limits) { scope in
        var positions: [JSONTransformSelectionPosition] = []
        while let p = try scope.next() { positions.append(p) }
        return positions
    }
}
private enum SelectionTestError: Error, Equatable { case sentinel }
private func refusal(_ expected: JSONTransformSelectionFailure, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected selection refusal \(expected)") }
    catch let e as JSONTransformSelectionFailure { #expect(e == expected) }
    catch { Issue.record("Wrong failure \(error)") }
}

@Test func selectionS01ExplicitOrdinalsPreserveDuplicateValuesOrderRepeatsAndTies() throws {
    let row = try JSON.parse(#"{"score":1,"é":9007199254740993,"é":0.1}"#)
    for (source, indices) in [(".[] | select(. == 1)", [UInt64(1)]), ("1,0,1", [1,0,1]),
                              ("sort_by([$values[.].score, .])[]", [0,1]),
                              (".[] | select($values[.][\"é\"] == 9007199254740993)", [0,1])] {
        let report = try select(source, [row,row])
        #expect(report.result.map(\.ordinal) == indices)
        #expect(try report.result.map { try report.completion.ordinal(of: $0) } == indices)
        #expect(report.completion.populationCount == 2 && report.completion.outputCount == UInt64(indices.count))
        #expect(report.completion.conventionRevision == 1 && report.completion.statistics.domain == .core)
    }
}

@Test func selectionS02EmptyEOFNullAndIncompletePrefixAreDistinct() throws {
    var zero = JSONTransformSelectionLimits(); zero.maximumPopulationValues = 0
    let empty = try select("empty", [], limits: zero)
    #expect(empty.result.isEmpty && empty.completion.outputCount == 0 && empty.completion.populationCount == 0)
    refusal(.incompleteSelection) { _ = try selectionPlan("empty").withSelection(population: []) { _ in () } }
    refusal(.incompleteSelection) {
        _ = try selectionPlan("0,0").withSelection(population: [42]) { s in _ = try s.next() }
    }
    refusal(.invalidPosition) { _ = try select("null", [.null]) }
    let presentNull = try select("0", [.null])
    #expect(presentNull.result.first?.ordinal == 0 && presentNull.completion.outputCount == 1)
}

@Test func selectionS03EveryInvalidOutputIsExactAndTerminalOutsideQueryCatch() throws {
    for bad in ["null","false","\"0\"","[]","{}","-1","0.1","18446744073709551616","18446744073709551615","9223372036854775808","1"] {
        var escaped: JSONTransformSelectionScope?
        refusal(.invalidPosition) {
            _ = try selectionPlan("try (0, " + bad + ") catch 0").withSelection(population: [42]) { s in
                escaped = s; let first = try s.next(); #expect(first?.ordinal == 0)
                for _ in 0..<2 { refusal(.invalidPosition) { _ = try s.next() } }
            }
        }
        let scope = try #require(escaped)
        refusal(.invalidPosition) { _ = try scope.next() }
        #expect(try scope.report()[.retainedBytes] == 0)
    }
    #expect(try select("42.0", Array(repeating: .null, count: 43)).result.first?.ordinal == 42)
    for source in ["0.0", "-0", "0e100"] { #expect(try select(source, [42]).result.first?.ordinal == 0) }
}

@Test func selectionS04CompletionRejectsForeignInvocationsAndPositionsRetainPopulation() throws {
    let plan = try selectionPlan("0")
    var scope: JSONTransformSelectionScope?
    var a: JSONTransformSelectionReport<JSONTransformSelectionPosition?>? = try plan.withSelection(population: [.string(String(repeating: "x", count: 8192))]) { s in
        scope = s; let p = try s.next(); #expect(try s.next() == nil); return p
    }
    var position = a?.result, alias = position
    var completion = a?.completion
    let b = try select("0", [.string(String(repeating: "x", count: 8192))])
    let p = try #require(position), witness = try #require(completion)
    refusal(.foreignPosition) { _ = try b.completion.ordinal(of: p) }
    #expect(try witness.ordinal(of: p) == 0)
    // Keep only aliases in a nested scope so last ARC releases are observable below.
    a = nil; position = nil
    let owner = try #require(scope)
    let withAlias = try withExtendedLifetime(alias) { try owner.report()[.retainedBytes] }
    #expect(withAlias > 8192)
    alias = nil; completion = nil
    // p/witness still own their real reservations until this function exits;
    // the separate S05 case proves the exact last-alias transition.
    #expect(try owner.report()[.retainedBytes] > 8192)
    do { _ = try owner.next(); Issue.record("Escaped closed scope resumed") }
    catch let e as JSONTransformFailure { #expect(e.category == .configuration && e.code == "scopeClosed") }
}

@Test func selectionS05FinalAliasAndCompletionReleaseSettleToZeroWithoutDataPulls() throws {
    var scope: JSONTransformSelectionScope?
    var position: JSONTransformSelectionPosition?
    var completion: JSONTransformSelectionCompletion?
    do {
        let report = try selectionPlan("0").withSelection(population: [.string(String(repeating: "p", count: 8192))]) { s in
            scope = s; position = try s.next(); #expect(try s.next() == nil)
        }
        completion = report.completion
    }
    let owner = try #require(scope)
    let bytes = try withExtendedLifetime(position) { try owner.report()[.retainedBytes] }
    #expect(bytes > 8192)
    position = nil
    let identityOnly = try withExtendedLifetime(completion) { try owner.report()[.retainedBytes] }
    #expect(identityOnly > 0 && identityOnly < 8192)
    completion = nil
    let settled = try owner.report()
    #expect(settled[.retainedBytes] == 0 && owner.used(.collectionValues) == 0 && owner.used(.bindings) == 0)
    #expect(settled[.workUnits] > 0)
}

@Test func selectionS06BindingsAreExplicitReservedAndScalarChecked() throws {
    let plan = try selectionPlan(".[] | select($values[.] >= $minimum)", extra: ["minimum"])
    let report = try plan.withSelection(population: [1,2,3], bindings: ["minimum": 2]) { s in
        var ids: [UInt64] = []; while let p = try s.next() { ids.append(p.ordinal) }; return ids
    }
    #expect(report.result == [1,2])
    for bindings: [String:JSON] in [[:],["values": .null],["other": 2],["K": 2]] {
        do { _ = try plan.withSelection(population: [1], bindings: bindings) { _ in () }; Issue.record("Accepted binding override/mismatch") }
        catch let e as JSONTransformFailure { #expect(e.category == .configuration && e.code == "invalidBindings") }
    }
    do { _ = try JSONTransformProgram.compile("0").withSelection(population: [1]) { _ in () }; Issue.record("Missing reserved declaration accepted") }
    catch let e as JSONTransformFailure { #expect(e.code == "invalidBindings") }
}

@Test func selectionS07PopulationPolicyIsInclusiveFiniteAndCannotSkipCompleteAdmission() throws {
    var policy = JSONTransformSelectionLimits(); policy.maximumPopulationValues = 2
    _ = try select("empty", [1,2], limits: policy)
    policy.maximumPopulationValues = 1
    do { _ = try select("empty", [1,2], limits: policy); Issue.record("Population cap escaped") }
    catch let e as JSONTransformFailure { #expect(e.category == .resource && e.metric == "populationValues" && e.limit == 1 && e.attemptedUsage == 2) }
    for cap in [UInt64.max, UInt64(Int.max)] {
        policy = .init(); policy.maximumPopulationValues = cap
        do { _ = try select("empty", [], limits: policy); Issue.record("Infinite/native overflow policy accepted") }
        catch let e as JSONTransformFailure { #expect(e.category == .configuration && e.code == "invalidLimits") }
    }
    policy = .init(); policy.transform.json[.stringBytes] = 1
    do { _ = try select("empty", [0,.string("too long")], limits: policy); Issue.record("Unused population tail bypassed admission") }
    catch let e as JSONTransformFailure { #expect(e.category == .resource && e.metric == "stringBytes") }
}

@Test func selectionS08ProjectionEvaluationAndCompletionShareExactCumulativeWorkAndRetention() throws {
    let source = "sort_by([$values[.],.])[]", values: [JSON] = [3,1,2]
    let baseline = try select(source, values)
    var policy = JSONTransformSelectionLimits()
    let work = baseline.completion.statistics[.workUnits], peak = baseline.completion.statistics.peakLogicalRetainedBytes
    policy.transform[.workUnits] = work
    #expect(try select(source, values, limits: policy).result.map(\.ordinal) == [1,2,0])
    policy.transform[.workUnits] = work - 1
    do { _ = try select(source, values, limits: policy); Issue.record("Completion work reset") }
    catch let e as JSONTransformFailure { #expect(e.category == .resource && e.metric == "workUnits") }
    policy = .init(); policy.transform[.retainedBytes] = peak
    _ = try select(source, values, limits: policy)
    policy.transform[.retainedBytes] = peak - 1
    do { _ = try select(source, values, limits: policy); Issue.record("Retention escaped") }
    catch let e as JSONTransformFailure { #expect(e.category == .resource && e.metric == "retainedBytes") }
    policy = .init(); policy.transform[.collectionValues] = 5
    do { _ = try select("empty", values, limits: policy); Issue.record("Projection slots not pre-admitted") }
    catch let e as JSONTransformFailure { #expect(e.category == .resource && e.metric == "collectionValues") }
}

@Test func selectionS09QuotaAndCancellationRefundTerminalAliasesAndPreserveFirstCause() throws {
    for cancel in [false,true] {
        var scope: JSONTransformSelectionScope?, output: JSONTransformSelectionPosition?
        var policy = JSONTransformSelectionLimits(); policy.transform[.results] = 1
        do {
            _ = try selectionPlan("0,0").withSelection(population: [.string(String(repeating: "q", count: 4096))], limits: policy) { s in
                scope = s; output = try s.next()
                if cancel { s.cancel() }
                for _ in 0..<2 {
                    do { _ = try s.next(); Issue.record("Terminal error swallowed") }
                    catch let e as JSONTransformFailure { #expect(e.category == (cancel ? .cancelled : .resource)) }
                }
                throw SelectionTestError.sentinel
            }
            Issue.record("Failed invocation certified")
        } catch let e as JSONTransformFailure { #expect(e.category == (cancel ? .cancelled : .resource)) }
        let s = try #require(scope)
        let bytes = try withExtendedLifetime(output) { try s.report()[.retainedBytes] }
        #expect(bytes > 4096); output = nil
        #expect(try s.report()[.retainedBytes] == 0)
    }
}

@Test func selectionS10ProviderEOFNullErrorAndNoFurtherPullsRemainDistinct() throws {
    var calls = 0
    let empty = try selectionPlan("inputs").withSelection(population: [], source: { calls += 1; return nil }) { s in let eof = try s.next(); #expect(eof == nil) }
    #expect(calls == 1 && empty.completion.outputCount == 0)
    calls = 0
    refusal(.invalidPosition) {
        _ = try selectionPlan("input").withSelection(population: [1], source: { calls += 1; return .null }) { s in
            for _ in 0..<2 { refusal(.invalidPosition) { _ = try s.next() } }
        }
    }
    #expect(calls == 1)
    calls = 0
    do {
        _ = try selectionPlan("try input catch 0").withSelection(population: [1], source: { calls += 1; throw SelectionTestError.sentinel }) { s in
            for _ in 0..<2 {
                do { _ = try s.next(); Issue.record("Provider failure swallowed") }
                catch let e as JSONTransformFailure { #expect(e.category == .provider && e.code == "providerFailed") }
            }
        }
        Issue.record("Provider error certified")
    } catch let e as JSONTransformFailure { #expect(e.category == .provider) }
    #expect(calls == 1)
}

@Test func selectionS11ReentryAndProviderCancellationUseSafeEntrySnapshots() throws {
    for cancel in [false,true] {
        var escaped: JSONTransformSelectionScope?, calls = 0
        do {
            _ = try selectionPlan("input").withSelection(population: [42], source: {
                calls += 1
                if let s = escaped {
                    let report = try s.report(); #expect(report[.workUnits] == s.used(.workUnits))
                    #expect(s.remainingWorkUnits > 0)
                    if cancel { s.cancel() }
                    else {
                        do { _ = try s.next(); Issue.record("Provider reentry accepted") }
                        catch let e as JSONTransformFailure { #expect(e.code == "reentrantSelection") }
                    }
                }
                return 0
            }) { s in
                escaped = s
                do { _ = try s.next(); Issue.record("Provider ignored terminal health") }
                catch let e as JSONTransformFailure { #expect(e.category == (cancel ? .cancelled : .configuration)) }
            }
            Issue.record("Caught provider failure certified")
        } catch let e as JSONTransformFailure { #expect(e.category == (cancel ? .cancelled : .configuration)) }
        #expect(calls == 1)
        #expect(try #require(escaped).report()[.retainedBytes] == 0)
    }
}

@Test func selectionS12CallerErrorAndEscapedClosuresReleaseProviderWithoutCompletion() throws {
    final class Source { var calls = 0; func next() -> JSON? { calls += 1; return 0 } }
    weak var weakSource: Source?
    var scope: JSONTransformSelectionScope?, closure: (() throws -> JSONTransformSelectionPosition?)?
    do {
        let source = Source(); weakSource = source
        do {
            _ = try selectionPlan("input").withSelection(population: [42], source: { source.next() }) { s in
                scope = s; closure = { try s.next() }; throw SelectionTestError.sentinel
            }
            Issue.record("Caller error lost")
        } catch let e as SelectionTestError { #expect(e == .sentinel) }
    }
    #expect(weakSource == nil)
    do { _ = try closure?(); Issue.record("Escaped closure resumed") }
    catch let e as JSONTransformFailure { #expect(e.code == "scopeClosed") }
    #expect(try #require(scope).report()[.retainedBytes] == 0)
}

@Test func selectionSharedImmutablePlanHasIndependentPopulationAndFailureHealth() async throws {
    let plan = try selectionPlan(".[]")
    let results = try await withThrowingTaskGroup(of: [UInt64].self) { group in
        for size in 0..<6 {
            group.addTask {
                var policy = JSONTransformSelectionLimits()
                if size == 5 { policy.transform[.results] = 0 }
                do {
                    let report = try plan.withSelection(population: Array(repeating: .null, count: size), limits: policy) { s in
                        var ids: [UInt64] = []; while let p = try s.next() { ids.append(p.ordinal) }; return ids
                    }
                    #expect(size != 5 && report.completion.populationCount == UInt64(size)); return report.result
                } catch let e as JSONTransformFailure { #expect(size == 5 && e.category == .resource); return [99] }
            }
        }
        var result: [[UInt64]] = []; for try await row in group { result.append(row) }; return result
    }
    #expect(results.count == 6 && results.contains([99]) && results.contains([0,1,2,3]))
}

@Test func selectionS13InnerProjectionTaskCancellationReleasesUnpublishedPreparation() async throws {
    let plan = try selectionPlan(".[]")
    let handle = Mutex<Task<UInt64, any Error>?>(nil), ready = Mutex<CheckedContinuation<Void, Never>?>(nil)
    let observed = Mutex<UInt64>(0)
    let task = Task<UInt64, any Error> {
        await withCheckedContinuation { continuation in ready.withLock { $0 = continuation } }
        var policy = JSONTransformSelectionLimits()
        policy.projectionObserver = { count in
            if count == 4 { observed.withLock { $0 = count }; handle.withLock { $0?.cancel() } }
        }
        var failed: JSONTransformSelectionScope?
        do {
            _ = try JSONTransformSelectionScope.make(plan: plan, values: Array(repeating: .null, count: 32), bindings: [:], limits: policy, source: nil, observing: { failed = $0 })
            Issue.record("Projection ignored task cancellation")
        } catch let e as JSONTransformFailure { #expect(e.category == .cancelled) }
        return try #require(failed).report()[.retainedBytes]
    }
    handle.withLock { $0 = task }
    var continuation: CheckedContinuation<Void, Never>?
    while continuation == nil { continuation = ready.withLock { $0 }; if continuation == nil { await Task.yield() } }
    continuation?.resume()
    #expect(try await task.value == 0)
    #expect(observed.withLock { $0 } == 4)
}

@Test func selectionS14FailedPreparationAndCompletionAllocationsRefundExactBoundaries() throws {
    let plan = try selectionPlan("empty")
    var failed: JSONTransformSelectionScope?
    var policy = JSONTransformSelectionLimits(); policy.transform[.collectionValues] = 3
    do {
        _ = try JSONTransformSelectionScope.make(plan: plan, values: [1,2], bindings: [:], limits: policy, source: nil, observing: { failed = $0 })
        Issue.record("Partial projection admitted")
    } catch let e as JSONTransformFailure { #expect(e.category == .resource && e.metric == "collectionValues") }
    #expect(try #require(failed).report()[.retainedBytes] == 0)
    let base = try select("empty", [])
    policy = .init(); policy.transform[.workUnits] = base.completion.statistics[.workUnits] - 1
    var closed: JSONTransformSelectionScope?
    do {
        _ = try selectionPlan("empty").withSelection(population: [], limits: policy) { s in
            closed = s; let eof = try s.next(); #expect(eof == nil)
        }
        Issue.record("Completion exceeded work budget")
    } catch let e as JSONTransformFailure { #expect(e.category == .resource) }
    #expect(try #require(closed).report()[.retainedBytes] == 0)
}

@Test func selectionS15LanguageCatchesRemainOrdinaryAndUncaughtFailuresStayTerminal() throws {
    #expect(try select("try error(\"expected\") catch 0", [42]).result.first?.ordinal == 0)
    var scope: JSONTransformSelectionScope?
    do {
        _ = try selectionPlan("0,error(\"expected\")").withSelection(population: [42]) { s in
            scope = s; let p = try s.next(); #expect(p?.ordinal == 0)
            for _ in 0..<2 {
                do { _ = try s.next(); Issue.record("Language failure reopened") }
                catch let e as JSONTransformFailure { #expect(e.category == .language) }
            }
        }
        Issue.record("Uncaught language failure certified")
    } catch let e as JSONTransformFailure { #expect(e.category == .language) }
    #expect(try #require(scope).report()[.retainedBytes] == 0)
}
