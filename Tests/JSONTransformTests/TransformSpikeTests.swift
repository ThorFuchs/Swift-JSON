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

@Test func jtxReentrantProviderFailureLatchesWithoutAccessConflict() throws {
    let plan = try JSONTransformProgram.compile("try inputs catch null")
    var handle: JSONTransformExecution?
    var calls = 0
    do {
        _ = try plan.withExecution(input: .null, source: {
            calls += 1
            do { _ = try handle!.next(); Issue.record("Expected re-entry rejection") }
            catch let error as JSONTransformFailure { #expect(error.category == .configuration && error.code == "reentrantExecution") }
            return 1 // Catching the error must not publish this value.
        }) { execution in
            handle = execution
            for _ in 0..<2 {
                do { _ = try execution.next(); Issue.record("Expected terminal re-entry failure") }
                catch let error as JSONTransformFailure { #expect(error.code == "reentrantExecution") }
            }
        }
        Issue.record("Expected terminal scope failure")
    } catch let error as JSONTransformFailure { #expect(error.code == "reentrantExecution") }
    #expect(calls == 1 && handle?.statistics[.retainedBytes] == 0)
}
@Test func jtxProviderCanObserveSnapshotAndCancelAfterOwnedProgress() throws {
    let plan = try JSONTransformProgram.compile("inputs")
    var handle: JSONTransformExecution?
    var calls = 0
    do {
        _ = try plan.withExecution(input: .null, source: {
            calls += 1
            let execution = handle!
            #expect(execution.statistics.domain == .core)
            #expect(execution.used(.workUnits) == execution.statistics[.workUnits])
            #expect(execution.statistics[.workUnits] > 0 && execution.remainingWorkUnits > 0)
            #expect(execution.used(.inputValues) == 1)
            execution.cancel()
            return 1
        }) { execution in
            handle = execution
            _ = try execution.next()
        }
        Issue.record("Expected callback cancellation")
    } catch let error as JSONTransformFailure { #expect(error.category == .cancelled) }
    #expect(calls == 1 && handle?.used(.results) == 0 && handle?.statistics[.retainedBytes] == 0)
}
@Test func jtxTaskCancellationIsObservedAfterProviderOwnedProgress() async throws {
    let plan = try JSONTransformProgram.compile("inputs")
    let checked = await Task {
        var handle: JSONTransformExecution?
        var calls = 0
        do {
            _ = try plan.withExecution(input: .null, source: {
                calls += 1
                withUnsafeCurrentTask { $0?.cancel() }
                return 1
            }) { execution in handle = execution; _ = try execution.next() }
            return false
        } catch let failure as JSONTransformFailure {
            return failure.category == .cancelled && calls == 1 && handle?.used(.results) == 0 && handle?.statistics[.retainedBytes] == 0
        } catch { return false }
    }.value
    #expect(checked)
}
@Test func jtxReportsUseCoreDomainAndCallerErrorRetainsIdentity() throws {
    enum CallerError: Error, Equatable { case sentinel }
    let plan = try JSONTransformProgram.compile(".")
    var limits = JSONTransformLimits(); limits[.workUnits] = 4096
    var work: UInt64 = 0
    let report = try plan.withExecution(input: 1, limits: limits) { execution in
        _ = try execution.next(); _ = try execution.next()
        work = execution.used(.workUnits)
        #expect(execution.remainingWorkUnits == 4096 - work)
    }
    #expect(report.statistics.domain == .core && report.statistics[.workUnits] == work)
    #expect(report.statistics[.retainedBytes] == 0)
    var escaped: JSONTransformExecution?
    do {
        _ = try plan.withExecution(input: .array([1,2])) { execution in
            escaped = execution
            _ = try execution.next()
            throw CallerError.sentinel
        }
        Issue.record("Expected caller error")
    } catch let error as CallerError { #expect(error == .sentinel) }
    #expect(escaped?.statistics[.retainedBytes] == 0)
}
@Test func jtxRuntimeCapsRejectBeforePublishingAndRemainTyped() throws {
    for metric in [JSONTransformLimits.Metric.frames, .bindings, .retainedBytes, .workUnits] {
        let plan = try JSONTransformProgram.compile("$v", variables: ["v"])
        var limits = JSONTransformLimits(); limits[metric] = 0
        do {
            _ = try plan.withExecution(input: .null, bindings: ["v": 1], limits: limits) { execution in try execution.next() }
            Issue.record("Expected finite runtime cap")
        } catch let error as JSONTransformFailure {
            #expect(error.category == .resource && error.metric == metric.rawValue && error.limit == 0)
        }
    }
    var invalid = JSONTransformLimits(); invalid[.results] = UInt64.max
    do { _ = try JSONTransformProgram.compile(".", limits: invalid); Issue.record("Expected finite policy") }
    catch let error as JSONTransformFailure { #expect(error.category == .configuration) }
}
@Test func jtxPublicEngineMatchesNativeExactDialectMatrix() throws {
    let rows: [(String,String,String)] = [
        (".a,.b", "{\"a\":1,\"b\":2}", "[1,2]"),
        (".missing,.present", "{\"present\":null}", "[null,null]"),
        ("map(.+1)", "[1,2]", "[[2,3]]"),
        ("map_values(.+1)", "{\"a\":1}", "[{\"a\":2}]"),
        (".[] | select(.>1)", "[1,2,3]", "[2,3]"),
        ("sort_by(.k)", "[{\"k\":2,\"v\":0},{\"k\":1},{\"k\":2,\"v\":1}]", "[[{\"k\":1},{\"k\":2,\"v\":0},{\"k\":2,\"v\":1}]]"),
        ("group_by(.)", "[2,1,2]", "[[[1],[2,2]]]"),
        ("unique", "[2,1,2]", "[[1,2]]"),
        ("first(.[]),last(.[])", "[1,2]", "[1,2]"),
        ("reduce .[] as $n (0; .+$n)", "[1,2,3]", "[6]"),
        ("foreach .[] as $n (0; .+$n)", "[1,2,3]", "[1,3,6]"),
        (".a += 2", "{\"a\":1}", "[{\"a\":3}]"),
        ("setpath([\"a\"];2)", "{}", "[{\"a\":2}]"),
        ("def inc: .+1; inc", "2", "[3]"),
        (". as $x | $x+1", "2", "[3]"),
        ("walk(if type == \"number\" then .+1 else . end)", "{\"a\":[1]}", "[{\"a\":[2]}]"),
        (".[1:3]", "\"e\\u0301x\"", "[\"\\u0301x\"]"),
        (". < \"z\"", "\"é\"", "[false]"),
        ("{a:1,a:2}", "null", "[{\"a\":2}]"),
        ("-0,1.00", "null", "[0,1]"),
    ]
    for (query, input, expected) in rows {
        #expect(try values(query, input: JSON.parse(input)) == JSON.parse(expected).arrayValue!, "\(query)")
    }
}

@Test func jtxBindingNamesUseTheCompilerIdentifierGrammar() throws {
    for name in ["", "é", "a-b", "$x", "1a"] {
        do { _ = try JSONTransformProgram.compile(".", variables: [name]); Issue.record("Expected invalid variable name") }
        catch let error as JSONTransformFailure { #expect(error.category == .configuration && error.code == "invalidVariableName") }
    }
    let plan = try JSONTransformProgram.compile("$a_1", variables: ["a_1"])
    let report = try plan.withExecution(input: .null, bindings: ["a_1": 7]) { execution in try execution.next()?.value }
    #expect(report.result == 7)
}
