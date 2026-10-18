# Use complete source-attached structural projections

Choose core Pointer/read APIs for one value, Navigation for many-node traversal,
and Inspection for observed evidence or complete structural metadata. These
projections are opt-in through `JSONInspection` on unreleased 1.7.0-dev main;
published 1.6.1 does not contain them. They are not schema validation, a new JSON
model or a query language.

## Select a physical tree

Build a complete snapshot, then capture one checked physical interval. Metadata
keeps the original parent/depth and insertion/index order. Scalars and empty
containers each have one node. Returned catalogues are complete or throw when
their inclusive cap is insufficient.

```swift
let document = JSONDocument(root: try JSON.parse(#"{"items":[null,{"0":9007199254740993}]}"#))
let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
let view = try JSONTreeProjection.build(snapshot: snapshot, rootOrdinal: 1).result
let children = try view.children(of: 1, maximumRecords: 2)
precondition(children.result == [2, 3])
let exactPath = try view.location(for: 4).result
precondition(exactPath == [.key("items"), .index(1), .key("0")])
let exact = try view.value(for: 4).result.numberValue!.integer(as: UInt64.self)
precondition(exact == 9_007_199_254_740_993)
```

Ordinals are trusted integer positions local to the captured snapshot. An integer
accidentally copied from another snapshot cannot be recognized as foreign if it
is in range. Neither records nor ordinals are durable identity. Constructors are
inaccessible; a view cannot attach a replacement document or forge its interval.
`record(at:)` reads fixed metadata without owned growth. Each catalogue, location,
value or span lookup is an explicitly separate finite operation that re-admits
the entire captured source. K lookups pay K admissions. Full value/path lookup is
not constant-time; spans are optional coherent original mappings only.

## Admit every row before returning a sparse table

The complete selected array must contain only objects, including its final row.
Rows keep original physical positions; columns follow first-seen exact JSONKey
order. Empty `[]` is 0-by-0; `[{},{}]` is 2-by-0. A sparse table stores original
member positions internally rather than a dense null grid or another JSON tree.
Cell lookup preserves three-state presence and exact decimals/scalar keys.

```swift
let source = JSONDocument(root: try JSON.parse(#"[{"n":9007199254740993,"é":null},{"e\u0301":0.0100},{}]"#))
let report = try JSONSparseTableProjection.build(document: source)
let table = report.result
precondition(table.rowCount == 3)
precondition(table.columns == [JSONKey("n"), JSONKey("é"), JSONKey("e\u{301}")])
let explicitNull = try table.cell(row: 0, column: 1).result
let missing = try table.cell(row: 2, column: 0).result
precondition(explicitNull == .null && missing == .absent)
if case .value(let value) = try table.cell(row: 0, column: 0).result {
    let integer = try value.numberValue!.integer(as: UInt64.self)
    precondition(integer == 9_007_199_254_740_993)
} else { preconditionFailure("Expected an exact present integer") }
precondition(report.statistics[.workUnits] > 0)
```

`rowCount` certifies complete row admission by this constructor. The `traversal`
summary separately describes walker coverage; descendants may be restricted.
Bounds errors never return absent/null. Negative settings fail before admission;
missing/wrong-kind selection, nonobject rows, quota exhaustion and cancellation
throw without a usable partial table. Existing prefix evidence cannot admit a
complete table or prove a numeric matrix/schema.

```swift
let source = JSONDocument(root: try JSON.parse("[{},{},false]"))
let prefix = try JSONShapeInspector(document: source)
    .inspectArray(sampling: .prefix(maximumRows: 2)).result
precondition(prefix.observedAllObjects == true)
do {
    _ = try JSONSparseTableProjection.build(document: source)
    preconditionFailure("A prefix cannot certify the unexamined final row")
} catch JSONProjectionFailure.nonObjectRow(let location, let kind) {
    precondition(location == [.index(2)] && kind == .boolean)
}
```

## Finite ownership and costs

Every constructor uses one original Navigation-owned reducer/read scope/meter,
including full source admission, exact comparisons, growth, finalization and
one-shot source transfer. No read cursor escapes. Separate public lookup calls
have separate explicit finite limits, not the construction ledger's remainder.
Returned immutable values may be shared; each concurrent invocation owns its
mutable state. Caller instructions and storage remain caller work.

Defaults are inclusive and finite: 100,000 snapshot/catalogue records, 100,000
table rows, 10,000 first-seen columns and 1,000,000 present members, plus existing
49 core caps. Original logical weights remain: tree view 64 plus snapshot alias
128 + 96 per record + edge-key UTF-8 bytes; catalogue 32 + 8 per returned ordinal
and 96 temporary bytes; table 256 + 8 per offset + 64 per column + key bytes + 16
per present member, plus captured source/selection. Reservations precede growth.
These are logical policy, not heap size, RSS or caller instruction limits.

Record retention is proportional to nodes/edge-key bytes. Build costs are
depth-sensitive; exact linear first-seen column scans may be quadratic. G4
controlled performance remains HOLD. No throughput, latency, RSS or speedup
claim follows from these structures. Persistence, graph/store/set/matrix,
retrieval, BFS, JSONPath and CLI/HTML integration remain separate future work.
