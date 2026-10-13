// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONHTML
import JSONSchema
import JSONStreaming
import JSONPatch
#if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
import CoreTransferable
import UniformTypeIdentifiers
#endif

struct FixtureRegistry: Decodable {
    struct Fixture: Decodable { let path: String; let sha256: String; let expected_native_parse: String }
    let fixtures: [Fixture]
}
struct Observation: Codable { let name: String; let passed: Bool }
struct Receipt: Codable {
    let status: String
    let cases: [Observation]
    let samples: [String: Int]
    let timingsMilliseconds: [Double]
    let preparedBytes: UInt64
    let workUnits: UInt64
    let peakLogicalRetainedBytes: UInt64
    let limitations: [String]
}

@main struct ExportConsumer {
    static func main() async throws {
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        var cases: [Observation] = []
        func check(_ name: String, _ passed: Bool) throws {
            cases.append(.init(name: name, passed: passed))
            if !passed { throw CocoaError(.fileReadCorruptFile) }
        }
        let fixtureRoot = Bundle.module.resourceURL!.appendingPathComponent("Fixtures")
        let registry = try JSONDecoder().decode(FixtureRegistry.self, from: Data(contentsOf: fixtureRoot.appendingPathComponent("registry.json")))
        for fixture in registry.fixtures {
            let bytes = try Data(contentsOf: fixtureRoot.appendingPathComponent(URL(fileURLWithPath: fixture.path).lastPathComponent))
            if fixture.expected_native_parse == "accepted" {
                let parsed = try JSONParser().parse(bytes)
                let prepared = try JSONExportDocument.prepare(parsed)
                try check("fixture-" + fixture.path, try JSONParser().parse(prepared.data(for: .json)) == parsed)
            } else {
                var rejected = false
                do { _ = try JSONParser().parse(bytes) } catch is JSONFailure { rejected = true }
                try check("fixture-" + fixture.path, rejected)
            }
        }
        let source = #"{"é":9007199254740993,"é":-0.00e+2,"empty":[],"end":"LAST-CONTENT-SENTINEL😀</script>"}"#
        let value = try JSONParser().parse(source)
        let report = try JSONExportDocument.prepareWithReport(value, options: .init(filenameStem: "Exact-JSON"))
        let item = report.result
        try check("available-four", item.availableFormats == [.json, .plainText, .markdown, .html])
        try check("advertised-four", item.advertisedFormats == item.availableFormats)
        try check("one-root-admission", report.operation[.nodes] == 5)
        try check("aggregate-artifact-sum", report.preparedBytes == report.representationBytes.values.reduce(0, +))
        try check("exact-native-roundtrip", try JSONWriter(options: .init(numberStyle: .preserved)).write(JSONParser().parse(item.data(for: .json))) == Data(source.utf8))
        try check("pretty-plain-body", try item.data(for: .json) == item.data(for: .plainText))
        var samples: [String: Int] = [:]
        for format in [JSONExportFormat.json, .plainText, .markdown, .html] {
            let bytes = try item.data(for: format)
            let name = "Exact-JSON." + format.filenameExtension
            try bytes.write(to: output.appendingPathComponent(name)); samples[name] = bytes.count
            let selected = try item.selecting([format])
            try check("selection-" + format.rawValue, selected.advertisedFormats == [format] && selected.availableFormats == item.availableFormats)
        }
        #if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
        try check("direct-native-import-only", JSON.importedContentTypes() == [.json])
        try check("prepared-export-only", JSONExportDocument.importedContentTypes().isEmpty)
        for (format, type) in [(JSONExportFormat.json, UTType.json), (.html, .html), (.plainText, .utf8PlainText), (.markdown, .markdown)] {
            let selected = try item.selecting([format])
            try check("instance-discovery-" + format.rawValue, selected.exportedContentTypes() == [type])
            try check("transfer-bytes-" + format.rawValue, try await selected.exported(as: type) == item.data(for: format))
        }
        let fileDirectory = output.appendingPathComponent("SystemExport", isDirectory: true)
        try FileManager.default.createDirectory(at: fileDirectory, withIntermediateDirectories: true)
        let path = try await item.selecting([.json]).export(to: fileDirectory, contentType: .json)
        try check("system-filename-and-file", path.lastPathComponent == "Exact-JSON.json" && Data(contentsOf: path) == item.data(for: .json))
        let imported = try await JSON(importing: path, contentType: .json)
        try check("system-file-strict-import", try JSONWriter(options: .init(numberStyle: .preserved)).write(imported) == Data(source.utf8))
        #endif
        var times: [Double] = []
        let clock = ContinuousClock()
        for _ in 0..<7 {
            let start = clock.now
            let measured = try JSONExportDocument.prepareWithReport(value)
            try check("measurement-complete-\(times.count)", measured.result.availableFormats.count == 4)
            let elapsed = start.duration(to: clock.now).components
            times.append(Double(elapsed.seconds) * 1_000 + Double(elapsed.attoseconds) / 1e15)
        }
        let receipt = Receipt(status: "passed", cases: cases, samples: samples, timingsMilliseconds: times,
            preparedBytes: report.preparedBytes, workUnits: report.operation[.workUnits],
            peakLogicalRetainedBytes: report.operation.peakLogicalRetainedBytes,
            limitations: ["API/file transport consumer, not share-sheet, drag/drop or recipient UI qualification.",
                "RTF and PDF are unavailable in this increment.", "Logical retention is not RSS; tiny sample timing does not prove throughput ceilings."])
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(receipt).write(to: output.appendingPathComponent("consumer.json"))
        print("JSONHTML_EXPORT_CONSUMER passed cases=\(cases.count) artifacts=\(samples.count) measurements=\(times.count)")
    }
}
