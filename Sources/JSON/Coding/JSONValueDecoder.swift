// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct JSONValueDecoder: Sendable {
    public let options: JSONCodingOptions
    public init(options: JSONCodingOptions = .init()) { self.options = options }
    public func decode<T: Decodable>(_ type: T.Type, from value: JSON) throws -> T { try decodeWithReport(type, from: value).result }
    public func decodeWithReport<T: Decodable>(_ type: T.Type, from value: JSON) throws -> JSONOperationReport<T> {
        let meter = try JSONWorkMeter(limits: options.limits, domain: .coding)
        let state = JSONCodingState(options: options, meter: meter)
        try JSONAdmission.value(value, meter: &state.meter)
        let result = try JSONNativeDecoder(value: value, state: state, codingPath: []).decode(type)
        try state.check()
        return .init(result: result, statistics: state.meter.statistics())
    }
}
package final class JSONNativeDecoder: Decoder {
    package let value: JSON
    package let state: JSONCodingState
    package let codingPath: [any CodingKey]
    package var userInfo: [CodingUserInfoKey: Any] { state.bridgedUserInfo }
    package init(value: JSON, state: JSONCodingState, codingPath: [any CodingKey]) { self.value = value; self.state = state; self.codingPath = codingPath }
    package func mismatch(_ type: Any.Type) -> DecodingError {
        .typeMismatch(type, .init(codingPath: codingPath, debugDescription: "JSON kind mismatch", underlyingError: JSONFailure(.typeMismatch, code: .wrongKind)))
    }
    package func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
        try state.check()
        guard case .object(let object) = value else { throw mismatch(JSONObject.self) }
        return KeyedDecodingContainer(JSONKeyedDecodingContainer<Key>(decoder: self, object: object))
    }
    package func unkeyedContainer() throws -> any UnkeyedDecodingContainer {
        try state.check()
        guard case .array(let values) = value else { throw mismatch([JSON].self) }
        return JSONUnkeyedDecodingContainer(decoder: self, values: values)
    }
    package func singleValueContainer() throws -> any SingleValueDecodingContainer { try state.check(); return JSONSingleDecodingContainer(decoder: self) }
    package func child(_ value: JSON, key: any CodingKey) throws -> JSONNativeDecoder {
        .init(value: value, state: state, codingPath: try state.path(codingPath, appending: key))
    }
    package func decode<T: Decodable>(_ type: T.Type) throws -> T {
        try state.check()
        if type == JSON.self { return value as! T }
        if type == JSONNumber.self {
            guard case .number(let number) = value else { throw mismatch(type) }; return number as! T
        }
        if type == Data.self && state.options.dataStrategy == .base64 {
            guard case .string(let string) = value else { throw mismatch(type) }
            do { return try JSONBase64.decode(string,meter: &state.meter) as! T }
            catch let error as JSONFailure where error.category != .resource {
                throw DecodingError.dataCorrupted(.init(codingPath: codingPath,debugDescription: "Invalid base64",underlyingError: error))
            }
        }
        if type == Date.self && state.options.dateStrategy != .deferredToDate {
            if state.options.dateStrategy == .secondsSince1970 {
                let seconds = try JSONSingleDecodingContainer(decoder: self).decode(Double.self)
                return Date(timeIntervalSince1970: seconds) as! T
            }
            guard case .string(let string) = value else { throw mismatch(type) }
            var length = 0
            for _ in string.utf8 {
                try state.meter.work(); length += 1
                guard length <= 128 else { throw DecodingError.dataCorrupted(.init(codingPath: codingPath,debugDescription: "ISO-8601 text exceeds fixed format capacity")) }
            }
            try state.meter.checkpoint()
            let strategy = Date.ISO8601FormatStyle().timeZone(separator: .colon).time(includingFractionalSeconds: true)
            guard let date = try? strategy.parse(string) else { throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Invalid ISO-8601 date")) }
            try state.meter.checkpoint(); return date as! T
        }
        let result = try T(from: self)
        // Dictionary's String equality normalizes canonically equivalent keys.
        // Its standard Decodable implementation is caller projection work; never
        // return a successfully decoded value after that projection lost members.
        if let projection = result as? any JSONStringDictionaryProjection,
           let count = projection.stringKeyCount, case .object(let object) = value,
           count != object.count {
            throw DecodingError.dataCorrupted(.init(codingPath: codingPath,
                debugDescription: "String dictionary cannot preserve scalar-distinct JSON keys"))
        }
        return result
    }
    package func integer<T: FixedWidthInteger>(_ type: T.Type) throws -> T {
        guard case .number(let number) = value else { throw mismatch(type) }
        do { return try number.integer(as: type, meter: &state.meter) }
        catch let error as JSONFailure where error.category == .conversion { throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Integer cannot represent JSON number", underlyingError: error)) }
    }
    package func floating<T: BinaryFloatingPoint & LosslessStringConvertible>(_ type: T.Type) throws -> T {
        guard case .number(let number) = value else { throw mismatch(type) }
        let text = try number.binaryConversionText(meter: &state.meter)
        try state.meter.checkpoint()
        guard let result = T(text), result.isFinite else { throw DecodingError.dataCorrupted(.init(codingPath: codingPath, debugDescription: "Floating-point range exceeded")) }
        try state.meter.checkpoint(); return result
    }
}

private protocol JSONStringDictionaryProjection {
    var stringKeyCount: Int? { get }
}
extension Dictionary: JSONStringDictionaryProjection {
    fileprivate var stringKeyCount: Int? { Key.self == String.self ? count : nil }
}
