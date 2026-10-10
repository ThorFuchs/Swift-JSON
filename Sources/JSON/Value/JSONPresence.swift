// SPDX-License-Identifier: Apache-2.0
/// Presence without conflating a missing field, JSON null and a non-null value.
public enum JSONPresence<Value> {
    /// The field is not present.
    case absent
    /// The field is present as JSON null.
    case null
    /// The field is present with a non-null payload.
    case value(Value)
}
extension JSONPresence: Sendable where Value: Sendable {}
extension JSONPresence: Equatable where Value: Equatable {}
extension JSONPresence: Hashable where Value: Hashable {}

extension JSONObject {
    /// Looks up an exact scalar key and distinguishes absence, null and non-null values.
    ///
    /// This convenience performs unmetered linear lookup. Use JSON.presence(of:limits:)
    /// when the enclosing operation requires bounded traversal.
    ///
    /// - Parameters:
    ///   - key: The exact decoded-scalar key to select or insert.
    public func presence(of key: JSONKey) -> JSONPresence<JSON> {
        guard let value = self[key] else { return .absent }
        if case .null = value { return .null }
        return .value(value)
    }
    /// Looks up an exact scalar key and distinguishes absence, null and non-null values.
    ///
    /// This convenience performs unmetered linear lookup. Use JSON.presence(of:limits:)
    /// when the enclosing operation requires bounded traversal.
    ///
    /// - Parameters:
    ///   - key: The exact decoded-scalar key to select or insert.
    public func presence(of key: String) -> JSONPresence<JSON> { presence(of: JSONKey(key)) }
}
