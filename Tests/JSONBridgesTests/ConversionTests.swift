// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONBridges

private enum BridgeOutcome<T: Equatable>: Equatable {
    case value(T), failure(JSONFailure), cancelled
}
private func outcome<T: Equatable>(_ body: () throws -> T) throws -> BridgeOutcome<T> {
    do { return .value(try body()) }
    catch let error as JSONFailure { return .failure(error) }
    catch is CancellationError { return .cancelled }
}

@Test func e2TrustedIntegersRetainExactMathematicalValues() throws {
    func check<T: FixedWidthInteger>(_ values: [T]) throws {
        for value in values {
            let n = value.jsonNumber()
            #expect(n == JSONNumber(integer: value))
            #expect(n.originalLexeme == nil)
            #expect(try T(jsonNumber: n) == value)
        }
    }
    try check([Int.min, -1, 0, 1, Int.max])
    try check([UInt64.min, 9_007_199_254_740_992, 9_007_199_254_740_993, UInt64.max])
    try check([Int8.min, -1, 0, Int8.max]); try check([UInt8.min, UInt8.max])
    try check([Int16.min, Int16.max]); try check([UInt16.min, UInt16.max])
    try check([Int32.min, Int32.max]); try check([UInt32.min, UInt32.max])
    #expect((9_007_199_254_740_993 as UInt64).jsonNumber() != (9_007_199_254_740_992 as UInt64).jsonNumber())
}

@Test func e2IntegerProjectionNeverTruncatesOrDefaults() throws {
    for text in ["1.5", "-1", "256", "18446744073709551616", "1e1000000"] {
        let n = try JSONNumber(parsing: text)
        #expect(try outcome { try UInt8(jsonNumber: n) } == outcome { try n.integer(as: UInt8.self) })
        #expect(try outcome { try Int64(jsonNumber: n) } == outcome { try n.integer(as: Int64.self) })
    }
    #expect(throws: JSONFailure.self) { try UInt64(jsonNumber: JSONNumber(parsing: "-1")) }
    #expect(throws: JSONFailure.self) { try Int(jsonNumber: JSONNumber(parsing: "0.1")) }
}

@Test func e2IntegerProjectionQuotaBoundaryMatchesDelegate() throws {
    let n = UInt64.max.jsonNumber()
    for metric in [JSONResourceMetric.numericWorkUnits, .workUnits] {
        for cap in 0...32 {
            var limits = JSONLimits.balanced; limits[metric] = UInt64(cap)
            #expect(try outcome { try UInt64(jsonNumber: n, limits: limits) } == outcome { try n.integer(as: UInt64.self, limits: limits) })
        }
    }
    var limits = JSONLimits.balanced; limits[.numericWorkUnits] = 20
    #expect(try UInt64(jsonNumber: n, limits: limits) == UInt64.max)
    limits[.numericWorkUnits] = 19
    #expect(throws: JSONFailure.self) { try UInt64(jsonNumber: n, limits: limits) }
}

@Test func e2RoundTripTextIsDistinctFromExactBinaryValue() throws {
    let decimalTenth = try JSONNumber(parsing: "0.1")
    let adoptedText = try Double(0.1).jsonNumberFromRoundTripText()
    #expect(adoptedText == decimalTenth)
    #expect(throws: JSONFailure.self) { try Double(jsonNumber: adoptedText) }
    #expect(try Double(jsonNumber: adoptedText, policy: .rounded) == 0.1)
    #expect(String(Float(0.1)) == "0.1")
    #expect(String(Double(Float(0.1))) != String(Float(0.1)))
    #expect(try Double(Float(0.1)).jsonNumberFromRoundTripText() != adoptedText)
}

@Test func e2RoundTripDoubleExtremesAndNonfiniteFailuresMatch() throws {
    for d in [-0.0, 0.0, -1, 0.5, 0.1, Double.leastNonzeroMagnitude, .leastNormalMagnitude, .greatestFiniteMagnitude, .nan, .infinity, -.infinity] {
        #expect(try outcome { try d.jsonNumberFromRoundTripText() } == outcome { try JSONNumber.fromFiniteDouble(d) })
    }
    #expect(try (-0.0).jsonNumberFromRoundTripText().isZero)
    #expect(try !(-0.0).jsonNumberFromRoundTripText().isNegative)
}

@Test func e2DoubleProjectionExactRoundedAndOverflowMatch() throws {
    for text in ["0", "0.5", "0.1", "9007199254740993", "1e1000000", "1e-1000000", "5e-324", "1.7976931348623157e308"] {
        let n = try JSONNumber(parsing: text)
        for policy in [JSONNumberConversionPolicy.exact, .rounded] {
            #expect(try outcome { try Double(jsonNumber: n, policy: policy) } == outcome { try n.doubleValue(policy: policy) })
        }
    }
}

@Test func e2FloatingAndDecimalQuotasPreserveStructuredFailures() throws {
    let n = try JSONNumber(parsing: "0.125")
    for metric in [JSONResourceMetric.workUnits, .numericWorkUnits, .retainedBytes, .outputBytes] {
        for cap in 0...150 {
            var limits = JSONLimits.balanced; limits[metric] = UInt64(cap)
            #expect(try outcome { try Double(jsonNumber: n, limits: limits) } == outcome { try n.doubleValue(limits: limits) })
            #expect(try outcome { try Decimal(jsonNumber: n, limits: limits) } == outcome { try n.decimalValue(limits: limits) })
            #expect(try outcome { try 0.125.jsonNumberFromRoundTripText(limits: limits) } == outcome { try JSONNumber.fromFiniteDouble(0.125, limits: limits) })
        }
    }
}

@Test func e2FoundationDecimalRangeAndPrecisionStayDelegated() throws {
    for text in ["0", "0.1", "1e-128", "1e-129", "1e127", "1e165", "1e166", "123456789012345678901234567890123456789", "1234567890123456789012345678901234567890", "12345678901234567890123456789012345678901"] {
        let n = try JSONNumber(parsing: text)
        for policy in [JSONNumberConversionPolicy.exact, .rounded] {
            #expect(try outcome { try Decimal(jsonNumber: n, policy: policy) } == outcome { try n.decimalValue(policy: policy) })
        }
    }
    #expect(try Decimal(jsonNumber: JSONNumber(parsing: "0.1")) == Decimal(string: "0.1"))
}

@Test func e2BridgeCancellationRemainsAnError() async throws {
    let n = try JSONNumber(parsing: "0.125")
    let cancelled = await Task {
        withUnsafeCurrentTask { $0?.cancel() }
        #expect(throws: CancellationError.self) { try Int(jsonNumber: JSONNumber(integer: 1)) }
        #expect(throws: CancellationError.self) { try Double(jsonNumber: n) }
        #expect(throws: CancellationError.self) { try Decimal(jsonNumber: n) }
        #expect(throws: CancellationError.self) { try 0.125.jsonNumberFromRoundTripText() }
        // Trusted integer construction is intentionally unmetered, just like its delegate.
        #expect(1.jsonNumber() == JSONNumber(integer: 1))
        return true
    }.value
    #expect(cancelled)
}

@Test func e2SharedBridgeInputsHaveInvocationOwnedState() async throws {
    let n = try JSONNumber(parsing: "0.125")
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for _ in 0..<8 {
            group.addTask { try Double(jsonNumber: n) == 0.125 && Decimal(jsonNumber: n) == Decimal(string: "0.125") }
        }
        for try await result in group { #expect(result) }
    }
}
