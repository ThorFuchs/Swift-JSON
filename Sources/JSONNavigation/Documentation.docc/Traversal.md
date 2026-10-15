# Exact traversal and explicit coverage

N1 adds many-node observation to the existing exact model. These three examples
are compiled and executed as external Swift 6 modules in Debug and Release by
`Scripts/qualify_navigation.py`. They assume explicit `import JSON` and
`import JSONNavigation`; installing a public Navigation product remains gated.

Core access remains the appropriate interface for one node:

```swift
let root = try JSON.parse(#"{"items":[1,2],"note":null}"#)
let selected = try JSONPointer(parsing: "/items/0").resolve(in: root)
let absent = try root.presence(of: "missing")
let null = try root.presence(of: "note")
precondition(selected == 1 && absent == .absent && null == .null)
```

The structural visitor explores object insertion order and ascending array indices.
Its paths remain absolute typed components; numeric keys remain keys. Root is `[]`
and empty-key is `[.key("")]`; Pointer text should be produced by the core Pointer.

```swift
let root = try JSON.parse(#"{"items":[1,2]}"#)
var locations: [[JSONLocationComponent]] = []
let report = try JSONTraversal(document: .init(root: root)).visit { hit, _ in
    locations.append(hit.absoluteLocation)
    return .continue
}
precondition(locations == [[], [.key("items")], [.key("items"), .index(0)], [.key("items"), .index(1)]])
precondition(report.result.completion == .complete && report.statistics[.nodes] == 4)
```

Virtual scopes select existing source nodes without materializing a new JSON array.
The default rejects duplicate and ancestor/descendant roots before any callback.

```swift
let root = try JSON.parse(#"{"items":[1,2],"tail":null}"#)
let selection = JSONTraversalScope.virtual(roots: [[.key("items")], [.key("tail")]])
let report = try JSONTraversal(document: .init(root: root)).collect(scope: selection, maximumRecords: 4)
precondition(report.result.nodes.count == 4 && report.result.summary.scopeRootCount == 2)
precondition(report.result.summary.completion == .complete)
```

`.orderedOccurrences` preserves repeated selections and their root index, occurrence
ordinal and relative depth. `.uniquePhysicalNodes` deduplicates exact typed paths,
including filtered/excluded roots: the first examined occurrence wins. Equal values
at different paths remain different nodes. Revisited paths still explore descendants
under their current relative depth; deduplication is never automatic subtree pruning.

Depth zero permits only a selected root. `includeScopeRoot: false` suppresses its
emission; `depthLimit: 1` then gives children-only traversal. Kind filtering suppresses
emission, never descendant exploration. A filtered empty result can be complete;
a missing scope throws. Pruning/depth omission is `.restricted`, explicit `.stop` is
`.visitorStopped`; neither establishes absence outside observed coverage. Coverage is
conservative per occurrence, not a proof that overlapping selections repaired an
earlier pruned region. Only DFS is implemented; no BFS label or prefix-snapshot API.

Collection defaults to 100,000 records and throws on the next record; its bound is
inclusive and zero is meaningful. Root/source admission, scope resolution, exact
overlap comparisons, path creation, frontier, source-span lookup and records share
one finite core ledger. Source spans are opt-in and come only from the captured
coherent document. `replacingRoot` supplies none. No source text or subtree appears
in a hit, and no read cursor crosses the synchronous visitor boundary.

Caller visitor computation and caller-retained copies are outside owned instruction
and retention quotas. Reports account for logical ownership, not process RSS or
allocator capacity. Unexpected quotas and cancellation throw and return no successful
report, even if cancellation occurs during a callback returning `.stop`. Earlier
callback effects cannot be recalled. Core access/resource errors retain their types;
collection capacity and ambiguous roots use ``JSONTraversalFailure``.

The initial overlap/dedup implementation uses metered linear comparisons rather than
an unqualified hash index. Complete path copies are bounded by the existing read
scope; deep frontiers can use quadratic path metadata. No EngineBench speed, linear
total-time, zero-copy or fixed-memory claim is made. Classification, snapshots,
projections, persistence, async actors, query syntax and rendering are later gates.
