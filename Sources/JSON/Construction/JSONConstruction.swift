// SPDX-License-Identifier: Apache-2.0
extension JSON: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) { self = .number(JSONNumber(integer: value)) }
}
extension JSON: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension JSON: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .boolean(value) }
}
extension JSON: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
extension JSON: ExpressibleByArrayLiteral {
    public init(arrayLiteral values: JSON...) { self = .array(values) }
}
