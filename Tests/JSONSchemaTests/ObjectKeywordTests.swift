// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

private func objectVerdict(_ schema: String,_ instance: String) throws -> JSONValidationResult {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(schema)))
    return try JSONSchemaValidator().validate(JSONParser().parse(instance),against: plan)
}
@Test func objectApplicatorsUseStaticCoverageAndExactScalarKeys() throws {
    let schema = #"{"properties":{"é":true,"é":{"type":"number"}},"patternProperties":{"^x":{"type":"string"}},"additionalProperties":false,"dependentRequired":{"é":["é"]}}"#
    #expect(try objectVerdict(schema,#"{"é":null,"é":1,"x":"yes"}"#).isValid)
    #expect(try !objectVerdict(schema,#"{"é":null}"#).isValid)
    #expect(try !objectVerdict(schema,#"{"x":1}"#).isValid)
    #expect(try !objectVerdict(schema,#"{"z":1}"#).isValid)
    #expect(try objectVerdict(#"{"propertyNames":{"minLength":2}}"#,#"{"ab":1}"#).isValid)
    #expect(try !objectVerdict(#"{"propertyNames":{"minLength":2}}"#,#"{"a":1}"#).isValid)
}
