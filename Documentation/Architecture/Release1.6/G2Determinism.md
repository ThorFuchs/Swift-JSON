# G2 determinism and accounting decision

Accepted on the isolated S3 branch before the G2 implementation. This supersedes
G1's provisional algorithm/digest identifiers, preserving its native certification
authority and explicit unsupported cases. General synthesis remains G3/G4 work.

`s3-candidates-v2` uses `splitmix64-v1` (the packet's wrapping constants and shifts).
Each raw draw costs 10 core work units, including rejected draws. Uniform selection
adds three units for the rejection threshold and two per comparison/modulo. The
threshold is `(0 &- bound) % bound`; zero bounds throw. Quota counters never wrap.
Mutable RNG/trace state is noncopyable and invocation-owned. Swift 6.4 initially
inferred Sendable for these internal value types; explicit unavailable Sendable
conformances now opt them out. Compiler fixtures reject copying and Sendable
requirements for the mutable helpers and accept moves plus the sharable facade.
Fixed draw/threshold/comparison costs are charged one unit at a time, including
inside a draw, so cancellation quantum one remains meaningful. No default Hasher,
locale, clock, network, callback or floating-point conversion affects decisions.

Candidate roles use ASCII keyword order: const, default, enum, examples; then
true/empty-schema candidates and compiler-qualified static references in ASCII
keyword order ($dynamicRef with a static target, then $ref). Array order
is semantic and retained. Minimal scans arrays from zero without draws;
demonstration picks an unbiased starting offset and scans circularly, without
replacement. It also chooses from the immutable synthetic corpus for true/empty
schemas. This is seeded candidate selection, not general demonstration synthesis.
There is no type preference until typed synthesis is implemented in G3.

Every proposed value is constructed by the existing iterative strict writer
(compact, scalar UTF-8 key order, normalized exact decimals), followed by the
existing strict parser using the SAME meter. This normalizes object insertion
order and numeric lexemes without changing scalar identity or mathematical value.
Nested arrays remain arrays; no Dictionary<String,...>, Double or approximate
arithmetic intervenes. Construction/admission/validation work remains cumulative.
Discarded attempts refund only their owned live bytes, excluding retained traces.

## Byte transports, version 1

All digests are lowercase SHA-256. `u64` means eight bytes, unsigned big-endian;
`field(b)` means `u64(byteCount) || b`. Literal headers include their final LF.
Text is exact UTF-8. These are Swift-JSON transports, **not RFC8785/JCS** or hashes
of unavailable original source text. No Unicode normalization is performed.

* `swift-json-schema-snapshot-v1`: header `SwiftJSON-schema-snapshot-v1\n`,
  u64 document count, root followed by registry in caller order. Each document is
  one URI-presence byte (0/1), field(retrievalURI UTF-8, empty when absent),
  field(compact scalar-key normalized-number strict writer bytes). Source maps,
  original numeric lexemes and policies are excluded. Registry order is identity.
* `swift-json-example-corpus-v1`: header `SwiftJSON-example-corpus-v1\n`,
  field(the same writer encoding of the ordered corpus as one JSON array).
  The built-in corpus is `[null,false,0,"example",[],{}]`. Custom values are
  admitted, normalized and hashed during preparation; caller array construction
  precedes preparation. Empty corpora are rejected. Corpus order is identity.
* `swift-json-example-policy-v1`: header `SwiftJSON-example-policy-v1\n`,
  u64 maximumAttempts, then three limit records in generation, compilation,
  validation order. Each record is u64(49), then for every JSONResourceMetric in
  declaration order field(metric rawValue UTF-8), u64(limit). Compilation flags
  then validation flags are four bytes each: formatAssertion (0/1), output
  (flag=0/basic=1), diagnosticPolicy (complete=0/bestEffort=1), collectAnnotations
  (0/1). This binds every one of the 49 caps, including cancellation quantum.
* `swift-json-example-trace-v1`: header `SwiftJSON-example-trace-v1\n`,
  fields of generatorVersion, source digest, corpus digest, policy digest (ASCII),
  u64 seed, profile byte (minimal=0/demonstration=1). Events are one code byte
  followed by two u64 operands: visit=1(0,0), offer=2(role,index), draw=3(raw,bound),
  verdict=4(attempt,valid:0/1), finish=5(attempts,draws). Role IDs: const=0,
  default=1, enum=2, examples=3, true/empty=4. No compiler-local IDs, arbitrary
  schema strings, values, diagnostic text, timing or work counts enter the trace.

Every trace byte charges diagnosticBytes, retainedBytes and work before append;
native diagnostics share that cumulative diagnosticBytes ceiling. There is no
silent truncation or partial-digest success. RNG draw events include rejected
draws. A successful trace includes the final native valid verdict and finish;
hashing and result metadata are charged before returning. Failure/cancellation
returns no certificate or accounting success. Digesting excludes its own hash
and work counts, avoiding circular definitions. Stable trace bytes are distinct
from platform-dependent diagnostic/work observations.

Preparation shares its compiler meter with corpus admission, all transports and
hashing. Generation uses the intersection of generation/evaluation limits.
Existing iterative codec/admission frames bound depth before growth; no recursive
constructor is introduced. Logical accounting is conservative live ownership,
not allocator/RSS or caller-instruction accounting. G7 must still run these
goldens on Linux/WASI before a cross-platform qualification claim.

## Accepted API additions and qualification boundary

`JSONSchemaExampleOptions` adds `corpus:` (default `.synthetic`). The corpus is
`JSONSchemaExampleCorpus(values:)`; its values are immutable and caller-authored
until checked preparation. `.demonstration` is the only added profile; boundary
and typed construction remain deferred. Prepared generators expose corpusDigest
and policyDigest. Results add corpus/policy/trace algorithm IDs and digests,
rngAlgorithm, randomDraws and traceEventCount. Result initialization stays internal.
The existing public JSON and JSONSchema APIs/dependencies are unchanged.

The focused `schema-examples-determinism` lane checks exact product/dependency
shape, all 42 generator tests in Debug and Release, implementation ownership
compiler probes and the real public consumer plus independent transport oracle.
The broader `schema-examples` lane and full release/safety lanes remain intact.
Unchanged-core suite reuse is tied to actual file path/hash sets in the G2 source
evidence map; it never upgrades a failed aggregate receipt to a passed lane.
No core metric probe or parameter/cardinality guard is removed.
