// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONFilterRuntime

@Test(arguments: CLIResourceMetric.allCases)
func cliEveryCounterHasInclusiveCheckedBoundaryAndTerminalFailure(metric: CLIResourceMetric) throws {
    var limits = CLILimits(); limits[metric] = 3
    var context = try CLIJobContext(limits: limits)
    try context.charge(metric, 3)
    #expect(context.used(metric) == 3)
    do { try context.charge(metric); Issue.record("Expected cap+1 rejection") }
    catch let error as CLIError { #expect(error.category == .resource && error.metric == metric.rawValue) }
    #expect(throws: CLIError.self) { try context.checkpoint() }
}
@Test(arguments: [CLIResourceMetric.querySourceBytes, .queryTokens, .astNodes, .queryDepth])
func cliCompilerEnforcesCapsAtActualSourceTokenAndIRGrowth(metric: CLIResourceMetric) throws {
    var limits = CLILimits(); limits[metric] = 1
    var allowed = try CLIJobContext(limits: limits)
    let program = try FilterCompiler.compile(".", context: &allowed)
    #expect(program.nodes.count == 1)
    limits[metric] = 0
    var blocked = try CLIJobContext(limits: limits)
    do { _ = try FilterCompiler.compile(".", context: &blocked); Issue.record("Expected actual compiler admission failure") }
    catch let failure as CLIError { #expect(failure.category == .resource && failure.metric == metric.rawValue) }
}
@Test func cliParserDepthUsesConfiguredWorkStackAndRejectsWithoutRecursion() throws {
    var limits = CLILimits(); limits[.queryDepth] = 64
    var context = try CLIJobContext(limits: limits)
    let source = String(repeating: "(", count: 65) + "." + String(repeating: ")", count: 65)
    do { _ = try FilterCompiler.compile(source, context: &context); Issue.record("Expected depth cap") }
    catch let failure as CLIError { #expect(failure.metric == "queryDepth") }
}
@Test func cliRuntimeFramesAndBindingsAreLiveOwnedCaps() throws {
    var limits = CLILimits(); limits[.runtimeFrames] = 0
    var context = try CLIJobContext(limits: limits)
    let program = try FilterCompiler.compile(".", context: &context)
    do { _ = try FilterVM(program: program, input: .init(value: .null), context: &context); Issue.record("Expected frame cap before growth") }
    catch let failure as CLIError { #expect(failure.metric == "runtimeFrames") }
}
@Test func cliQueryPlanIsImmutableAndCheckedSendable() throws {
    func requireSendable<T: Sendable>(_ value: T) {}
    var context = try CLIJobContext()
    let program = try FilterCompiler.compile(".a, .b", context: &context)
    requireSendable(program)
    #expect(program.nodes.count > 1 && program.sourceRanges.count == program.nodes.count)
}

@Test func cliQueryOperationalFailureBypassesTryAndCleansInvocationStorage() throws {
    var compilation = try CLIJobContext()
    let program = try FilterCompiler.compile("try [1,2,3] catch null", context: &compilation)
    var limits = CLILimits(); limits[.collectionValues] = 2
    var context = try CLIJobContext(limits: limits)
    let baseline = context.meter.used(.retainedBytes)
    var vm = try FilterVM(program: program, input: .init(value: .null), context: &context)
    struct NoInput: FilterInput { mutating func next(context: inout CLIJobContext) throws -> FilterYield? { nil } }
    var input = NoInput()
    do { _ = try vm.next(input: &input, context: &context); Issue.record("Resource failure must not become catch null") }
    catch let failure as CLIError { #expect(failure.category == .resource && failure.metric == "collectionValues") }
    try vm.close(context: &context)
    #expect(context.used(.runtimeFrames) == 0 && context.used(.collectionValues) == 0)
    #expect(context.meter.used(.retainedBytes) == baseline)
    #expect(throws: CLIError.self) { try context.checkpoint() }
}
@Test func cliQueryCancellationHappensInsideOwnedEvaluationAndCleansFrames() async throws {
    var compilation = try CLIJobContext()
    let program = try FilterCompiler.compile(".[]", context: &compilation)
    let task = Task {
        var context = try CLIJobContext()
        let baseline = context.meter.used(.retainedBytes)
        var value = try FilterValues.produced(.array((0..<100).map { .number(JSONNumber(integer: $0)) }), context: &context)
        var vm = try FilterVM(program: program, input: value, context: &context)
        try value.release(context: &context)
        struct NoInput: FilterInput { mutating func next(context: inout CLIJobContext) throws -> FilterYield? { nil } }
        var input = NoInput()
        var pending = try vm.next(input: &input, context: &context)
        var first = try #require(pending); pending = nil
        try first.release(context: &context)
        context.meter.checkpointObserver = { _ in withUnsafeCurrentTask { $0?.cancel() } }
        #expect(throws: CancellationError.self) { _ = try vm.next(input: &input, context: &context) }
        try vm.close(context: &context)
        #expect(context.used(.runtimeFrames) == 0 && context.used(.collectionValues) == 0)
        #expect(context.meter.used(.retainedBytes) == baseline)
    }
    try await task.value
}

@Test func cliQueryConstructorsAndSelectorsReleaseScratchAfterMidOperationFailure() throws {
    let object = try JSONParser().parse(Array("{\"a\":1,\"b\":2,\"c\":3,\"d\":4,\"e\":5,\"f\":6}".utf8))
    let array = JSON.array((0..<20).map { .number(JSONNumber(integer: $0)) })
    struct NoInput: FilterInput { mutating func next(context: inout CLIJobContext) throws -> FilterYield? { nil } }
    for (source, value) in [("keys", object), (".[1:15]", array), ("map_values(.)", object), ("{a: .a,b: .b}", object), ("try error(.) catch .", object)] {
        var compilation = try CLIJobContext()
        let program = try FilterCompiler.compile(source, context: &compilation)
        var rejected = 0
        for cap: UInt64 in [360, 720, 1440, 2880] {
            var limits = CLILimits(); limits[.retainedBytes] = cap
            var context = try CLIJobContext(limits: limits)
            var vm = try FilterVM(program: program, input: .init(value: value), context: &context)
            var input = NoInput()
            do { while var result = try vm.next(input: &input, context: &context) { try result.release(context: &context) } }
            catch { rejected += 1 }
            try vm.close(context: &context)
            #expect(context.used(.runtimeFrames) == 0 && context.used(.collectionValues) == 0)
            #expect(context.meter.used(.retainedBytes) == 0, "\(source) cap=\(cap)")
        }
        #expect(rejected > 0)
    }
}
