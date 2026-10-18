# NAV7 P1-A private projection proof

Status: isolated package-only experiment, no new target or product, no merge/
release/public-API approval. JSONInspection hosts the proof beside its immutable
snapshot. A separate JSONProjections module would add an interface solely for
private reuse; this wave needs no additional module boundary. N1/N2/N3 code and
public declarations remain unchanged. Exact compiled declarations/proofs are
recorded in the NAV7 return, not inferred from this design note.

## Source and API

`JSONTreeProjection.build(snapshot:rootOrdinal:limits:)` accepts a complete sealed
snapshot and returns a view of an original physical interval. It stores that
snapshot, selected root ordinal and finalized end only. Root metadata keeps its
original parent/depth; no synthetic root/value/DOM is constructed. Ordinary fixed
`record(at:)` reads have no new owned growth/report. `children` and `subtreeOrdinals`
are new bounded catalogue operations with an inclusive100000-record default; they
reject insufficient caps and never publish truncation. Direct children jump
finalized subtree ends. `location`, `value`, `sourceSpan` validate local view bounds,
then delegate exactly once to the existing independent N3 operation.

Every tree build/catalogue invocation uses the established N1 exclusive reducer,
one original read scope and complete captured-source admission. Root-only traversal
reuses already-proven complete snapshot topology; it does not rebuild the tree or
continue the completed snapshot build's meter. Snapshot/row ordinals are local
positions, not portable identifiers. A bare Int can be reused as a position in
another source, but this API accepts no replacement source or detached node handle.

`JSONSparseTableProjection.build(document:at:limits:maximumRows:maximumColumns:
maximumPresentCells:)` selects one existing array. Every row must be object or a
`nonObjectRow(at:kind:)` error identifies the exact physical row. Full source
admission precedes success, including unselected input. Empty0x0 is explicitly
allowed; `[{},{}]` is2x0. Positive N2 prefix evidence cannot admit an unseen suffix.
Rows remain original array indices, including equal rows. JSONKey columns follow
first encounter in source member order. Sparse member/column ordinal references
and nondecreasing row offsets retain empty rows without a dense null grid.
P27's offsets can be equal for empty rows; demanding strict increase would
contradict P18. Each nonempty row advances the offset.

`cell(row:column:limits:)` is a separate original-source-admitted read operation.
It charges row-reference scans and delegates key/presence to core JSONObject
lookup/comparison. It returns canonical JSONPresence absent/null/value, preserves
arrays/objects/exact numbers/lexemes, and throws for bad bounds or inconsistent
metadata. It stores no per-cell JSON/path/span, normalizes no key and converts no
number. Wrong type, missing selection, nonobject, operational failure and null
remain distinct. The captured immutable source cannot be rebound.

## Finite accounting policy v1

All49 core profiles/caps are unchanged. Additional inclusive defaults are100000
rows,10000 columns and1000000 present members; negative configuration fails before
admission. Tree catalogue default is100000 records. Arithmetic products and count
increments are checked before growth. Each scan, key comparison, finalization
step, returned slot and key alias is charged on the original invocation ledger.
Unexpected capacity/resource/cancellation failures throw without successful output.

Logical output overlays, plus core source/selection costs:

- Tree view:64 descriptor +128 snapshot header +96 per retained record alias and
  exact UTF8 edge-key bytes. COW sharing does not erase logical alias ownership.
- Catalogue:32 header +8 per ordinal;96 temporary record bytes are refunded.
- Table:256 summary +8 per offset +64 per column plus exact UTF8 key bytes +16 per
  present member reference. A complete source ownership transfer occurs once.

These are declared logical weights, not MemoryLayout, allocation bytes or RSS.
Sparse slots are O(rows+columns+present members); exact linear column scans may
be quadratic. Tree build/lookup costs still include full source/map admission;
N1/N3 path reconstruction remains depth-sensitive. No time, RSS, throughput or
scalability improvement is claimed. G4 remains HOLD with zero timed workloads.

## Proof and boundaries

32 Swift Testing identities cover all P01–P32 obligations and independent packet
oracles, exact keys/pointers/presence, deep16/64/256 and wide1024 trees, sparse
1/16/1024/10000 rows, core differentials, inclusive caps/work/retention, checked
overflow,16 concurrent mixed-success/failure views and cells, actual source
retention, legacy statistics parity, source replacement and post-finalization
terminal priority. Cancellation is exercised inside long key scans, offset
finalization and after source transfer; scope root/state invalidation is observed.
No deallocation of caller aliases or process-memory bound is claimed.

The compiler qualifier requires ordinary primary diagnostics in Debug/Release:
external packages cannot name the package types; even same-package code cannot
forge a tree via its file-private initializer or mutate table source/columns.
Original ownership2-positive/20-negative and public Snapshot18-negative probes
remain separate. The full supported native/safety/docs/portable/SDK/archive lanes
must bind to final source. SDK builds do not establish device/simulator runtime.
Public projection surfaces, batching, persistence, durable identity, query DSL,
BFS/matrix/graph/retrieval, mutation, renderer/CLI integration and EngineBench are
future owner gates. No release version is assigned by this prototype.
