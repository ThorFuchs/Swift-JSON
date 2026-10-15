# N0 source authority

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
