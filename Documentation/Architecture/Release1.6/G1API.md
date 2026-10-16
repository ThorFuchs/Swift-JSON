# G1 API and preparation decision

Accepted before implementation on `codex/1.6-schema-examples`, base `507dbf9`.
This is a working candidate-verification increment, not the G3 constructive subset.

The optional eighth product `JSONSchemaExamples` imports JSON and JSONSchema only.
Existing product dependencies remain unchanged. Its immutable Sendable generator
accepts `document:registry:options:`, compiles once and retains that exact offline
plan. Each `generate(seed:profile:)` invocation owns one noncopyable core meter,
intersecting generation and validation limits without changing evaluator policies.
Preparation has its own compilation meter, shared with snapshot serialization and
hashing. Caller document/registry admission precedes preparation.

G1 accepts these public roles:

- `JSONSchemaExampleOptions(limits:maximumAttempts:compilationOptions:validationOptions:)`.
  Use existing JSONLimits rather than a second copy of its 49 metrics. A positive
  finite maximumAttempts is a separate search ceiling; zero/UInt64.max are invalid.
- `JSONSchemaExampleGenerator(document:registry:options:) throws`, and
  `generate(seed:profile:) throws -> JSONSchemaExampleResult`. The only current
  profile is `.minimal`. Seed is recorded; G1 makes no random choices. No RNG or
  corpus API is advertised before G2's algorithms are implemented.
- An immutable result containing the exact value, actual completed validation,
  seed/profile, implementation version, source snapshot digest, evaluation policy,
  attempt count and cumulative invocation statistics. Result initialization is
  internal; callers cannot construct a purported certification through this API.
- Typed failure cases `unsupportedFeature`, `searchExhausted`,
  `provenUnsatisfiable`, `invalidConfiguration`, with finite enum codes instead
  of untrusted free-form messages/paths. Core schema/resource/configuration errors
  and CancellationError propagate unchanged.

Candidate order is active const, enum in declaration order, default, examples in
declaration order, then compiler-resolved static references in compiler edge order.
Boolean true and empty object schemas propose null. Each candidate is checked
against the **original prepared root**, including reference siblings. Metadata is
never inserted or repaired. Every completed false check consumes the same ledger;
operational errors terminate immediately. Discarded validation ownership is released without refunding work. Statistics
use existing logical weights; they are not RSS or allocator measurements.
Unsupported construction and reference cycles remain explicit failures. Dynamic
edges are not followed; encountering one in the searched declaration is unsupported.

Only root false and root not-true/not-empty-object with an active applicator
vocabulary have G1 unsatisfiability proofs. No reference-cycle, invalid-candidate
or search-limit failure is presented as a proof. Other satisfiable schemas can
still fail to produce a witness until later gates.

The package-only `JSONSchemaQualifiedNode` handle is created only by a compiled
plan or its checked child/reference edges. Its immutable view exposes raw
declaration, compiler resource URI, original document Pointer, active vocabulary
and format-assertion flag. Indexed edge inspection charges the borrowed meter.
It exposes neither mutable graph fields nor regex programs. Integer identities are
local to one plan. No new public JSONSchema declarations or URI resolver are added.
An internal compiler overload borrows the preparation meter while preserving the
original admitted document/source map, with the same compilation implementation.

`swift-json-schema-snapshot-g1-v1` is SHA-256 over this exact transport: ASCII
`SwiftJSON-schema-snapshot-g1-v1\n`, big-endian UInt64 document count (root then
registry documents in explicit caller order), then for each document a one-byte
retrieval-URI-present marker, a length-prefixed UTF-8 retrieval URI (empty if absent),
and length-prefixed compact JSONWriter bytes (scalar key order, normalized exact
numbers). Every length is big-endian UInt64. Source maps/original lexemes are not
source text and are excluded. Registry order is deliberately part of this identity.
Policies are retained separately, unchanged; equal source digest does not imply
equal policies. This is not RFC8785, raw-source hashing or G2's final corpus/trace
transport. The G1 algorithm ID is `s3-g1-candidates-v1`.

Rejected for G1: public graph access, caller-supplied compiled plans without a
coherent source/registry snapshot, URI guessing, opaque validation reports, broad
arithmetic/regex synthesis, unimplemented profiles, invented corpus/trace receipts,
and any dependency on the separate DSL train. Full G5 lifecycle qualification and
G7 platform/conformance qualification remain separate gates.

## G1 resource units and review

Each newly searched compiled declaration charges schemaNodes, rather than treating
visited identities as active evaluator frames. Pending construction handles are
bounded by evaluationFrames. Identity slots and pending handles use the existing
indexSlot (32) and frame (16) logical weights; a returned certificate reserves
128 logical bytes for its metadata. Candidate admission/evaluation uses the native
weights. Failed completed validations release their newly owned result/scratch
retention without refunding work, diagnostics or lifetime value-admission counts.
No independent peaks are added to impersonate live retention or RSS. The G1 tests
include a zero schemaNodes discovery ceiling and a shared-work exact boundary.
