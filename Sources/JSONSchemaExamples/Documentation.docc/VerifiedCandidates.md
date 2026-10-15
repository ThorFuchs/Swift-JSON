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

G3 offers active const, default, enum and examples in exact ASCII keyword
order, then compiler-qualified static reference declarations in ASCII keyword
order. Array order remains semantic. True and empty schemas offer null under
minimal, or a seeded synthetic token under demonstration. Defaults and examples are merely candidates: an invalid candidate
is rejected, without inserting defaults or repairing values. Reference siblings
are enforced by validating against the original root. Dynamic construction and
same-instance ancestor cycles fail explicitly. After declared candidates, G3
constructs bounded typed proposals from compiler-qualified constraints. See <doc:TypedConstruction> for the qualified subset. This is neither full Draft 2020-12 generation nor a
complete satisfiability solver.

Minimal performs no random draws. Demonstration uses `splitmix64-v1` rejection
sampling to pick a starting offset, followed by a circular scan without replacement.
Every rejected draw and invalid candidate consumes the same invocation ledger.
See <doc:DeterministicConstruction> for exact construction and provenance.

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

`swift-json-schema-snapshot-v1` hashes the admitted normalized root and explicit
registry documents in caller order, including unambiguous retrieval identities.
It uses compact scalar-key/normalized-number writer bytes and big-endian UInt64
lengths. It excludes source maps and unavailable original source bytes. Policies
are retained separately: equal source digests do not imply equal policy. This is
not RFC8785/JCS and is not a raw-text digest. The result also binds
the immutable corpus and all policies with separate versioned digests. The complete
abstract trace includes every raw draw and native verdict, without raw schema or
instance content. It throws on exhaustion rather than silently truncating. Full
byte transports are in the repository's Release1.6/G2Determinism and G3Construction contracts.
