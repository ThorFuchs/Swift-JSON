// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private enum ForeignError: Error, Equatable { case injected }
private final class ForeignTrace {
    var calls: [String] = []
    let reject: Set<String>
    let representedInteger: Int64?
    let nanDecimal: Bool
    init(reject: Set<String> = [], representedInteger: Int64? = nil, nanDecimal: Bool = false) {
        self.reject = reject; self.representedInteger = representedInteger; self.nanDecimal = nanDecimal
    }
    func visit(_ name: String) throws { calls.append(name); if reject.contains(name) { throw ForeignError.injected } }
}
// These synchronous, invocation-owned wrappers deliberately hide the native coder
// type. They exercise the *foreign* bridge, retaining typed paths and allowing
// independently controlled primitive rejection. No Foundation JSON serialization.
private struct ForeignDecoder: Decoder {
    let base: any Decoder
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { base.codingPath }
    var userInfo: [CodingUserInfoKey: Any] { base.userInfo }
    func singleValueContainer() throws -> any SingleValueDecodingContainer {
        try trace.visit("decode:single")
        return ForeignSingleDecoder(base: base, c: try base.singleValueContainer(), trace: trace)
    }
    func container<K: CodingKey>(keyedBy type: K.Type) throws -> KeyedDecodingContainer<K> {
        try trace.visit("decode:object")
        return KeyedDecodingContainer(ForeignKeyedDecoder(c: try base.container(keyedBy: type), trace: trace))
    }
    func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try trace.visit("decode:array")
        return ForeignUnkeyedDecoder(c: try base.unkeyedContainer(), trace: trace)
    }
}
private struct ForeignSingleDecoder: SingleValueDecodingContainer {
    let base: any Decoder
    let c: any SingleValueDecodingContainer
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { base.codingPath }
    func decodeNil() -> Bool { c.decodeNil() }
    func decode<T: Decodable>(_ type: T.Type) throws -> T {
        if type == Decimal.self {
            try trace.visit("decode:Decimal")
            if trace.nanDecimal { return Decimal.nan as! T }
            return try c.decode(JSONNumber.self).decimalValue() as! T
        }
        return try T(from: ForeignDecoder(base: base, trace: trace))
    }
    private func primitive<T: Decodable>(_ type: T.Type, _ body: () throws -> T) throws -> T {
        try trace.visit("decode:\(type)"); return try body()
    }
    func decode(_ type: Bool.Type) throws -> Bool { try primitive(type) { try c.decode(type) } }
    func decode(_ type: String.Type) throws -> String { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Double.Type) throws -> Double { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Float.Type) throws -> Float { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Int.Type) throws -> Int { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Int8.Type) throws -> Int8 { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Int16.Type) throws -> Int16 { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Int32.Type) throws -> Int32 { try primitive(type) { try c.decode(type) } }
    func decode(_ type: Int64.Type) throws -> Int64 { try primitive(type) { if let value = trace.representedInteger { return value }; return try c.decode(type) } }
    func decode(_ type: UInt.Type) throws -> UInt { try primitive(type) { try c.decode(type) } }
    func decode(_ type: UInt8.Type) throws -> UInt8 { try primitive(type) { try c.decode(type) } }
    func decode(_ type: UInt16.Type) throws -> UInt16 { try primitive(type) { try c.decode(type) } }
    func decode(_ type: UInt32.Type) throws -> UInt32 { try primitive(type) { try c.decode(type) } }
    func decode(_ type: UInt64.Type) throws -> UInt64 { try primitive(type) { try c.decode(type) } }
}
private struct ForeignKeyedDecoder<K: CodingKey>: KeyedDecodingContainerProtocol {
    let c: KeyedDecodingContainer<K>
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { c.codingPath }
    var allKeys: [K] { c.allKeys }
    func contains(_ key: K) -> Bool { c.contains(key) }
    func decodeNil(forKey key: K) throws -> Bool { try c.decodeNil(forKey: key) }
    func decode<T: Decodable>(_ type: T.Type, forKey key: K) throws -> T { try T(from: superDecoder(forKey: key)) }
    func superDecoder(forKey key: K) throws -> any Decoder { ForeignDecoder(base: try c.superDecoder(forKey: key), trace: trace) }
    func superDecoder() throws -> any Decoder { ForeignDecoder(base: try c.superDecoder(), trace: trace) }
    func nestedContainer<N: CodingKey>(keyedBy type: N.Type, forKey key: K) throws -> KeyedDecodingContainer<N> { try superDecoder(forKey: key).container(keyedBy: type) }
    func nestedUnkeyedContainer(forKey key: K) throws -> any UnkeyedDecodingContainer { try superDecoder(forKey: key).unkeyedContainer() }
}
private struct ForeignUnkeyedDecoder: UnkeyedDecodingContainer {
    var c: any UnkeyedDecodingContainer
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { c.codingPath }
    var count: Int? { c.count }
    var currentIndex: Int { c.currentIndex }
    var isAtEnd: Bool { c.isAtEnd }
    mutating func decodeNil() throws -> Bool { try c.decodeNil() }
    mutating func decode<T: Decodable>(_ type: T.Type) throws -> T { try T(from: superDecoder()) }
    mutating func superDecoder() throws -> any Decoder { ForeignDecoder(base: try c.superDecoder(), trace: trace) }
    mutating func nestedContainer<N: CodingKey>(keyedBy type: N.Type) throws -> KeyedDecodingContainer<N> { try superDecoder().container(keyedBy: type) }
    mutating func nestedUnkeyedContainer() throws -> any UnkeyedDecodingContainer { try superDecoder().unkeyedContainer() }
}
private struct ForeignEncoder: Encoder {
    let base: any Encoder
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { base.codingPath }
    var userInfo: [CodingUserInfoKey: Any] { base.userInfo }
    func singleValueContainer() -> any SingleValueEncodingContainer { ForeignSingleEncoder(base: base, c: base.singleValueContainer(), trace: trace) }
    func container<K: CodingKey>(keyedBy type: K.Type) -> KeyedEncodingContainer<K> { KeyedEncodingContainer(ForeignKeyedEncoder(c: base.container(keyedBy: type), trace: trace)) }
    func unkeyedContainer() -> any UnkeyedEncodingContainer { ForeignUnkeyedEncoder(c: base.unkeyedContainer(), trace: trace) }
}
private struct ForeignSingleEncoder: SingleValueEncodingContainer {
    let base: any Encoder
    var c: any SingleValueEncodingContainer
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { base.codingPath }
    mutating func encodeNil() throws { try trace.visit("encode:nil"); try c.encodeNil() }
    mutating func encode<T: Encodable>(_ value: T) throws {
        if let decimal = value as? Decimal {
            try trace.visit("encode:Decimal")
            try c.encode(JSONNumber(parsing: decimal.description))
        } else { try value.encode(to: ForeignEncoder(base: base, trace: trace)) }
    }
    mutating func encode(_ v: Bool) throws { try trace.visit("encode:Bool"); try c.encode(v) }
    mutating func encode(_ v: String) throws { try trace.visit("encode:String"); try c.encode(v) }
    mutating func encode(_ v: Double) throws { try trace.visit("encode:Double"); try c.encode(v) }
    mutating func encode(_ v: Float) throws { try trace.visit("encode:Float"); try c.encode(v) }
    mutating func encode(_ v: Int) throws { try trace.visit("encode:Int"); try c.encode(v) }
    mutating func encode(_ v: Int8) throws { try trace.visit("encode:Int8"); try c.encode(v) }
    mutating func encode(_ v: Int16) throws { try trace.visit("encode:Int16"); try c.encode(v) }
    mutating func encode(_ v: Int32) throws { try trace.visit("encode:Int32"); try c.encode(v) }
    mutating func encode(_ v: Int64) throws { try trace.visit("encode:Int64"); try c.encode(v) }
    mutating func encode(_ v: UInt) throws { try trace.visit("encode:UInt"); try c.encode(v) }
    mutating func encode(_ v: UInt8) throws { try trace.visit("encode:UInt8"); try c.encode(v) }
    mutating func encode(_ v: UInt16) throws { try trace.visit("encode:UInt16"); try c.encode(v) }
    mutating func encode(_ v: UInt32) throws { try trace.visit("encode:UInt32"); try c.encode(v) }
    mutating func encode(_ v: UInt64) throws { try trace.visit("encode:UInt64"); try c.encode(v) }
}
private struct ForeignKeyedEncoder<K: CodingKey>: KeyedEncodingContainerProtocol {
    var c: KeyedEncodingContainer<K>
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { c.codingPath }
    mutating func encodeNil(forKey key: K) throws { try c.encodeNil(forKey: key) }
    mutating func encode<T: Encodable>(_ value: T, forKey key: K) throws { try value.encode(to: superEncoder(forKey: key)) }
    mutating func superEncoder(forKey key: K) -> any Encoder { ForeignEncoder(base: c.superEncoder(forKey: key), trace: trace) }
    mutating func superEncoder() -> any Encoder { ForeignEncoder(base: c.superEncoder(), trace: trace) }
    mutating func nestedContainer<N: CodingKey>(keyedBy type: N.Type, forKey key: K) -> KeyedEncodingContainer<N> { superEncoder(forKey: key).container(keyedBy: type) }
    mutating func nestedUnkeyedContainer(forKey key: K) -> any UnkeyedEncodingContainer { superEncoder(forKey: key).unkeyedContainer() }
}
private struct ForeignUnkeyedEncoder: UnkeyedEncodingContainer {
    var c: any UnkeyedEncodingContainer
    let trace: ForeignTrace
    var codingPath: [any CodingKey] { c.codingPath }
    var count: Int { c.count }
    mutating func encodeNil() throws { try c.encodeNil() }
    mutating func encode<T: Encodable>(_ value: T) throws { try value.encode(to: superEncoder()) }
    mutating func superEncoder() -> any Encoder { ForeignEncoder(base: c.superEncoder(), trace: trace) }
    mutating func nestedContainer<N: CodingKey>(keyedBy type: N.Type) -> KeyedEncodingContainer<N> { superEncoder().container(keyedBy: type) }
    mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer { superEncoder().unkeyedContainer() }
}
private struct ForeignRead<T: Decodable>: Decodable {
    let value: T
    let calls: [String]
    init(from decoder: any Decoder) throws {
        let trace = ForeignTrace()
        value = try T(from: ForeignDecoder(base: decoder, trace: trace)); calls = trace.calls
    }
}
private struct ForeignWrite<T: Encodable>: Encodable {
    let value: T
    let trace: ForeignTrace
    func encode(to encoder: any Encoder) throws { try value.encode(to: ForeignEncoder(base: encoder, trace: trace)) }
}
private func captured(_ body: () throws -> Void) -> any Error {
    do { try body(); Issue.record("Expected foreign coder failure"); return ForeignError.injected }
    catch { return error }
}

@Test func qaForeignNumberDecodingSelectsInt64UInt64ThenDecimalWithoutDouble() throws {
    for (text, candidates) in [
        ("-9223372036854775808", ["decode:Int64"]),
        ("18446744073709551615", ["decode:Int64", "decode:UInt64"]),
        ("0.125", ["decode:Int64", "decode:UInt64", "decode:Decimal"])
    ] {
        let number = try JSONNumber(parsing: text)
        let decoded = try JSONValueDecoder().decode(ForeignRead<JSONNumber>.self, from: .number(number))
        #expect(decoded.value == number)
        #expect(decoded.calls.filter { ["decode:Int64", "decode:UInt64", "decode:Decimal"].contains($0) } == candidates)
        #expect(!decoded.calls.contains("decode:Double") && !decoded.calls.contains("decode:Float"))
    }
}
@Test func qaForeignNumberEncodingUsesExactRepresentationsWithoutBinaryFallback() throws {
    for (text, expected) in [("-9223372036854775808", "encode:Int64"), ("18446744073709551615", "encode:UInt64"), ("0.125", "encode:Decimal")] {
        let number = try JSONNumber(parsing: text), trace = ForeignTrace()
        #expect(try JSONValueEncoder().encode(ForeignWrite(value: number, trace: trace)) == .number(number))
        #expect(trace.calls == [expected])
    }
}
@Test func qaForeignSixKindsAndNestedScalarKeysMatchIndependentGolden() throws {
    for text in ["null", "true", #""é""#, "9007199254740993", "[null,false,0.125]", #"{"é":[1],"é":{"value":0.125}}"#] {
        let value = try JSONParser().parse(text), trace = ForeignTrace()
        let decoded = try JSONValueDecoder().decode(ForeignRead<JSON>.self, from: value)
        #expect(decoded.value == value)
        #expect(try JSONValueEncoder().encode(ForeignWrite(value: value, trace: trace)) == value)
        #expect(!decoded.calls.contains("decode:Double") && !trace.calls.contains("encode:Double"))
    }
}
@Test func qaForeignJSONObjectBridgePreservesOrderAndRejectsNonobjects() throws {
    let value = try JSONParser().parse(#"{"z":null,"é":1,"é":2}"#)
    let decoded = try JSONValueDecoder().decode(ForeignRead<JSONObject>.self, from: value)
    #expect(decoded.value.map { Array($0.key.string.utf8) } == [Array("z".utf8), Array("é".utf8), Array("e\u{301}".utf8)])
    #expect(try JSONValueEncoder().encode(ForeignWrite(value: decoded.value, trace: ForeignTrace())) == value)
    let error = captured { _ = try JSONValueDecoder().decode(ForeignRead<JSONObject>.self, from: .array([])) }
    guard case DecodingError.typeMismatch(let type, let context) = error else { Issue.record("Expected object type mismatch"); return }
    #expect(ObjectIdentifier(type) == ObjectIdentifier(JSONObject.self) && context.codingPath.isEmpty)
}
@Test func qaForeignUnrepresentableNumbersRejectInsteadOfRounding() throws {
    let number = try JSONNumber(parsing: "1e1000")
    let error = captured { _ = try JSONValueDecoder().decode(ForeignRead<JSONNumber>.self, from: .number(number)) }
    guard case DecodingError.typeMismatch(let type, let context) = error else { Issue.record("Expected exact-number type mismatch"); return }
    #expect(ObjectIdentifier(type) == ObjectIdentifier(JSONNumber.self) && context.codingPath.isEmpty)
    let encodedError = captured { _ = try JSONValueEncoder().encode(ForeignWrite(value: number, trace: ForeignTrace())) }
    guard case EncodingError.invalidValue(_, let encodedContext) = encodedError else { Issue.record("Expected exact-number encoding failure"); return }
    #expect(encodedContext.codingPath.isEmpty)
    let cause = try #require(encodedContext.underlyingError as? JSONFailure)
    #expect(cause.category == .conversion && cause.code == .inexactConversion)
}
@Test func qaForeignIntegerSinkErrorPropagatesWithoutTryingAnotherRepresentation() throws {
    let trace = ForeignTrace(reject: ["encode:Int64"])
    let error = captured { _ = try JSONValueEncoder().encode(ForeignWrite(value: JSONNumber(integer: 7), trace: trace)) }
    #expect(error as? ForeignError == .injected && trace.calls == ["encode:Int64"])
}
@Test func qaForeignDecimalSinkErrorIsWrappedWithItsNestedPathAndCause() throws {
    let trace = ForeignTrace(reject: ["encode:Decimal"])
    let error = captured { _ = try JSONValueEncoder().encode(ForeignWrite(value: [JSONNumber(parsing: "0.125")], trace: trace)) }
    guard case EncodingError.invalidValue(_, let context) = error else { Issue.record("Expected decimal encoding failure"); return }
    #expect(context.codingPath.map(\.stringValue) == ["0"] && context.codingPath.map(\.intValue) == [0])
    #expect(context.underlyingError as? ForeignError == .injected && trace.calls == ["encode:Decimal"])
}
private struct RejectSingleContainer: Decodable {
    init(from decoder: any Decoder) throws {
        _ = try JSONNumber(from: ForeignDecoder(base: decoder, trace: ForeignTrace(reject: ["decode:single"])))
    }
}
@Test func qaForeignSingleContainerAcquisitionErrorPropagatesUnchanged() throws {
    #expect(captured { _ = try JSONValueDecoder().decode(RejectSingleContainer.self, from: 7) } as? ForeignError == .injected)
}

private struct ForcedNumericFallback: Decodable {
    let number: JSONNumber
    let calls: [String]
    init(from decoder: any Decoder) throws {
        let trace = ForeignTrace(reject: ["decode:Int64", "decode:UInt64"])
        number = try JSONNumber(from:ForeignDecoder(base:decoder,trace:trace)); calls = trace.calls
    }
}
@Test func qaForeignRejectedIntegerCandidatesUseOnlyTheDecimalFallback() throws {
    let decoded = try JSONValueDecoder().decode(ForcedNumericFallback.self,from:7)
    #expect(decoded.number == JSONNumber(integer:7))
    #expect(decoded.calls == ["decode:single", "decode:Int64", "decode:UInt64", "decode:Decimal"])
}
private struct NaNForeignNumber: Decodable {
    init(from decoder: any Decoder) throws {
        let trace = ForeignTrace(reject:["decode:Int64", "decode:UInt64"],nanDecimal:true)
        let error = captured { _ = try JSONNumber(from:ForeignDecoder(base:decoder,trace:trace)) }
        guard case DecodingError.typeMismatch(let type,let context) = error else { Issue.record("Expected rejected NaN Decimal"); return }
        #expect(ObjectIdentifier(type) == ObjectIdentifier(JSONNumber.self) && context.codingPath.isEmpty)
        #expect(trace.calls == ["decode:single", "decode:Int64", "decode:UInt64", "decode:Decimal"])
    }
}
@Test func qaForeignNaNDecimalNeverBecomesJSONOrABinaryFallback() throws {
    _ = try JSONValueDecoder().decode(NaNForeignNumber.self,from:7)
}
private struct AlreadyChangedForeignNumber: Decodable {
    let number: JSONNumber
    init(from decoder: any Decoder) throws {
        number = try JSONNumber(from:ForeignDecoder(base:decoder,trace:ForeignTrace(representedInteger:9_007_199_254_740_992)))
    }
}
@Test func qaForeignCoderFidelityCannotRecoverPreviouslyChangedNumbers() throws {
    let source = try JSONParser().parse("9007199254740993")
    let decoded = try JSONValueDecoder().decode(AlreadyChangedForeignNumber.self,from:source)
    #expect(decoded.number == JSONNumber(integer:Int64(9_007_199_254_740_992)))
    #expect(JSON.number(decoded.number) != source)
    #expect(try JSONValueDecoder().decode(JSON.self,from:source) == source)
}
@Test func qaForeignExactDecimalLimitsRejectFractionalUnderflowAndLongPrecision() throws {
    for text in ["1e-1000", "0.123456789012345678901234567890123456789012345678901"] {
        let value = try JSONParser().parse(text)
        let error = captured { _ = try JSONValueDecoder().decode(ForeignRead<JSONNumber>.self,from:value) }
        guard case DecodingError.typeMismatch(let type,let context) = error else { Issue.record("Expected finite exact Decimal rejection"); continue }
        #expect(ObjectIdentifier(type) == ObjectIdentifier(JSONNumber.self) && context.codingPath.isEmpty)
    }
}
