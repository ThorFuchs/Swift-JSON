// SPDX-License-Identifier: Apache-2.0
import Foundation
import Darwin
import CryptoKit
@testable import JSON

private final class AllocationObservations {
    var snapshots: [[String: UInt64]] = []
    func capture(_ position: Int) {
        var info = malloc_statistics_t(); malloc_zone_statistics(nil, &info)
        snapshots.append(["position": UInt64(position), "blocksInUse": UInt64(info.blocks_in_use), "bytesInUse": UInt64(info.size_in_use)])
    }
}
private struct Fields: Encodable {
    let keys: [String]
    var observations: AllocationObservations? = nil
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: JSONCodingKey.self)
        observations?.capture(0)
        for (position, key) in keys.enumerated() {
            try c.encodeNil(forKey: JSONCodingKey(key))
            if [1,32,256,1024,keys.count].contains(position + 1) { observations?.capture(position + 1) }
        }
    }
}
private struct Sample: Encodable {
    let operation: String, width: Int, shape: String, sample: Int, status: String
    let inputSHA256: String, seconds: Double
    let work: UInt64?, logicalPeak: UInt64?, failure: String?
    let processPeakRSS: Int64, allocatorBlocksInUse: UInt64, allocatorBytesInUse: UInt64
}
@main struct ConstructionBenchmark {
    static func main() throws {
        var samples: [Sample] = [], allocationRows: [[String: String]] = []
        for width in [0,1,4,8,16,32,64,256,1024,10000] {
            for shape in ["ascii", "prefix", "unicode"] {
                let keys = (0..<width).map { index in
                    let suffix = String(format: "%06d", index)
                    if shape == "prefix" { return String(repeating: "p", count: 128) + suffix }
                    if shape == "unicode" { return (index.isMultiple(of: 2) ? "é" : "e\u{301}") + "🚀" + suffix }
                    return "key" + suffix
                }
                let bytes = Array(("{" + keys.map { "\"" + $0 + "\":null" }.joined(separator: ",") + "}").utf8)
                let digest = SHA256.hash(data: Data(bytes)).map { String(format: "%02x", $0) }.joined()
                let members = keys.map { JSONMember($0, value: .null) }
                for operation in ["checked", "parse", "accumulator", "native-keyed"] {
                    for sample in -3..<9 {
                        let clock = ContinuousClock(); let start = clock.now
                        var stats: JSONOperationStatistics?
                        var object: JSONObject?
                        var failure: String?
                        do {
                            switch operation {
                            case "checked":
                                var meter = try JSONWorkMeter(limits: .offline, domain: .core)
                                object = try JSONObject.checked(members: members, meter: &meter)
                                stats = meter.statistics()
                            case "parse":
                                let report = try JSONParser(options: .init(limits: .offline)).parseWithReport(bytes)
                                object = report.result.objectValue; stats = report.statistics
                            case "accumulator":
                                object = try JSONObject.build(limits: .offline) { builder in
                                    for key in keys { try builder.append(key, value: .null) }
                                }
                            default:
                                let report = try JSONValueEncoder(options: .init(limits: .offline)).encodeWithReport(Fields(keys: keys))
                                object = report.result.objectValue; stats = report.statistics
                            }
                        } catch let error as JSONFailure where error.category == .resource {
                            failure = "\(error.code.rawValue):\(error.resource?.metric.rawValue ?? "unknown")"
                        }
                        let duration = start.duration(to: clock.now).components
                        if let object {
                            precondition(object.count == keys.count)
                            for (key, member) in zip(keys, object.members) { precondition(key.utf8.elementsEqual(member.key.string.utf8) && member.value.isNull) }
                        } else { precondition(failure != nil) }
                        var usage = rusage(); precondition(getrusage(RUSAGE_SELF, &usage) == 0)
                        var info = malloc_statistics_t(); malloc_zone_statistics(nil, &info)
                        if sample >= 0 || failure != nil {
                            samples.append(.init(operation: operation, width: width, shape: shape, sample: sample,
                                status: failure == nil ? "passed" : "refused", inputSHA256: digest,
                                seconds: Double(duration.seconds) + Double(duration.attoseconds)/1e18,
                                work: stats?[.workUnits], logicalPeak: stats?.peakLogicalRetainedBytes, failure: failure,
                                processPeakRSS: Int64(usage.ru_maxrss), allocatorBlocksInUse: UInt64(info.blocks_in_use), allocatorBytesInUse: UInt64(info.size_in_use)))
                        }
                        if failure != nil { break }
                    }
                }
                if [32,256,1024].contains(width) {
                    let observer = AllocationObservations()
                    _ = try JSONValueEncoder(options: .init(limits: .offline)).encode(Fields(keys: keys, observations: observer))
                    let data = try JSONEncoder().encode(observer.snapshots)
                    allocationRows.append(["width": String(width), "shape": shape, "snapshots": String(decoding: data, as: UTF8.self)])
                }
            }
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let url = URL(fileURLWithPath: CommandLine.arguments[1])
        try encoder.encode(samples).write(to: url)
        try encoder.encode(allocationRows).write(to: url.deletingPathExtension().appendingPathExtension("allocations.json"))
        print("CONSTRUCTION_BENCHMARK cells=120 samples=\(samples.count) warmups=3 measured_samples=9 resource_refusals=\(samples.filter { $0.status == "refused" }.count) allocation_cells=\(allocationRows.count)")
    }
}
