// SPDX-License-Identifier: Apache-2.0
import Foundation
import CryptoKit
@testable import JSON

private struct Sample: Encodable {
    let width: Int, shape: String, query: String, sample: Int
    let iterations: Int, seconds: Double, work: UInt64, logicalPeak: UInt64
    let inputSHA256: String
}
@main struct LookupBenchmark {
    static func main() throws {
        var samples: [Sample] = []
        for width in [0,1,4,8,16,32,64,256,1024,10000] {
            for shape in ["ascii", "prefix", "unicode"] {
                let keys = (0..<width).map { index in
                    let suffix = String(format: "%06d", index)
                    if shape == "prefix" { return String(repeating: "p", count: 128) + suffix }
                    if shape == "unicode" { return (index.isMultiple(of: 2) ? "é" : "e\u{301}") + "🚀" + suffix }
                    return "key" + suffix
                }
                let digest = SHA256.hash(data: try JSONEncoder().encode(keys)).map { String(format: "%02x", $0) }.joined()
                // Caller-built fixture admission and member allocation are outside this lookup stage.
                #if INDEX_METADATA
                var fixtureMeter = try JSONWorkMeter(limits: .offline, domain: .core)
                let object = try JSONObject.indexed(admitted: keys.map { JSONMember($0, value: .string($0)) }, meter: &fixtureMeter)
                #else
                let object = JSONObject(admitted: keys.map { JSONMember($0, value: .string($0)) })
                #endif
                var queries = width == 0 ? [("miss", "absent")] : [("first", keys[0]), ("middle", keys[width/2]), ("last", keys[width-1]), ("miss", shape == "prefix" ? String(repeating: "p", count: 128) + "absent" : "absent")]
                if width > 8 { queries.append(("first-filtered", keys[8])) }
                for (name, key) in queries {
                    for sample in -3..<9 {
                        var meter = try JSONWorkMeter(limits: .offline, domain: .core)
                        let clock = ContinuousClock(); let start = clock.now
                        for _ in 0..<20 {
                            let value = try object.lookup(key, meter: &meter)
                            precondition(name == "miss" ? value == nil : value?.stringValue?.utf8.elementsEqual(key.utf8) == true)
                        }
                        let duration = start.duration(to: clock.now).components
                        if sample >= 0 {
                            let stats = meter.statistics()
                            samples.append(Sample(width: width, shape: shape, query: name, sample: sample, iterations: 20,
                                seconds: Double(duration.seconds) + Double(duration.attoseconds)/1e18,
                                work: stats[.workUnits], logicalPeak: stats.peakLogicalRetainedBytes, inputSHA256: digest))
                        }
                    }
                }
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(samples).write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print("LOOKUP_BENCHMARK samples=\(samples.count) warmups=3 iterations=20 measured_samples=9")
    }
}
