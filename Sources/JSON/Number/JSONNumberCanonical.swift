// SPDX-License-Identifier: Apache-2.0
// Original implementation of the RFC 8785 section 3.2.2.3 number serialization,
// which is ECMAScript Number::toString applied to a binary64 value.

extension JSONNumber {
    /// The ECMAScript spelling of this number's binary64 value.
    ///
    /// Swift's `description` of a finite Double supplies the shortest digits that
    /// round-trip, choosing the closest such digits, which is the digit string
    /// ECMAScript also requires. Only the layout around those digits is rebuilt here.
    package func canonicalText(policy: JSONCanonicalWriter.NumberPolicy, meter: inout JSONWorkMeter) throws -> String {
        try meter.work(subsystem: .numericWorkUnits)
        if isZero { return "0" }
        let value = try doubleValue(policy: .rounded, meter: &meter, chargesOutput: false)
        // A finite Double's description is at most 24 ASCII bytes; reserve a fixed
        // bound around the synchronous foreign rendering.
        let foreign: UInt64 = 32
        try meter.retain(foreign); try meter.checkpoint()
        let shortest = value.magnitude.description
        try meter.checkpoint()
        var digits: [UInt8] = [], point: Int? = nil, exponent = 0, exponentNegative = false, inExponent = false
        try meter.retain(foreign)
        for byte in shortest.utf8 {
            try meter.work(subsystem: .numericWorkUnits)
            switch byte {
            case 48...57 where inExponent: exponent = exponent * 10 + Int(byte - 48)
            case 48...57: digits.append(byte - 48)
            case 46: point = digits.count
            case 101, 69: inExponent = true
            case 45: exponentNegative = true
            case 43: break
            default: throw JSONFailure(.conversion, code: .inexactConversion)
            }
        }
        var position = (point ?? digits.count) + (exponentNegative ? -exponent : exponent)
        while digits.count > 1 && digits[0] == 0 { try meter.work(subsystem: .numericWorkUnits); digits.removeFirst(); position -= 1 }
        while digits.count > 1 && digits[digits.count - 1] == 0 { try meter.work(subsystem: .numericWorkUnits); digits.removeLast() }
        var output: [UInt8] = []
        func append(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
            try meter.work(subsystem: .numericWorkUnits); try meter.retain(1); output.append(byte)
        }
        func appendDigits(_ range: Range<Int>, meter: inout JSONWorkMeter) throws {
            for index in range { try append(digits[index] + 48, meter: &meter) }
        }
        if digits == [0] {
            try append(48, meter: &meter)
        } else {
            if value < 0 { try append(45, meter: &meter) }
            let k = digits.count, n = position
            if k <= n && n <= 21 {
                try appendDigits(0..<k, meter: &meter)
                for _ in 0..<(n - k) { try append(48, meter: &meter) }
            } else if 0 < n && n <= 21 {
                try appendDigits(0..<n, meter: &meter); try append(46, meter: &meter); try appendDigits(n..<k, meter: &meter)
            } else if -6 < n && n <= 0 {
                try append(48, meter: &meter); try append(46, meter: &meter)
                for _ in 0..<(-n) { try append(48, meter: &meter) }
                try appendDigits(0..<k, meter: &meter)
            } else {
                try append(digits[0] + 48, meter: &meter)
                if k > 1 { try append(46, meter: &meter); try appendDigits(1..<k, meter: &meter) }
                try append(101, meter: &meter); try append(n - 1 < 0 ? 45 : 43, meter: &meter)
                for byte in String((n - 1).magnitude).utf8 { try append(byte, meter: &meter) }
            }
        }
        try meter.release(foreign * 2)
        let text = String(decoding: output, as: UTF8.self)
        if policy == .preserving {
            let spelled = try Self.parse(output, meter: &meter)
            guard spelled == self else { throw JSONFailure(.conversion, code: .inexactConversion) }
        }
        try meter.release(UInt64(output.count))
        return text
    }
}
