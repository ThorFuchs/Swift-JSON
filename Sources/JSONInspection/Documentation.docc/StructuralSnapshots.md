# Index complete physical structure

Build source-attached metadata without replacing the canonical JSON document.

## Capture even a scalar root

```swift
let source = JSONDocument(root: .null)
let report = try JSONStructuralSnapshotBuilder(document: source).build()
let snapshot = report.result
let root = try snapshot.record(at: 0)
precondition(snapshot.recordCount == 1)
precondition(root.parentOrdinal == nil && root.componentFromParent == nil)
precondition(root.depth == 0 && root.childCount == 0 && root.subtreeEndExclusive == 1)
let value = try snapshot.value(for: 0)
precondition(value.result == .null)
```

The builder always covers one entire physical root, including null and empty
containers. No filter, prefix, prune, depth selection or caller callback can return
an incomplete snapshot. A negative maximumRecords fails configuration before
admission. Zero refuses the real root with a typed capacity error; there is no
successful empty or partial artifact. Quota exhaustion and cancellation throw.

## Keep paths and numbers exact

```swift
let source = try JSONParser().parseDocument(Data(#"{"":null,"0":[9007199254740993,0.0100]}"#.utf8))
let snapshot = try JSONStructuralSnapshotBuilder(document: source).build().result
let rootPath = try snapshot.location(for: 0).result
let emptyKeyPath = try snapshot.location(for: 1).result
let arrayElementPath = try snapshot.location(for: 3).result
precondition(rootPath.isEmpty && emptyKeyPath == [.key("")])
precondition(arrayElementPath == [.key("0"), .index(0)])
let integer = try snapshot.value(for: 3).result.numberValue!.integer(as: UInt64.self)
let lexeme = try snapshot.value(for: 4).result.numberValue!.originalLexeme
precondition(integer == 9_007_199_254_740_993 && lexeme == "0.0100")
let root = try snapshot.record(at: 0)
precondition(root.subtreeEndExclusive == snapshot.recordCount)
```

Object members retain insertion order and decoded scalar key identity. Array
indices increase from zero. Root [] differs from an empty key; key "0" differs
from index 0. Parent ordinals are lower than children; finalized half-open subtree
ranges include the node and all its descendants, not merely direct children.
Numbers remain in the exact canonical source, with no binary64 projection.

## Preserve source binding and explicit lookup budgets

```swift
let document = try JSONParser().parseDocument(Data(#"{"old":null}"#.utf8))
let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
let replacement = document.replacingRoot(.array([42]))
let newer = try JSONStructuralSnapshotBuilder(document: replacement).build().result
let oldPath = try snapshot.location(for: 1)
let newPath = try newer.location(for: 1)
precondition(oldPath.result == [.key("old")] && newPath.result == [.index(0)])
let oldSpan = try snapshot.sourceSpan(for: 1)
let newSpan = try newer.sourceSpan(for: 1)
precondition(oldSpan.result != nil && newSpan.result == nil)
precondition(oldPath.statistics[.nodes] == 2 && newPath.statistics[.nodes] == 2)
```

Ordinals are positions local to the particular snapshot method being called.
A record carries metadata, not a portable node identity. No method accepts a
replacement source or detached handle. An older snapshot keeps its original
immutable source and coherent map; it never follows another document’s revision.
Only original mapped spans are available. Invalid ordinals throw typed bounds
errors before admission rather than returning null, missing or a default record.

Construction uses Navigation’s original single cumulative read scope and meter.
It transfers the already-admitted document ownership once after complete range
finalization, retaining one source and parent/edge records, without per-node JSON
values, full paths or source maps. Logical overlay v1 reserves 128 fixed bytes,
96 per record, exact edge-key UTF-8 bytes and 16 per open frame, plus original
source/path costs. These policy weights are not Swift heap layout or process RSS.

record(at:) is O(1) metadata access without opening a new ledger. Each location,
value or sourceSpan call deliberately opens a separate finite operation and
re-admits the whole captured document, even for root or unmapped-span lookup.
Repeated K lookups pay K admissions; they do not share the builder’s remainder.
Path reconstruction also uses depth-sensitive core prefix copies and selection.
The existing traversal builds full hit paths, so total snapshot build work is
not guaranteed linear in node count. No batch session, persistence, stable source
fingerprint, table certification or new JSON representation is provided.
