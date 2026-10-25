// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONSchemaDSL
import JSONValueDSL

let tenth = try JSONNumber(parsing: "0.1")
let instance = try JSONValueDSL.object {
    Field("id", UInt64(9_007_199_254_740_993))
    Field("amount", exactNumber: tenth)
    Field("é", 1)
    Field("e\u{301}", 2)
    Field.array("nested") {
        Element.array {
            Element(1)
            Element(2)
        }
    }
}
let schema = try JSONSchemaDSL.document {
    Schema.schemaURI("https://json-schema.org/draft/2020-12/schema")
    Schema.type(.object)
    Schema.properties {
        Property("id") { Schema.type(.integer) }
        Property("amount") { Schema.reference("#/$defs/Amount") }
    }
    Schema.required("id", "amount")
    Schema.definitions {
        Definition("Amount") {
            Schema.type(.number)
            Schema.minimum(tenth)
            Schema.multipleOf(tenth)
        }
    }
}
let plan = try JSONSchemaCompiler().compile(schema)
let validator = JSONSchemaValidator()
let validResult = try validator.validate(instance, against: plan)
precondition(validResult.isValid)
let elevenHundredths = try JSONNumber(parsing: "0.11")
let invalid = try JSONValueDSL.object {
    Field("id", 1)
    Field("amount", exactNumber: elevenHundredths)
}
let invalidResult = try validator.validate(invalid, against: plan)
precondition(!invalidResult.isValid)
let absent = try JSONValueDSL.object { Field("id", 1) }
let absentResult = try validator.validate(absent, against: plan)
precondition(!absentResult.isValid)
precondition(instance.objectValue?["é"] == 1 && instance.objectValue?["e\u{301}"] == 2)
precondition(instance.objectValue?["nested"]?.arrayValue?.count == 1)
let missing = try JSONSchemaDSL.document { Schema.reference("https://not-supplied.invalid/schema") }
var observedOperational = false
do { _ = try JSONSchemaCompiler().compile(missing) } catch let error as JSONSchemaCompilationFailure {
    precondition(error.category == .missingResource)
    observedOperational = true
}
precondition(observedOperational)
let bytes = try JSONWriter().write(instance)
let restored = try JSONParser().parse(bytes)
precondition(restored == instance)
print("DUAL_DSL_CONSUMER passed valid=1 invalid=2 operational=1 exact_keys=2 nested_arrays=1")
