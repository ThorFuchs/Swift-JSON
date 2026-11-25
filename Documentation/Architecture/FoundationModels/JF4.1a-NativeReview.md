# JF4.1a — Successful native prepared-generation and typed-codec qualification

**Decision: APPLE_ERGONOMICS_CANDIDATE_PASS.** Focused native Apple
qualification passes with all prior schema and value regressions.
Product admission remains NOT_ADMITTED. Reviewed 2026-11-25.

## Source-bound evidence

- Archive: jf4-onqzbtj2.tar.gz (23,582 bytes)
- SHA-256: 8a3c5cb57261798b1cd4d6809975156209b0033dbe69c19b41cd3d202058a00c
- Exact source: `45b0eb69ce6bb0aca392f082899db73bbee4d46d`
- Base review: `7f63b2c38a578b1fd8c49bb64c95a4d7c98bb3f0`
- Manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- PreparedGeneration blob: `2d72fa538d85b83210eca708b6d78da3e2eacef5`
- Repaired public-consumer test blob: `9e631178a7d7a6ac14695a052de9283554d856a1`
- Borrowed-scope ValueBridge blob: `be8d0a640f7df7edf18c26cba09efa02122be277`
- SchemaBridge blob: `bce3c3965e210d4f5ee8db4b5cecc8f63e407b04`
- StructuralProof blob: `ed07244f0d6370498b119a4f97aeb7ba59a7f2af`
- Runner blob: `229e2471279f4a612b6f0024a6a6864c1a0f38bb`
- Offline control blob: `e9d8376be65a54571d213f512c94d2c3276dc471`
- Reverse fixture SHA-256: 9e8d6b50ae8c407f8d4d42632cbd66c5f381f3bf7bef53fd36b6659e8134bb47
- Darwin arm64; macOS 27.3; Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9); Xcode 27.2 (27B52); SDK 27.2.

Read regular members directly without extracting or executing archive
content. All twelve recorded subprocess exits are zero; no failure.txt.
The earlier failed Debug run is preserved in JF4.1-NativeReview.md.
Separate offline-control stdout is not included in the new archive;
no new 16/16 execution claim is inferred from this native receipt.

## Native qualification

| Suite | Debug | Release |
| --- | ---: | ---: |
| JF4.1 ergonomics | 12/12 | 12/12 |
| JF3.3 structural proof | 10/10 | 10/10 |
| JF3.2 reverse matrix | 4/4 | 4/4 |
| JF3.1 schema bridge | 11/11 | 11/11 |
| JF2.2 value fidelity | 14/14 | 14/14 |
| Total | 51/51 | 51/51 |

102 method executions; both evaluated manifests pass. All ten test
logs have matching unique started and passed names and passing totals.
No observed compiler warning, skip, known issue or failed method.
The initial builds take 19.83 s Debug and 27.47 s Release; JF4.1
test execution 2.685 s Debug and 0.286 s Release. Incidental log
timings only, not controlled performance qualification.

All eight portable-policy methods pass in both configurations:
validation before foreign construction; complete/invalid/malformed
import; typed ordering and roundtrip; rejection of valid-but-changed
typed values; typed encode validation; schema-valid but lossy value;
cumulative work/retention N/N-1; cancellation after typed callback.
All four actual Apple public-API methods pass. These methods exercise
public imports inside the candidate package, not a separate external
consumer build.

## New native evidence

The actual JF4SearchArguments generation schema preserves the guided
description, inclusive integer bounds, enum order, array length,
required names, nonnullable optional note and closed object. Two
typed source/returned rows per mode (four total) are exactly equal:
absent note remains absent; present string note remains present.
The actual public JSON and completed-GeneratedContent decode paths
and typed encode assertions pass. Canonical validation remains
authoritative before the typed initializer.

Each of the same six invalid cases rejects on four input routes
(decodeJSON, decodeContent, export, import). Mutated typed range on
encodeTyped and nested required on dslExport add two receipts.
All 26 per mode / 52 total native diagnostics now match exactly one
expected tuple of keyword, keywordLocation, instanceLocation.

| Case | Keyword | Keyword location | Instance location |
| --- | --- | --- | --- |
| null-note | type | /properties/note/type | /note |
| range | maximum | /properties/limit/maximum | /limit |
| enum | enum | /properties/sort/enum | /sort |
| count | minItems | /properties/tags/minItems | /tags |
| required | required | /required | empty (root) |
| unknown | empty (false subschema) | /additionalProperties | /extra |
| nested-required | required | /properties/child/required | /child |

This confirms the source-derived correction in the preceding review.
No keyword is invented for the false Boolean subschema, and a blank
keyword alone is not accepted as a wildcard. Full diagnostic
completeness is asserted by the native tests.

Nested DSL schema preparation preserves canonical Root and inline Child.
Actual framework projection uses the previously qualified root-local
$defs/Child and pure $ref at /properties/child; one structural rewrite,
no annotation additions. The actual exported schema equals the same
mode's JF3.2 raw nested schema. The instance {"child":{"name":"Swift"}}
roundtrips exactly, and the missing nested required value rejects.
The DSL remains an independent product.

Both 9007199254740992 and 9007199254740993 are valid against the exact
bounded integer schema. The former roundtrips; the latter rejects with
changedValue. Successful schema preparation does not waive exact
instance conversion. The JF2 borrowed-scope refactor retains the
previous contract; the new typed composed N/N-1 tests pass.

## Independent reconciliation

Verified locally available JF4.1a, JF3.3a and JF3.2 receipt-verifier
Git blobs and the exact reverse fixture hash before replay. Replay
all three verifiers on both actual native logs and reconcile their
results against ergonomics.json, structural-matrix.json and
reverse-regressions.json. All rows and mode stability checks agree.
Reconcile JF3.1 and JF2.2 raw receipt lines with their respective
stored receipts and unique passing test names independently, including
exact Decimal/scalar/type-aware source/raw comparisons, completeness
and dispositions for all 104 value observations, 28 guide rows and
two typed optionality observations. Reject duplicate keys and nonfinite
JSON constants. No historical verifier execution is claimed for
JF3.1 or JF2.2 in this review.

Compare the actual previously qualified JF3.3a archive
jf33-u7mkc3bi.tar.gz (SHA-256
8d923f21c96cf2cd6aeee9324624bd1e9cee01ffc7802aeaac69855f3780ee4f).
All measured raw schemas, instance verdicts, policy outcomes and
structural/annotation evidence agree under the existing stability
contract; all JF3.1 schemas and JF2.2 value/guide/typed semantic
receipts agree. Each mode retains 13 exact, 14 annotation-opt-in
and 18 structural accepted schemas out of 19. Each mode retains
23 accepted value exports, 15 changedValue, 14 incompleteContent.
No observed regression in the fixed measured corpus.

Independent jsonschema 4.26.0 Draft202012Validator replays 550 prior
matrix verdicts (124 canonical, 124 raw, 90 exact, 96 annotation,
116 structural) and 32 new fixture/schema evaluations: 8 typed
source/returned, 12 typed-invalid fixture evaluations, 8 DSL
canonical/projected valid and invalid evaluations, 4 canonical
large-integer endpoint evaluations. All 582 agree. The six new
negative fixtures per mode match the actual byte-verified Swift
test literals; each has one independent assertion failure.
Numbers are parsed as Decimal, with integral values converted
exactly to Python int for integer-type checks, not to binary float.
These independent evaluations are supplemental, not additional
Swift test methods, nor a proof of arbitrary JSON Schema equivalence.

## Packaging and decision

Independently compare evaluated manifests: 13 -> 14 products,
31 -> 33 targets, zero external dependencies, macOS 15/iOS 18
deployment floors unchanged. All existing products, targets and
other manifest fields remain unchanged. Only the disposable
JSONFoundationModels library (JSON and JSONSchema dependencies)
and its test target (also JSONSchemaDSL and copied ReverseMatrix.json)
are added. The root manifest remains unchanged.

JF4.1a completes the focused native typed-ergonomics milestone.
Nested reference-bearing macro schema import, actor transfer and
external standalone consumer qualification remain open. No actual
language-model generation or tool execution qualified; no universal
schema-equivalence, framework-hidden-state fidelity or process
memory bound claim. Next JF4.2: deliberately qualify nested
Generable type import and an independent public consumer, keeping
original schema authority and exact typed roundtrip guards. Then
review JF5 product admission, including existing native, floor,
documentation, Linux and WASI gates, API inventory and package
isolation. MF1/MF2 remain separate integration work.

This review adds documentation only. Reproduce the successful
candidate at the exact source SHA above, not the later review tip.
No merge, tag, release, public product admission or hosted CI launch.
