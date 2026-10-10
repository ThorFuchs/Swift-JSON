// SPDX-License-Identifier: Apache-2.0
public struct JSONMember: Sendable, Equatable, Hashable {
    public let key: JSONKey
    public let value: JSON
    public init(_ key: JSONKey, value: JSON) { self.key = key; self.value = value }
    public init(_ key: String, value: JSON) { self.init(JSONKey(key), value: value) }
}
