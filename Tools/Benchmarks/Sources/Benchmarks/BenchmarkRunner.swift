// SPDX-License-Identifier: Apache-2.0
import Foundation
import Darwin
import CryptoKit
import JSON
import JSONSchema
import JSONPatch
import JSONStreaming

private struct Sample: Codable {
    let name: String, input_sha256: String
    let units_per_invocation: Int, unit: String, seconds: [Double]
    let median_seconds: Double, variance_seconds_squared: Double, median_units_per_second: Double
    let peak_logical_retained_bytes: UInt64, process_peak_rss_bytes_after: Int64
    let malloc_blocks_in_use_after: UInt64, malloc_bytes_in_use_after: UInt64
}
private struct Receipt: Codable {
    let schema_version: Int, warmup: Int, repetitions: Int, invocations_per_sample: Int
    let environment: String, configuration_sha256: String, resource_profile: String, memory_policy: String, optimization_profile: String
    let samples: [Sample]
}
private func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x",$0) }.joined() }
private func seconds(_ d: Duration) -> Double { Double(d.components.seconds) + Double(d.components.attoseconds)/1e18 }
private struct Model: Codable, Equatable { let count: UInt64; let name: String; let list: [Int] }
private struct GeneratedArray: AsyncSequence, Sendable {
    typealias Element = JSONByteChunk
    let count: Int
    func makeAsyncIterator() -> Iterator { .init(count: count) }
    struct Iterator: AsyncIteratorProtocol {
        let count: Int; var index = -1
        mutating func next() async -> JSONByteChunk? {
            defer { index += 1 }
            if index == -1 { return .init([91]) }
            if index < count { return .init(index == 0 ? [48] : [44,48]) }
            if index == count { return .init([93]) }; return nil
        }
    }
}
@main struct BenchmarkRunner {
    static func main() async throws {
        var args = Array(CommandLine.arguments.dropFirst()), output = ".build/handoff/benchmarks.json", repetitions = 9, warmup = 3, iterations = 3
        while !args.isEmpty {
            let flag = args.removeFirst(); guard !args.isEmpty else { fatalError("Missing value") }; let value = args.removeFirst()
            switch flag { case "--output": output = value; case "--repetitions": repetitions = Int(value)!; case "--warmup": warmup = Int(value)!; case "--iterations": iterations = Int(value)!; default: fatalError("Unknown option") }
        }
        guard (5...50).contains(repetitions),(1...10).contains(warmup),(1...100).contains(iterations) else { fatalError("Invalid sample configuration") }
        var samples: [Sample] = []
        func measure(_ name: String,input: Data,units: Int,unit: String = "operations",_ operation: () async throws -> UInt64) async throws {
            for _ in 0..<warmup { _ = try await operation() }
            var durations: [Double] = [], peak: UInt64 = 0
            let clock = ContinuousClock()
            for _ in 0..<repetitions {
                let start = clock.now
                for _ in 0..<iterations { peak = max(peak,try await operation()) }
                durations.append(seconds(start.duration(to: clock.now))/Double(iterations))
            }
            let median = durations.sorted()[durations.count/2], mean = durations.reduce(0,+)/Double(durations.count)
            let variance = durations.reduce(0) { $0 + ($1-mean)*($1-mean) }/Double(durations.count)
            var usage = rusage(); precondition(getrusage(RUSAGE_SELF,&usage) == 0)
            var info = malloc_statistics_t(); malloc_zone_statistics(nil,&info)
            samples.append(.init(name: name,input_sha256: hash(input),units_per_invocation: units,unit: unit,seconds: durations,median_seconds: median,variance_seconds_squared: variance,median_units_per_second: Double(units)/median,peak_logical_retained_bytes: peak,process_peak_rss_bytes_after: Int64(usage.ru_maxrss),malloc_blocks_in_use_after: UInt64(info.blocks_in_use),malloc_bytes_in_use_after: UInt64(info.size_in_use)))
            try FileHandle.standardOutput.write(contentsOf: Data("\(name): median=\(median)s logical_peak=\(peak)\n".utf8))
        }
        let parser = JSONParser(), writer = JSONWriter()
        let small = Data(#"{"é":9007199254740993,"e\u0301":0.10000000000000001,"list":[true,null,"text"]}"#.utf8)
        let value = try parser.parse(small)
        try await measure("parse_small_exact",input: small,units: small.count,unit: "bytes") {
            let report = try parser.parseWithReport(Array(small)); precondition(report.result == value); return report.statistics.peakLogicalRetainedBytes
        }
        try await measure("parse_owned_data",input: small,units: small.count,unit: "bytes") { let result = try parser.parse(small); precondition(result == value); return 0 }
        let large = Data(("[" + Array(repeating: "9007199254740993",count: 4_000).joined(separator: ",") + "]").utf8)
        try await measure("parse_large_exact_array",input: large,units: large.count,unit: "bytes") {
            let report = try parser.parseWithReport(Array(large)); precondition(report.result.arrayValue?.count == 4_000); return report.statistics.peakLogicalRetainedBytes
        }
        let text = String(repeating: "unicode:é:𝄞:e\u{301}:\n",count: 20_000)
        try await measure("write_large_unicode_string",input: Data(text.utf8),units: text.utf8.count,unit: "payload_bytes") {
            let report = try writer.writeWithReport(.string(text)); precondition(!report.result.isEmpty); return report.statistics.peakLogicalRetainedBytes
        }
        let model = Model(count: .max,name: "e\u{301}",list: Array(0..<1000)), encoded = try JSONValueEncoder().encode(model)
        try await measure("native_value_codable",input: try writer.write(encoded),units: 1) {
            let report = try JSONValueEncoder().encodeWithReport(model), decoded = try JSONValueDecoder().decode(Model.self,from: report.result)
            precondition(decoded == model); return report.statistics.peakLogicalRetainedBytes
        }
        let digits = String(repeating: "1234567890",count: 300)
        try await measure("exact_number_parse_compare",input: Data(digits.utf8),units: digits.count,unit: "digits") {
            let a = try JSONNumber(parsing: digits), b = try JSONNumber(parsing: digits + ".0"); precondition(a == b); return 0
        }
        let pattern = #"^(?<word>[a-z]+)-(?:[0-9]{2,8}|x+)\k<word>$"#
        let term = try writer.writeString(.object(JSONObject(members: [.init("pattern",value: .string(pattern))])))
        let schemaText = "{\"allOf\":[" + Array(repeating: term,count: 32).joined(separator: ",") + "]}"
        let schema = try JSONSchemaDocument(parser.parse(schemaText))
        try await measure("schema_compile_repeated_patterns",input: Data(schemaText.utf8),units: 1) {
            let report = try JSONSchemaCompiler().compileWithReport(schema); precondition(report.result.document.raw == schema.raw); return report.statistics.peakLogicalRetainedBytes
        }
        let plan = try JSONSchemaCompiler().compile(schema)
        try await measure("shared_plan_regex_evaluation",input: Data("alpha-42alpha".utf8),units: 32,unit: "pattern_searches") {
            let report = try JSONSchemaValidator(options: .init(output: .flag)).validateWithReport("alpha-42alpha",against: plan)
            precondition(report.result.isValid); return report.statistics.peakLogicalRetainedBytes
        }
        let exact = try JSONSchemaCompiler().compile(JSONSchemaDocument(parser.parse(#"{"type":"object","required":["é","e\u0301"],"properties":{"é":{"minimum":9007199254740993},"e\u0301":{"multipleOf":0.00000000000000001}},"unevaluatedProperties":true}"#)))
        try await measure("schema_exact_evaluation",input: small,units: 1) {
            let report = try JSONSchemaValidator().validateWithReport(value,against: exact); precondition(report.result.isValid); return report.statistics.peakLogicalRetainedBytes
        }
        let input = JSON.array(Array(repeating: 1,count: 1000)), patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/500"),value: 2)])
        try await measure("staged_rfc6902",input: try writer.write(input),units: 1) {
            let report = try patch.applyingWithReport(to: .document(input)); guard case .document(let result) = report.result else { fatalError("Removed") }; precondition(result.arrayValue?[500] == 2); return report.statistics.peakLogicalRetainedBytes
        }
        let merge = JSONMergePatch(try parser.parse(#"{"list":[1,2,3],"é":null}"#))
        try await measure("rfc7396",input: small,units: 1) {
            let report = try merge.applyingWithReport(to: value); precondition(report.result.objectValue?["é"] == nil); return report.statistics.peakLogicalRetainedBytes
        }
        try await measure("generated_root_array_stream",input: Data("GeneratedArray(count:100000); scalar 0; no preload".utf8),units: 100_000,unit: "records") {
            var count = 0, peak: UInt64 = 0
            for try await event in JSONTopLevelArraySequence(GeneratedArray(count: 100_000)) { switch event { case .element: count += 1; case .documentCompleted(let summary): peak = summary.statistics.peakLogicalRetainedBytes } }
            precondition(count == 100_000); return peak
        }
        let config = "warmup=\(warmup);repetitions=\(repetitions);iterations=\(iterations);balanced;accounting=1;scalar-baseline"
        let report = Receipt(schema_version: 1,warmup: warmup,repetitions: repetitions,invocations_per_sample: iterations,environment: ProcessInfo.processInfo.operatingSystemVersionString,configuration_sha256: hash(Data(config.utf8)),resource_profile: "balanced",memory_policy: "Logical peak per public report; zero means that facade has no report. ru_maxrss is cumulative process peak in bytes; malloc statistics are allocator-wide end observations, not workload allocation counts or hard bounds.",optimization_profile: "scalar baseline; no SIMD scan or literal prefilter",samples: samples)
        let encoder = Foundation.JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        let url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(output)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),withIntermediateDirectories: true); try encoder.encode(report).write(to: url,options: .atomic)
    }
}
