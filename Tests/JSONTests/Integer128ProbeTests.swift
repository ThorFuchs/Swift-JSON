// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private func refusal(_ body: () throws -> Void) -> any Error {
    do { try body(); Issue.record("Expected unsupported typed Codable operation"); return CancellationError() }
    catch { return error }
}
@Test func qaInt128ExactProjectionsCoverSignedAndUnsignedBoundaries() throws {
    for (text, value) in [
        ("-170141183460469231731687303715884105728", Int128.min),
        ("-18446744073709551617", -Int128(UInt64.max)-2),
        ("0", Int128(0)), ("1", Int128(1)),
        ("170141183460469231731687303715884105727", Int128.max)
    ] {
        let number = try JSONNumber(parsing: text)
        #expect(try number.integer(as: Int128.self) == value)
        #expect(JSONNumber(integer: value) == number)
    }
    for (text,value) in [("0",UInt128(0)),("18446744073709551616",UInt128(UInt64.max)+1),
                         ("340282366920938463463374607431768211455",UInt128.max)] {
        let number = try JSONNumber(parsing: text)
        #expect(try number.integer(as: UInt128.self) == value)
        #expect(JSONNumber(integer: value) == number)
    }
}
@Test func qaInt128ProjectionOverflowIsExactConversionFailure() throws {
    for text in ["170141183460469231731687303715884105728", "-170141183460469231731687303715884105729", "1.5"] {
        let number = try JSONNumber(parsing: text)
        #expect(refusal { _ = try number.integer(as: Int128.self) } as? JSONFailure == JSONFailure(.conversion,code:.inexactConversion))
    }
    for text in ["340282366920938463463374607431768211456", "-1", "0.1"] {
        let number = try JSONNumber(parsing: text)
        #expect(refusal { _ = try number.integer(as: UInt128.self) } as? JSONFailure == JSONFailure(.conversion,code:.inexactConversion))
    }
}
private func encodingUnsupported<T: FixedWidthInteger & Encodable>(_ value: T) {
    let error = refusal { _ = try JSONValueEncoder().encode(value) }
    guard case EncodingError.invalidValue(let rejected,let context) = error else { Issue.record("Expected SDK unsupported integer encoding"); return }
    #expect(rejected as? T == value && context.codingPath.isEmpty && context.underlyingError == nil)
}
@Test func qaInt128NativeCodableEncodingRefusesWithoutLossyCoercion() {
    for value in [Int128.min, -1, 0, 1, Int128.max] { encodingUnsupported(value) }
    for value in [UInt128(0),1,UInt128.max] { encodingUnsupported(value) }
}
private func decodingUnsupported<T: FixedWidthInteger & Decodable>(_ type: T.Type,_ text: String) throws {
    let value = try JSONParser().parse(text)
    let error = refusal { _ = try JSONValueDecoder().decode(type,from:value) }
    guard case DecodingError.typeMismatch(let requested,let context) = error else { Issue.record("Expected SDK unsupported integer decoding"); return }
    #expect(ObjectIdentifier(requested) == ObjectIdentifier(type))
    #expect(context.codingPath.isEmpty && context.underlyingError == nil)
}
@Test func qaInt128NativeCodableDecodingRefusesEvenRepresentableValues() throws {
    for text in ["1","-170141183460469231731687303715884105728","170141183460469231731687303715884105727"] {
        try decodingUnsupported(Int128.self,text)
    }
    for text in ["1","340282366920938463463374607431768211455"] { try decodingUnsupported(UInt128.self,text) }
}
@Test func qaInt128ExactJSONAndVersion1PayloadAreSupportedAlternatives() throws {
    for text in ["-170141183460469231731687303715884105728", "340282366920938463463374607431768211455"] {
        let number = try JSONNumber(parsing:text), value = JSON.number(number)
        #expect(try JSONValueEncoder().encode(number) == value)
        #expect(try JSONValueDecoder().decode(JSONNumber.self,from:value) == number)
        let payload = try JSONCodablePayload(preserving:value)
        #expect(try JSONValueDecoder().decode(JSONCodablePayload.self,from:JSONValueEncoder().encode(payload)).value() == value)
    }
}
