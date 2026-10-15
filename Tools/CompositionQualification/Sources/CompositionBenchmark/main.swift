// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

struct Sample: Codable {
    let name: String
    let inputBytes: Int
    let iterations: Int
    let seconds: [Double]
    let work: UInt64?
    let peak: UInt64?
}
// Deterministic 512-field exact/scalar workload, not an external conformance corpus.
let text = "{" + (0..<512).map { "\"field\($0)\":" + #"{"n":9007199254740993,"s":"é","a":[true,null,0.01]}"# }.joined(separator: ",") + "}"
let realPath = ProcessInfo.processInfo.environment["JCOMP_BENCHMARK_INPUT"]
let data = try realPath.map { try Data(contentsOf: URL(fileURLWithPath: $0)) } ?? Data(text.utf8)
let bytes = Array(data)
let expectedMembers = realPath == nil ? 512 : 2
let root = try JSONParser().parse(bytes)
let schema = try JSONSchemaDocument(JSONParser().parse(#"{"type":"object","properties":{"n":{"type":"integer"},"s":{"type":"string"}},"required":["n"]}"#))
let parserProbe = try JSONParser().parseWithReport(bytes)
let schemaProbe = try JSONSchemaCompiler().compileWithReport(schema)
let compositionProbe = try JSON.withComposition(limits: .offline) { try $0.parseDocument(data) }
let clock = ContinuousClock()
func seconds(_ duration: Duration) -> Double { Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18 }
func measure(_ name: String, iterations: Int, work: UInt64? = nil, peak: UInt64? = nil, _ operation: () throws -> Void) throws -> Sample {
    for _ in 0..<2 { for _ in 0..<iterations { try operation() } }
    var samples: [Double] = []
    for _ in 0..<9 {
        let start = clock.now
        for _ in 0..<iterations { try operation() }
        samples.append(seconds(start.duration(to: clock.now)) / Double(iterations))
    }
    return Sample(name: name, inputBytes: bytes.count, iterations: iterations, seconds: samples, work: work, peak: peak)
}
let samples = try [
    measure("parser-bytes-wide512", iterations: 8, work: parserProbe.statistics[.workUnits], peak: parserProbe.statistics.peakLogicalRetainedBytes) {
        let parsed = try JSONParser().parse(bytes)
        precondition(parsed.objectValue?.count == expectedMembers)
    },
    measure("parser-document-data-wide512", iterations: 6) {
        let value = try JSONParser().parseDocument(data)
        precondition(value.sourceBytes == data)
    },
    measure("pointer-wide512", iterations: 30) {
        let pointer = try JSONPointer(tokens: realPath == nil ? ["field511", "n"] : ["$defs", "Request"])
        let value = try pointer.resolve(in: root)
        if realPath == nil { precondition(value.numberValue?.originalLexeme == "9007199254740993") }
        else { precondition(value.objectValue != nil) }
    },
    measure("composition-document", iterations: 4, work: compositionProbe.statistics[.workUnits], peak: compositionProbe.statistics.peakLogicalRetainedBytes) {
        let report = try JSON.withComposition(limits: .offline) { try $0.parseDocument(data) }
        precondition(report.result.sourceBytes == data)
    },
    measure("schema-only", iterations: 3, work: schemaProbe.statistics[.workUnits], peak: schemaProbe.statistics.peakLogicalRetainedBytes) {
        _ = try JSONSchemaCompiler().compile(schema)
    }
]
let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(samples), as: UTF8.self))
