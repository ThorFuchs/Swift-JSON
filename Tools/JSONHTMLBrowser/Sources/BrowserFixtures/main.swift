// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONHTML

let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
func object(_ members: [JSONMember]) throws -> JSON { .object(try JSONObject(members: members)) }
let exact = try JSONParser().parse(#"{"~1/a\u0000\r\n":[{"0":9007199254740993}],"é":-0.00e+2,"é":1.2300e+2,"needle":["literal [needle]","Needle",null]}"#)
let hostile: JSON = .string("</script><img src=x onerror=evil()>&\u{2028}\u{2029}\u{0}")
var deep: JSON = .string("last-sentinel"); for _ in 0..<40 { deep = .array([deep]) }
let wide: JSON = .array((0..<150).map { .string("literal [needle] \($0)") })
var zero = JSONHTMLRenderingOptions(presentation: .interactive); zero.limits.maxSearchQueryBytes = 0
let fixtures: [(String, JSON, JSONHTMLRenderingOptions)] = [
    ("exact", exact, .init(title: "Exact offline JSON", presentation: .interactive)),
    ("hostile", hostile, .init(title: "</title><script>evil()</script>", presentation: .interactive)),
    ("deep", deep, .init(presentation: .interactive, initiallyExpandedDepth: 0)),
    ("wide", wide, .init(presentation: .interactive)),
    ("null", .null, .init(presentation: .interactive)),
    ("zero-query", exact, zero),
    ("no-outline", exact, .init(presentation: .interactive, outlineDepth: nil)),
    ("formatted", exact, .init())]
var records: [JSON] = []
for (name, root, options) in fixtures {
    let report = try JSONHTMLRenderer(options: options).renderWithReport(root)
    try report.result.write(to: output.appendingPathComponent(name + ".html"))
    let bytes = try JSONWriter(options: .init(indentation: options.indentation, numberStyle: .preserved, indentationUnit: options.indentationUnit)).write(root)
    try bytes.write(to: output.appendingPathComponent(name + ".json"))
    records.append(try object([
        JSONMember("name", value: .string(name)),
        JSONMember("nodes", value: .number(JSONNumber(integer: report.statistics.renderedJSONNodes))),
        JSONMember("domUpperBound", value: .number(JSONNumber(integer: report.statistics.domNodeUpperBound))),
        JSONMember("documentBytes", value: .number(JSONNumber(integer: report.statistics.documentBytes))),
        JSONMember("metadataBytes", value: .number(JSONNumber(integer: report.statistics.metadataBytes))),
        JSONMember("workUnits", value: .number(JSONNumber(integer: report.statistics.operation[.workUnits]))),
        JSONMember("logicalPeakBytes", value: .number(JSONNumber(integer: report.statistics.operation.peakLogicalRetainedBytes))) ]))
}
try JSONWriter(options: .init(indentation: 2)).write(.array(records)).write(to: output.appendingPathComponent("fixtures.json"))
print("JSONHTML_BROWSER_FIXTURES passed count=8")
