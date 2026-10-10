// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func formatAnnotationAndRequiredVocabularyHaveDifferentPolicies() throws {
    let raw = try JSONParser().parse(#"{"format":"ipv4"}"#), input = JSON.string("not-an-ipv4")
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw))
    #expect(try JSONSchemaValidator().validate(input,against: plan).isValid)
    #expect(try !JSONSchemaValidator(options: .init(formatAssertion: true)).validate(input,against: plan).isValid)
    let meta = try JSONSchemaDocument(JSONParser().parse(#"{"$id":"https://e.test/meta","$schema":"https://json-schema.org/draft/2020-12/schema","$vocabulary":{"https://json-schema.org/draft/2020-12/vocab/core":true,"https://json-schema.org/draft/2020-12/vocab/format-assertion":true}}"#),retrievalURI: JSONSchemaURI("https://e.test/meta"))
    #expect(throws: JSONSchemaCompilationFailure.self) {
        try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"$schema":"https://e.test/meta","format":"unknown-format"}"#)),registry: JSONSchemaRegistry(documents: [meta]))
    }
}
