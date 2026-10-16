# NAV6 snapshot public candidate

This isolated draft descends from original package-only N3 872b5fd and reconciled
N2 37d84e8 (current main c79d48c). It proposes a public facade inside the existing
JSONInspection product; it creates no additional SwiftPM product. No merge or
release is authorized. Original #41/#42 evidence identities remain unchanged.

## Accepted interface

Keep JSONStructuralSnapshotBuilder(document:limits:), build(maximumRecords:),
JSONStructuralSnapshot.document/recordCount, record(at:), location/value/sourceSpan
(for:limits:), JSONStructuralRecord and the two existing typed failure cases.
There are no public record/snapshot initializers or setters. The implementation
remains the original package/private algorithm; no scope, meter, reducer, observer,
borrowed cursor or source-rebinding capability becomes public.

An ordinal is an integer position local to the snapshot method being called,
never a detached node identity. Two sources may both have position 1 with different
values; explicitly selecting each snapshot selects its own original source. No
method accepts a record, handle or replacement document. The immutable document
attachment keeps old snapshots coherent after other values are patched/replaced.

## Ownership and errors

Build performs complete physical preorder under Navigation’s one original scope
and meter. Source ownership transfers once after finalized half-open subtree ends;
ordinary read/visit/collect/inspectArray never transfer and preserve refunds. All
three counters (record count, open depth, subtree end) are bounded by arrays and
admitted nodes. Parent assignment uses existing indices; end equals records.count;
ordinal < maximumRecords is checked before append, so count can at most Int.max
without an increment from Int.max. No end/count arithmetic adds unchecked user
integers. Core retention/work increments use checked UInt64 accounting. Supported
wasm32 capacities retain the existing admission policy; no new narrowing occurs.

Negative maximumRecords precedes admission; zero refuses the real root. No quota,
cancellation, incomplete traversal or finalization failure returns an artifact.
The exclusive context latches owned failures, including second transfer. A direct
package read-scope transfer guard is an implementation primitive; public N3
construction reaches it only through that guarded context. Post-transfer caller
errors and quota/cancellation still invalidate the scope and publish no result.

## Costs and qualification

Overlay v1 remains 128 fixed logical bytes, 96 per record, edge-key UTF-8 bytes,
16 per open frame, plus original source/path costs. Compact record retention is
O(nodes + key bytes), while existing walker full-path storage and copying remain
depth-sensitive. record(at:) is O(1) trusted-memory metadata access. Each location,
value or span lookup is an explicitly separate finite operation with full source
re-admission and core prefix/path/selection work. K lookups pay K admissions. These
are semantic costs, not new performance claims; logical bytes are not heap or RSS.

All I01–I17 and S01–S24 identities remain. Three new proofs add an independent
28-record oracle, post-transfer terminal/lifetime cases and concurrent lookup
health isolation. Exact discovery rises to 747 native / 731 Linux / 643 WASI,
with 325/288 parameter invocations unchanged, 44 Inspection functions and 50/49
shared-state functions. Preserve 49 cap probes, 126 maintenance identities,
2-positive/20-negative full codegen, composition and schema-example lanes. Public
qualification adds fourteen external cases, three executable DocC examples and
18 external full-codegen negative outcomes. Requirements become passes only when
actual source-bound receipts say so; SDK compilation is not device execution.

Read the [compiled guide](../../../Sources/JSONInspection/Documentation.docc/StructuralSnapshots.md)
and [independent consumer](../../../Tools/SnapshotQualification).
