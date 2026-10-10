// SPDX-License-Identifier: Apache-2.0
/// An ordered collection of exact-key members with order-independent equality.
///
/// Replacing a member preserves its position; removing and re-inserting appends it.
/// Lookup is linear in the scalar implementation. Use bounded operations for untrusted work.
public struct JSONObject: Sendable, Hashable, RandomAccessCollection {
    /// The integer position of a member in insertion order.
    public typealias Index = Int
    /// The element yielded by this collection or sequence.
    public typealias Element = JSONMember
    /// Members in deterministic insertion order.
    public let members: [JSONMember]
    /// Admits ordered members and rejects identical decoded scalar keys.
    ///
    /// - Throws: Duplicate-key, value/growth/work failure or cancellation.
    ///
    /// - Parameters:
    ///   - members: Members in insertion order; exact duplicates fail checked construction.
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    public init(members: [JSONMember] = [], limits: JSONLimits = .balanced) throws {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        self = try Self.checked(members: members, meter: &meter)
    }
    package init(admitted members: [JSONMember]) {
        self.members = members
    }
    package static func checked(members: [JSONMember], meter: inout JSONWorkMeter) throws -> Self {
        try meter.require(.objectMembers, UInt64(members.count))
        var output: [JSONMember] = []
        for member in members {
            try JSONAdmission.text(member.key.string, key: true, meter: &meter, owned: true)
            for previous in output {
                if try JSONComparison.textEquals(previous.key.string, member.key.string, meter: &meter) {
                    throw JSONFailure(.syntax, code: .duplicateKey)
                }
            }
            try JSONAdmission.value(member.value, meter: &meter, owned: true, depth: 1)
            try meter.retain(JSONLogicalWeights.member + JSONLogicalWeights.indexSlot)
            output.append(member)
        }
        try meter.charge(.nodes); try meter.retain(JSONLogicalWeights.node)
        try meter.require(.maxDepth, 1)
        return Self(admitted: output)
    }
    /// The first member index; equal to endIndex for an empty object.
    public var startIndex: Int { members.startIndex }
    /// The collection boundary immediately after the final member.
    public var endIndex: Int { members.endIndex }
    /// Looks up an exact decoded-scalar key with unmetered linear traversal.
    ///
    /// Returns nil for absence and JSON.null for a present null. Use bounded JSON
    /// member access when untrusted traversal requires work accounting.
    ///
    /// - Parameters:
    ///   - position: A valid insertion-order member index.
    public subscript(position: Int) -> JSONMember { members[position] }
    /// Looks up an exact decoded-scalar key with unmetered linear traversal.
    ///
    /// Returns nil for absence and JSON.null for a present null. Use bounded JSON
    /// member access when untrusted traversal requires work accounting.
    ///
    /// - Parameters:
    ///   - key: The exact decoded-scalar key or caller CodingKey.
    public subscript(key: JSONKey) -> JSON? { members.first { $0.key == key }?.value }
    /// Looks up an exact decoded-scalar key with unmetered linear traversal.
    ///
    /// Returns nil for absence and JSON.null for a present null. Use bounded JSON
    /// member access when untrusted traversal requires work accounting.
    ///
    /// - Parameters:
    ///   - key: The exact decoded-scalar key or caller CodingKey.
    public subscript(key: String) -> JSON? { self[JSONKey(key)] }
    /// Compares semantic identity without a throwing work budget.
    ///
    /// - Parameters:
    ///   - lhs: The left value.
    ///   - rhs: The right value.
    public static func == (lhs: Self, rhs: Self) -> Bool { JSON.object(lhs) == JSON.object(rhs) }
    /// Hashes semantic identity; the randomized result is not a persistent digest.
    ///
    /// This protocol operation has no throwing work budget.
    ///
    /// - Parameters:
    ///   - hasher: The caller's randomized Swift hasher.
    public func hash(into hasher: inout Hasher) { JSON.object(self).hash(into: &hasher) }
    package func lookup(_ key: String, meter: inout JSONWorkMeter) throws -> JSON? {
        for member in members {
            try meter.work()
            if try JSONComparison.textEquals(member.key.string, key, meter: &meter) { return member.value }
        }
        return nil
    }
    /// Returns an admitted object with a member added or replaced in place.
    ///
    /// A new key appends; replacement preserves its insertion position.
    /// - Throws: Value, key, growth or work limit failure, or cancellation.
    ///
    /// - Parameters:
    ///   - value: The input value; admission occurs where the operation is bounded.
    ///   - key: The exact decoded-scalar key to select or insert.
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    public func setting(_ value: JSON, for key: JSONKey, limits: JSONLimits = .balanced) throws -> Self {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        try JSONAdmission.value(.object(self), meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.text(key.string, key: true, meter: &meter, owned: true)
        try JSONAdmission.value(value, meter: &meter, owned: true, depth: 1)
        let result = try JSONEditing.modify(.object(self), token: key, change: .add(value), meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.value(result, meter: &meter)
        return result.objectValue!
    }
    /// Returns an admitted object without the selected exact key; absence leaves it unchanged.
    ///
    /// - Throws: Resource or configuration failure, or cancellation.
    ///
    /// - Parameters:
    ///   - key: The exact decoded-scalar key or caller CodingKey.
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    public func removing(_ key: JSONKey, limits: JSONLimits = .balanced) throws -> Self {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        try JSONAdmission.value(.object(self), meter: &meter)
        guard try lookup(key.string, meter: &meter) != nil else { return self }
        let result = try JSONEditing.modify(.object(self), token: key, change: .remove, meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.value(result, meter: &meter)
        return result.objectValue!
    }
}
