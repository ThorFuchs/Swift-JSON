# Schema examples public consumer

This standalone Swift 6.4 package imports only the public JSON, JSONSchema and
JSONSchemaExamples products. It executes 12 cases: strict/exact values, scalar-key
identity, preceding invalid candidates, static/offline references, explicit proof
and incomplete-search failures. It independently validates every success and
roundtrips exact JSON through the strict writer/parser. It uses no private meters.

```sh
swift run --package-path Examples/SchemaExamplesConsumer SchemaExamplesConsumer
```

The two compile-negative fixtures must fail for package access protection and an
inaccessible certificate initializer. `Scripts/qualify_schema_examples.py` builds
the real consumer and typechecks them against its actual modules. G1 is explicit
candidate verification, not broad schema synthesis. See the G1 architecture record
and JSONSchemaExamples DocC guide for the current boundary.
