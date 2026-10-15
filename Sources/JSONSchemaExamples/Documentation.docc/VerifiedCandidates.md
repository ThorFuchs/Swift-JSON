# Verified candidates

Compile once, retain explicit offline resources, and publish only a native valid verdict.

## A working exact example

```swift
import JSON
import JSONSchema
import JSONSchemaExamples

let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"const":9007199254740993}"#
))
let prepared = try JSONSchemaExampleGenerator(document: document)
let result = try prepared.generate(seed: 42, profile: .minimal)
precondition(result.validation.isValid)
let text = try JSONWriter().writeString(result.value)
```

The large integer stays exact. The standalone `Examples/SchemaExamplesConsumer`
package compiles this public shape, validates every returned value independently,
and exercises scalar-distinct keys, static/offline references and failures.

## Current construction boundary

G1 offers active const, enum members in declaration order, default, examples,
then compiler-qualified static reference declarations. True and empty schemas
offer null. Defaults and examples are merely candidates: an invalid candidate
is rejected, without inserting defaults or repairing values. Reference siblings
are enforced by validating against the original root. Dynamic construction and
cycles fail explicitly. This is neither full Draft 2020-12 generation nor a
complete satisfiability solver.

Only the minimal profile exists. Seed is recorded, but `s3-g1-candidates-v1`
performs no random draws; varying seed need not vary output. Deterministic random
construction, richer profiles and corpus/trace contracts belong to later gates.

## Policies, errors and sharing

Preparation owns one compilation ledger, including source snapshot serialization
and SHA-256. Generation owns a fresh invocation ledger shared by discovery and
**all** candidate validations, including false verdicts. The effective capacities
are the intersection of generation limits and evaluation limits. Compilation
options and validation options remain separate; no format policy is changed.
Required assertion vocabularies remain authoritative. Discarded validation ownership is released while work remains charged. Logical
retention uses existing accounting weights and is not allocator memory or RSS.

An ordinary false verdict may lead to another candidate. Native operational
errors, exhaustion and cancellation terminate the invocation immediately. Typed
construction errors distinguish unsupported features, search exhaustion, reviewed
trivial unsatisfiability proofs and invalid generator configuration. No value
accompanies a failed invocation. Reuse the immutable generator across tasks; each
call owns its mutable search and evaluation state.

## Snapshot identity

`swift-json-schema-snapshot-g1-v1` hashes the admitted normalized root and explicit
registry documents in caller order, including unambiguous retrieval identities.
It uses compact scalar-key/normalized-number writer bytes and big-endian UInt64
lengths. It excludes source maps and unavailable original source bytes. Policies
are retained separately: equal source digests do not imply equal policy. This is
not RFC8785/JCS and is not a raw-text digest. Full transport details and future
qualification boundaries are in the repository's Release1.6/G1API contract.
