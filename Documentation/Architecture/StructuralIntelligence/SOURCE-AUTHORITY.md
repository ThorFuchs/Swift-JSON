# N0 source authority

## Published authority — 16 October 2026

The published [1.6.0 source](https://github.com/ThorFuchs/Swift-JSON/tree/1.6.0)
is `f975ac1c5a18af9b422db0994cbc551fd37eee2f`, tree
`31de4dcd167c03af721c1b18594490e051a8a695`. It contains released N1
JSONNavigation: eight libraries plus `swift-json`, eight DocC catalogs, no external
root dependencies, Swift tools/compiler 6.4+, language mode 6 and Apple OS/SDK 27+.
[Release qualification](../../Qualification/Release1.6.0.md) distinguishes published
availability from the preserved prepublication receipts.

The N0 research/reconnaissance record and semantic delegates below remain unchanged
historical source editions. In particular, their experimental/no-public-product
and latest-release statements apply to their recorded stage, not to 1.6.0.
The [N1 promotion record](N1Promotion.md) likewise preserves its original decisions.

### Unreleased N2 source scope

This source includes opt-in JSONInspection alongside JSONNavigation: nine libraries
plus the CLI and nine source DocC catalogs. Inspection depends only on JSON and
JSONNavigation; its 44 authored declarations are separate from the unchanged
56-declaration Navigation surface. The [Inspection contract](Inspection.md) defines
observed-only row/column evidence, full-source admission and one cumulative ledger.
This source availability does not alter the published 1.6.0 tag, assets or
eight-library/eight-catalog release scope. No later release is claimed.

The N2 promotion and NAV6/NAV7 records preserve their original candidate-stage
source and decisions. The table below is the dated 16 October observation, including
original #46; it does not classify this source as awaiting N2 API acceptance.
N3 snapshots, private P1 and the other proposals retain their separate gates.

### Unmerged candidates observed on 16 October 2026

These are source-bound draft proposals, not accepted, merged or released additions.
A technical pass on a candidate does not approve its API or close another gate.

| Candidate | Captured head | Boundary |
| --- | --- | --- |
| [N2 inspection #46](https://github.com/ThorFuchs/Swift-JSON/pull/46) | `258a23eb01cd0cbcc702c0a2550d35ff05f4881d` | Separate Inspection owner/API decision; independent of composition timing |
| [N3 snapshots #47](https://github.com/ThorFuchs/Swift-JSON/pull/47) | `db991c51dc15e8e47a0356a66ae7e03f4ed51b98` | Depends on #46; public promotion separate; G4 has zero timed workloads and remains held |
| [Private P1 #48](https://github.com/ThorFuchs/Swift-JSON/pull/48) | `bda8aef4c8347ac4f6f2d7264c4be244367e4869` | Depends on #47; package-only proof, no public product or E11 promotion |
| [Composition accounting #36](https://github.com/ThorFuchs/Swift-JSON/pull/36) | `3571cb0d8aea5cf2c4ba454c5eab02ea2ce23f11` | Per-document admission/cumulative totals and 50-work/424-logical-byte final report costs are not released behavior; controlled comparison pending |
| [Root reuse #40](https://github.com/ThorFuchs/Swift-JSON/pull/40) | `95267eea3d4ab3c3c1553d4afcf89806fde8788e` | Distinct admission proposal; does not contain #36 accounting |
| [Value/schema DSL #31](https://github.com/ThorFuchs/Swift-JSON/pull/31) | `64264218dc0073a5738ab557bfa25b3bb9f6fa7a` | Older-base proposal; trusted authoring staging is distinct from checked finalization |
| [Deployment #49](https://github.com/ThorFuchs/Swift-JSON/pull/49) | `5617483ae222c6823d0231ac0f984b0a863e789b` | Lower floors are not released; exact macOS 26.2 evidence blocked and changed-schema controlled measurement pending |

The original [#41](https://github.com/ThorFuchs/Swift-JSON/pull/41),
[#42](https://github.com/ThorFuchs/Swift-JSON/pull/42) and
[#43](https://github.com/ThorFuchs/Swift-JSON/pull/43) stack remains historical;
its receipts are not silently rebound to #46–#48. The separate runtime-handle
alternative retains 13 full-Debug streaming deadline issues and withheld full lanes;
narrow probes do not replace those failures or authorize a static-to-runtime API change.

The [composition guide](../../../Sources/JSON/Documentation.docc/Composition.md)
records the source-bound Swift 6.4 borrowing/compiler limitation. A compiler crash
is not expected rejection or a universal non-escape proof. Logical accounting is
not RSS, ordinary schema invalidity is not an operational error, and corpus policy
exclusions are not evaluated successes. No approval or held-gate promotion follows
from this documentary map. E11 public projection and E12 framing remain deferred.

The research baseline is `507dbf9ad4b545a5d60d7d6acf6b814795ec3099`.
The reconciled implementation base is main
`037e735dc6224789e4d04d2c18d15b8d27440198`, tree
`5c53288c50ae8a1999d889f0a8c4f0cb14dca913`. Origin was fetched before edits.
PR #33 forward-ports maintenance repairs after the research snapshot; no reset,
old scaffold or historical navigation implementation is used.

At reconnaissance all nine main checks passed: Native CI 38735450692 and Linux
CI 38735450703. Those are baseline results, not qualification of this increment.
The latest published release observed was 1.5.0; main's `1.6.0-dev` CLI metadata
does not establish a publication. Draft #31 owns opt-in value/schema DSLs, and a
separate schema-example worktree has active edits. Neither is imported or modified.
The primary checkout stays on main; implementation uses
`codex/structural-navigation-n0-n1` in an isolated existing feature worktree.

## Semantic delegates and owners

Paths below identify code ownership, not a second resolver API. All new owned
phases use the **same** read-scope state and its noncopyable core-domain meter.

| New operation or fact | Existing authority / owner | Budget boundary |
| --- | --- | --- |
| Captured canonical source | [JSONDocument](../../../Sources/JSON/Document/JSONDocument.swift) and JSON | Constructor captures trusted immutable values; each invocation admits its full root/source/map |
| Admission and source lifetime | [JSONReadScope.init/check/complete/invalidate](../../../Sources/JSON/Reading/JSONReadScope.swift) | Exactly one root/source admission and terminal ledger; complete releases scope ownership |
| Exact keys / insertion order | [JSONObject](../../../Sources/JSON/Value/JSONObject.swift), JSONKey | Visit ordinal members; no String sort, dictionary conversion or duplicate index |
| Typed physical selection | JSONReadScope.select inside run | Strict key/index parent checks and existing JSONAccessFailure; no Pointer-token reinterpretation |
| Requested scope-key admission | JSONAdmission.text(key: true), as in JSONReadCursor's JSONKey subscript | Caller query keys consume the same cumulative key/text capacities before path staging or lookup |
| Typed path staging | JSONReadScope.append and JSONReadPath | Existing pointerTokens/pointerBytes/diagnosticBytes checks, path copy/UTF-8 work and live refunds |
| Meter/operational failure | [JSONWorkMeter](../../../Sources/JSON/Limits/JSONWorkMeter.swift), JSONCodingState | Shared cumulative work, capacity/retention, cancellation and terminal health; never reset |
| DFS child enumeration | JSON array indices / JSONObject ordinal collection access | New iterative frontier; each node/edge/frame/callback handoff checked and charged |
| Overlap / unique-path comparison | [JSONComparison.textEquals](../../../Sources/JSON/Value/JSONComparison.swift) + typed integer components | New metered component/prefix loops; no Set<String>, unmetered path hash, or value-based dedup |
| Decimal and text values given to visitor | JSON/JSONNumber/JSONKey | Original source value; no conversion or re-admission per hit |
| Pointer serialization / differential oracle | [JSONPointer](../../../Sources/JSON/Pointer/JSONPointer.swift) | Explicit separate caller operation; walker never calls a public helper to start a fresh owned quota |
| Native projection / presence oracle | [JSONReadCursor](../../../Sources/JSON/Reading/JSONReadCursor.swift), JSONPresence | Compiler/behavior witnesses only; no cursor is a traversal result or task argument |
| Optional value spans | [JSONSourceMap.span](../../../Sources/JSON/Document/JSONSourceMap.swift) | Same meter, only coherent captured maps; replacingRoot supplies no map |
| Successful resource reporting | JSONOperationReport / JSONOperationStatistics | Existing accountingVersion/domain/counts/peak convention; no successful report after error |
| Mutations | JSONPatch / JSONMergePatch | Unchanged and outside N1; traversal has no edits or writable value view |

`JSONReadScope` and `JSONWorkMeter` are already `package`, so no core SPI,
public meter protocol or package helper change is needed. Actual target compilation
and the inclusive work-budget tests prove this access/composition boundary. The
public N0 consumer compiled and ran seven core-only witnesses before N1: root versus
empty key, typed key/index, exact Unicode keys, presence, native projection and
invalid array-index rejection. Compiler receipts retain the actual source/toolchain.

## Collision and dialect reconciliation

| Historical/proposed surface | Disposition |
| --- | --- |
| JSONCursor / JSONNavigationCursor | Rejected: guarded core read cursor already owns synchronous one-node access |
| JSONNodePath / dotted flattening | Rejected: canonical components are JSONLocationComponent; root [] and empty key differ |
| New JSON. facade / JSONPath grammar | Rejected: neither necessary nor an RFC 9535 implementation |
| JSONFilterRuntime paths/getpath/walk | Existing private query dialect can accept negative indices and language-level missing behavior; not a strict typed scope delegate |
| JSONHTML exact paths and previews | Existing rendering authority; no renderer import/edit or duplicate preview logic |
| JSONTraversal and metadata names | New target-qualified names; no existing core/sibling definition found at the recorded base |
| Sketch BFS / inspection / snapshots / projections | Deferred; no reserved BFS label, parallel model, digest or classifier added |

The packet's declarations were illustrative. N1 returns existing
JSONOperationReport envelopes, passes the source value separately to a synchronous
visitor, and keeps records metadata-only. Its module is experimental; **no public
SwiftPM product is added**. API shape and all remaining release gates are recorded
in [API-DECISIONS](API-DECISIONS.md).
