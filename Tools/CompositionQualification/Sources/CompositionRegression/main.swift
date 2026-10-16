// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

struct Sample: Codable {
    let name: String
    let iterations: Int
    let seconds: [Double]
    let work: UInt64
    let peak: UInt64
}
let text = "[" + Array(repeating: #"{"n":9007199254740993,"s":"é","a":[true,null,0.01]}"#, count: 40).joined(separator: ",") + "]"
let bytes = Array(text.utf8)
let data = Data(bytes)
let root = try JSONParser().parse(bytes)
let schema = try JSONSchemaDocument(JSONParser().parse(#"{"type":"object","properties":{"n":{"type":"integer"},"s":{"type":"string"}},"required":["n"]}"#))
let parserProbe = try JSONParser().parseWithReport(bytes)
let schemaProbe = try JSONSchemaCompiler().compileWithReport(schema)
let clock = ContinuousClock()
func seconds(_ duration: Duration) -> Double { Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18 }
func measure(_ name: String, iterations: Int, work: UInt64 = 0, peak: UInt64 = 0, _ operation: () throws -> Void) throws -> Sample {
    for _ in 0..<3 { for _ in 0..<iterations { try operation() } }
    var samples: [Double] = []
    for _ in 0..<9 {
        let start = clock.now
        for _ in 0..<iterations { try operation() }
        samples.append(seconds(start.duration(to: clock.now)) / Double(iterations))
    }
    return Sample(name: name, iterations: iterations, seconds: samples, work: work, peak: peak)
}
let samples = try [
    measure("parser-bytes", iterations: 40, work: parserProbe.statistics[.workUnits], peak: parserProbe.statistics.peakLogicalRetainedBytes) {
        let value = try JSONParser().parse(bytes)
        precondition(value.arrayValue?.count == 40)
    },
    measure("parser-document-data", iterations: 30) {
        let value = try JSONParser().parseDocument(data)
        precondition(value.sourceBytes == data)
    },
    measure("pointer", iterations: 200) {
        let pointer = try JSONPointer(tokens: ["0"]).appending(key: "n")
        let value = try pointer.resolve(in: root)
        precondition(value.numberValue?.originalLexeme == "9007199254740993")
    },
    measure("schema-only", iterations: 3, work: schemaProbe.statistics[.workUnits], peak: schemaProbe.statistics.peakLogicalRetainedBytes) {
        _ = try JSONSchemaCompiler().compile(schema)
    }
]
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(samples), as: UTF8.self))
