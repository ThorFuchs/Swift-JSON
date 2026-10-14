// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONFilterRuntime

private struct EmptyFilterInput: FilterInput {
    mutating func next(context: inout CLIJobContext) throws -> FilterYield? { nil }
}
private func evaluateFilter(_ source: String, input: String = "null") throws -> [JSON] {
    var context = try CLIJobContext()
    let program = try FilterCompiler.compile(source, context: &context)
    let entry = context.meter.used(.retainedBytes)
    let value = try JSONParser().parse(Array(input.utf8), meter: &context.meter)
    let owned = context.meter.used(.retainedBytes) - entry
    let lease = try CLIValueLease(ownedRetained: owned, context: &context)
    var vm = try FilterVM(program: program, input: .init(value: value, lease: lease), context: &context)
    defer { try? vm.close(context: &context) }
    var input = EmptyFilterInput(), values: [JSON] = []
    while var result = try vm.next(input: &input, context: &context) {
        values.append(result.value)
        try result.release(context: &context)
    }
    return values
}
@Test func cliQueryCommaAndPipeAreOrderedPullStreams() throws {
    #expect(try evaluateFilter("1,2 | .") == [.number(1), .number(2)])
    #expect(try evaluateFilter(".[] | .", input: "[1,2,3]") == [.number(1), .number(2), .number(3)])
    #expect(try evaluateFilter("[1,2,3]") == [.array([.number(1), .number(2), .number(3)])])
}
@Test func cliQueryDecodedScalarKeysAndPresenceStayExact() throws {
    let input = "{\"é\":1,\"é\":2,\"null\":null}"
    #expect(try evaluateFilter(".[\"é\"], .[\"é\"]", input: input) == [.number(1), .number(2)])
    #expect(try evaluateFilter("has(\"null\"),has(\"missing\")", input: input) == [.boolean(true), .boolean(false)])
    #expect(try evaluateFilter(".missing?", input: input) == [.null])
}
@Test func cliQueryWrongTypesAreCatchableButEmptyIsNotNull() throws {
    #expect(try evaluateFilter(".[]?", input: "null").isEmpty)
    #expect(try evaluateFilter("try .[] catch .", input: "null") == [.string("cannotIterate")])
    #expect(try evaluateFilter("empty // 9") == [.number(9)])
    #expect(try evaluateFilter("(false,null,0) // 9") == [.number(0)])
}
@Test func cliQueryLogicalShortCircuitAndBranchesUseOriginalInput() throws {
    #expect(try evaluateFilter("false and error(\"unreachable\")") == [.boolean(false)])
    #expect(try evaluateFilter("true or error(\"unreachable\")") == [.boolean(true)])
    #expect(try evaluateFilter("if (true,false) then . else null end", input: "7") == [.number(7), .null])
    #expect(try evaluateFilter("if . == 0 then 0 elif . == 1 then 2 else 3 end", input: "1") == [.number(2)])
}
@Test func cliQueryMapsKeepAllResultsAndFirstUpdatePolicy() throws {
    #expect(try evaluateFilter("map((.,.))", input: "[1,2]") == [.array([.number(1), .number(1), .number(2), .number(2)])])
    #expect(try evaluateFilter("map_values((.,9))", input: "[1,2]") == [.array([.number(1), .number(2)])])
    #expect(try evaluateFilter("map_values(empty)", input: "[1,2]") == [.array([])])
}
@Test func cliQueryUnicodeLengthCountsScalarsAndRecursiveNullLeaves() throws {
    #expect(try evaluateFilter("length,utf8bytelength", input: "\"é🦊\"") == [.number(3), .number(7)])
    #expect(try evaluateFilter("..", input: "[null,1]") == [.array([.null, .number(1)]), .null, .number(1)])
}
@Test func cliQueryAliasesKeepSourceChargedUntilTheirLastRelease() throws {
    var context = try CLIJobContext()
    let baseline = context.meter.used(.retainedBytes)
    var value = try FilterValues.produced(.array([.string(String(repeating: "x", count: 1000))]), context: &context)
    var alias = value.selecting(value.value.arrayValue![0])
    try value.release(context: &context)
    #expect(context.meter.used(.retainedBytes) > baseline)
    try alias.release(context: &context)
    #expect(context.meter.used(.retainedBytes) == baseline)
}
@Test func cliQueryTerminalQuotaStillReleasesValueStorage() throws {
    var limits = CLILimits(); limits[.totalWorkUnits] = 2000
    var context = try CLIJobContext(limits: limits)
    let baseline = context.meter.used(.retainedBytes)
    var value = try FilterValues.produced(.string("owned"), context: &context)
    do { try context.work(2000); Issue.record("Expected terminal work failure") } catch let failure as CLIError { #expect(failure.category == .resource) }
    try value.release(context: &context)
    #expect(context.meter.used(.retainedBytes) == baseline)
    #expect(throws: CLIError.self) { try context.checkpoint() }
}
@Test func cliQueryObjectsUseCartesianOrderAndExactReplacement() throws {
    let values = try evaluateFilter("{a:(1,2),b:(3,4)}")
    let expected = try ["{\"a\":1,\"b\":3}","{\"a\":1,\"b\":4}","{\"a\":2,\"b\":3}","{\"a\":2,\"b\":4}"].map { try JSONParser().parse($0) }
    #expect(values == expected)
    let replacement = try evaluateFilter("{a:1,b:2,a:3}")
    #expect(replacement[0].objectValue!.members.map(\.key.string) == ["a","b"])
    #expect(replacement[0].objectValue![JSONKey("a")] == .number(3))
    #expect(try evaluateFilter("{\"é\":1,\"é\":2}")[0].objectValue!.count == 2)
}
@Test func cliQuerySlicesUseScalarBoundariesAndCheckedNegativeIndices() throws {
    #expect(try evaluateFilter(".[1:3]", input: "\"é🦊x\"") == [.string("́🦊")])
    #expect(try evaluateFilter(".[-2:]", input: "[1,2,3]") == [.array([.number(2),.number(3)])])
    #expect(try evaluateFilter(".[-1],.[1e1000]", input: "[1,2,3]") == [.number(3),.null])
}
@Test func sharedFilterPlanHasIndependentConcurrentInvocations() async throws {
    var compilation = try CLIJobContext()
    let program = try FilterCompiler.compile(#"def project(f): f|walk(if type=="number" then .+1 else . end);project(.a)|.[]|="v\(.)""#, context: &compilation)
    let outputs = try await withThrowingTaskGroup(of: [JSON].self, returning: [[JSON]].self) { group in
        for _ in 0..<8 {
            group.addTask {
                var context = try CLIJobContext()
                let input = try JSONParser().parse(#"{"a":[1,2]}"#)
                var value = try FilterValues.produced(input, context: &context)
                var vm = try FilterVM(program: program, input: value, context: &context), source = EmptyFilterInput()
                defer { try? vm.close(context: &context) }
                try value.release(context: &context)
                var results: [JSON] = []
                while var result = try vm.next(input: &source, context: &context) { results.append(result.value); try result.release(context: &context) }
                #expect(context.used(.totalWorkUnits) > 0)
                #expect(context.meter.used(.retainedBytes) == 0)
                return results
            }
        }
        var values: [[JSON]] = []
        for try await value in group { values.append(value) }
        return values
    }
    #expect(outputs.count == 8 && outputs.allSatisfy { $0 == [.array([.string("v2"),.string("v3")])] })
}
