// SPDX-License-Identifier: Apache-2.0
import JSON

package enum ExactDecimal {
    /// Keeps the normalized coefficient reservation alive until complete result
    /// admission; a JSONNumber array alias alone cannot own its scratch lease.
    private struct Result {
        let number: JSONNumber
        let storage: DecimalMagnitude?
        init(_ number: JSONNumber, storage: DecimalMagnitude? = nil) { self.number = number; self.storage = storage }
        init(components: DecimalComponents) { number = .init(components: components); storage = nil }
    }
    private static func failure(_ context: inout TransformRuntimeContext, metric: JSONResourceMetric = .absoluteExponent) throws -> Never {
        let error = JSONFailure(.resource, code: .counterOverflow, resource: .init(domain: context.meter.domain, metric: metric, limit: context.meter.limits[metric], attemptedUsage: nil, overflow: true))
        context.latch(error); throw error
    }
    private static func addExponent(_ a: Int64, _ b: Int64, context: inout TransformRuntimeContext) throws -> Int64 {
        let (sum, overflow) = a.addingReportingOverflow(b); if overflow { try failure(&context) }; return sum
    }
    private static func subtractExponent(_ a: Int64, _ b: Int64, context: inout TransformRuntimeContext) throws -> Int64 {
        let (difference, overflow) = a.subtractingReportingOverflow(b); if overflow { try failure(&context) }; return difference
    }
    private static func admit(_ number: JSONNumber, context: inout TransformRuntimeContext) throws {
        try context.meter.resetValueBounds(); try JSONAdmission.value(.number(number), meter: &context.meter)
    }
    private static func admitToken(_ number: JSONNumber, context: inout TransformRuntimeContext) throws {
        let c = number.components
        var bytes = UInt64(c.digits.count) + (c.negative ? 1 : 0)
        if c.exponent != 0 { try context.work(20); bytes += 1 + UInt64(String(c.exponent).utf8.count) }
        try context.meter.require(.numberTokenBytes, bytes)
    }
    private static func normalized(_ magnitude: DecimalMagnitude, negative: Bool, exponent: Int64, context: inout TransformRuntimeContext) throws -> Result {
        if magnitude.isZero { try DecimalMagnitude.step(&context); return Result(JSONNumber(integer: 0)) }
        var value = try magnitude.coefficient(context: &context), exponent = exponent
        while try value.removingTrailingZero(context: &context) { exponent = try addExponent(exponent, 1, context: &context) }
        try context.meter.require(.numberDigits, UInt64(value.count)); try context.meter.require(.absoluteExponent, exponent.magnitude)
        return Result(.init(components: .init(negative: negative, digits: value.coefficientDigits, exponent: exponent)), storage: value)
    }
    package static func binary(_ op: String, _ lhs: JSONNumber, _ rhs: JSONNumber, context: inout TransformRuntimeContext) throws -> FilterYield {
        try context.checkpoint(); try admit(lhs, context: &context); try admit(rhs, context: &context)
        let number: Result
        switch op {
        case "+", "-": number = try adding(lhs, rhs, subtract: op == "-", context: &context)
        case "*":
            let a = lhs.components, b = rhs.components
            if a.isZero || b.isZero { number = Result(JSONNumber(integer: 0)) }
            else {
                let exponent = try addExponent(a.exponent, b.exponent, context: &context)
                let value = try DecimalMagnitude.multiply(.init(borrowing: a.digits), .init(borrowing: b.digits), context: &context)
                number = try normalized(value, negative: a.negative != b.negative, exponent: exponent, context: &context)
            }
        case "/": number = try dividing(lhs, rhs, context: &context)
        case "%":
            guard lhs.isInteger, rhs.isInteger else { throw FilterLanguageFailure("integralOperandsRequired") }
            guard !rhs.isZero else { throw FilterLanguageFailure("divisionByZero") }
            let a = lhs.components, b = rhs.components
            let left = try DecimalMagnitude.shifted(.init(borrowing: a.digits), zeros: a.exponent, context: &context)
            let right = try DecimalMagnitude.shifted(.init(borrowing: b.digits), zeros: b.exponent, context: &context)
            let value = try DecimalMagnitude.divmod(left, right, context: &context).remainder
            number = try normalized(value, negative: a.negative, exponent: 0, context: &context)
        default: throw FilterLanguageFailure("unknownArithmeticOperator")
        }
        return try withExtendedLifetime(number) {
            try admitToken(number.number, context: &context)
            return try FilterValues.produced(.number(number.number), context: &context)
        }
    }
    private static func adding(_ lhs: JSONNumber, _ rhs: JSONNumber, subtract: Bool, context: inout TransformRuntimeContext) throws -> Result {
        let a = lhs.components, originalB = rhs.components
        let b = DecimalComponents(negative: !originalB.isZero && (originalB.negative != subtract), digits: originalB.digits, exponent: originalB.exponent)
        if a.isZero { return .init(components: b) }
        if b.isZero { return .init(components: a) }
        let exponent = min(a.exponent, b.exponent)
        let left = try DecimalMagnitude.shifted(.init(borrowing: a.digits), zeros: subtractExponent(a.exponent, exponent, context: &context), context: &context)
        let right = try DecimalMagnitude.shifted(.init(borrowing: b.digits), zeros: subtractExponent(b.exponent, exponent, context: &context), context: &context)
        let value: DecimalMagnitude, negative: Bool
        if a.negative == b.negative { value = try .add(left, right, context: &context); negative = a.negative }
        else if try DecimalMagnitude.compare(left, right, context: &context) >= 0 { value = try .subtract(left, right, context: &context); negative = a.negative }
        else { value = try .subtract(right, left, context: &context); negative = b.negative }
        return try normalized(value, negative: negative, exponent: exponent, context: &context)
    }
    private static func discarded(context: inout TransformRuntimeContext) throws {
        let (next, overflow) = context.roundedDivisions.addingReportingOverflow(1)
        if overflow { try failure(&context, metric: .workUnits) }; context.roundedDivisions = next
    }
    private static func quantized(_ input: Result, scale: Int, context: inout TransformRuntimeContext) throws -> Result {
        return try withExtendedLifetime(input) {
        let c = input.number.components, target = -Int64(scale)
        if c.isZero || c.exponent >= target { return input }
        let drop = try subtractExponent(target, c.exponent, context: &context)
        let length = Int64(c.digits.count), prefix = drop >= length ? 0 : Int(length-drop)
        var quotient: DecimalMagnitude
        if prefix == 0 { quotient = .zero() }
        else { quotient = try DecimalMagnitude.prefix(c.digits, count: prefix, context: &context) }
        var above = false, tie = false
        if drop <= length {
            let first = c.digits[prefix]; try DecimalMagnitude.step(&context)
            var rest = false
            if prefix+1 < c.digits.count { for digit in c.digits[(prefix+1)...] { try DecimalMagnitude.step(&context); if digit != 0 { rest = true } } }
            above = first > 5 || first == 5 && rest; tie = first == 5 && !rest
        }
        if above || tie && quotient[quotient.count-1] & 1 == 1 {
            quotient = try .add(quotient, .init(borrowing: [1]), context: &context)
        }
        try discarded(context: &context)
        return try normalized(quotient, negative: c.negative, exponent: target, context: &context)
        }
    }
    private static func dividing(_ lhs: JSONNumber, _ rhs: JSONNumber, context: inout TransformRuntimeContext) throws -> Result {
        guard !rhs.isZero else { throw FilterLanguageFailure("divisionByZero") }
        if lhs.isZero { return Result(JSONNumber(integer: 0)) }
        let a = lhs.components, b = rhs.components
        let exponent = try subtractExponent(a.exponent, b.exponent, context: &context)
        let left = DecimalMagnitude(borrowing: a.digits), right = DecimalMagnitude(borrowing: b.digits)
        let common = try DecimalMagnitude.gcd(left, right, context: &context)
        let numerator = try DecimalMagnitude.divmod(left, common, context: &context).quotient
        let denominator = try DecimalMagnitude.divmod(right, common, context: &context).quotient
        var remaining = denominator, twos: Int64 = 0, fives: Int64 = 0
        while true {
            let pair = try DecimalMagnitude.divmod(remaining, .init(borrowing: [2]), context: &context)
            if !pair.remainder.isZero { break }
            remaining = pair.quotient; twos = try addExponent(twos, 1, context: &context)
        }
        while true {
            let pair = try DecimalMagnitude.divmod(remaining, .init(borrowing: [5]), context: &context)
            if !pair.remainder.isZero { break }
            remaining = pair.quotient; fives = try addExponent(fives, 1, context: &context)
        }
        let negative = a.negative != b.negative
        if remaining.count == 1 && remaining[0] == 1 {
            let places = max(twos, fives)
            var coefficient = numerator
            if twos < places { for _ in twos..<places { coefficient = try .multiply(coefficient, .init(borrowing: [2]), context: &context) } }
            if fives < places { for _ in fives..<places { coefficient = try .multiply(coefficient, .init(borrowing: [5]), context: &context) } }
            let value = try normalized(coefficient, negative: negative, exponent: subtractExponent(exponent, places, context: &context), context: &context)
            if let scale = context.divisionScale { return try quantized(value, scale: scale, context: &context) }
            return value
        }
        guard let scale = context.divisionScale else { throw FilterLanguageFailure("inexactDivision") }
        let shift = try addExponent(exponent, Int64(scale), context: &context)
        // A sparse exponent shortcut is exact: even twice the numerator is below
        // the denominator when this decimal-order separation exceeds one place.
        let order = try addExponent(Int64(numerator.count), shift, context: &context)
        if order < Int64(denominator.count)-1 { try discarded(context: &context); return Result(JSONNumber(integer: 0)) }
        let n: DecimalMagnitude, d: DecimalMagnitude
        if shift >= 0 { n = try .shifted(numerator, zeros: shift, context: &context); d = denominator }
        else { n = numerator; d = try .shifted(denominator, zeros: -shift, context: &context) }
        let pair = try DecimalMagnitude.divmod(n, d, context: &context)
        var quotient = pair.quotient
        if !pair.remainder.isZero {
            let twice = try DecimalMagnitude.multiply(pair.remainder, .init(borrowing: [2]), context: &context)
            let order = try DecimalMagnitude.compare(twice, d, context: &context)
            if order > 0 || order == 0 && quotient[quotient.count-1] & 1 == 1 { quotient = try .add(quotient, .init(borrowing: [1]), context: &context) }
            try discarded(context: &context)
        }
        return try normalized(quotient, negative: negative, exponent: -Int64(scale), context: &context)
    }
    package static func unary(_ name: String, _ number: JSONNumber, context: inout TransformRuntimeContext) throws -> FilterYield {
        try context.checkpoint(); try admit(number, context: &context)
        let c = number.components, output: Result
        if name == "positive" { output = .init(components: c) }
        else if name == "abs" { output = .init(components: .init(negative: false, digits: c.digits, exponent: c.exponent)) }
        else if name == "negate" { output = .init(components: .init(negative: !c.isZero && !c.negative, digits: c.digits, exponent: c.exponent)) }
        else if c.isZero || c.exponent >= 0 { output = .init(components: c) }
        else {
            let drop = c.exponent.magnitude, length = UInt64(c.digits.count), prefix = drop >= length ? 0 : Int(length-drop)
            var quotient = prefix == 0 ? DecimalMagnitude.zero() : try DecimalMagnitude.prefix(c.digits, count: prefix, context: &context)
            let increase: Bool
            switch name {
            case "floor": increase = c.negative
            case "ceil": increase = !c.negative
            case "trunc": increase = false
            case "round": increase = drop <= length && c.digits[prefix] >= 5
            default: throw FilterLanguageFailure("unknownArithmeticBuiltin")
            }
            if increase { quotient = try .add(quotient, .init(borrowing: [1]), context: &context) }
            output = try normalized(quotient, negative: c.negative, exponent: 0, context: &context)
        }
        return try withExtendedLifetime(output) {
            try admitToken(output.number, context: &context)
            return try FilterValues.produced(.number(output.number), context: &context)
        }
    }
}
