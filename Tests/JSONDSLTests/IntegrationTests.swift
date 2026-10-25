import JSON
import JSONSchema
import JSONSchemaDSL
import JSONValueDSL
// SPDX-License-Identifier: Apache-2.0
import Testing

@Test func dslExactEngineIntegration() throws {
    let tenth = try JSONNumber(parsing: "0.1")
    let value = try JSONValueDSL.object {
        Field("amount", exactNumber: tenth)
        Field("id", UInt64(9_007_199_254_740_993))
        Field.array("nested") {
            Element.array {
                Element(1)
                Element(2)
            }
        }
    }
    let manual = try JSONParser().parse(#"{"amount":0.1,"id":9007199254740993,"nested":[[1,2]]}"#)
    #expect(value == manual)
    let schema = try JSONSchemaDSL.document {
        Schema.type(.object)
        Schema.properties {
            Property("amount") {
                Schema.type(.number)
                Schema.minimum(tenth)
            }
        }
        Schema.required("amount")
    }
    let plan = try JSONSchemaCompiler().compile(schema)
    #expect(try JSONSchemaValidator().validate(value, against: plan).isValid)
    #expect(
        try !JSONSchemaValidator().validate(JSONParser().parse(#"{"amount":0.09}"#), against: plan).isValid)
}
