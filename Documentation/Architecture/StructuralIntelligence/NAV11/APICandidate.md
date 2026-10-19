# Graph API proposal for later owner review

All NAV11 types and operations are **package-only**, not application API. Product
count remains ten, dependencies remain empty, Navigation56/Inspection95 unchanged.
The proposed future public subset, contingent on separate review, is:

- Immutable `JSONGraphProfile(nodesAt:edgesAt:nodeIDKey:edgeSourceKey:edgeTargetKey:)`.
- `JSONGraphProjection.build(document:profile:limits:maximumNodes:maximumEdges:)`
  returning `JSONOperationReport<JSONGraphProjection>`, defaults 10000/50000.
- Read-only captured document/profile/nodeCount/edgeCount and complete traversal
  summary. IDs/CSR buffers are research metadata; promoting their raw arrays is
  not proposed. Source-local node/edge ordinals have no cross-view identity.
- `nodeValue(at:limits:)`, `edgeValue(at:limits:)`, `nodeSpan(at:limits:)` and
  `outgoingEdges(of:limits:maximumResults:)` with independent finite whole-source
  admissions. Returned JSON aliases receive additional owned-value accounting.
- `breadthFirst(fromNode:limits:maximumFrontier:maximumVisited:maximumResults:)`
  returning original node ordinals; defaults 10000 each, start included, complete
  reachable component. Zero caps refuse a real start; an empty graph has no start.
- Typed semantic errors with original row/field paths; core missing/kind/resource
  and cancellation errors stay intact. No partial-success variant exists.

BFS stores queue history as returned output; frontier means pending entries, while
visited/result caps independently bound total enqueues/output. Graph metadata
aliases, visited flags and queue entries share the query's original traversal
ledger. Scalar-exact linear resolution and O(N²+NE+E²) construction are explicit
costs, not optimized lookup claims. No new JSON identity/path or serialization.

Actual compiled spelling is in Sources/JSONInspection/Graph. Constructors remain
fileprivate. Compiler probes reject external type access, private initializers,
mutation, internal reducers, and context escape. No public DocC examples imply
these private declarations are available. No merge or promotion is authorized.

## Public successor review

The owner approved the compiler-derived 34-declaration public subset for the draft
candidate, subject to qualification. The exact source spelling is authoritative:
public JSONGraphProfile (immutable explicit paths/keys and initializer),
JSONGraphProjection (checked factory, immutable document/profile/traversal/counts
and five independent query operations), and JSONGraphFailure with fourteen typed cases.
No existing public declaration changes. CSR buffers, ID staging, edge records,
reducers and the noncopyable context remain inaccessible externally. The old
public-type-invisibility negatives are replaced by internal builder/query/stage
negatives; initializer, storage, mutation and ownership rejections remain.

Sixteen public-only scenarios and a distinct-package consumer supplement all
G01–G32 and 27 independently pinned fixtures. Three executable DocC examples and
26 external full-codegen rejections are mandatory. This is signature approval
for a draft, not merge/release approval or a claim of unexecuted platform passes.
