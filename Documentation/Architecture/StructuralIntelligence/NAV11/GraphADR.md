# NAV11 directed simple graph experiment

Package-only JSONInspection research, based on merged Navigation/Inspection;
no NAV10, new product, public symbol or graph JSON model. One original
`JSONTraversal.inspectOwned` invocation selects `[nodesAt, edgesAt]` with
`.rejectAmbiguous` and depth one. All strict root selections and overlap checks
precede callbacks; nodes are validated before edges, in their physical order.

Negative capacities are configuration failures before admission. Existing core
precedence is retained: complete source admission precedes strict selection,
overlap and root-kind checks. No separate unmetered profile scan or second ledger
is added to move those checks ahead of admission. Missing roots preserve core
`missingMember`/`missingTarget`; wrong root kinds preserve typed core access errors.
Paths and explicit keys are immutable. Reusing a field spelling across roles is
intentional and valid (an edge's single field may explicitly name both ends of a
self-edge); no field inference or silent repair occurs.

The exclusive context adds mutating delegates only: direct string member selection,
scalar-exact string comparison and matching alias release. JSONObject.lookup and
JSONComparison.textEquals remain authorities. Missing, null and wrong kind are
reported separately; strings own 32+UTF8 logical bytes until released or handed off.
Profile keys are explicitly key-admitted on that meter even for empty arrays;
the preexisting retainKey delegate gains an opt-in caller-input admission flag,
with its original default behavior/counters preserved.
No cursor, scope, ledger or noncopyable capability leaves the reducer. Original
2-positive/20-negative codegen tests are unchanged; helper escape probes and runtime
parity run separately in Debug and Release. A compiler crash blocks implementation.

Graph metadata is source-local: first row ordinals, exact ID aliases, endpoint
ordinals and CSR offsets/edge ordinals in original edge order. Original source is
transferred once after complete validation/finalization. Defaults are 10,000 nodes,
50,000 edges; each independently configurable finite cap is inclusive and still
subject to all 49 core metrics. Linear exact scans may cost O(N²+NE+E²).

Later value/span/catalogue/BFS calls start explicit independent full-source
operations. BFS has a head-index queue, visited-at-enqueue and source-edge order.
Defaults: 10,000 frontier entries, visited nodes and returned nodes. Queue history
remains charged until handoff; frontier capacity means live pending entries.
Results certify the complete reachable component including the start, not global
reachability. Failure/cancellation returns no partial result.

Logical policy V1: 256 fixed builder bytes, 32+UTF8 per node ID alias,
16 per node record, 24 per edge record, 8 per offset and adjacency reference,
plus exact profile keys/paths and the original source. Queries admit graph metadata
aliases, queue/output slots (8 each), visited flags (1 each) and their source;
returned JSON aliases additionally receive core owned-retention accounting.
These are logical quotas, not allocator/RSS or caller-instruction guarantees.

No public promotion, merge, release, timing or speed claim. Controlled performance
remains HOLD. Store, persistence, graph editing, weights, algorithms other than BFS,
query/CLI/HTML/network adapters and NAV10 batching remain separate work.

BFS entry precedence is negative capacities, node bounds, whole source/metadata
admission, then enqueue's frontier/visited/result ceilings. Work/cancellation that
is observed first takes precedence. Edge rows validate source field then target
field before resolving source then target IDs, then compare ordered pairs. All
node rows precede all edge rows; a late duplicate node outranks a dangling edge.
