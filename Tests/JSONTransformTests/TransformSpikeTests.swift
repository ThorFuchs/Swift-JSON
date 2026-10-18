// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONTransform

private func values(_ source: String, input: JSON = .null) throws -> [JSON] {
    let plan = try JSONTransformProgram.compile(source)
    return try plan.withExecution(input: input) { execution in
        var result: [JSON] = []
        while let output = try execution.next() { result.append(output.value) }
        return result
    }.result
}

@Test func jtxZeroNullAndManyAreDistinctOrderedPullResults() throws {
    #expect(try values("empty").isEmpty)
    #expect(try values("null") == [.null])
    #expect(try values("1,2,3") == [1,2,3])
}
@Test func jtxExactNumbersAndScalarKeysKeepCoreAuthority() throws {
    let big = try JSON.parse("9007199254740994")
    #expect(try values("9007199254740993 + 1, 0.1+0.2") == [big, JSON.parse("0.3")])
    let input = try JSON.parse(#"{"é":1,"e\u0301":2}"#)
    #expect(try values(#".["é"], .["e\u0301"]"#, input: input) == [1,2])
    #expect(try values("length", input: .string("e\u{301}")) == [2])
}
@Test func jtxTypedCompileLocationAndLanguageFailureStayDistinct() throws {
    do { _ = try JSONTransformProgram.compile("["); Issue.record("Expected compilation failure") }
    catch let failure as JSONTransformFailure { #expect(failure.category == .compilation && failure.byteOffset == 0) }
    do { _ = try values("1/3"); Issue.record("Expected nonterminating decimal failure") }
    catch let failure as JSONTransformFailure { #expect(failure.category == .language) }
    #expect(try values("try (1/3) catch null") == [.null])
}
@Test func jtxBindingsAndProviderAreExplicitAndLazy() throws {
    let plan = try JSONTransformProgram.compile("$n, input, inputs", variables: ["n"])
    var pulls = 0
    let result = try plan.withExecution(input: .null, bindings: ["n": 9], source: {
        pulls += 1
        return pulls <= 2 ? .number(JSONNumber(integer: pulls)) : nil
    }) { execution in
        #expect(pulls == 0)
        var outputs: [JSON] = []
        while let output = try execution.next() { outputs.append(output.value) }
        #expect(execution.used(.inputValues) == 3)
        return outputs
    }
    #expect(result.result == [9,1,2] && pulls == 3)
    #expect(result.statistics[.workUnits] > 0)
}
@Test func jtxProviderFailureIsOperationalAndNeverCaughtByLanguageTry() throws {
    struct SourceFailure: Error {}
    let plan = try JSONTransformProgram.compile("try inputs catch null")
    var calls = 0
    do {
        _ = try plan.withExecution(input: .null, source: { calls += 1; throw SourceFailure() }) { execution in
            for _ in 0..<2 {
                do { _ = try execution.next(); Issue.record("Expected provider failure") }
                catch let failure as JSONTransformFailure { #expect(failure.category == .provider) }
            }
            return 0 // Catching the pull error must not make completion successful.
        }
        Issue.record("Expected latched scope failure")
    } catch let failure as JSONTransformFailure { #expect(failure.category == .provider) }
    #expect(calls == 1)
}
@Test func jtxCumulativeProviderAndResultCapsCannotResetPerPull() throws {
    let plan = try JSONTransformProgram.compile("try inputs catch null")
    var limits = JSONTransformLimits(); limits[.inputValues] = 2
    var calls = 0
    do {
        _ = try plan.withExecution(input: .null, limits: limits, source: { calls += 1; return .null }) { execution in
            let first = try execution.next()
            #expect(first?.value == .null && execution.used(.inputValues) == 2)
            return try execution.next()
        }
        Issue.record("Expected cumulative input cap")
    } catch let failure as JSONTransformFailure { #expect(failure.category == .resource && failure.metric == "inputValues") }
    #expect(calls == 2)
    limits = .init(); limits[.results] = 1
    do { _ = try JSONTransformProgram.compile("1,2").withExecution(input: .null, limits: limits) { execution in
        _ = try execution.next(); return try execution.next()
    }; Issue.record("Expected result cap") }
    catch let failure as JSONTransformFailure { #expect(failure.category == .resource && failure.metric == "results") }
}
@Test func jtxResourceErrorBypassesCatchAndLatchesAfterHostCatch() throws {
    let plan = try JSONTransformProgram.compile("try [1,2,3] catch null")
    var limits = JSONTransformLimits(); limits[.collectionValues] = 2
    do {
        _ = try plan.withExecution(input: .null, limits: limits) { execution in
            for _ in 0..<2 {
                do { _ = try execution.next(); Issue.record("Expected resource failure") }
                catch let failure as JSONTransformFailure { #expect(failure.category == .resource && failure.metric == "collectionValues") }
            }
        }
        Issue.record("Expected scope failure")
    } catch let failure as JSONTransformFailure { #expect(failure.category == .resource) }
}
@Test func jtxCancellationLatchesAndStopsProviderCalls() throws {
    let plan = try JSONTransformProgram.compile("inputs")
    var calls = 0
    do {
        _ = try plan.withExecution(input: .null, source: { calls += 1; return .null }) { execution in
            execution.cancel()
            do { _ = try execution.next(); Issue.record("Expected cancellation") }
            catch let failure as JSONTransformFailure { #expect(failure.category == .cancelled) }
        }
        Issue.record("Expected cancellation at completion")
    } catch let failure as JSONTransformFailure { #expect(failure.category == .cancelled) }
    #expect(calls == 0)
}
@Test func jtxSelectedAliasKeepsSourceReservationUntilLastHandleDies() throws {
    let plan = try JSONTransformProgram.compile(".a")
    let root = try JSON.parse("{\"a\":1,\"padding\":\"" + String(repeating: "x", count: 4096) + "\"}")
    _ = try plan.withExecution(input: root) { execution in
        var result = try execution.next()
        #expect(result?.value == 1)
        let retained = execution.statistics[.retainedBytes]
        let end = try execution.next()
        #expect(end == nil)
        #expect(execution.statistics[.retainedBytes] > 4096)
        result = nil
        _ = try execution.next() // Drains ARC notifications, not work refunds.
        #expect(execution.statistics[.retainedBytes] < retained - 4096)
    }
}
@Test func jtxPlanIsSendableAndExecutionsHaveIndependentHealth() async throws {
    let plan = try JSONTransformProgram.compile(". + 1")
    func requireSendable<T: Sendable>(_: T) {}
    requireSendable(plan)
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for n in 0..<16 {
            group.addTask {
                let result = try plan.withExecution(input: .number(JSONNumber(integer: n))) { execution in
                    let output = try execution.next()
                    let end = try execution.next()
                    return output?.value == .number(JSONNumber(integer: n + 1)) && end == nil
                }
                return result.result && result.statistics[.workUnits] > 0
            }
        }
        for try await good in group { #expect(good) }
    }
}
@Test func jtxConfiguredCompilerGrowthHasInclusiveBoundaries() throws {
    for metric in [JSONTransformLimits.Metric.sourceBytes, .tokens, .planNodes, .depth] {
        var limits = JSONTransformLimits(); limits[metric] = 1
        _ = try JSONTransformProgram.compile(".", limits: limits)
        limits[metric] = 0
        do { _ = try JSONTransformProgram.compile(".", limits: limits); Issue.record("Expected compiler cap") }
        catch let failure as JSONTransformFailure { #expect(failure.category == .resource && failure.metric == metric.rawValue) }
    }
}

@Test func jtxCopiedHandlesShareOneCumulativeLedger() throws {
    let plan = try JSONTransformProgram.compile("1,2")
    var limits = JSONTransformLimits(); limits[.results] = 1
    do {
        _ = try plan.withExecution(input: .null, limits: limits) { execution in
            let alias = execution
            let first = try alias.next()
            #expect(first?.value == 1 && execution.used(.results) == 1)
            _ = try execution.next()
        }
        Issue.record("A handle copy must not reset results")
    } catch let failure as JSONTransformFailure { #expect(failure.category == .resource && failure.metric == "results") }
}
@Test func jtxEscapedHandleInvalidatesAndReleasesProvider() throws {
    final class Marker {}
    weak var marker: Marker?
    var escaped: JSONTransformExecution?
    func makeProvider() -> () throws -> JSON? {
        let held = Marker(); marker = held
        return { _ = held; return nil }
    }
    _ = try JSONTransformProgram.compile(".").withExecution(input: .array([1,2]), source: makeProvider()) { execution in
        escaped = execution
        #expect(marker != nil)
        // Early exit deliberately leaves a live VM. Scope exit must clear it.
    }
    #expect(marker == nil)
    let handle = try #require(escaped)
    #expect(handle.statistics[.retainedBytes] == 0)
    do { _ = try handle.next(); Issue.record("Escaped scope accepted data access") }
    catch let failure as JSONTransformFailure { #expect(failure.category == .configuration && failure.code == "scopeClosed") }
}
