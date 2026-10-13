// SPDX-License-Identifier: Apache-2.0
import Foundation
import Darwin
import JSON
import JSONSchema

struct Sample: Codable {
    let workload: String
    let invocations: Int
    let nanoseconds: [Double]
    let medianNanoseconds: Double
    let checksum: Int
}
struct Receipt: Codable {
    let samples: [Sample]
    let warmups: Int
    let repetitions: Int
    let processPeakRSSBytes: Int
    let retentionPolicy: String
}
let clock = ContinuousClock()
var samples: [Sample] = []
let warmups = 3, repetitions = 9
for (name, members, size, invocations) in [("description100", 1, 100, 20000), ("wide64_strings256", 64, 256, 1000)] {
    let payload = String(repeating: "x", count: size)
    let keys = members == 1 ? ["description"] : (0..<members).map { "metadata_" + String($0) }
    var measured: [Double] = [], checksum = 0
    for run in 0..<(warmups + repetitions) {
        let start = clock.now
        for _ in 0..<invocations {
            let document = try JSONSchemaBuilder.object { builder in
                for key in keys { try builder.append(key, value: .string(payload)) }
            }
            let count = document.raw.objectValue!.count
            precondition(count == members)
            checksum += count
        }
        let duration = start.duration(to: clock.now).components
        let nanos = Double(duration.seconds) * 1_000_000_000 + Double(duration.attoseconds) / 1_000_000_000
        if run >= warmups { measured.append(nanos / Double(invocations)) }
    }
    samples.append(.init(workload: name, invocations: invocations, nanoseconds: measured, medianNanoseconds: measured.sorted()[repetitions / 2], checksum: checksum))
}
var usage = rusage()
precondition(getrusage(RUSAGE_SELF, &usage) == 0)
let receipt = Receipt(samples: samples, warmups: warmups, repetitions: repetitions, processPeakRSSBytes: Int(usage.ru_maxrss), retentionPolicy: "ru_maxrss is the cumulative process peak, not logical retained bytes or an RSS cap; this builder exposes no public report. Boundary tests qualify logical overlap separately.")
let encoder = Foundation.JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(receipt), as: UTF8.self))
