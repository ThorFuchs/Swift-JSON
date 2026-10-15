# Release 1.6 — S3 schema examples

The proposed addition is an opt-in `JSONSchemaExamples` library. It constructs
deterministic candidate JSON and returns a witness only after the existing native
validator completes with `isValid == true`. Incomplete search, unsupported
construction, sound trivial unsatisfiability and operational errors stay distinct.
No arbitrary-schema completeness or unsatisfiability claim is intended.

The isolated branch is `codex/1.6-schema-examples`, pinned to main
`507dbf9ad4b545a5d60d7d6acf6b814795ec3099`. See
[source reconciliation](Reconciliation.md), [decisions](Decisions.md) and
[progress](Progress.json). The initial orientation and compiler probes are complete. G1 now has a working
explicit-candidate API, a package-only qualified plan bridge and a real public
consumer; see [the accepted declarations and scope](G1API.md). [G1 native qualification](G1Qualification.md) is complete; G2 is next. Broad
generation is not implemented.

## Integration boundary

Current main has six library products and `swift-json`. S3 will add one library
with dependencies on JSON and JSONSchema only. Existing products gain no dependency
on it. Private regex/filter/CLI targets, empty root dependencies, Swift tools/compiler
6.4, language mode 6, Apple 27 minima, Apache-2.0 and notices remain authoritative.
Dual DSL PR #31 is independent and is not a build or qualification prerequisite.
No DSL integration example is promised until those products actually land.

## Reviewable increments

| Gate | Work and acceptance |
| --- | --- |
| G0 | Pin release/main/worktrees, inspect compiled APIs, verify packet and fixture expectations, identify package boundaries |
| G1 | Review exact public declarations; add optional target/test target; implement the smallest qualified read-only plan bridge and real public consumer |
| G2 | Metered splitmix64-v1, exact ordering/construction, versioned corpus/snapshot transport and SHA-256, confined invocation state |
| G3 | Mandatory final certification, foundational 24 must-generate cases and two sound trivial proofs, keyword capability ledger |
| G4 | Ten additional must-generate cases, eight honest incomplete-search cases, qualified refs/composition/regex boundaries |
| G5 | One cumulative ledger across construction and all validation attempts, including completed false verdicts; overflow, retention, terminal failure and cancellation tests |
| G6 | Compiled public examples, DocC, README/API/limits documentation and optional-product isolation |
| G7 | Swift Testing Debug/Release, exact inherited discovery and all 49 caps, safety, pinned suites, determinism and applicable platform qualification |
| G8 | Source/diff/API/capability ledger, actual receipts and fixture outcomes, reproducible source and materialized review return |

Keep G1/G2/G3 cohesive local commits. Split later reference/search/resource work
when its diff needs separate review. No passing scaffold tests or unimplemented
public success API should be introduced. The amended fixture set has 155 witnesses;
its 44 case classifications and generator acceptance gates are unchanged.

The current harness requires 419 native functions, 325 parameter invocations and
15 shared-state TSan functions before S3 adds tests. These are current-source
requirements, distinct from the observed 1.5.0 counts of 395/199/14. Preserve
exact identities/cardinalities, all 49 metric probes and independent suite policies.
Fresh S3 qualification must cover its actual final source; old evidence is a baseline.

Release notes/version metadata, tagging, publication and public activation are
later deliberate steps. This kickoff does not authorize or perform them. E11/E12,
AI/model services, importers, CLI expansion and complete regex inversion stay outside S3.


G2 implements `s3-candidates-v2`: metered SplitMix64, stable exact construction,
explicit versioned corpus/source/policy/complete-trace transports and compiler
ownership boundaries. See G2Determinism.md and the subsequent qualification record.
The isolated branch retains its G0/G1 base. Main independently advanced to 037e735
with 1.5.1 repairs; rebasing/merging that train is a separate integration task
before final G7/G8 release qualification, not silently part of G2.
