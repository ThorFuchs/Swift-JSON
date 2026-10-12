# Qualification

Run `python3 Scripts/ci.py --lane native` on macOS/SDK 27+ with Swift 6.4+.
Each receipt identifies the source content, command exits and environment. CI
artifacts contain raw logs, consumer outcomes and per-case corpus results.
Safety and DocC lanes run separately. Unsupported hosts fail preflight.

The Linux development increment adds four private integrity tests and one schema
integrity test: exactly 180 root functions (JSON 101, JSONSchema 42, regex 12,
streaming 14, Patch 11) with the 173 parameterized invocations retained. Targeted
shared-state safety adds the sixth function for concurrent hashing. Historical
counts below remain the receipts for their original stages. The
[Linux contract](../Architecture/Linux.md) defines the separate runtime lanes.

The 1.0 baseline has 122 Swift Testing functions across five bundles and
173 parameterized invocations. The first 1.1 qualification milestone adds seven
authored prototype cases in JSONTests (54 to 61), for 129 functions, with the existing 173 parameterized invocations retained
and seven additional nonparameterized cases. The first production lookup increment adds two further cases (JSONTests 63, total 131 functions). No baseline case or corpus outcome is removed. One public cap test exercises all 49 metrics;
the independent runner adds nine budget/report vectors. There are three separate
JSON/JSONSchema consumer tests. All discoveries must be nonzero.

The Turn002 integrated 1.1 candidate checked exactly 156 root functions:
JSON 86, JSONStreaming 11, JSONSchema 38, JSONRegexRuntime 12 and JSONPatch 9.
All 173 parameterized invocations remain. The earlier counts above describe their
historical stages, not this source. Three additional public/mobile Swift Testing
functions exercise eight pinned payload fixtures and three independently exited
SwiftData disk phases. The seven-function R0 subset, all 49 cap probes, rooted
20-case consumer and independent policies retain their exact checks.

The additional QA wave adds 19 behavior functions, for exactly 175:
JSON 97, JSONStreaming 14, JSONSchema 41, JSONRegexRuntime 12 and JSONPatch 11.
All 48 earlier Swift test files and 173 parameterized invocations are retained.
The focused `python3 Scripts/ci.py --lane qa` checks exact counts 11/3/3/2 in
debug, release and Address Sanitizer. It supplements the full native/safety lanes
and does not replace independent qualification or any of the 49 cap probes.
Thread Sanitizer checks five shared-state cases, including concurrent payload
opening and separate read scopes over one immutable root. See [QA](../Architecture/Release1.1/QA.md).

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

The [1.1 platform policy](../Architecture/Release1.1/QualificationPolicy.json)
accepts iPad SDK/simulator behavior and three-process disk persistence for this
release. Physical iPad qualification is deferred and nonblocking. Physical iPhone
evidence remains required; no test, corpus policy or resource assertion is removed.
