// SPDX-License-Identifier: Apache-2.0
import Foundation
import CryptoKit
@testable import JSON

@main struct IndexBenchmark {
    struct Sample: Codable {
        let algorithm: String, shape: String, operation: String, status: String
        let width: Int, sample: Int
        let seconds: Double, work: UInt64, logicalPeak: UInt64
        let inputSHA256: String
        let failure: String?
    }
    static func seconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
    }
    static func keys(_ width: Int, shape: String) -> [String] {
        (0..<width).map { index in
            let suffix = String(format: "%06d", index)
            switch shape {
            case "prefix": return String(repeating: "p", count: 128) + suffix
            case "unicode": return (index % 2 == 0 ? "\u{e9}" : "e\u{301}") + "🚀" + suffix
            default: return "key" + suffix
            }
        }
    }
    static func run<I: ProbeIndex>(_ type: I.Type, algorithm: String, width: Int, shape: String) throws -> [Sample] {
        let keys = keys(width, shape: shape)
        let digest = SHA256.hash(data: try JSONEncoder().encode(keys)).map { String(format: "%02x", $0) }.joined()
        let clock = ContinuousClock()
        var results: [Sample] = []
        for sample in -3..<9 {
            var meter = try JSONWorkMeter(limits: .offline, domain: .core)
            var index = I()
            let start = clock.now
            do {
                for (position, text) in keys.enumerated() {
                    try index.insert(ProbeKey(text, position: position, meter: &meter), meter: &meter)
                }
            } catch let error as JSONFailure where error.category == .resource {
                results.append(.init(algorithm: algorithm, shape: shape, operation: "construction", status: "refused", width: width, sample: sample,
                                     seconds: seconds(start.duration(to: clock.now)), work: meter.statistics()[.workUnits],
                                     logicalPeak: meter.statistics().peakLogicalRetainedBytes, inputSHA256: digest, failure: error.resource?.metric.rawValue))
                // A refusal is recorded once, never converted into a timing advantage.
                return results
            }
            let construction = seconds(start.duration(to: clock.now))
            if sample >= 0 {
                results.append(.init(algorithm: algorithm, shape: shape, operation: "construction", status: "passed", width: width, sample: sample,
                                     seconds: construction, work: meter.statistics()[.workUnits], logicalPeak: meter.statistics().peakLogicalRetainedBytes,
                                     inputSHA256: digest, failure: nil))
            }
            let before = meter.statistics()[.workUnits]
            let lookupStart = clock.now
            for _ in 0..<3 {
                for position in [0, width / 2, width - 1, width] {
                    let text = position >= 0 && position < width ? keys[position] : "missing"
                    let query = try ProbeKey(text, position: -1, meter: &meter)
                    let found = try index.find(query, meter: &meter)
                    precondition(found == (position >= 0 && position < width ? position : nil))
                    try meter.release(UInt64(query.bytes.count))
                }
            }
            if sample >= 0 {
                results.append(.init(algorithm: algorithm, shape: shape, operation: "12-lookups", status: "passed", width: width, sample: sample,
                                     seconds: seconds(lookupStart.duration(to: clock.now)), work: meter.statistics()[.workUnits] - before,
                                     logicalPeak: meter.statistics().peakLogicalRetainedBytes, inputSHA256: digest, failure: nil))
            }
        }
        return results
    }
    static func main() throws {
        var samples: [Sample] = []
        for shape in ["ascii", "prefix", "unicode"] {
            for width in [0, 1, 4, 8, 16, 32, 64, 256, 1024, 10000] {
                samples += try run(ProbeScalarIndex.self, algorithm: "scalar", width: width, shape: shape)
                samples += try run(ProbeLinearIndex.self, algorithm: "fingerprint-linear", width: width, shape: shape)
                samples += try run(ProbeAVLIndex.self, algorithm: "array-AVL", width: width, shape: shape)
                samples += try run(ProbeHashIndex.self, algorithm: "controlled-hash", width: width, shape: shape)
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(samples).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("INDEX_AB samples=\(samples.count) widths=10 shapes=3 algorithms=4 warmups=3 samples=9 lookupIterations=3 profile=offline constructionIterations=1")
    }
}
