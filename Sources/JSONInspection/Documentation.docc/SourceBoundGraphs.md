# Build a source-bound directed graph

An explicit profile names two disjoint physical arrays and their direct string fields.
Build validates every row and publishes only a complete directed simple graph.
ID and field-key identity uses exact decoded Unicode scalars. Arrays retain source
order. Duplicate IDs, dangling endpoints and repeated directed pairs throw; reverse
edges, self-edges, cycles and isolated nodes are valid data.

## Capture the complete source

```swift
let graphSource = try JSONParser().parseDocument(Data(#"{"nodes":[{"id":"A","n":9007199254740993},{"id":"B"}],"edges":[{"from":"A","to":"B"}]}"#.utf8))
let graphProfile = JSONGraphProfile(nodesAt: [.key("nodes")], edgesAt: [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
let graphBuild = try JSONGraphProjection.build(document: graphSource, profile: graphProfile)
precondition(graphBuild.result.nodeCount == 2 && graphBuild.result.edgeCount == 1)
precondition(graphBuild.statistics[.workUnits] > 0)
```

## Traverse a complete reachable component

```swift
let graph = try JSONGraphProjection.build(document: .init(root: JSON.parse(#"{"nodes":[{"id":"A"},{"id":"B"}],"edges":[{"from":"A","to":"B"},{"from":"B","to":"A"}]}"#)), profile: .init(nodesAt: [.key("nodes")], edgesAt: [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")).result
let outgoing = try graph.outgoingEdges(of: 0).result
let reachable = try graph.breadthFirst(fromNode: 0).result
precondition(outgoing == [0])
precondition(reachable == [0, 1])
```

## Preserve semantic failures

```swift
let duplicate = JSONDocument(root: try JSON.parse(#"{"nodes":[{"id":"A"},{"id":"A"}],"edges":[]}"#))
let profile = JSONGraphProfile(nodesAt: [.key("nodes")], edgesAt: [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
do {
    _ = try JSONGraphProjection.build(document: duplicate, profile: profile)
    preconditionFailure("Duplicate ID was accepted")
} catch JSONGraphFailure.duplicateNodeID(let first, let second) {
    precondition(first == [.key("nodes"), .index(0)])
    precondition(second == [.key("nodes"), .index(1)])
}
```

Every later value, span, outgoing-edge or BFS query is a new independent whole-source
admission under the supplied finite limits. Returned JSON aliases remain charged.
No constructor budget is silently reused. Build defaults to 10,000 nodes and 50,000
edges; outgoing queries default to 50,000 results; BFS defaults to 10,000 live pending
nodes, 10,000 visited nodes and 10,000 results. All caps are inclusive. Zero caps
refuse nonempty work; cancellation, quotas and typed semantic failures throw without
successful partial artifacts. Missing, null and wrong kind remain distinguishable.
Core selection errors retain their typed cause; operational errors are not graph facts.

Ordinals name positions in this immutable captured source, not durable graph IDs.
There is no replacement-source argument. Replacing a document root drops obsolete
source spans; an existing graph keeps its original source and map. Node spans can be
nil for a source without a map. Storage, reducers and mutable meters are private.

BFS uses source-edge order and visited-at-enqueue, including the start. Its output
certifies the reachable component, not global connectivity, acyclicity or schema validity.
Exact construction uses bounded linear scans and can cost quadratic work; repeated
queries re-admit the whole source. Logical retention is not RSS. Controlled G4
performance remains HOLD, with no speed claim. No new product, graph serializer,
mutation, topology, weighted edges or persistent identity is supplied.
