# G3 native construction milestone

G3 extends G2 commit `42a523c6d0a4dab9195c847feb4e47b43803bfd1` on the
isolated `codex/1.6-schema-examples` branch. The accepted construction and transport
decisions are in [G3Construction](G3Construction.md); the machine-readable
[capabilities](Capabilities.json) distinguish proposal hints from native semantic
authority. No existing JSON/JSONSchema production source or dependency changed.
G0-G2 history remains intact. G4-G8 and main's independent 1.5.1 integration remain
open; this is not a release candidate.

## Actual commands and outcomes

On macOS 27.0 arm64, Xcode 27.2 (27B5019j), Apple Swift 6.4
(`swiftlang-6.4.0.34.1 clang-2100.3.34.1`), SDK 27.2, language mode 6:

* `python3 -B Scripts/ci.py --lane schema-examples-construction --output Artifacts/SchemaExamplesS3/G3/native-final`
  exited 0, all eight commands passed. Exact eight-product isolation and empty
  dependencies passed. All 61 Swift Testing functions passed in Debug and Release.
* `python3 -B Scripts/ci.py --lane schema-examples-safety --output Artifacts/SchemaExamplesS3/G3/safety-final`
  exited 0, all three commands passed: 61 Release ASan functions, two TSan sharing
  functions with 32 concurrent invocations each, and strict-memory-safety
  compilation with warnings as errors. No unsafe annotation or compatibility
  flag was introduced.
* The actual public consumer independently compiled plans, certified/validated
  and strictly roundtripped all 24 required cases, two profiles and four seeds
  (192 invocations per process), in two separate processes. Exact values, traces
  and cumulative statistics matched. Each process checked 90 fixture witness
  expectations and two separate trivial proofs. These are repeated executions,
  not 384 distinct fixtures. The other 18 G4 cases are not counted as successes.
* The preserved default public consumer passed 15 cases twice and two expected
  public access-control rejections. The independent byte-format/SHA-256 oracle
  matched both profiles. Implementation-only compiler fixtures accepted one move
  and immutable-facade sharing, and rejected eight copy/Sendable violations with
  the expected ownership diagnostics, not missing imports.
* Harness mutation checks passed 22 cases; the Testing event parser passed 19.
  Exact full-lane discovery remains 480 native functions, 325 parameter
  invocations, 17 sharing functions and all 49 baseline metrics. Focused G3
  results do not substitute for those later release lanes.

Commands use `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer` and
the selected Xcode's macOS 27.2 SDK. Receipts retain the actual command arrays,
environment, exits, log/event hashes and complete working-tree source hashes.
Their recorded Git HEAD is the G2 base plus those captured G3 files; that SHA
alone does not contain this implementation. The private final SourceEvidenceMap
compares full critical path sets/hashes to the committed source. The final
clean-head `Scripts/ci.py --lane docs` receipt records actual documentation,
compiled-consumer and site results for that final snapshot.

## Regression evidence and fixture identity

The amended fixture bytes are pinned to
`5b3e6e40e83439a810d0eb7ac412ce158a4e582f36b9d36d6e313c159654ddd3`.
The unchanged original is separately retained at
`6f2bfd4fdb7c7e206b6570c2156ca8e248831840733b0258aa8cd5938b35649f`.
The [manifest](../../../Tests/Fixtures/SchemaExamples/Manifest.json) preserves
G0's integral-number amendment and the complete 44-case/155-witness inventory.
The G3 subset has 90 witness expectations; no old negative was removed to qualify
the generator. These authored fixtures are not independent external-suite passes.

A 654-file path-set/hash comparison proves the existing JSON/JSONSchema/regex
source, 69 schema functions, their pinned fixtures and qualification policies
unchanged from G2's separately passed schema command: 12 parameter invocations,
2300 evaluated pinned cases and 37 separate policy exclusions. Its aggregate G2
lane failed a stale consumer marker and is never relabelled passed. The reuse
record explicitly excludes the new G3 fixture directory, which that old suite
does not read. Raw selected-command logs/events and the original receipt accompany
the G3 return; no fresh whole-package or platform-suite pass is inferred.

## Behavior and review findings

The 19 added functions cover the fixture matrix, sound proofs, conjunctive exact
NFC/NFD keys and additionalProperties scope, huge/tiny/open signed decimals,
scalar lengths, native format policy, min-properties/unique arrays, nested
arrays, exact cumulative work boundaries after a false verdict, finite staging
caps, dense-alignment rejection, terminal operational failure/cancellation,
100 repeated calls, concurrent sharing, twelve positional prefix indices,
2940 independent integer rounding checks and repeated static-target DAGs.

Review found that normalized JSON number spelling cannot represent positional
indices: index 10 needs `"10"`, not `"1e1"`. The constructor now uses prepaid,
bounded positional UInt64 formatting. Repeated static references are deduplicated
as DAG sharing; only an active ancestor cycle is rejected. Internal frame types
explicitly opt out of Sendable inference; compiler fixtures enforce that boundary.

The first exploratory run's old format-hint test expected search exhaustion.
Typed construction correctly found null: format alone does not imply string.
The test now separately verifies the invalid string against native assertion and
uses one attempt to exercise the rejected hint. Another old invalid-default test
now expects a later independently constructed valid object while proving the
original default remains unchanged. The corrected 60-function exploratory run
and final 61-function lanes passed; failed attempts remain in private evidence.

## Remaining limits

The candidate algorithm is `s3-candidates-v3`; complete trace is
`swift-json-example-trace-v2`. Source/corpus/policy v1 transports remain unchanged;
G2 vectors remain historical. No cross-version/platform identity is implied.
Every returned value still requires completed validation of the original root.
No schema merge, branch-local certificate, alternate validator, approximate
number, online resolver or unconstrained retry is introduced.

Construction is conservative: arbitrary regex inversion, dynamic scope, difficult
dependencies/conditionals and general satisfiability are not solved. Dense decimal
alignment can exhaust a finite quota. All owned staging and every native false
verdict share the generation ledger; preparation has its separately reported
compilation ledger. Scratch retention is conservatively charged. Logical bytes
are not allocator RSS and caller qualification work is not an instruction quota.
G5's broader lifecycle review, G6 final documentation and G7/G8 integration,
Linux/WASI/mobile/performance/release qualification remain separate.

No sibling source, main checkout, remote branch, PR, tag, release, deployment or
external message was changed by this local milestone.
