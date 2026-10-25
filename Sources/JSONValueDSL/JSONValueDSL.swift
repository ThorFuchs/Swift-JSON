// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONDSLCore

/// Stages one object; only finalization is checked and callbacks/staging are unmetered.
///
/// - Parameters:
///   - limits: Inclusive finite finalization capacities and work quotas; staging is excluded.
///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
public func object<Content: JSONValueFieldsContent>(
    limits: JSONLimits = .balanced,
    @JSONContentBuilder _ content: () -> Content
) throws -> JSON {
    try Task.checkCancellation()
    try limits.validate()
    var members: [JSONDSLMember] = []
    content().writeValueFields(to: &members)
    return try JSONDSLNode.object(members).materialize(limits: limits)
}
/// Stages one array; only finalization is checked and callbacks/staging are unmetered.
///
/// - Parameters:
///   - limits: Inclusive finite finalization capacities and work quotas; staging is excluded.
///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
public func array<Content: JSONValueElementsContent>(
    limits: JSONLimits = .balanced,
    @JSONContentBuilder _ content: () -> Content
) throws -> JSON {
    try Task.checkCancellation()
    try limits.validate()
    var nodes: [JSONDSLNode] = []
    content().writeValueElements(to: &nodes)
    return try JSONDSLNode.array(nodes).materialize(limits: limits)
}

/// One ordered object member. Keys are literal decoded Unicode scalars; no dotted path coercion.
public struct Field: Sendable, JSONValueFieldsContent {
    /// The literal decoded-scalar member name; it is not a Pointer or dotted path.
    public let key: String
    /// The exact staged payload; admission occurs at finalization.
    public let value: JSONDSLNode
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ key: String, _ value: JSON) {
        self.key = key
        self.value = .literal(value)
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ key: String, _ value: String) { self.init(key, .string(value)) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ key: String, _ value: Bool) { self.init(key, .boolean(value)) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init<Integer: BinaryInteger>(_ key: String, _ value: Integer) {
        self.init(key, .number(JSONNumber(integer: value)))
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ key: String, exactNumber value: JSONNumber) { self.init(key, .number(value)) }
    /// Stages one object; only finalization is checked and callbacks/staging are unmetered.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func object<Content: JSONValueFieldsContent>(
        _ key: String, @JSONContentBuilder _ content: () -> Content
    ) -> Self {
        var members: [JSONDSLMember] = []
        content().writeValueFields(to: &members)
        return Self(key: key, value: .object(members))
    }
    /// Stages one array; only finalization is checked and callbacks/staging are unmetered.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func array<Content: JSONValueElementsContent>(
        _ key: String, @JSONContentBuilder _ content: () -> Content
    ) -> Self {
        var nodes: [JSONDSLNode] = []
        content().writeValueElements(to: &nodes)
        return Self(key: key, value: .array(nodes))
    }
    private init(key: String, value: JSONDSLNode) {
        self.key = key
        self.value = value
    }
    /// Emits ordered object members into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeValueFields(to members: inout [JSONDSLMember]) { members.append(.init(key, value)) }
}

/// One array item. A nested JSON array remains one element; never silently flattens.
public struct Element: Sendable, JSONValueElementsContent {
    /// The exact staged payload; admission occurs at finalization.
    public let value: JSONDSLNode
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ value: JSON) { self.value = .literal(value) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ value: String) { self.init(.string(value)) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ value: Bool) { self.init(.boolean(value)) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init<Integer: BinaryInteger>(_ value: Integer) { self.init(.number(JSONNumber(integer: value))) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - exactNumber: The exact authored input for this declaration; no semantic fallback is applied.
    public init(exactNumber: JSONNumber) { self.init(.number(exactNumber)) }
    /// Stages one object; only finalization is checked and callbacks/staging are unmetered.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func object<Content: JSONValueFieldsContent>(@JSONContentBuilder _ content: () -> Content)
        -> Self
    {
        var members: [JSONDSLMember] = []
        content().writeValueFields(to: &members)
        return Self(value: .object(members))
    }
    /// Stages one array; only finalization is checked and callbacks/staging are unmetered.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func array<Content: JSONValueElementsContent>(@JSONContentBuilder _ content: () -> Content)
        -> Self
    {
        var nodes: [JSONDSLNode] = []
        content().writeValueElements(to: &nodes)
        return Self(value: .array(nodes))
    }
    private init(value: JSONDSLNode) { self.value = value }
    /// Emits array elements into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public func writeValueElements(to elements: inout [JSONDSLNode]) { elements.append(value) }
}

/// Explicit sequence expansion (rather than implicit flattening of array values).
public struct Elements: Sendable, JSONValueElementsContent {
    /// Caller-supplied values to expand explicitly, preserving array values as single elements.
    public let values: [JSON]
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - values: Explicit exact payloads in declaration order; nested arrays remain values.
    public init(contentsOf values: [JSON]) { self.values = values }
    /// Emits array elements into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public func writeValueElements(to elements: inout [JSONDSLNode]) {
        elements.append(contentsOf: values.map(JSONDSLNode.literal))
    }
}
