// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func nativeTestHostLoadsPackagedSchemasWithoutOverrides() throws {
    let registry = try JSONSchemaRegistry.draft2020_12()
    #expect(registry.documents.count == 9)
    let raw = try JSONParser().parse(#"{"$schema":"https://json-schema.org/draft/2020-12/schema","type":"integer","minimum":9007199254740993}"#)
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw), registry: registry)
    #expect(try JSONSchemaValidator().validate(JSONParser().parse("9007199254740993"), against: plan).isValid)
    #expect(try !JSONSchemaValidator().validate(JSONParser().parse("9007199254740992"), against: plan).isValid)
    print("DISTRIBUTION native_test_host nine_offline_resources exact_verdicts")
}
