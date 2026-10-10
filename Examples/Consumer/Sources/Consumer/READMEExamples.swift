// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

func runREADMEExamples() throws {
    let parser = JSONParser()
    let value = try parser.parse(#"{"count":9007199254740993,"note":null}"#)
    let count = try JSONPointer(parsing: "/count").resolve(in: value)
    let exact = try count.numberValue!.integer(as: Int64.self)
    precondition(exact == 9_007_199_254_740_993)
    let encoded = try JSONWriter().write(value)
    let roundTrip = try parser.parse(encoded)
    precondition(roundTrip == value)
    let schema = try JSONSchemaDocument(parser.parse(#"{"type":"object","properties":{"count":{"type":"integer"}},"required":["count"]}"#))
    let plan = try JSONSchemaCompiler().compile(schema)
    let result = try JSONSchemaValidator().validate(value, against: plan)
    precondition(result.isValid)
    let output = try result.output()
    precondition(output.objectValue?["valid"] == true)
    let keys = try JSONObject(members: [JSONMember("\u{e9}", value: 1), JSONMember("e\u{301}", value: 2)])
    precondition(keys.count == 2)
    let equal = try JSONComparison.equals(.object(keys), .object(keys))
    precondition(equal)
}
