# ``JSONNavigation``

Exact, synchronous, bounded exploration of many nodes in one canonical JSON source.

JSONNavigation is an opt-in library product introduced in Swift-JSON 1.6.0.
Add its SwiftPM product and import it explicitly; core JSON does not re-export it.
One-node reads remain available directly from JSON.

The core JSON module continues to own one-node lookup, exact numbers and keys,
presence and RFC 6901 Pointer. Use ``JSONTraversal`` for deterministic DFS preorder,
physical subtrees and explicitly ordered virtual selections. One call admits the
captured source once and shares its core read-scope meter across all phases.

## Topics

### Exact structural exploration

- <doc:Traversal>
- ``JSONTraversal``
- ``JSONTraversalScope``
- ``JSONTraversalOptions``
- ``JSONScopeOverlapPolicy``

### Observation and coverage

- ``JSONTraversalHit``
- ``JSONTraversalKind``
- ``JSONTraversalAction``
- ``JSONTraversalSummary``
- ``JSONTraversalCompletion``
- ``JSONTraversalCollection``
- ``JSONTraversalFailure``
