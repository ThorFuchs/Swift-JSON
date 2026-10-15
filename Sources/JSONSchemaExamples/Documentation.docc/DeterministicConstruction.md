# Deterministic construction

Retain exact values, seed choices explicitly and identify every input to a decision.

## Choose a profile and corpus

```swift
import JSON
import JSONSchema
import JSONSchemaExamples

let corpus = JSONSchemaExampleCorpus(values: [.string("example"), .null])
let prepared = try JSONSchemaExampleGenerator(
    document: JSONSchemaDocument(JSONParser().parse("true")),
    options: .init(corpus: corpus)
)
let result = try prepared.generate(seed: 42, profile: .demonstration)
precondition(result.validation.isValid)
precondition(result.corpusDigest == prepared.corpusDigest)
precondition(result.randomDraws > 0)
```

The runnable public consumer exercises both profiles and a corpus with exact
large decimals and scalar-distinct keys. Minimal scans declared candidates in
stable order. Demonstration chooses an unbiased starting offset and scans
circularly, without replacement. It uses corpus tokens for true/empty schemas.
Neither profile claims to synthesize arbitrary constrained values or vary output
for every seed. Custom tokens never bypass native validation.

## Exact construction

The generator uses the existing iterative strict writer and parser with its one
invocation meter. Returned objects have scalar UTF-8 key order, numbers have
normalized exact spelling and arrays retain their nesting/order. Equivalent source
member orders and numeric spellings yield the same emitted bytes. NFC/NFD scalar
spellings remain distinct. No binary floating point or String dictionary intervenes.
Depth, value admission, construction, rejected choices and all native validations
consume cumulative work. Prepared plans can be shared; mutable PRNG and trace
state belong to each call.

## Versioned identities

`s3-candidates-v4` records `splitmix64-v1`, seed and profile. Snapshot, ordered
corpus, all policy caps/flags and complete abstract trace have independent versioned
SHA-256 identities. See the Release1.6/G2Determinism and G3Construction contracts for the byte formats.
These transports use compact scalar-key normalized-number strict JSON, not JCS
or unavailable original source bytes. Caller registry order is part of snapshot
identity. Policy identity includes all 49 metrics for each of generation,
compilation and evaluation; compilation assertion policy remains distinct.

Trace records contain fixed codes and unsigned integers, including every raw
random draw and completed verdict. No arbitrary schema/instance text or diagnostic
message is logged. Every byte shares the cumulative diagnostic byte quota with
native diagnostics. A successful trace is complete; exhaustion/cancellation throws
without a certificate. Hash work and result metadata also fit before return.
Logical retained bytes do not describe process RSS, and owned work quotas do not
limit caller code. Native golden vectors and separate-process checks establish
the native G5 increment; full Linux/WASI/mobile qualification remains G7.


G3 adds conservative typed value requests to the trace and uses
`swift-json-example-trace-v2`. The original snapshot/corpus/policy transports stay
at v1. Historical G2 vectors retain their earlier IDs in source history and the
immutable G2 review archive. A new algorithm version can change witnesses/traces;
reproducibility requires the same implementation and versioned inputs.

G4 extends proposals while retaining the trace v2 grammar; its envelope binds
s3-candidates-v4. Historical G3 witnesses/traces remain in the G3 source/archive.

## Replay the same prepared inputs

```swift
let prepared = try JSONSchemaExampleGenerator(
    document: JSONSchemaDocument(JSONParser().parse(#"{"type":"string","minLength":3}"#))
)
let first = try prepared.generate(seed: 42, profile: .demonstration)
let second = try prepared.generate(seed: 42, profile: .demonstration)
precondition(first.value == second.value && first.traceDigest == second.traceDigest)
precondition(first.statistics == second.statistics)
precondition(first.sourceSnapshotDigest == prepared.sourceSnapshotDigest)
precondition(first.policyDigest == prepared.policyDigest && first.corpusDigest == prepared.corpusDigest)
```

Retain the implementation commit as well as algorithm ID, seed/profile, source,
ordered registry, corpus and policies. Identical source digests alone do not bind
evaluator policies; equal seeds need not produce different values. There is no
locale, clock, system randomness, online lookup or process-randomized Hasher input.
