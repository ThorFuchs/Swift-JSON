# P2-D graph — design only, no engine

NAV9 Branch B adds no graph API, adjacency structure, BFS or topological sort.
Legacy graph source was reviewed for incompatible assumptions, not adapted.
A future implementation needs a separate ownership, capacity and semantic gate.

A profile must explicitly name typed physical node-array and edge-array paths,
relative exact string-ID and endpoint fields, and directed/simple versus multigraph
policy. No heuristic ID discovery. IDs are exact decoded scalar strings: absent,
explicit null, wrong kind and duplicate ID are distinct refusals with typed paths.
Canonically equivalent Unicode spellings stay distinct. Equal node payloads do
not merge physical positions. Original node/edge order is retained.

Proposed first profile is directed and simple: duplicate ordered endpoint pairs
are refused; self-edges and cycles are allowed as general graph facts. An explicit
acyclic profile/topological operation would instead report a typed cycle failure,
never an empty/partial order. Dangling endpoints are errors. A future multigraph
profile would preserve parallel edges explicitly, not silently drop them.

Future BFS uses source edge order for neighbors and source node order to break
otherwise equal choices. It needs a bounded head-index queue (no removeFirst),
visited positions, checked counters and complete admission of the original source
under one owned invocation. Every ID comparison, candidate scan, queue operation,
retained alias and finalization must share that meter; caller callbacks cannot
create inner default budgets. Quota/cancellation is an error, not partial success.
Exact IDs are invocation-local, not persistent hashes or detached snapshot IDs.

Design fixtures record duplicate/missing/null/scalar-distinct IDs, dangling edges,
self/parallel edges, cycles, equal payloads and deterministic neighbor premises.
Their independent data oracle proves premises only; it does not qualify any graph
runtime. Selection paths with slash/tilde remain core typed paths/Pointer rules.
Edits, if ever proposed, must delegate to JSONPatch rather than mutate JSON.
