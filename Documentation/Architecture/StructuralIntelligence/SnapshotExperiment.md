# NAV5 I0 — Complete source-attached snapshot

Status: accepted design for a package-only experiment; implementation remains
conditional on the N2 public surface freeze and repeated owned-reducer proof.
Base: frozen N2 API candidate 2e952c00ea2f4c2a943032a54f3a3fd85b1b96fb,
with the subsequent generated-identity correction replayed separately. Both descend
from 462f3ea and main 7d72c88. No public N3 API,
new product, persistence, actor, projection, index-by-path or traversal option.

## Representation and invariants

One immutable Sendable snapshot holds one JSONDocument plus compact records.
Each record contains ordinal, optional parent, optional exact edge component,
kind, depth, immediate child count and a finalized half-open subtree end. No JSON
subtree, absolute path, span, source bytes or label is stored per record. Ordinals
are snapshot-local inputs to instance methods; no detached node/handle type exists
and no API accepts a replacement document. Metadata lookup is bounds checked.

The sole builder calls inspectOwned with its default complete physical root and
no options or callback supplied by the caller. Before a depth-d hit, close stack
entries while count > d, setting their ends to the next ordinal. The remaining
top is the parent. Append the record and ordinal after charging storage. The
root has depth 0 and nil parent/component. On finish, require complete summary,
visited/emitted == records.count, and close every remaining frame at total count.
No failed or cancelled finish returns an artifact. Empty/scalar roots yield one
record. Metadata and parent links are immutable after initialization.

## One original admission and source ownership transfer

Existing JSONReadScope.complete refunds input/source ownership unconditionally.
Returning a source-attached snapshot without extending that accounting would
underreport live output; readmitting the document would duplicate work/quotas.
Use a narrowly package-scoped, one-shot transferDocumentOwnership capability:
check original scope health/owner and charge one work step, then designate the
already-admitted source bytes as result-owned. At complete, refund paths and
transient invocation storage as before, but retain the original rootBytes in the
same report. The context method remains mutating and returns only the canonical
immutable JSONDocument, never scope/state/meter/cursor. No new admission or ledger.

Default false preserves every existing read/visit/collect/N2 completion statistic.
Only the N3 finish path invokes transfer, after complete structural finalization.
Invalidation always clears scope document/state; returned source is an ordinary
immutable alias. Failure after transfer still returns no report/artifact, and
scope teardown releases its references. Tests must prove exactly one admitted
node/source-map count, captured source cost retained once, N1/N2 parity, and source
release/terminal behavior. If this narrow package helper cannot preserve existing
semantics or the compiler proof, do not implement N3 with a weaker meter.

## Logical overlay v1 and complexity

Declare 96 bytes per record (seven scalar/optional/enum slots plus component
storage policy), plus exact UTF-8 key alias bytes, 16 per open ordinal frame and
128 fixed snapshot/report bytes. Reserve each before append. Source ownership is
the original read-scope admission cost, transferred once rather than recomputed.
All record finalizations charge work and check cancellation; pop/refund a frame
only after removal. These versioned logical weights are policy rather than Swift
MemoryLayout, allocator behavior or RSS. No claimed hard physical-memory bound.

Record retention O(nodes + key bytes), frontier O(depth). The existing walker
constructs absolute hit paths: build work may be O(sum of depths), plus admission,
key processing and finalization. Do not claim linear total construction or a speedup.

## Separate bounded lookup

Snapshot-scoped ordinal methods reject negative/out-of-range indices. Each path,
value or span lookup starts an explicitly separate finite core operation, admits
the captured immutable document using JSONReadScope, charges parent-chain work and
temporary/output path retention, then delegates exact selection/source-map lookup
to the core on that original scope. No lookup runs during build. Values are returned
under existing read-value semantics; a returned JSON alias is caller value storage,
not a second serialized graph. Path result ownership remains charged at handoff.
No incomplete snapshot, missing-as-null or negative-query API is available.

## Proof gate

Keep N1's 56 public declarations and unmodified 2-positive/20-negative full-codegen
matrix. Preserve I01-I17. Add S01-S24 structural, exact-key/number, source attachment,
quota/cancel and generated depth/breadth tests; run Debug/Release, strict, sanitizers
and qualified platform lanes. Actual source-bound results decide qualification;
this ADR alone qualifies no executable behavior.

The builder defaults to 100,000 records inclusive. Negative configuration fails
before source admission; zero fails at the physical root with a typed capacity
error. Invalid lookup ordinals precede source admission. Finalized subtree ends
are nonoptional Int: no public or package result can carry an unfinished range.
