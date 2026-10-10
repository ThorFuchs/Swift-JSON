// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

private func verdict(_ schema: String, _ instance: String) throws -> JSONValidationResult {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(schema)))
    return try JSONSchemaValidator().validate(JSONParser().parse(instance),against: plan)
}
@Test func evaluatedLocationsFlowThroughSuccessfulReferencesAndComposition() throws {
    let schema = ##"{"$defs":{"left":{"properties":{"a":true}}},"allOf":[{"$ref":"#/$defs/left"},{"properties":{"b":true}}],"unevaluatedProperties":false}"##
    #expect(try verdict(schema,#"{"a":1,"b":null}"#).isValid)
    #expect(try !verdict(schema,#"{"a":1,"b":2,"c":3}"#).isValid)
    let branches = #"{"anyOf":[{"properties":{"a":{"type":"number"}},"required":["a"]},{"properties":{"b":true},"required":["b"]}],"unevaluatedProperties":false}"#
    #expect(try verdict(branches,#"{"a":1,"b":2}"#).isValid)
    #expect(try !verdict(branches,#"{"a":"bad","b":2}"#).isValid)
    #expect(try verdict(#"{"oneOf":[{"type":"number"},{"minimum":5}]}"#,"3").isValid)
    #expect(try !verdict(#"{"oneOf":[{"type":"number"},{"minimum":5}]}"#,"7").isValid)
}
@Test func arrayContainsAndConditionalAnnotationsRespectTheirBranches() throws {
    #expect(try verdict(#"{"contains":{"type":"number"},"unevaluatedItems":false}"#,"[1,2]").isValid)
    #expect(try !verdict(#"{"contains":{"type":"number"},"unevaluatedItems":false}"#,"[1,\"x\"]").isValid)
    #expect(try verdict(#"{"contains":false,"minContains":0,"maxContains":0}"#,"[1,2]").isValid)
    #expect(try !verdict(#"{"contains":true,"minContains":0,"maxContains":1}"#,"[1,2]").isValid)
    #expect(try verdict(#"{"prefixItems":[true],"items":{"type":"number"},"unevaluatedItems":false}"#,"[\"x\",2,3]").isValid)
    let conditional = #"{"if":{"properties":{"a":{"const":1}},"required":["a"]},"then":{"properties":{"b":true}},"else":{"properties":{"c":true}},"unevaluatedProperties":false}"#
    #expect(try verdict(conditional,#"{"a":1,"b":2}"#).isValid)
    #expect(try verdict(conditional,#"{"c":2}"#).isValid)
    #expect(try !verdict(conditional,#"{"a":2,"c":2}"#).isValid)
}
