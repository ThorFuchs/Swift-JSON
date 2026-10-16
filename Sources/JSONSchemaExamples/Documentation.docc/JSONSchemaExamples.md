# ``JSONSchemaExamples``

Deterministic exact JSON candidates certified by the existing offline schema validator.

Use this optional 1.6 development library for schema-driven fixtures, examples and
tooling where every returned value must satisfy the original compiled root. Prepare
an admitted JSONSchemaDocument with explicit offline resources, then generate with
finite policies and a reproducible seed. JSON and JSONSchema keep their existing
semantics and acquire no dependency on this module.

Construction is conservative: exact declared hints, bounded typed values, static
references and qualified composition, contains and anchored ASCII-pattern proposals.
Every candidate requires completed native root validation. Unsupported or exhausted
search is explicit; this is not a complete satisfiability solver. Formats, defaults,
requiredness, dynamic scope and annotations retain the native dialect's meanings.

All Swift guide blocks execute through a separate public consumer. Native G1-G6
incremental evidence is separate from remaining G7/G8 release/platform qualification.
The standalone source checkout is the API authority until this product is released.

## Topics

### Start with an offline schema

- <doc:VerifiedCandidates>
- ``JSONSchemaExampleGenerator``
- ``JSONSchemaExampleOptions``
- ``JSONSchemaExampleResult``

### Construct exact, reproducible candidates

- <doc:TypedConstruction>
- <doc:AdvancedConstruction>
- <doc:DeterministicConstruction>
- ``JSONSchemaExampleProfile``
- ``JSONSchemaExampleCorpus``

### Bound work and handle failures

- <doc:PoliciesAndLimits>
- ``JSONSchemaExampleFailure``
- ``JSONSchemaExampleUnsupportedFeature``
- ``JSONSchemaUnsatisfiableProof``
- ``JSONSchemaExampleConfigurationIssue``
