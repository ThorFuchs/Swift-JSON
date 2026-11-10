// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
import Synchronization
import JSON
@testable import JSONTransform

private enum DefinitionTestError: Error { case expectedFailure }
private func definitionFailure(_ body: () throws -> Void) throws -> JSONTransformDefinitionFailure {
    do { try body(); Issue.record("Expected definition failure"); throw DefinitionTestError.expectedFailure }
    catch let error as JSONTransformDefinitionFailure { return error }
}
private func definitionResource(_ body: () throws -> Void) throws -> JSONFailure {
    do { try body(); Issue.record("Expected native failure"); throw DefinitionTestError.expectedFailure }
    catch let error as JSONFailure { #expect(error.category == .resource); return error }
}
private let dotDefinition = #"{"definition":"swift-json-transform-source","version":1,"dialect":"swift-json-query-v1","source":".","variables":[]}"#

@Test func bindingD01CanonicalGoldenBytesAndReload() throws {
    let definition = try JSONTransformProgramDefinition.prepare(source: "$z + $a", variables: ["z", "a"])
    let expected = #"{"definition":"swift-json-transform-source","version":1,"dialect":"swift-json-query-v1","source":"$z + $a","variables":["a","z"]}"#
    let bytes = try definition.result.encode()
    #expect(bytes.result == Array(expected.utf8))
    let decoded = try JSONTransformProgramDefinition.decode(bytes.result)
    #expect(decoded.result.variableNames == ["a", "z"])
    #expect(try decoded.result.encode().result == bytes.result)
    #expect(decoded.result.definitionRevision == 1 && decoded.result.dialectRevision == "swift-json-query-v1")
    #expect(decoded.statistics[.workUnits] > definition.statistics[.workUnits])
}

@Test func bindingD02CanonicalEscapingAndExactScalarSource() throws {
    let source = "é e\u{301}\n\t\"\\/"
    let expected = #"{"definition":"swift-json-transform-source","version":1,"dialect":"swift-json-query-v1","source":"é é\u000a\u0009\"\\/","variables":[]}"#
    let a = try JSONTransformProgramDefinition.prepare(source: source).result
    #expect(try a.encode().result == Array(expected.utf8))
    let reload = try JSONTransformProgramDefinition.decode(Array(expected.utf8)).result
    #expect(Array(reload.source.utf8) == Array(source.utf8))
    let composed = try JSONTransformProgramDefinition.prepare(source: "é").result
    let decomposed = try JSONTransformProgramDefinition.prepare(source: "e\u{301}").result
    #expect(try composed.encode().result != decomposed.encode().result)
}

@Test func bindingD03StrictSemanticDecodeCanonicalizesPresentation() throws {
    let input = #" { "variables":[], "source":"\u002e", "dialect":"swift-json-query-v1", "version":1.0, "definition":"swift-json-transform-source" } "#
    let value = try JSONTransformProgramDefinition.decode(Array(input.utf8)).result
    #expect(try value.encode().result == Array(dotDefinition.utf8))
    let reordered = #"{"definition":"swift-json-transform-source","version":1,"dialect":"swift-json-query-v1","source":".","variables":["z","_a","B"]}"#
    #expect(try JSONTransformProgramDefinition.decode(Array(reordered.utf8)).result.variableNames == ["B", "_a", "z"])
}

@Test func bindingD04ClosedFieldsVersionsAndKindsArePrecise() throws {
    for input in ["null", "[]", "{}", dotDefinition.replacingOccurrences(of: "\"version\":1", with: "\"version\":true"),
                  dotDefinition.replacingOccurrences(of: "\"source\":\".\"", with: "\"unknown\":\".\""),
                  dotDefinition.replacingOccurrences(of: "[]}", with: "[],\"extra\":null}"),
                  dotDefinition.replacingOccurrences(of: "[]}", with: "[42]}"),
                  dotDefinition.replacingOccurrences(of: "swift-json-transform-source", with: "other")] {
        #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.decode(Array(input.utf8)) } == .invalidDefinition)
    }
    let version = dotDefinition.replacingOccurrences(of: "\"version\":1", with: "\"version\":2")
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.decode(Array(version.utf8)) } == .unsupportedDefinitionRevision)
    let dialect = dotDefinition.replacingOccurrences(of: "query-v1", with: "query-v2")
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.decode(Array(dialect.utf8)) } == .unsupportedDialectRevision)
}

@Test func bindingD05NativeGrammarAndDuplicateFieldsStayAuthoritative() throws {
    let duplicate = dotDefinition.replacingOccurrences(of: "\"version\":1", with: "\"version\":1,\"ver\\u0073ion\":1")
    do { _ = try JSONTransformProgramDefinition.decode(Array(duplicate.utf8)); Issue.record("Accepted duplicate key") }
    catch let error as JSONFailure { #expect(error.category == .syntax && error.code == .duplicateKey) }
    for bytes in [Array((dotDefinition + "false").utf8), [0xef, 0xbb, 0xbf] + Array(dotDefinition.utf8), [0xff]] {
        do { _ = try JSONTransformProgramDefinition.decode(bytes); Issue.record("Accepted malformed JSON") }
        catch let error as JSONFailure { #expect(error.category == .syntax) }
    }
}

@Test func bindingD06NamesRejectBeforeSetConversion() throws {
    for name in ["", "$x", "é", "K", "a-b", "1a", "a\u{0}"] {
        #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: [name]) } == .invalidVariableName)
    }
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["b","a","b"]) } == .duplicateVariableName)
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["K","K"]) } == .invalidVariableName)
    let bytes = Array(dotDefinition.replacingOccurrences(of: "[]}", with: "[\"a\",\"a\"]}").utf8)
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.decode(bytes) } == .duplicateVariableName)
}

@Test func bindingD07SpecificCapsAreInclusiveAndFinite() throws {
    var limits = JSONTransformDefinitionLimits(); limits.maximumSourceBytes = 1
    _ = try JSONTransformProgramDefinition.prepare(source: ".", limits: limits)
    limits.maximumSourceBytes = 0
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", limits: limits) } == .limitExceeded(metric: "sourceBytes", limit: 0, attempted: 1))
    _ = try JSONTransformProgramDefinition.prepare(source: "", limits: limits)
    limits = .init(); limits.maximumVariableNames = 2
    _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["a","b"], limits: limits)
    limits.maximumVariableNames = 1
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["a","b"], limits: limits) } == .limitExceeded(metric: "variableNames", limit: 1, attempted: 2))
    limits = .init(); limits.maximumNameBytes = 1
    _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["a"], limits: limits)
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["ab"], limits: limits) } == .limitExceeded(metric: "nameBytes", limit: 1, attempted: 2))
    limits = .init(); limits.maximumTotalNameBytes = 2
    _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["a","b"], limits: limits)
    limits.maximumTotalNameBytes = 1
    #expect(try definitionFailure { _ = try JSONTransformProgramDefinition.prepare(source: ".", variables: ["a","b"], limits: limits) } == .limitExceeded(metric: "totalNameBytes", limit: 1, attempted: 2))
    let keys: [WritableKeyPath<JSONTransformDefinitionLimits, UInt64>] = [\.maximumSourceBytes, \.maximumVariableNames, \.maximumNameBytes, \.maximumTotalNameBytes, \.maximumEncodedBytes]
    for key in keys {
        limits = .init(); limits[keyPath: key] = .max
        do { _ = try JSONTransformProgramDefinition.prepare(source: ".", limits: limits); Issue.record("Accepted infinite cap") }
        catch let error as JSONFailure { #expect(error.category == .configuration && error.code == .invalidLimits) }
    }
}

@Test func bindingD08WireAndOwnedWorkRetentionHaveExactBoundaries() throws {
    let definition = try JSONTransformProgramDefinition.prepare(source: ".").result
    let encoded = try definition.encode(); var limits = JSONTransformDefinitionLimits()
    limits.maximumEncodedBytes = UInt64(encoded.result.count)
    #expect(try definition.encode(limits: limits).result == encoded.result)
    #expect(try JSONTransformProgramDefinition.decode(encoded.result, limits: limits).result.source == ".")
    limits.maximumEncodedBytes -= 1
    #expect(try definitionResource { _ = try definition.encode(limits: limits) }.resource?.metric == .outputBytes)
    #expect(try definitionResource { _ = try JSONTransformProgramDefinition.decode(encoded.result, limits: limits) }.resource?.metric == .inputBytes)
    for operation in 0..<3 {
        func run(_ policy: JSONTransformDefinitionLimits) throws -> JSONOperationStatistics {
            if operation == 0 { return try JSONTransformProgramDefinition.prepare(source: "$b", variables: ["b","a"], limits: policy).statistics }
            if operation == 1 { return try JSONTransformProgramDefinition.decode(encoded.result, limits: policy).statistics }
            return try definition.encode(limits: policy).statistics
        }
        let measured = try run(.init())
        for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
            var p = JSONTransformDefinitionLimits()
            let boundary = metric == .workUnits ? measured[metric] : measured.peakLogicalRetainedBytes
            #expect(boundary > 0); p.json[metric] = boundary; _ = try run(p)
            p.json[metric] = boundary - 1
            #expect(try definitionResource { _ = try run(p) }.resource?.metric == metric)
        }
    }
    #expect(encoded.statistics[.retainedBytes] == UInt64(encoded.result.count))
}

@Test func bindingD09CompileReportsPreserveExistingPlanBehaviorAndBudget() throws {
    let report = try JSONTransformProgram.compileWithReport("[$n, .]", variables: ["n"])
    #expect(report.statistics.domain == .core && report.statistics[.workUnits] > 0)
    var limits = JSONTransformLimits(); limits[.workUnits] = report.statistics[.workUnits]
    let old = try JSONTransformProgram.compile("[$n, .]", variables: ["n"], limits: limits)
    for plan in [report.result, old] {
        let result = try plan.withExecution(input: 1, bindings: ["n": 42]) { try $0.next()?.value }
        #expect(result.result == .array([42,1]))
    }
    limits[.workUnits] -= 1
    do { _ = try JSONTransformProgram.compile("[$n, .]", variables: ["n"], limits: limits); Issue.record("Compile reset work") }
    catch let error as JSONTransformFailure { #expect(error.category == .resource && error.metric == "workUnits") }
    let definition = try JSONTransformProgramDefinition.prepare(source: "[$n, .]", variables: ["n"]).result
    #expect(try definition.compile().statistics[.workUnits] > report.statistics[.workUnits])
}

@Test func bindingD10CodecDoesNotInventQueryValidationOrDecimalAuthority() throws {
    let bad = try JSONTransformProgramDefinition.prepare(source: "(").result
    _ = try JSONTransformProgramDefinition.decode(bad.encode().result)
    do { _ = try bad.compile(); Issue.record("Accepted invalid query") }
    catch let error as JSONTransformFailure { #expect(error.category == .compilation) }
    let source = "[9007199254740993,0.1,\"é\"]"
    let definition = try JSONTransformProgramDefinition.prepare(source: source).result
    let reload = try JSONTransformProgramDefinition.decode(definition.encode().result).result
    let plan = try reload.compile().result
    let result = try plan.withExecution(input: .null) { try $0.next()?.value }
    let expected: JSON = .array([.number(try JSONNumber(parsing: "9007199254740993")),
                                .number(try JSONNumber(parsing: "0.1")),.string("e\u{301}")])
    #expect(result.result == expected)
}

@Test func bindingD11CancellationOccursInsideOwnedCodecWork() async throws {
    let handle = Mutex<Task<Void, any Error>?>(nil)
    let ready = Mutex<CheckedContinuation<Void, Never>?>(nil)
    let observed = Mutex<UInt64>(0)
    let task = Task<Void, any Error> {
        await withCheckedContinuation { continuation in ready.withLock { $0 = continuation } }
        var limits = JSONTransformDefinitionLimits()
        limits.checkpointObserver = { work in
            if work >= 32 { observed.withLock { $0 = work }; handle.withLock { $0?.cancel() } }
        }
        _ = try JSONTransformProgramDefinition.prepare(source: String(repeating: "x", count: 4096), limits: limits)
    }
    handle.withLock { $0 = task }
    var continuation: CheckedContinuation<Void, Never>?
    while continuation == nil { continuation = ready.withLock { $0 }; if continuation == nil { await Task.yield() } }
    continuation?.resume()
    do { try await task.value; Issue.record("Owned codec ignored cancellation") } catch is CancellationError {}
    #expect(observed.withLock { $0 } >= 32)
}

@Test func bindingSharedDefinitionAndCompilationHaveIndependentHealth() async throws {
    let definition = try JSONTransformProgramDefinition.prepare(source: ".").result
    let results = try await withThrowingTaskGroup(of: Bool.self) { group in
        for index in 0..<6 { group.addTask {
            if index == 0 {
                var limits = JSONTransformLimits(); limits[.workUnits] = 0
                do { _ = try definition.compile(limits: limits); return false }
                catch let error as JSONTransformFailure { return error.category == .resource }
            }
            let bytes = try definition.encode().result
            let reload = try JSONTransformProgramDefinition.decode(bytes).result
            let plan = try reload.compile().result
            return try plan.withExecution(input: 42) { try $0.next()?.value }.result == 42
        } }
        var values: [Bool] = []; for try await value in group { values.append(value) }; return values
    }
    #expect(results.count == 6 && results.allSatisfy { $0 })
}
