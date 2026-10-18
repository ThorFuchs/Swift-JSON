# Graph G0 preflight — design questions only

NAV9 GraphADR and its pinned premise fixtures remain authoritative research,
without a graph engine. Before NAV11 runtime work, freeze explicit typed node/edge
paths and ID/endpoint fields, directed simple policy and exact decoded-scalar string
IDs. Missing, null, wrong kind, duplicate ID, duplicate ordered endpoint pair and
dangling endpoint require distinct typed failures and original physical paths.

Adversarial additions: equal payloads at distinct positions; scalar-distinct IDs
and slash/tilde field names; duplicate reverse versus identical directed pairs;
self-edge and two-node cycle; isolated nodes; zero nodes with a dangling edge;
late duplicate after queue-cap exhaustion. Ask which failure takes precedence.
Cycles are general graph data; a separately proposed topological operation must
refuse a cycle explicitly. It must never return an empty successful order.

One original source admission must cover ID comparison, endpoint scans, adjacency
slots, head-index BFS queue and finalization. No callback may open public readers
with fresh defaults. Define inclusive node/edge/frontier/result capacities and
post-transfer cancellation proofs before exposing signatures. No graph runtime,
API, BFS or inferred conformance is added by this preflight.
