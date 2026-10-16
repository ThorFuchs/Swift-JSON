// SPDX-License-Identifier: Apache-2.0
import JSON

// Dense scratch is deliberately finite. Exponents stay sparse until an exact
// quotient needs alignment, which must fit numberDigits before zero expansion.
enum SchemaExampleDecimal {
    struct Integer { let negative: Bool; let digits: [UInt8] }
    static func tick(_ meter: inout JSONWorkMeter) throws { try meter.work(subsystem: .numericWorkUnits) }
    static func append(_ digit: UInt8, to digits: inout [UInt8], meter: inout JSONWorkMeter) throws {
        try tick(&meter); try meter.require(.numberDigits, UInt64(digits.count) + 1)
        try meter.retain(1); digits.append(digit)
    }
    static func zero(_ digits: [UInt8]) -> Bool { digits.count == 1 && digits[0] == 0 }
    static func trim(_ digits: [UInt8], meter: inout JSONWorkMeter) throws -> [UInt8] {
        var start = 0
        while start < digits.count - 1 && digits[start] == 0 { try tick(&meter); start += 1 }
        var result: [UInt8] = []
        for digit in digits[start...] { try append(digit, to: &result, meter: &meter) }
        return result
    }
    static func compare(_ a: [UInt8], _ b: [UInt8], meter: inout JSONWorkMeter) throws -> Int {
        try tick(&meter)
        if a.count != b.count { return a.count < b.count ? -1 : 1 }
        for i in a.indices { try tick(&meter); if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 } }
        return 0
    }
    static func subtract(_ a: [UInt8], _ b: [UInt8], meter: inout JSONWorkMeter) throws -> [UInt8] {
        var reversed: [UInt8] = [], borrow = 0
        for offset in 0..<a.count {
            try tick(&meter)
            let digit = offset < b.count ? Int(b[b.count - 1 - offset]) : 0
            var difference = Int(a[a.count - 1 - offset]) - digit - borrow
            borrow = difference < 0 ? 1 : 0
            if difference < 0 { difference += 10 }
            try append(UInt8(difference), to: &reversed, meter: &meter)
        }
        guard borrow == 0 else { throw JSONFailure(.configuration, code: .invalidOperation) }
        var result: [UInt8] = []
        for d in reversed.reversed() { try append(d, to: &result, meter: &meter) }
        return try trim(result, meter: &meter)
    }
    static func add(_ a: [UInt8], _ b: [UInt8], meter: inout JSONWorkMeter) throws -> [UInt8] {
        var reversed: [UInt8] = [], carry = 0
        for offset in 0..<max(a.count, b.count) {
            try tick(&meter)
            let x = offset < a.count ? Int(a[a.count - 1 - offset]) : 0
            let y = offset < b.count ? Int(b[b.count - 1 - offset]) : 0
            let sum = x + y + carry; carry = sum / 10
            try append(UInt8(sum % 10), to: &reversed, meter: &meter)
        }
        if carry != 0 { try append(UInt8(carry), to: &reversed, meter: &meter) }
        var result: [UInt8] = []
        for d in reversed.reversed() { try append(d, to: &result, meter: &meter) }
        return result
    }
    static func offset(_ value: Integer, by amount: UInt64, negative: Bool,
                       meter: inout JSONWorkMeter) throws -> Integer {
        var reversed: [UInt8] = [], remainder = amount
        repeat { try append(UInt8(remainder % 10), to: &reversed, meter: &meter); remainder /= 10 } while remainder != 0
        var digits: [UInt8] = []
        for d in reversed.reversed() { try append(d, to: &digits, meter: &meter) }
        if value.negative == negative { return .init(negative: negative, digits: try add(value.digits, digits, meter: &meter)) }
        let order = try compare(value.digits, digits, meter: &meter)
        if order >= 0 { return .init(negative: value.negative, digits: try subtract(value.digits, digits, meter: &meter)) }
        return .init(negative: negative, digits: try subtract(digits, value.digits, meter: &meter))
    }
    static func aligned(_ c: DecimalComponents, exponent: Int64, meter: inout JSONWorkMeter) throws -> [UInt8] {
        if zero(c.digits) { try meter.retain(1); return [0] }
        let (shift, overflow) = c.exponent.subtractingReportingOverflow(exponent)
        guard !overflow, shift >= 0 else { throw JSONFailure(.resource, code: .counterOverflow) }
        _ = try meter.adding(.numberDigits, UInt64(c.digits.count), UInt64(shift))
        var result: [UInt8] = []
        for d in c.digits { try append(d, to: &result, meter: &meter) }
        for _ in 0..<shift { try append(0, to: &result, meter: &meter) }
        return result
    }
    static func divide(_ a: [UInt8], by b: [UInt8], meter: inout JSONWorkMeter) throws -> (quotient: [UInt8], remainder: Bool) {
        guard !zero(b) else { throw JSONFailure(.configuration, code: .invalidNumber) }
        try meter.retain(1)
        var remainder: [UInt8] = [0], quotient: [UInt8] = []
        for digit in a {
            try tick(&meter)
            if zero(remainder) { remainder[0] = digit } else { try append(digit, to: &remainder, meter: &meter) }
            var q: UInt8 = 0
            while try compare(remainder, b, meter: &meter) >= 0 {
                remainder = try subtract(remainder, b, meter: &meter); q += 1
            }
            guard q <= 9 else { throw JSONFailure(.configuration, code: .invalidOperation) }
            try append(q, to: &quotient, meter: &meter)
        }
        return (try trim(quotient, meter: &meter), !zero(remainder))
    }
    static func multiply(_ a: [UInt8], _ b: [UInt8], meter: inout JSONWorkMeter) throws -> [UInt8] {
        let count = try meter.adding(.retainedBytes, UInt64(a.count), UInt64(b.count))
        try meter.retain(count)
        for _ in 0..<count { try tick(&meter) }
        var digits = Array(repeating: UInt8(0), count: Int(count))
        for i in a.indices.reversed() {
            var carry = 0
            for j in b.indices.reversed() {
                try tick(&meter)
                let n = Int(digits[i + j + 1]) + Int(a[i]) * Int(b[j]) + carry
                digits[i + j + 1] = UInt8(n % 10); carry = n / 10
            }
            digits[i] = UInt8(carry)
        }
        return try trim(digits, meter: &meter)
    }
    static func number(_ digits: [UInt8], negative: Bool, exponent: Int64, meter: inout JSONWorkMeter) throws -> JSONNumber {
        var digits = try trim(digits, meter: &meter), exponent = exponent
        while digits.count > 1 && digits.last == 0 {
            try tick(&meter); digits.removeLast()
            let (next, overflow) = exponent.addingReportingOverflow(1)
            guard !overflow else { throw JSONFailure(.resource, code: .counterOverflow) }; exponent = next
        }
        try meter.require(.absoluteExponent, exponent.magnitude)
        return JSONNumber(components: .init(negative: negative && !zero(digits), digits: digits, exponent: zero(digits) ? 0 : exponent))
    }
    static func integralStep(_ step: JSONNumber, meter: inout JSONWorkMeter) throws -> JSONNumber {
        let c = step.components
        if c.exponent >= 0 { return step }
        var digits = c.digits
        for factor in [2, 5] {
            for _ in 0..<c.exponent.magnitude {
                try tick(&meter)
                var remainder = 0, next: [UInt8] = []
                for d in digits {
                    try tick(&meter); let n = remainder * 10 + Int(d)
                    try append(UInt8(n / factor), to: &next, meter: &meter); remainder = n % factor
                }
                if remainder != 0 { break }
                digits = try trim(next, meter: &meter)
            }
        }
        return try number(digits, negative: false, exponent: 0, meter: &meter)
    }
    static func rounded(_ bound: JSONNumber, step: JSONNumber, up: Bool, open: Bool,
                        variation: UInt64, meter: inout JSONWorkMeter) throws -> JSONNumber {
        let a = bound.components, b = step.components, common = min(a.exponent, b.exponent)
        // Preserve sparse, already-aligned endpoints without materializing their quotient.
        if variation == 0, !open, try bound.isMultiple(of: step, meter: &meter) { return bound }
        let dividend = try aligned(a, exponent: common, meter: &meter)
        let divisor = try aligned(b, exponent: common, meter: &meter)
        let division = try divide(dividend, by: divisor, meter: &meter)
        var integer = Integer(negative: a.negative, digits: division.quotient)
        if division.remainder && up != a.negative {
            integer = try offset(integer, by: 1, negative: a.negative, meter: &meter)
        }
        if !division.remainder && open { integer = try offset(integer, by: 1, negative: !up, meter: &meter) }
        if variation > 0 { integer = try offset(integer, by: variation, negative: !up, meter: &meter) }
        let product = try multiply(integer.digits, b.digits, meter: &meter)
        return try number(product, negative: integer.negative, exponent: b.exponent, meter: &meter)
    }
}
