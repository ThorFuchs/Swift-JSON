// SPDX-License-Identifier: Apache-2.0
import JSON

// Proposal scanner only, never a regex matcher or schema-validity authority.
// Fully anchored sequences of printable literals, escaped punctuation or single
// ASCII ranges. Each atom may carry one exact {n}; other quantifiers are unsupported.
enum SchemaExamplePattern {
    static let punctuation: [UInt8] = [92,94,36,46,124,63,42,43,40,41,91,93,123,125,47,45]
    static func propose(_ pattern: String, variation: UInt64, minimum: UInt64, maximum: UInt64,
                        meter: inout JSONWorkMeter) throws -> String? {
        var source: [UInt8] = []
        for byte in pattern.utf8 {
            try meter.work(); try meter.require(.regexPatternBytes, UInt64(source.count) + 1)
            try meter.retain(1); source.append(byte)
        }
        guard source.count >= 2, source.first == 94, source.last == 36 else { return nil }
        let end = source.count - 1
        var position = 1, output: [UInt8] = []
        while position < end {
            try meter.work()
            let first = source[position], byte: UInt8
            if first == 92 {
                guard position + 1 < end else { return nil }
                let escaped = source[position + 1]
                var accepted = false
                for symbol in punctuation { try meter.work(); if symbol == escaped { accepted = true; break } }
                guard accepted else { return nil }
                byte = escaped; position += 2
            } else if first == 91 {
                guard end - position >= 5, source[position + 2] == 45, source[position + 4] == 93 else { return nil }
                let lower = source[position + 1], upper = source[position + 3]
                guard lower >= 32, upper <= 126, lower <= upper,
                      lower != 92, lower != 94, lower != 93, upper != 92, upper != 93 else { return nil }
                byte = lower + UInt8(variation % UInt64(upper - lower + 1)); position += 5
            } else {
                guard first >= 32, first <= 126 else { return nil }
                var special = false
                for symbol in punctuation { try meter.work(); if symbol == first && symbol != 47 && symbol != 45 { special = true; break } }
                guard !special else { return nil }
                byte = first; position += 1
            }
            var repetitions: UInt64 = 1
            if position < end && source[position] == 123 {
                position += 1; repetitions = 0
                let start = position
                while position < end && source[position] >= 48 && source[position] <= 57 {
                    try meter.work(subsystem: .numericWorkUnits)
                    let (product, badProduct) = repetitions.multipliedReportingOverflow(by: 10)
                    let (next, badSum) = product.addingReportingOverflow(UInt64(source[position] - 48))
                    guard !badProduct, !badSum else {
                        let failure = JSONFailure(.resource, code: .counterOverflow)
                        meter.recordFailure(failure); throw failure
                    }
                    try meter.require(.stringBytes, next)
                    repetitions = next; position += 1
                }
                guard position > start, position < end, source[position] == 125 else { return nil }
                position += 1
            }
            let length = try meter.adding(.stringBytes, UInt64(output.count), repetitions)
            guard length <= maximum else { return nil }
            for _ in 0..<repetitions {
                try meter.work(); try meter.charge(.aggregateTextBytes); try meter.retain(1); output.append(byte)
            }
        }
        guard UInt64(output.count) >= minimum else { return nil }
        for _ in output { try meter.work(); try meter.retain(1) }
        return String(decoding: output, as: UTF8.self)
    }
}
