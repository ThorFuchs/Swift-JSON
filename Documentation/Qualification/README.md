# Qualification

Run `python3 Scripts/ci.py --lane native` on macOS/SDK 27+ with Swift 6.4+.
Each receipt identifies the source content, command exits and environment. CI
artifacts contain raw logs, consumer outcomes and per-case corpus results.
Safety and DocC lanes run separately. Unsupported hosts fail preflight.

The unchanged library has 122 Swift Testing functions across five bundles and
173 parameterized invocations. One public cap test exercises all 49 metrics;
the independent runner adds nine budget/report vectors. There are three separate
JSON/JSONSchema consumer tests. All discoveries must be nonzero.

| Independent input | Observed policy |
| --- | --- |
| JSONTestSuite, pinned in FixtureRegistry.json | 318 discovered: 101 accepted, 186 rejected, 31 strict/finite-policy rejections |
| JSON Schema Test Suite, pinned in FixtureRegistry.json | 2337 discovered: 2300 evaluated, 37 optional cross-draft/legacy cases explicitly not evaluated |
| Regex oracle corpus | 31824 cases, 442 patterns |
| Unicode normalization corpus | 18853 cases, 94265 comparisons, fixed Unicode 13 |
| Authored public vectors | 82 cases and nine public budget/report checks |
| Malformed replay | 4396 deterministic cases |
| Rooted JSON/JSONSchema consumer | 20 cases, eight positive and twelve negative; operational failures recorded separately |

Policy exclusions are never evaluated successes. A resource error, compilation
error, evaluation error or cancellation is distinct from an invalid schema verdict.
Fixtures, their licenses and manifests are retained under Tests/Fixtures. The
explicit schema policy table stays at Evidence/SchemaMilestone/schema-policy-exceptions.json
because both the tests and independent runner read it. Runtime resolution is offline.

[LimitsMatrix.json](LimitsMatrix.json) maps all 49 finite metrics to accounting
sites and native boundary tests. Public probes produce 47 resource rejections,
one invalid zero cancellation quantum, and successful zero owned reusable scratch.
The three profiles are initial policy, not hard RSS or throughput guarantees.

Exact values, scalar identity, native coding, Pointer, both Patch standards,
stream completion/backpressure, reports, cancellation and concurrent plan reuse
are tested. Native safety includes Address Sanitizer, Thread Sanitizer and strict
memory safety compilation. [CI](../CI/README.md) describes executed lanes;
[performance](../Performance/README.md) retains the reviewed streaming disposition.
