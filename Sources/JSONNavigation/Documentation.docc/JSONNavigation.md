# ``JSONNavigation``

Exact, synchronous, bounded exploration of many nodes in one canonical JSON source.

This is an experimental N1 target, **not a released SwiftPM product**. The package's
seven public products remain unchanged. Product promotion requires the recorded
correctness, resource, compiler, platform and API review gate.

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
