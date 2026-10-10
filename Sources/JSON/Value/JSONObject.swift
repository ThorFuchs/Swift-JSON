// SPDX-License-Identifier: Apache-2.0
/// Ordered members with order-independent mathematical equality.
public struct JSONObject: Sendable, Hashable, RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = JSONMember
    public let members: [JSONMember]
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
    public var startIndex: Int { members.startIndex }
    public var endIndex: Int { members.endIndex }
    public subscript(position: Int) -> JSONMember { members[position] }
    public subscript(key: JSONKey) -> JSON? { members.first { $0.key == key }?.value }
    public subscript(key: String) -> JSON? { self[JSONKey(key)] }
    public static func == (lhs: Self, rhs: Self) -> Bool { JSON.object(lhs) == JSON.object(rhs) }
    public func hash(into hasher: inout Hasher) { JSON.object(self).hash(into: &hasher) }
    package func lookup(_ key: String, meter: inout JSONWorkMeter) throws -> JSON? {
        for member in members {
            try meter.work()
            if try JSONComparison.textEquals(member.key.string, key, meter: &meter) { return member.value }
        }
        return nil
    }
    public func setting(_ value: JSON, for key: JSONKey, limits: JSONLimits = .balanced) throws -> Self {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        try JSONAdmission.value(.object(self), meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.text(key.string, key: true, meter: &meter, owned: true)
        try JSONAdmission.value(value, meter: &meter, owned: true, depth: 1)
        let result = try JSONEditing.modify(.object(self), token: key, change: .add(value), meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.value(result, meter: &meter)
        return result.objectValue!
    }
    public func removing(_ key: JSONKey, limits: JSONLimits = .balanced) throws -> Self {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        try JSONAdmission.value(.object(self), meter: &meter)
        guard try lookup(key.string, meter: &meter) != nil else { return self }
        let result = try JSONEditing.modify(.object(self), token: key, change: .remove, meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.value(result, meter: &meter)
        return result.objectValue!
    }
}
