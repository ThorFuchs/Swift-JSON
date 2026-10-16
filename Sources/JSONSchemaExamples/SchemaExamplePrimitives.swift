// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

// Conservative hints only. Complete native validation, not these proposals,
// establishes whether all constraints on the resulting instance are satisfied.
enum SchemaExamplePrimitives {
    struct Bound { let number: JSONNumber; let open: Bool }
    static func number(_ constraints: [SchemaExampleConstraint], integral: Bool, variation: UInt64,
                       meter: inout JSONWorkMeter) throws -> JSONNumber? {
        try meter.retain(64)
        var lower: Bound?, upper: Bound?, step: JSONNumber?, precision: Int64 = 0
        for c in constraints {
            for kind in [JSONSchemaPlan.Keyword.minimum, .exclusiveMinimum, .maximum, .exclusiveMaximum] {
                guard let n = try c.value(kind, meter: &meter)?.numberValue else { continue }
                precision = min(precision, n.components.exponent)
                let candidate = Bound(number: n, open: kind == .exclusiveMinimum || kind == .exclusiveMaximum)
                if kind == .minimum || kind == .exclusiveMinimum {
                    if let prior = lower {
                        let order = try n.compare(to: prior.number, meter: &meter)
                        if order == .orderedDescending || order == .orderedSame && candidate.open { lower = candidate }
                    } else { lower = candidate }
                } else {
                    if let prior = upper {
                        let order = try n.compare(to: prior.number, meter: &meter)
                        if order == .orderedAscending || order == .orderedSame && candidate.open { upper = candidate }
                    } else { upper = candidate }
                }
            }
            if step == nil { step = try c.value(.multipleOf, meter: &meter)?.numberValue }
        }
        if let lower, let upper {
            let order = try lower.number.compare(to: upper.number, meter: &meter)
            if order == .orderedDescending || order == .orderedSame && (lower.open || upper.open) { return nil }
        }
        let stride: JSONNumber
        if let step {
            stride = integral ? try SchemaExampleDecimal.integralStep(step, meter: &meter) : step
        } else {
            let exponent = integral ? 0 : precision - 1 // admitted exponent magnitudes fit Int capacity, safely below Int64.max
            try meter.require(.absoluteExponent, exponent.magnitude)
            try meter.retain(1)
            stride = JSONNumber(components: .init(negative: false, digits: [1], exponent: exponent))
        }
        func fits(_ n: JSONNumber, meter: inout JSONWorkMeter) throws -> Bool {
            if let lower {
                let order = try n.compare(to: lower.number, meter: &meter)
                if order == .orderedAscending || order == .orderedSame && lower.open { return false }
            }
            if let upper {
                let order = try n.compare(to: upper.number, meter: &meter)
                if order == .orderedDescending || order == .orderedSame && upper.open { return false }
            }
            return true
        }
        let zero = JSONNumber(integer: 0)
        let candidate: JSONNumber
        if try fits(zero, meter: &meter) {
            candidate = try SchemaExampleDecimal.rounded(zero, step: stride, up: true, open: false, variation: variation, meter: &meter)
        } else if let lower {
            candidate = try SchemaExampleDecimal.rounded(lower.number, step: stride, up: true, open: lower.open, variation: variation, meter: &meter)
        } else if let upper {
            candidate = try SchemaExampleDecimal.rounded(upper.number, step: stride, up: false, open: upper.open, variation: variation, meter: &meter)
        } else { return nil }
        return try fits(candidate, meter: &meter) ? candidate : nil
    }

    static func size(_ constraints: [SchemaExampleConstraint], minimum: JSONSchemaPlan.Keyword,
                     maximum: JSONSchemaPlan.Keyword, capacity: JSONResourceMetric,
                     meter: inout JSONWorkMeter) throws -> (minimum: UInt64, maximum: UInt64)? {
        var lo: UInt64 = 0, hi = meter.limits[capacity]
        for c in constraints {
            if let n = try c.value(minimum, meter: &meter)?.numberValue { lo = max(lo, try n.integer(as: UInt64.self, meter: &meter)) }
            if let n = try c.value(maximum, meter: &meter)?.numberValue { hi = min(hi, try n.integer(as: UInt64.self, meter: &meter)) }
        }
        try meter.require(capacity, lo)
        return lo <= hi ? (lo,hi) : nil
    }
    static func string(_ constraints: [SchemaExampleConstraint], variation: UInt64,
                       profile: JSONSchemaExampleProfile, corpus: [JSON], assertion: Bool,
                       random: inout SchemaExampleRandom, trace: inout SchemaExampleTrace,
                       meter: inout JSONWorkMeter) throws -> String? {
        guard let bounds = try size(constraints, minimum: .minLength, maximum: .maxLength,
                                    capacity: .stringBytes, meter: &meter) else { return nil }
        for c in constraints {
            if let pattern = try c.value(.pattern, meter: &meter)?.stringValue,
               let proposal = try SchemaExamplePattern.propose(pattern, variation: variation, minimum: bounds.minimum,
                                                               maximum: bounds.maximum, meter: &meter) { return proposal }
        }
        var email = false
        for c in constraints {
            if c.view.formatAssertion || assertion,
               let format = try c.value(.format, meter: &meter)?.stringValue,
               try JSONComparison.textEquals(format, "email", meter: &meter) { email = true }
        }
        var token = ""
        if email { token = "example@example.com" }
        else if profile == .demonstration && variation == 0 {
            var strings: [String] = []
            for value in corpus {
                try meter.work()
                if let text = value.stringValue { try meter.retain(JSONLogicalWeights.indexSlot); strings.append(text) }
            }
            if !strings.isEmpty {
                token = strings[Int(try random.uniform(upperBound: UInt64(strings.count), trace: &trace, meter: &meter))]
            }
        }
        var bytes: [UInt8] = [], scalars: UInt64 = 0
        func append(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
            try meter.work(); try meter.require(.stringBytes, UInt64(bytes.count) + 1)
            try meter.charge(.aggregateTextBytes); try meter.retain(1); bytes.append(byte)
        }
        for scalar in token.unicodeScalars {
            try meter.work()
            if scalars == bounds.maximum { break }
            // A Unicode scalar has at most four bytes. Charge the bounded temporary
            // before native scalar encoding, then the actual output bytes.
            try meter.retain(4)
            for byte in String(scalar).utf8 { try append(byte, meter: &meter) }
            try meter.release(4); scalars += 1
        }
        var length = bounds.minimum
        if variation > 0 && length == 0 { length = min(1, bounds.maximum) }
        while scalars < length {
            try append(UInt8(97 + variation % 26), meter: &meter); scalars += 1
        }
        // String's owned UTF-8 result overlaps its construction buffer.
        for _ in bytes { try meter.work(); try meter.retain(1) }
        return String(decoding: bytes, as: UTF8.self)
    }
}
