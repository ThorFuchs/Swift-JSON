// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
@testable import JSON

@Test(arguments: ["1", "1.0", "1e0", "10e-1"])
func equivalentDecimalSpellings(text: String) throws {
    let value = try JSONNumber(parsing: text)
    #expect(value == JSONNumber(integer: 1))
    #expect(value.hashValue == JSONNumber(integer: 1).hashValue)
    #expect(try value.integer(as: Int64.self) == 1)
}
@Test(arguments: ["-0", "0.0", "-0e10"])
func negativeZeroHasOneIdentity(text: String) throws {
    let value = try JSONNumber(parsing: text)
    #expect(value == JSONNumber(integer: 0))
    #expect(!value.isNegative)
    #expect(try value.numericText() == "0")
}
@Test func machineIntegerBoundaries() throws {
    #expect(try JSONNumber(parsing: "9007199254740993").integer(as: Int64.self) == 9_007_199_254_740_993)
    #expect(try JSONNumber(parsing: "-9223372036854775808").integer(as: Int64.self) == Int64.min)
    #expect(try JSONNumber(parsing: "9223372036854775807").integer(as: Int64.self) == Int64.max)
    #expect(try JSONNumber(parsing: "18446744073709551615").integer(as: UInt64.self) == UInt64.max)
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: "18446744073709551616").integer(as: UInt64.self) }
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: "-1").integer(as: UInt64.self) }
}
@Test func binaryConversionProvesActualEquality() throws {
    #expect(try JSONNumber(parsing: "0.5").doubleValue() == 0.5)
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: "0.1").doubleValue() }
    #expect(try JSONNumber(parsing: "0.1").doubleValue(policy: .rounded) == 0.1)
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: "9007199254740993").doubleValue() }
    #expect(throws: JSONFailure.self) { try JSONNumber.fromFiniteDouble(.infinity) }
}
@Test func decimalConversionIsExact() throws {
    #expect(try JSONNumber(parsing: "0.1").decimalValue() == Decimal(string: "0.1")!)
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: "123456789012345678901234567890123456789012345").decimalValue() }
}
@Test func hugeExponentHasCompactStorageAndOutput() throws {
    let value = try JSONNumber(parsing: "1e1000000")
    #expect(try value.numericText() == "1e1000000")
    #expect(throws: JSONFailure.self) { try value.integer(as: Int64.self) }
}
@Test(arguments: ["", "+1", "01", "-", "1.", ".1", "1e", "1e+", "NaN", "1 2"])
func numberGrammarIsStrict(text: String) {
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: text) }
}
@Test func rawDigitsAndNumericWorkRemainBounded() throws {
    var limits = JSONLimits.balanced
    limits[.numberDigits] = 3
    #expect(throws: JSONFailure.self) { try JSONNumber(parsing: "1.000", limits: limits) }
    limits[.numericWorkUnits] = 2
    do { _ = try JSONNumber(parsing: "123", limits: limits); Issue.record("Work must fail") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .numericWorkUnits) }
}
@Test(arguments: [("0.3", "0.1", true), ("1", "0.3", false), ("12.5", "0.5", true), ("-6", "3", true), ("1e1000000", "2", true), ("0", "0.03", true)])
func exactDivisibilityUsesDecimalMathematics(a: String, b: String, expected: Bool) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaEvaluation)
    let lhs = try JSONNumber.parse(a.utf8, meter: &meter), rhs = try JSONNumber.parse(b.utf8, meter: &meter)
    #expect(try lhs.isMultiple(of: rhs, meter: &meter) == expected)
}
@Test func divisibilityAndExponentAdjustmentHaveStructuredBoundaries() throws {
    var limits = JSONLimits.balanced; limits[.numericWorkUnits] = 100
    var meter = try JSONWorkMeter(limits: limits, domain: .schemaEvaluation)
    let lhs = try JSONNumber.parse("1e1000".utf8, meter: &meter), rhs = try JSONNumber.parse("3".utf8, meter: &meter)
    #expect(throws: JSONFailure.self) { try lhs.isMultiple(of: rhs, meter: &meter) }
    limits = .balanced; limits[.absoluteExponent] = UInt64(Int.max) - 1
    do {
        _ = try JSONNumber(parsing: "0.001e-9223372036854775806", limits: limits)
        Issue.record("Checked exponent subtraction must reject overflow")
    } catch let failure as JSONFailure { #expect(failure.code == .counterOverflow && failure.resource?.metric == .absoluteExponent) }
}

@Test func boundedBinaryBridgePreservesLongHalfwayAndSubnormalTails() throws {
    let halfway = "1.00000000000000011102230246251565404236316680908203125"
    let above = halfway + String(repeating: "0",count: 2000) + "1"
    #expect(try JSONNumber(parsing: halfway).doubleValue(policy: .rounded) == 1)
    #expect(try JSONNumber(parsing: above).doubleValue(policy: .rounded) == 1.nextUp)
    #expect(try JSONNumber(parsing: "-"+above).doubleValue(policy: .rounded) == -1.nextUp)
    let floatHalf = "1.000000059604644775390625"
    #expect(try JSONValueDecoder().decode(Float.self,from: .number(JSONNumber(parsing: floatHalf))) == 1)
    #expect(try JSONValueDecoder().decode(Float.self,from: .number(JSONNumber(parsing: floatHalf + String(repeating: "0",count: 2000) + "1"))) == Float(1).nextUp)
    let number = try JSONNumber(parsing: above)
    var meter = try JSONWorkMeter(limits: .balanced,domain: .core)
    let text = try number.binaryConversionText(meter: &meter)
    #expect(text.utf8.count <= 822)
    #expect(throws: JSONFailure.self) { try number.doubleValue() }
    let decoded = try JSONValueDecoder().decode(Double.self,from: .number(number))
    #expect(decoded == 1.nextUp)
    // Independent exact fixture: coefficient 5^1075 with decimal exponent -1075.
    let minSubnormalHalf = "24703282292062327208828439643411068618252990130716238221279284125033775363510437593264991818081799618989828234772285886546332835517796989819938739800539093906315035659515570226392290858392449105184435931802849936536152500319370457678249219365623669863658480757001585769269903706311928279558551332927834338409351978015531246597263579574622766465272827220056374006485499977096599470454020828166226237857393450736339007967761930577506740176324673600968951340535537458516661134223766678604162159680461914467291840300530057530849048765391711386591646239524912623653881879636239373280423891018672348497668235089863388587925628302755995657524455507255189313690836254779186948667994968324049705821028513185451396213837722826145437693412532098591327667236328125"
    let half = minSubnormalHalf + "e-1075"
    let beyond = minSubnormalHalf + String(repeating: "0",count: 1000) + "1e-2076"
    #expect(try JSONNumber(parsing: half).doubleValue(policy: .rounded) == 0)
    #expect(try JSONNumber(parsing: beyond).doubleValue(policy: .rounded) == Double.leastNonzeroMagnitude)
    var limits = JSONLimits.balanced; limits[.numericWorkUnits] = 100
    #expect(throws: JSONFailure.self) { try number.doubleValue(policy: .rounded,limits: limits) }
}
