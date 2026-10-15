// SPDX-License-Identifier: Apache-2.0
// Public-only before/after examples; guide fences are verified by qualify_ergonomics.py.
import Foundation
import JSON
import JSONBridges
import JSONSchema

func runE2CoreExamples() throws {
    let source = #"{"n":9007199254740993,"label":null}"#
    let before = try JSONParser().parse(source)
    let after = try JSON.parse(source)
    precondition(before == after)
    let built = try JSON.buildObject { try $0.append("n", value: 42) }
    let builtBefore = JSON.object(try JSONObject.build { try $0.append("n", value: 42) })
    precondition(built == builtBefore)
    let decimal = try JSON.number(parsing: "0.1")
    let decimalBefore = JSON.number(try JSONNumber(parsing: "0.1"))
    precondition(decimal == decimalBefore)
    let pointer = try JSONPointer(parsing: "/n")
    let selected = try after.value(at: pointer)
    let selectedBefore = try pointer.resolve(in: before)
    precondition(selected == selectedBefore)
    let object = try after.read { try $0.requiredObject() }
    precondition(object.containsKey("label") && !object.containsKey("missing"))
    let label = try after.presence(of: "label").map { try $0.decode(String.self) }
    precondition(label.fold(absent: { "missing" }, null: { "null" }, value: { $0 }) == "null")
    let scoped = try after.readWithReport { try $0["n"].requiredInteger(as: UInt64.self) }
    precondition(scoped.result == 9_007_199_254_740_993 && scoped.statistics[.workUnits] > 0)
}

func runE2BridgeExamples() throws {
    let count: UInt64 = 9_007_199_254_740_993
    let before = JSONNumber(integer: count)
    let after = count.jsonNumber() // Trusted construction, without an operation meter.
    precondition(before == after)
    let recovered = try UInt64(jsonNumber: after)
    precondition(recovered == count)
    let tenth = try JSONNumber(parsing: "0.1")
    let rounded = try Double(jsonNumber: tenth, policy: .rounded)
    let adoptedText = try rounded.jsonNumberFromRoundTripText()
    precondition(adoptedText == tenth)
    let decimal = try Decimal(jsonNumber: tenth)
    precondition(decimal == Decimal(string: "0.1"))
}

func runE2SchemaExamples() throws {
    let document = try JSONSchemaDocument(JSON.parse(#"{"type":"integer","minimum":0}"#))
    let plan = try JSONSchemaCompiler().compile(document)
    let before = try JSONSchemaValidator().validate(42, against: plan)
    let after = try plan.validate(42)
    precondition(before.isValid && after.isValid)
    let invalid = try plan.validate(-1)
    precondition(!invalid.isValid)
    let report = try JSONSchemaValidator().validateWithReport(42, against: plan)
    precondition(report.result.isValid && report.statistics[.evaluationWorkUnits] > 0)
}
