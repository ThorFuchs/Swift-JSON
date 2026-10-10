// SPDX-License-Identifier: Apache-2.0
public struct JSONArrayAccumulator: ~Copyable {
    private var values: [JSON] = []
    private var meter: JSONWorkMeter
    public init(limits: JSONLimits = .balanced) throws {
        var initialMeter = try JSONWorkMeter(limits: limits, domain: .core)
        try initialMeter.require(.maxDepth, 1); try initialMeter.charge(.nodes); try initialMeter.retain(JSONLogicalWeights.node)
        meter = initialMeter
    }
    public mutating func append(_ value: JSON) throws {
        try meter.require(.arrayItems, UInt64(values.count) + 1)
        try JSONAdmission.value(value, meter: &meter, owned: true, depth: 1)
        try meter.retain(JSONLogicalWeights.arraySlot); values.append(value)
    }
    public mutating func append(contentsOf values: [JSON]) throws {
        for value in values { try append(value) }
    }
    public consuming func finish() -> [JSON] { values }
}
extension JSON {
    public static func buildArray(limits: JSONLimits = .balanced, _ body: (inout JSONArrayAccumulator) throws -> Void) throws -> Self {
        var accumulator = try JSONArrayAccumulator(limits: limits)
        try body(&accumulator)
        return .array(accumulator.finish())
    }
}
