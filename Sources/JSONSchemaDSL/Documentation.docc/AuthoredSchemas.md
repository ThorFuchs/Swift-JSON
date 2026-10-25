# Authored schemas, engine validation

Emit an exact declaration, then explicitly compile and evaluate it.

The following example is compiled and run by `Examples/DualDSL` after its value example.

```swift
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
```

Import JSON, JSONSchema and JSONSchemaDSL. The source example in `Examples/DualDSL`
also validates a positive instance, two negative instances and a missing-resource
operational failure. A document containing only definitions does not select one;
use an explicit reference such as the one above. IDs and reference text are preserved.
Externally supplied resources use the existing JSONSchemaDocument retrieval identity
and immutable JSONSchemaRegistry; the DSL never fetches a URL or infers a registry.

`Property` does not imply requiredness, `defaultValue` does not fill missing values,
and `format` does not select assertion policy. Use existing JSONSchemaOptions.
`Rule(false)` is a false subschema; `Rule {}` is an empty object schema; neither is
JSON null. Explicit `rawKeyword` preserves unknown metadata and malformed declarations
for the existing compiler to classify. There is no synonym that silently repairs them.
An empty enum compiles as an empty allowed set and produces ordinary invalidity;
negative lengths and an empty oneOf remain compilation failures under the engine.

Duplicate exact names fail during finalization; scalar-distinct names remain distinct.
Resource/configuration failures and cancellation throw. An invalid instance returns
`isValid == false`; malformed declarations, missing resources, nonproductive reference
cycles and operational exhaustion throw. Branches do not swallow these failures.
Annotations and dynamic scope remain engine-owned and are compared with handwritten
schema paths in the real-engine tests.

The authored closure, typed wrappers and staged buffers are unmetered. A flat IR avoids
recursive owned staging-node teardown; finalization uses explicit frames and one finite
ledger through document admission. This is not a whole-DSL resource report, an instruction
quota for caller code, a staging retention cap or process RSS guarantee. Use the existing
checked JSONSchemaBuilder and explicit accumulators for dynamic bounded construction.
