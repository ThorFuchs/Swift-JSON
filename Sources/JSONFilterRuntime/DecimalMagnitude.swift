// SPDX-License-Identifier: Apache-2.0
import JSON

/// Base-ten unsigned working magnitude. Every mutable digit buffer owns an
/// invocation lease; aliases share that reservation until their last release.
package struct DecimalMagnitude {
    private(set) var storage: [UInt8]
    private var start: Int = 0
    private let lease: CLIValueLease?
    package init(borrowing digits: [UInt8]) { storage = digits; lease = nil }
    private init(storage: [UInt8], lease: CLIValueLease) { self.storage = storage; self.lease = lease }
    package var count: Int { storage.count - start }
    package var isZero: Bool { count == 1 && storage[start] == 0 }
    package subscript(_ index: Int) -> UInt8 { storage[start + index] }
    package static func zero() -> Self { .init(borrowing: [0]) }
    package static func allocate(_ count: Int, context: inout CLIJobContext) throws -> Self {
        try context.checkpoint()
        guard count > 0, count < Int.max else { throw CLIError(.resource, "counterOverflow", metric: "numberDigits") }
        let maximum = context.meter.limits[.numberDigits]
        let (twice, overflow) = maximum.multipliedReportingOverflow(by: 2)
        let (scratch, extraOverflow) = twice.addingReportingOverflow(2)
        guard !overflow, !extraOverflow, UInt64(count) <= scratch else { try context.meter.require(.numberDigits, UInt64(count)); throw CLIError(.resource, "limitExceeded", metric: "numberDigits") }
        try context.meter.retain(UInt64(count))
        let lease: CLIValueLease
        do { lease = try .init(ownedRetained: UInt64(count), context: &context) }
        catch { try context.meter.release(UInt64(count)); throw error }
        return .init(storage: [UInt8](repeating: 0, count: count), lease: lease)
    }
    package static func step(_ context: inout CLIJobContext) throws { try context.meter.work(subsystem: .numericWorkUnits) }
    private mutating func trim(context: inout CLIJobContext) throws {
        while start + 1 < storage.count && storage[start] == 0 { try Self.step(&context); start += 1 }
    }
    package static func compare(_ a: Self, _ b: Self, context: inout CLIJobContext) throws -> Int {
        try step(&context)
        if a.count != b.count { return a.count < b.count ? -1 : 1 }
        for i in 0..<a.count { try step(&context); if a[i] != b[i] { return a[i] < b[i] ? -1 : 1 } }
        return 0
    }
    package static func add(_ a: Self, _ b: Self, context: inout CLIJobContext) throws -> Self {
        let count = max(a.count, b.count)
        var output = try allocate(count + 1, context: &context), carry: UInt16 = 0
        for offset in 0..<count {
            try step(&context)
            let left = offset < a.count ? UInt16(a[a.count - 1 - offset]) : 0
            let right = offset < b.count ? UInt16(b[b.count - 1 - offset]) : 0
            let sum = left + right + carry // <= 9 + 9 + 1 = 19 on every host
            output.storage[count - offset] = UInt8(sum % 10); carry = sum / 10
        }
        output.storage[0] = UInt8(carry); try output.trim(context: &context); return output
    }
    package static func subtract(_ a: Self, _ b: Self, context: inout CLIJobContext) throws -> Self {
        guard try compare(a, b, context: &context) >= 0 else { throw CLIError(.resource, "arithmeticInvariant") }
        var output = try allocate(a.count, context: &context), borrow: Int16 = 0
        for offset in 0..<a.count {
            try step(&context)
            let right = offset < b.count ? Int16(b[b.count - 1 - offset]) : 0
            var digit = Int16(a[a.count - 1 - offset]) - right - borrow
            borrow = digit < 0 ? 1 : 0; if digit < 0 { digit += 10 }
            output.storage[a.count - 1 - offset] = UInt8(digit)
        }
        guard borrow == 0 else { throw CLIError(.resource, "arithmeticInvariant") }
        try output.trim(context: &context); return output
    }
    package static func multiply(_ a: Self, _ b: Self, context: inout CLIJobContext) throws -> Self {
        if a.isZero || b.isZero { try step(&context); return .zero() }
        let (count, overflow) = a.count.addingReportingOverflow(b.count)
        guard !overflow else { throw CLIError(.resource, "counterOverflow", metric: "numberDigits") }
        var output = try allocate(count, context: &context)
        for i in (0..<a.count).reversed() {
            var carry: UInt16 = 0
            for j in (0..<b.count).reversed() {
                try step(&context)
                let sum = UInt16(a[i]) * UInt16(b[j]) + UInt16(output.storage[i+j+1]) + carry
                // 81 + 9 + 9 <= 99, independent of Int/UInt host width.
                output.storage[i+j+1] = UInt8(sum % 10); carry = sum / 10
            }
            output.storage[i] = UInt8(carry)
        }
        try output.trim(context: &context); return output
    }
    package static func shifted(_ value: Self, zeros: Int64, context: inout CLIJobContext) throws -> Self {
        guard zeros >= 0 else { throw CLIError(.resource, "arithmeticInvariant") }
        if value.isZero { try step(&context); return .zero() }
        let (count, overflow) = UInt64(value.count).addingReportingOverflow(UInt64(zeros))
        guard !overflow, count < UInt64(Int.max) else { throw CLIError(.resource, "counterOverflow", metric: "numberDigits") }
        var output = try allocate(Int(count), context: &context)
        for i in 0..<value.count { try step(&context); output.storage[i] = value[i] }
        // Charge every admitted zero initialization, not just the source digits.
        for _ in value.count..<Int(count) { try step(&context) }
        return output
    }
    package static func divmod(_ a: Self, _ b: Self, context: inout CLIJobContext) throws -> (quotient: Self, remainder: Self) {
        guard !b.isZero else { throw FilterLanguageFailure("divisionByZero") }
        if try compare(a, b, context: &context) < 0 { return (.zero(), a) }
        var quotient = try allocate(a.count, context: &context)
        var remainder = try allocate(b.count + 1, context: &context), used = 1
        func remainderCompare(context: inout CLIJobContext) throws -> Int {
            try step(&context)
            if used != b.count { return used < b.count ? -1 : 1 }
            for i in 0..<used { try step(&context); if remainder.storage[i] != b[i] { return remainder.storage[i] < b[i] ? -1 : 1 } }
            return 0
        }
        for i in 0..<a.count {
            try step(&context)
            if used == 1 && remainder.storage[0] == 0 { remainder.storage[0] = a[i] }
            else { remainder.storage[used] = a[i]; used += 1 }
            var digit: UInt8 = 0
            while try remainderCompare(context: &context) >= 0 {
                var borrow: Int16 = 0
                for offset in 0..<used {
                    try step(&context)
                    let right = offset < b.count ? Int16(b[b.count - 1 - offset]) : 0
                    let index = used - 1 - offset
                    var value = Int16(remainder.storage[index]) - right - borrow
                    borrow = value < 0 ? 1 : 0; if value < 0 { value += 10 }
                    remainder.storage[index] = UInt8(value)
                }
                guard borrow == 0, digit < 9 else { throw CLIError(.resource, "arithmeticInvariant") }
                digit += 1
                while used > 1 && remainder.storage[0] == 0 {
                    for j in 1..<used { try step(&context); remainder.storage[j-1] = remainder.storage[j] }
                    used -= 1
                }
            }
            quotient.storage[i] = digit
        }
        try quotient.trim(context: &context)
        // Copy the used prefix into independently admitted result storage.
        var result = try allocate(used, context: &context)
        for i in 0..<used { try step(&context); result.storage[i] = remainder.storage[i] }
        try result.trim(context: &context)
        return (quotient, result)
    }
    package static func gcd(_ a: Self, _ b: Self, context: inout CLIJobContext) throws -> Self {
        var left = a, right = b
        while !right.isZero {
            try context.checkpoint(); try step(&context)
            let next = try divmod(left, right, context: &context).remainder
            left = right; right = next
        }
        return left
    }
    package func coefficient(context: inout CLIJobContext) throws -> Self {
        var output = try Self.allocate(count, context: &context)
        for i in 0..<count { try Self.step(&context); output.storage[i] = self[i] }
        return output
    }
    package mutating func removingTrailingZero(context: inout CLIJobContext) throws -> Bool {
        try Self.step(&context)
        guard count > 1, storage.last == 0 else { return false }
        storage.removeLast(); return true
    }
    package static func prefix(_ digits: [UInt8], count: Int, context: inout CLIJobContext) throws -> Self {
        guard count > 0, count <= digits.count else { throw CLIError(.resource, "arithmeticInvariant") }
        var result = try allocate(count, context: &context)
        for index in 0..<count { try step(&context); result.storage[index] = digits[index] }
        return result
    }
    package var coefficientDigits: [UInt8] { storage }
}
