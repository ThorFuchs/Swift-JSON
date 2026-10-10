// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func schemaAssertionsUseExactDecimalsAndUnicodeScalars() throws {
    func valid(_ schema: String,_ instance: String) throws -> Bool {
        let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(schema)))
        return try JSONSchemaValidator().validate(JSONParser().parse(instance),against: plan).isValid
    }
    #expect(try valid(#"{"const":9007199254740993}"#,"9007199254740993"))
    #expect(try !valid(#"{"const":9007199254740993}"#,"9007199254740992"))
    #expect(try valid(#"{"multipleOf":0.1}"#,"0.3"))
    #expect(try !valid(#"{"multipleOf":0.1}"#,"0.30000000000000001"))
    #expect(try valid(#"{"type":"integer","minimum":1e100}"#,"1e100"))
    #expect(try !valid(#"{"minLength":2}"#,#""é""#))
    #expect(try valid(#"{"minLength":2}"#,#""é""#))
    #expect(try valid(#"{"uniqueItems":true}"#,#"["é","é"]"#))
    #expect(try !valid(#"{"uniqueItems":true}"#,#"[{"a":1,"b":2},{"b":2,"a":1}]"#))
    #expect(try !valid(#"{"minItems":1e100}"#,"[]"))
}
