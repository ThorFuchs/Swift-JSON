// SPDX-License-Identifier: Apache-2.0
public enum JSONPresence<Value> { case absent, null, value(Value) }
extension JSONPresence: Sendable where Value: Sendable {}
extension JSONPresence: Equatable where Value: Equatable {}
extension JSONPresence: Hashable where Value: Hashable {}

extension JSONObject {
    public func presence(of key: JSONKey) -> JSONPresence<JSON> {
        guard let value = self[key] else { return .absent }
        if case .null = value { return .null }
        return .value(value)
    }
    public func presence(of key: String) -> JSONPresence<JSON> { presence(of: JSONKey(key)) }
}
