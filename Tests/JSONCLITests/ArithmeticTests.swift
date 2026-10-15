// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONCLIEngine
@testable import JSONFilterRuntime

private struct ArithmeticEmptyInput: FilterInput { mutating func next(context: inout CLIJobContext) throws -> FilterYield? { nil } }
private func numericQuery(_ source: String, scale: Int? = nil) throws -> [JSON] {
    var context = try CLIJobContext(); context.divisionScale = scale
    let program = try FilterCompiler.compile(source, context: &context)
    var vm = try FilterVM(program: program, input: .init(value: .null), context: &context)
    defer { try? vm.close(context: &context) }
    var input = ArithmeticEmptyInput(), values: [JSON] = []
    while var value = try vm.next(input: &input, context: &context) { values.append(value.value); try value.release(context: &context) }
    return values
}
@Test func cliArithmeticMatchesIndependentIntegerRationalOracle() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/CLI/ArithmeticOracle.json")
    let root = try JSONParser().parse(Array(Data(contentsOf: url)))
    guard case .object(let fixture) = root, case .array(let cases) = fixture[JSONKey("cases")] else { Issue.record("Missing oracle fixture"); return }
    #expect(cases.count == 738)
    for row in cases {
        guard case .object(let item) = row, case .string(let op) = item[JSONKey("op")], case .string(let lhs) = item[JSONKey("lhs")], case .string(let expected) = item[JSONKey("expected")] else { Issue.record("Malformed oracle row"); continue }
        var context = try CLIJobContext()
        if case .number(let scale) = item[JSONKey("scale")] { context.divisionScale = try scale.integer(as: Int.self, meter: &context.meter) }
        var result: FilterYield
        if case .string(let rhs) = item[JSONKey("rhs")] { result = try ExactDecimal.binary(op, JSONNumber(parsing: lhs), JSONNumber(parsing: rhs), context: &context) }
        else { result = try ExactDecimal.unary(op, JSONNumber(parsing: lhs), context: &context) }
        guard case .number(let actual) = result.value else { Issue.record("Non-number arithmetic result"); continue }
        #expect(try actual.compare(to: JSONNumber(parsing: expected), meter: &context.meter) == .orderedSame, "\(op) \(lhs) expected \(expected)")
        #expect(actual.originalLexeme == nil)
        if case .number(let rounded) = item[JSONKey("rounded")] { #expect(context.roundedDivisions == (try rounded.integer(as: UInt64.self, meter: &context.meter))) }
        try result.release(context: &context)
        #expect(context.meter.used(.retainedBytes) == 0)
    }
}
@Test func cliArithmeticOperatorsKeepCartesianOrderAndPipelinePrecedence() throws {
    var argvContext = try CLIJobContext()
    let argv = try CLIArguments(["query","--","-7%3"], context: &argvContext)
    #expect(argv.positionals == ["-7%3"])
    #expect(try numericQuery("(1,2)+(10,20)") == [.number(11),.number(12),.number(21),.number(22)])
    #expect(try numericQuery("1,2 | .+10") == [.number(11),.number(12)])
    #expect(try numericQuery("+(-0), -(-0), 0*1e1000000") == [.number(0),.number(0),.number(0)])
    #expect(try numericQuery("{\"é\":1,\"é\":2} | .\"é\", .\"é\"") == [.number(1),.number(2)])
}
@Test func cliArithmeticLanguageErrorsAreCatchableAndRoundedPolicyExplicit() throws {
    #expect(try numericQuery("try (1/3) catch .") == [.string("inexactDivision")])
    #expect(try numericQuery("try (1/0) catch .") == [.string("divisionByZero")])
    #expect(try numericQuery("try (1.5%1) catch .") == [.string("integralOperandsRequired")])
    #expect(try numericQuery("1/8,3/8,-1/8", scale: 2) == [.number(JSONNumber(parsing:"0.12")),.number(JSONNumber(parsing:"0.38")),.number(JSONNumber(parsing:"-0.12"))])
    #expect(try numericQuery("1e-1000000/3", scale: 2) == [.number(0)])
    #expect(try numericQuery("2.5|round") == [.number(3)])
    #expect(try numericQuery("2.5/1", scale: 0) == [.number(2)])
}
@Test func cliArithmeticNonNumericOverloadsPreserveScalarAndContainerIdentity() throws {
    #expect(try numericQuery("\"é\"+\"é\"") == [.string("éé")])
    #expect(try numericQuery("[1,2,3,2]-[2]") == [.array([.number(1),.number(3)])])
    #expect(try numericQuery("\"éé\"/\"é\"") == [.array([.string(""),.string(""),.string("")])])
    #expect(try numericQuery("\"🦊\"*3") == [.string("🦊🦊🦊")])
    #expect(try numericQuery("({a:{x:1,y:2}}*{a:{y:3,z:4}}).a") == [try JSONParser().parse(Array("{\"x\":1,\"y\":3,\"z\":4}".utf8))])
    #expect(try numericQuery("[1,2,3]|add") == [.number(6)])
    #expect(try numericQuery("[]|add") == [.null])
}
@Test func cliArithmeticRangeIsExactDemandDrivenAndZeroStepErrors() throws {
    #expect(try numericQuery("[range(5;0;-2)]") == [.array([.number(5),.number(3),.number(1)])])
    #expect(try numericQuery("[range(0;0.3;0.1)]") == [.array([.number(0),.number(JSONNumber(parsing:"0.1")),.number(JSONNumber(parsing:"0.2"))])])
    #expect(try numericQuery("try range(0;10;0) catch .") == [.string("zeroRangeStep")])
}
@Test func cliArithmeticExponentGapFailsBeforeDenseAllocationAndCannotBeCaught() throws {
    var compilation = try CLIJobContext()
    let program = try FilterCompiler.compile("try (1e1000000+1) catch null", context: &compilation)
    var context = try CLIJobContext(), input = ArithmeticEmptyInput()
    var vm = try FilterVM(program: program, input: .init(value: .null), context: &context)
    do { _ = try vm.next(input: &input, context: &context); Issue.record("Expected checked dense-growth cap") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .numberDigits) }
    try vm.close(context: &context)
    #expect(context.meter.statistics().peakLogicalRetainedBytes < 20000)
    #expect(context.meter.used(.retainedBytes) == 0)
}

@Test func cliArithmeticActualDigitExponentTokenWorkAndRetentionCapsAreInclusive() throws {
    let a = try JSONNumber(parsing: "99"), b = try JSONNumber(parsing: "99")
    for (metric, boundary, lhs, rhs) in [(JSONResourceMetric.numberDigits, UInt64(4), a, b), (.absoluteExponent, 20, try JSONNumber(parsing:"1e10"), try JSONNumber(parsing:"1e10")), (.numberTokenBytes, 4, a, b)] {
        for allowed in [true,false] {
            var limits = CLILimits(); limits.core[metric] = boundary - (allowed ? 0 : 1)
            var context = try CLIJobContext(limits: limits)
            do {
                var result = try ExactDecimal.binary("*",lhs,rhs,context:&context)
                #expect(allowed); try result.release(context:&context)
            } catch let failure as JSONFailure { #expect(!allowed && failure.category == .resource && failure.resource?.metric == metric) }
            try context.reclaimValueLeases()
            #expect(context.meter.used(.retainedBytes) == 0)
        }
    }
    var measured = try CLIJobContext()
    var value = try ExactDecimal.binary("*",a,b,context:&measured)
    let work = measured.meter.used(.numericWorkUnits), peak = measured.meter.statistics().peakLogicalRetainedBytes
    try value.release(context:&measured)
    for metric in [JSONResourceMetric.numericWorkUnits,.retainedBytes] {
        for allowed in [true,false] {
            var limits = CLILimits(); limits.core[metric] = (metric == .numericWorkUnits ? work : peak) - (allowed ? 0 : 1)
            var context = try CLIJobContext(limits:limits)
            do { var result = try ExactDecimal.binary("*",a,b,context:&context); #expect(allowed); try result.release(context:&context) }
            catch let failure as JSONFailure { #expect(!allowed && failure.category == .resource && failure.resource?.metric == metric) }
            try context.reclaimValueLeases(); #expect(context.meter.used(.retainedBytes) == 0)
        }
    }
}
@Test func cliArithmeticCancellationRendezvousIsInsideLongMultiply() async throws {
    let a = try JSONNumber(parsing:String(repeating:"9",count:300))
    let task = Task {
        var context = try CLIJobContext()
        context.meter.checkpointObserver = { work in if work >= 5000 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws:CancellationError.self) { _ = try ExactDecimal.binary("*",a,a,context:&context) }
        #expect(context.meter.used(.numericWorkUnits) >= 5000)
        try context.reclaimValueLeases(); #expect(context.meter.used(.retainedBytes) == 0)
        #expect(throws:CancellationError.self) { try context.checkpoint() }
    }
    try await task.value
}
@Test func cliArithmeticHostIndexNarrowingIsCheckedAndFiniteConfigurationsStayDistinct() throws {
    var context = try CLIJobContext()
    let count = try JSONNumber(parsing:"18446744073709551616")
    do { _ = try FilterOperators.apply("*",.string("x"),.number(count),context:&context); Issue.record("Expected checked host index overflow") }
    catch let error as CLIError { #expect(error.category == .resource && error.code == "counterOverflow") }
    try context.reclaimValueLeases(); #expect(context.meter.used(.retainedBytes) == 0)
    var limits = CLILimits(); limits.core[.numberDigits] = UInt64(Int.max)-1
    var overflow = try CLIJobContext(limits:limits)
    var buffer: DecimalMagnitude? = try DecimalMagnitude.allocate(10,context:&overflow)
    #expect(buffer?.count == 10); buffer = nil
    try overflow.reclaimValueLeases(); #expect(overflow.meter.used(.retainedBytes) == 0)
    #expect(throws:CLIError.self) { _ = try DecimalMagnitude.allocate(Int.max,context:&overflow) }
}

@Test func cliArithmeticDomainHandoffDrainsDeadScratchBeforeOutputBaseline() throws {
    var context = try CLIJobContext()
    var result = try ExactDecimal.binary("+",JSONNumber(parsing:"0.1"),JSONNumber(parsing:"0.2"),context:&context)
    // The result is live; only dead coefficient drafts may refund here.
    try context.domain(.writing)
    let entry = context.meter.used(.retainedBytes)
    #expect(entry == result.lease?.retained)
    try context.work()
    #expect(context.meter.used(.retainedBytes) == entry)
    try result.release(context:&context)
    #expect(context.meter.used(.retainedBytes) == 0)
}
