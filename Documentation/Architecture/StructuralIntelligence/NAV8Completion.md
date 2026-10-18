# Navigation V1 completion on development main

NAV8 starts at development main `e0a4185477047d92e4b8e1a2b56303848472d9be`
on `feature/json-navigation-v1-completion`, proposed in
[PR #59](https://github.com/ThorFuchs/Swift-JSON/pull/59). Published 1.6.1 at
`e431f157ececc0cf3d061192420b0e36a9062f83` remains immutable and has no Inspection.
This is unreleased 1.7.0-dev source, with the same ten products/nine libraries.
No version/tag/publication or sibling feature is part of this integration.

## Source reconciliation and semantic owners

N1 walker/reducer and N2 shape source blobs are identical on starting main and
NAV7's final P1 donor. They are retained rather than replayed. Only the missing
N3 increment (`db991c51dc15e8e47a0356a66ae7e03f4ed51b98` relative to
`258a23eb01cd0cbcc702c0a2550d35ff05f4881d`) and P1 increment
(`bda8aef4c8347ac4f6f2d7264c4be244367e4869` relative to `db991c5`) are adapted.
Original NAV7 stacked drafts remain evidence, not integration bases.

| Operation | Sole existing semantic authority | Budget boundary |
| --- | --- | --- |
| Snapshot build | Navigation's exclusive mutating-inout owned reducer, original read scope/admission | One full physical-root invocation; finalize all ranges before one-shot source transfer |
| Tree build | Same owned executor plus sealed snapshot topology | New full-source admission; charge retained snapshot alias and view; no new DOM |
| Tree metadata | Snapshot's checked `record(at:)` after selected-interval bounds | Fixed trusted metadata read; no owned growth/report |
| Tree child/subtree catalogue | Same owned executor, finalized physical ranges | Separate whole-source invocation, charged output slots; cap refusal throws |
| Tree location/value/span | Exactly one existing snapshot lookup | Separate full-source admission; original typed selection/map; no hidden nested operation |
| Sparse table build | Same exclusive reducer and original exact key comparison | One complete row pass and cumulative ledger including finalization/source transfer |
| Sparse cell | Original core read scope, selection, object lookup/scalar comparison | New explicit full-source admission; no construction remainder or null-on-error |

The two package-only transfer hooks extend completion accounting only for a
source-owning result. Ordinary core read/visit/collect/N2 completion does not
designate transfer and retains its original refunds/statistics. No borrowed
callback, escaped cursor, second meter, normalized key/value or new concurrency
authority is introduced. The historical Swift 6.4 nonmutating-borrow codegen bug
is not declared fixed; full positive/negative exclusive-inout codegen remains.

## Deliberate public P1 decision

Promote the checked `JSONTreeProjection` factory, immutable snapshot/root/end,
metadata/catalogue and delegated location/value/span methods. Promote the checked
`JSONSparseTableProjection` factory, immutable source/selection/row count/columns/
traversal and tri-state `cell` lookup. Expose typed `JSONProjectionFailure` cases.
Keep initializers fileprivate, sparse offsets/member references package-only,
and accounting/reducers internal. This is a small surface within JSONInspection,
with no extra product, umbrella facade, setter or rival path model.

Bare Int positions are intentionally consistent with N3's existing snapshot-local
ordinal contract. A captured immutable owner enforces source attachment and range;
it cannot diagnose accidental reuse of an in-range integer from another snapshot.
There is no detached identity or public replacement-source argument. A stronger
token type is deferred rather than implying provenance that this API cannot prove.

All table rows must be objects. Prefix evidence does not certify a suffix. Empty
arrays are 0-by-0; empty objects remain rows. Columns retain first-seen exact scalar
identity; missing/null/value stay distinct. Row admission is complete even when
descendant traversal coverage is restricted. Constructors never publish partial
artifacts after wrong kind, missing target, quota, cancellation or terminal error.

No Navigation or original N2 declaration changes. N3 preserves its original 23
public additions; P1's precise promoted declaration fragments are audited from
the actual Swift 6.4 compiler graph. Public usage and costs appear in the
[compiled guide](../../../Sources/JSONInspection/Documentation.docc/StructuralProjections.md)
and [independent SwiftPM consumer](../../../Tools/ProjectionQualification).

## Qualification and review boundary

Original I01–I17, S01–S24/promotion, P01–P32 and pinned independent fixtures remain.
The public consumer adds 16 named scenarios each in Debug/Release/ASan, three
compiled guide blocks/configuration and 18 ordinary external full-codegen
rejections. Private compiler cases are retained, replacing the now-obsolete
public-type-invisibility negatives with sparse-storage/accounting/reducer
invisibility negatives. No former invariant or behavior assertion is removed.
The receipt harness rejects missing/duplicate/renamed cases, zero counters,
incidental diagnostics, compiler crashes and incomplete command inventories.

Current discovery is 76 Inspection functions, 779 native/763 Linux/675 WASI root
functions, unchanged 325/288 parameter invocations and 51/50 shared functions.
All 49 core metric witnesses and 126 maintenance identities remain mandatory.
These are required inventories, not claims of unexecuted qualification. Final
source-bound native/safety/docs/Git-free reproduction, both Linux architectures,
full Node WASI, limited direct Inspection WasmKit, Apple SDK compile/link,
external consumer and source/API/protection receipts accompany this PR.
SDK compilation is not mobile runtime; limited WasmKit is not full-root support.

The source/public API review compares canonical donor algorithms, final compiler
fragments, exact fixtures and independent public consumers. Human owner review
and a fresh protected-main/check/thread lease remain prerequisites to merge;
historical green receipts cannot qualify this combined source.

## Resource and performance disposition

Published 49 profiles/metrics remain unchanged. Additional finite bounds and
logical weights are those in the compiled guide and original P1 proof record.
Every reservation precedes growth and every owned loop is cumulative/cancellable.
Source aliases incur logical ownership even when physical COW shares storage.
No bound on caller instructions, physical heap, RSS or allocator behavior follows.

G4 controlled performance remains **HOLD**, with zero accepted timing samples.
The owner explicitly permits this correctness/platform-qualified integration
with that HOLD and **no performance claims**. G4 blocks speed claims, not this
specific guarded merge; other semantic/API/compiler/platform/protection gates
are unchanged. There is no benchmark PASS, shifted threshold or inferred speedup.
Snapshot build remains depth-sensitive; repeated lookups re-admit the full source;
linear first-seen column scans may be quadratic. No EngineBench claim is made.

Persistence, global/durable indexes, graph/store/set/matrix, retrieval, BFS,
JSONPath/query grammar, HTML/CLI additions and unrelated DSL/composition/developer
kit work remain out of this completion train.
