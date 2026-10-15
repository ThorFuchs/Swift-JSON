# Schema examples public consumer

This standalone Swift 6.4 package imports only the public JSON, JSONSchema and
JSONSchemaExamples products. It executes 15 cases: strict/exact values, scalar-key
identity, preceding invalid candidates, static/offline references, explicit proof
and incomplete-search failures. It independently validates every success and
roundtrips exact JSON through the strict writer/parser. It uses no private meters.

```sh
swift run --package-path Examples/SchemaExamplesConsumer SchemaExamplesConsumer
```

The two compile-negative fixtures must fail for package access protection and an
inaccessible certificate initializer. `Scripts/qualify_schema_examples.py` builds
the real consumer and typechecks them against its actual modules. G3 is explicit
candidate verification, not broad schema synthesis. See the G3 architecture record
and JSONSchemaExamples DocC guide for the current boundary.

The two true-schema profiles emit `G3_VECTORS` for the independent Python stdlib
transport oracle. The qualifier executes the binary in a second process and
requires identical value/trace bytes. This is native process repeatability;
Linux/WASI determinism remains a later platform gate. The consumer uses public
corpus, policy and trace identities and no private meters.


Run the foundational acceptance matrix from the repository root after building:

```sh
python3 -B Scripts/ci.py --lane schema-examples-construction
```

The separate public G3 mode evaluates 24 must-generate schemas across two profiles
and four seeds (192 completed native certifications per process), 90 fixture
witnesses and two sound proofs. Its qualifier repeats in a second process and
materializes every value/trace/work row. The 18 G4 cases remain outside these
success counts. Fixture hashes and the G0 numeric correction are explicit.
