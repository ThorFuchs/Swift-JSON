# Experimental graph qualification

NAV11 explores a package-only directed simple graph over two explicitly selected
physical arrays in one canonical document. Applications cannot import its types.
The existing public array evidence, snapshots, tree and sparse table interfaces
remain unchanged; this page is a scope notice rather than an available graph API.

IDs are decoded-scalar-exact strings from explicitly named direct members. The
experiment distinguishes missing, null, wrong kind, duplicate IDs, dangling
endpoints and duplicate ordered pairs. Self-edges and cycles are valid data.
Adjacency preserves original edge order; finite head-index BFS returns the complete
reachable component or throws, with no partial successful result.

Construction uses the original Navigation ledger. Later catalogue, source and BFS
queries are explicit independent full-source operations. Logical retained-byte
quotas do not cap process RSS or caller computation. Public API promotion, merge
and release require a separate owner decision. Controlled timing remains HOLD.

This page records the original package-only experiment. The owner-reviewed successor candidate exposes the narrow checked API described in <doc:SourceBoundGraphs>; storage and reducers remain non-public. No release is implied.
