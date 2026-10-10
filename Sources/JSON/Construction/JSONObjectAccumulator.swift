// SPDX-License-Identifier: Apache-2.0
public struct JSONObjectAccumulator: ~Copyable {
    private var members: [JSONMember] = []
    private var meter: JSONWorkMeter
    public init(limits: JSONLimits = .balanced) throws {
        var initialMeter = try JSONWorkMeter(limits: limits, domain: .core)
        try initialMeter.require(.maxDepth, 1); try initialMeter.charge(.nodes); try initialMeter.retain(JSONLogicalWeights.node)
        meter = initialMeter
    }
    public mutating func append(_ key: String, value: JSON) throws {
        try meter.require(.objectMembers, UInt64(members.count) + 1)
        try JSONAdmission.text(key, key: true, meter: &meter, owned: true)
        for member in members {
            if try JSONComparison.textEquals(member.key.string, key, meter: &meter) {
                throw JSONFailure(.syntax, code: .duplicateKey)
            }
        }
        try JSONAdmission.value(value, meter: &meter, owned: true, depth: 1)
        try meter.retain(JSONLogicalWeights.member + JSONLogicalWeights.indexSlot)
        members.append(JSONMember(try JSONKey(key, meter: &meter), value: value))
    }
    public consuming func finish() -> JSONObject { JSONObject(admitted: members) }
}

extension JSONObject {
    public static func build(limits: JSONLimits = .balanced, _ body: (inout JSONObjectAccumulator) throws -> Void) throws -> Self {
        var accumulator = try JSONObjectAccumulator(limits: limits)
        try body(&accumulator)
        return accumulator.finish()
    }
}
