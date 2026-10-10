// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct JSONValueEncoder: Sendable {
    public let options: JSONCodingOptions
    public init(options: JSONCodingOptions = .init()) { self.options = options }
    public func encode<T: Encodable>(_ value: T) throws -> JSON { try encodeWithReport(value).result }
    public func encodeWithReport<T: Encodable>(_ value: T) throws -> JSONOperationReport<JSON> {
        let meter = try JSONWorkMeter(limits: options.limits, domain: .coding)
        let state = JSONCodingState(options: options, meter: meter)
        let value = try Self.encode(value, state: state)
        return .init(result: value, statistics: state.meter.statistics())
    }
    package static func encode<T: Encodable>(_ value: T, state: JSONCodingState) throws -> JSON {
        try state.check()
        let box = JSONEncodingBox()
        try state.meter.retain(JSONLogicalWeights.node)
        try JSONNativeEncoder(box: box, state: state, codingPath: []).encode(value)
        try state.check()
        let result = try box.materialize(state: state)
        try JSONAdmission.value(result, meter: &state.meter)
        return result
    }
}
package final class JSONEncodingBox {
    package enum Storage { case unset, value(JSON), keyed([(JSONKey, JSONEncodingBox)]), unkeyed([JSONEncodingBox]) }
    package var storage: Storage = .unset
    package func materialize(state: JSONCodingState) throws -> JSON {
        enum Step { case node(JSONEncodingBox), object([JSONKey]), array(Int) }
        var pending: [Step] = [.node(self)], results: [JSON] = []
        while let step = pending.popLast() {
            try state.meter.work()
            switch step {
            case .node(let node):
                switch node.storage {
                case .unset: throw EncodingError.invalidValue("unset", .init(codingPath: [], debugDescription: "No value was encoded"))
                case .value(let value): results.append(value)
                case .keyed(let members):
                    pending.append(.object(members.map { $0.0 }))
                    for (_, box) in members.reversed() { try state.meter.work(); try state.meter.retain(16); pending.append(.node(box)) }
                case .unkeyed(let boxes):
                    pending.append(.array(boxes.count))
                    for box in boxes.reversed() { try state.meter.work(); try state.meter.retain(16); pending.append(.node(box)) }
                }
            case .object(let keys):
                var members: [JSONMember] = []
                for (key, value) in zip(keys, results.suffix(keys.count)) {
                    try state.meter.work(); try state.meter.retain(JSONLogicalWeights.member + JSONLogicalWeights.indexSlot); members.append(JSONMember(key, value: value))
                }
                results.removeLast(keys.count); results.append(.object(JSONObject(admitted: members)))
            case .array(let count):
                var values: [JSON] = []
                for value in results.suffix(count) { try state.meter.work(); try state.meter.retain(JSONLogicalWeights.arraySlot); values.append(value) }
                results.removeLast(count); results.append(.array(values))
            }
        }
        guard results.count == 1 else { throw JSONFailure(.configuration, code: .invalidOperation) }
        return results[0]
    }
}
package final class JSONNativeEncoder: Encoder {
    package let box: JSONEncodingBox
    package let state: JSONCodingState
    package let codingPath: [any CodingKey]
    package var userInfo: [CodingUserInfoKey: Any] { state.bridgedUserInfo }
    package init(box: JSONEncodingBox, state: JSONCodingState, codingPath: [any CodingKey]) { self.box = box; self.state = state; self.codingPath = codingPath }
    package func container<Key: CodingKey>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> {
        state.latch {
            try state.check()
            switch box.storage {
            case .unset: box.storage = .keyed([])
            case .keyed: break
            default: throw EncodingError.invalidValue("container", .init(codingPath: codingPath, debugDescription: "Conflicting containers"))
            }
        }
        return KeyedEncodingContainer(JSONKeyedEncodingContainer<Key>(encoder: self))
    }
    package func unkeyedContainer() -> any UnkeyedEncodingContainer {
        state.latch {
            try state.check()
            switch box.storage {
            case .unset: box.storage = .unkeyed([])
            case .unkeyed: break
            default: throw EncodingError.invalidValue("container", .init(codingPath: codingPath, debugDescription: "Conflicting containers"))
            }
        }
        return JSONUnkeyedEncodingContainer(encoder: self)
    }
    package func singleValueContainer() -> any SingleValueEncodingContainer { JSONSingleEncodingContainer(encoder: self) }
    package func set(_ value: JSON) throws {
        try state.check(); try JSONAdmission.value(value, meter: &state.meter, owned: true)
        guard case .unset = box.storage else { throw EncodingError.invalidValue(value, .init(codingPath: codingPath, debugDescription: "Value encoded twice")) }
        box.storage = .value(value)
    }
    package func encode<T: Encodable>(_ value: T) throws {
        if let json = value as? JSON { try set(json) }
        else if let number = value as? JSONNumber { try set(.number(number)) }
        else if let data = value as? Data, state.options.dataStrategy == .base64 {
            let encoded = try JSONBase64.encode(data,meter: &state.meter)
            try set(.string(encoded.text)); try state.meter.release(encoded.bytes)
        } else if let date = value as? Date, state.options.dateStrategy != .deferredToDate {
            if state.options.dateStrategy == .secondsSince1970 { try floating(date.timeIntervalSince1970) }
            else {
                let seconds = date.timeIntervalSince1970
                guard seconds.isFinite,seconds >= -62_167_219_200,seconds < 253_402_300_800 else {
                    throw EncodingError.invalidValue(date,.init(codingPath: codingPath,debugDescription: "ISO-8601 year must be 0000...9999"))
                }
                try state.meter.retain(128); try state.meter.checkpoint()
                let text = date.ISO8601Format(.iso8601.timeZone(separator: .colon).time(includingFractionalSeconds: true))
                try state.meter.checkpoint(); try set(.string(text)); try state.meter.release(128)
            }
        } else { try value.encode(to: self) }
    }
    package func floating<T: BinaryFloatingPoint>(_ value: T) throws {
        guard value.isFinite else { throw EncodingError.invalidValue(value, .init(codingPath: codingPath, debugDescription: "Nonfinite JSON number")) }
        try set(.number(JSONNumber.parse(String(describing: value).utf8, meter: &state.meter)))
    }
    package func child(_ key: any CodingKey) throws -> JSONNativeEncoder {
        let path = try state.path(codingPath, appending: key)
        try state.meter.retain(JSONLogicalWeights.node)
        return .init(box: JSONEncodingBox(), state: state, codingPath: path)
    }
}
