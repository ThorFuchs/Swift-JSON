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
the real consumer and typechecks them against its actual modules. Construction remains conservative and natively certified. See the G3/G4 architecture records
and JSONSchemaExamples DocC guide for the current boundary.

The two true-schema profiles emit `G2_VECTORS` (the retained qualification marker) for the independent Python stdlib
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


Run the advanced acceptance layer after the current public consumer build:

```sh
python3 -B Scripts/ci.py --lane schema-examples-advanced
```

This retains the foundational checks and adds 10 G4 must-generate schemas and
8 may-fail schemas, both profiles and four seeds (144 invocations per process).
Every success is certified, independently validated and strictly roundtripped.
Only explicit unsupported/searchExhausted results are accepted for may-fail cases;
no proof, configuration error, native operational error or cancellation can replace
a required success. The qualifier repeats in two processes and materializes each
outcome, plus native verdicts for all 44 schemas/155 witness expectations. Failures
carry no invented value or successful work report. General inversion, triggered
dependency solving and constructive dynamic scope remain incomplete.

## Compiled public documentation

All ten Swift snippets across the five JSONSchemaExamples DocC guides execute as
independent scopes in DocumentationExamples.swift, synchronized byte-for-byte from
the authored guides. The exact examples cover scalar-distinct required/null keys,
large integers, offline resource/definition selection and native revalidation,
contains/pattern proposals, seeded replay, remaining work, unchanged format/default
policy and honest incomplete search. No package-private state is imported.

```sh
python3 -B Scripts/schema_example_documentation.py
swift run --package-path Examples/SchemaExamplesConsumer SchemaExamplesConsumer --documentation
```

The existing qualifier runs this mode twice and requires exactly ten completed
snippets each time, in addition to the preserved 15 cases, two process repeatability
vectors, independent transport oracle and two compiler negatives. Drift and count
failures are rejected, without adding root package dependencies. See the current
[API](../../Documentation/Architecture/Release1.6/API.md),
[49-metric scope](../../Documentation/Architecture/Release1.6/SchemaExamplesLimits.md)
and [compiled policy guide](../../Sources/JSONSchemaExamples/Documentation.docc/PoliciesAndLimits.md).

JSONSchemaDSL is absent from this S3 source snapshot. Its independent train remains
untouched; a DSL/handwritten equality example waits for an available integrated
product. Native examples do not establish later Linux/WASI/mobile release gates.
