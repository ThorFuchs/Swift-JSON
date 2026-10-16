# JSONSchemaExamples current public contract

This is the current S3 interface through G6, superseding the provisional G1 API
notes where later accepted increments differ. Historical decisions and receipts
are preserved. It is an opt-in 1.6 development product; G7/G8 and main repair
integration remain open. Native compiler symbol graphs and source declarations
are the API authority. There is no public mutable plan, evaluator, meter or result
initializer, and no new root-package dependency.

## Prepare, generate and inspect

| API | Actual role and defaults |
| --- | --- |
| `JSONSchemaExampleGenerator(document:registry:options:) throws` | Admitted JSONSchemaDocument, explicit registry default `.empty`, options default `.init()`; compile/normalize/hash once under one preparation ledger |
| `generate(seed:profile:) throws -> JSONSchemaExampleResult` | Seed UInt64 default 0; profile default `.minimal`; independent cumulative invocation; returns only after native valid verdict and complete trace/hash |
| `document`, `registry`, `options` | Immutable original preparation inputs/policies; no inferred format/default/registry behavior |
| `preparationStatistics` | Separate compilation-domain counts, including snapshot/corpus/policy work; not part of the generation report |
| `sourceSnapshotDigest`, `corpusDigest`, `policyDigest` | Lowercase SHA-256 identities of the documented separate transports |

The generator is checked Sendable. Mutable construction frames, PRNG, trace and
validation state belong to one synchronous call. The compiled root is private and
retained immutable. Caller document/registry/corpus construction precedes preparation.
Returned values have normalized exact numbers, scalar-sorted object insertion order
and preserved array nesting; mathematical/scalar semantics are those of JSON.

## Options and profiles

`JSONSchemaExampleOptions(limits:maximumAttempts:corpus:compilationOptions:validationOptions:)`
uses balanced generation limits, maximumAttempts **16**, corpus **.synthetic** and
native JSONSchemaOptions defaults for both compilation and validation. Options are
values checked when preparing a generator. Changing a caller's options afterward
does not mutate an existing preparation.

* Generation limits intersect validation limits per metric. All 49 entries remain
  finite and contribute to policy identity. See [limits](SchemaExamplesLimits.md).
* Compilation options remain separate, including any format assertion selected at
  compilation. Validation output, diagnostic policy, annotations and assertion
  settings are forwarded unchanged. Required vocabulary assertions still apply.
* `maximumAttempts` must be positive and strictly below UInt64.max. It bounds
  completed candidate validations, including false verdicts, without promising
  that every search reaches the limit or finds an existing witness.
* `.minimal` uses stable declared order and conservative small typed proposals,
  with no random draws. It is not a global minimization guarantee.
* `.demonstration` uses seeded SplitMix64 candidate/corpus choices. Some inputs
  produce the same value for every seed. Every raw rejected draw is charged.
* `JSONSchemaExampleCorpus(values:)` stores exact ordered caller JSON without
  admission; preparation checks/normalizes it and rejects an empty corpus. The
  synthetic ordered values are null, false, 0, "example", [], {}. The read-only
  `synthetic` property materializes these values per access; caller lifetime owns
  their storage, before checked preparation. Corpora are hints.

Candidate role order is **const, default, enum, examples** (ASCII keyword order).
Array order is semantic. Discovery follows qualified alternatives/static edges;
typed construction then offers bounded variations. Defaults and examples can be
invalid; nothing is inserted or repaired. Complete original-root validation alone
establishes success. See [supported subset](../../../Sources/JSONSchemaExamples/Documentation.docc/TypedConstruction.md)
and [all 59 keyword classifications](Capabilities.json). General satisfiability,
regex inversion, triggered dependency/key synthesis and constructive dynamic scope
are incomplete. No boundary profile, AI, online resolver or interop converter is added.

## Result and provenance

JSONSchemaExampleResult exposes immutable `value`, actual native `validation`,
`seed`, `profile`, `attempts`, `statistics`, `validationOptions` and
`compilationOptions`, plus these identities:

| Properties | Current identity |
| --- | --- |
| generatorVersion | s3-candidates-v4 |
| schemaDigestAlgorithm / sourceSnapshotDigest | swift-json-schema-snapshot-v1 / source and ordered registry hash |
| corpusDigestAlgorithm / corpusDigest | swift-json-example-corpus-v1 / admitted ordered corpus hash |
| policyDigestAlgorithm / policyDigest | swift-json-example-policy-v1 / all three 49-cap profiles, attempt ceiling and policy flags |
| rngAlgorithm / randomDraws | splitmix64-v1 / every raw draw, including rejection |
| traceDigestAlgorithm / traceDigest / traceEventCount | swift-json-example-trace-v2 / complete abstract decision hash and event count |

Transports exclude source maps, unavailable original source bytes and caller time.
They are not RFC8785/JCS. Registry order contributes to source identity. Seed alone
cannot bind a result; retain implementation commit, versions and all input identities.
[G2 transports](G2Determinism.md), [G3 trace additions](G3Construction.md) and the
[G5 accounting correction](G5Resources.md) preserve historical versions separately.
Statistics snapshot certification and conservative staging ownership, before transfer;
logical retained bytes/peaks are not heap size or RSS. WorkUnits includes subsystem work.

## Failures and semantic authority

| Failure | Meaning |
| --- | --- |
| unsupportedFeature(candidateConstruction / dynamicReference / cyclicReference) | Current constructor lacks a proposal or reached unsupported scope/active cycle; no validity conclusion |
| searchExhausted(attempts:) | All offered candidates rejected or finite ceiling reached; not an unsatisfiability proof |
| provenUnsatisfiable(falseSchema / notTrue) | Only reviewed trivial root false or active root `not` of true/empty schema |
| invalidConfiguration(attemptLimit / emptyCorpus) | Invalid generator configuration before preparation/search |
| Native compilation/evaluation/resource error or CancellationError | Operational failure; terminal, never ordinary false validation or accepted incompleteness |

No failed call publishes a value, complete trace or successful work report. A caught
operational error cannot resume its internal invocation; a later public call is an
independent operation. Immutable preparation remains reusable. Public consumers must
not invent failed-work statistics when composing separate calls.

## Compiled examples and integration

[README examples](../../../README.md#generate-verified-schema-examples-16-development)
compile in the seven-library consumer. Every Swift block in all five S3 DocC guides
is synchronized with DocumentationExamples.swift and runs twice in the separate
[public consumer](../../../Examples/SchemaExamplesConsumer/README.md), alongside
15 preserved cases and two compiler negatives. Drift/missing snippets fail the lane.
Both packages import public products only; neither is a root runtime dependency.

JSONSchemaDSL is absent from the inspected S3 Package.swift and main base. Its
independent train is untouched. A DSL equality example is deferred until a real
product is available during integration. An admitted document from any authoring
source can use this API under the same native dialect; no foreign notation is
implicitly converted. CLI, JSONHTML, AI and schema interop gain no S3 dependency.
