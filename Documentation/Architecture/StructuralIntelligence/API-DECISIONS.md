# N1 exact traversal decisions

Scope is N0/N1 only. JSONNavigation depends exclusively on JSON and currently has
no public SwiftPM product. The seven existing products and empty external graph
remain the manifest acceptance contract. Core, schema, Patch, streaming, bridge,
filter/query and renderer behavior is unchanged. The generated CLI source-identity
stamp must refresh when Package.swift/Sources change; this mechanical integration
update adds no CLI behavior, command, language or version change.

## Actual experimental declarations

- `JSONTraversal(document:limits:)` captures one immutable JSONDocument.
- `visit(scope:options:_:)` takes `(JSONTraversalHit, JSON) throws -> JSONTraversalAction`
  and returns `JSONOperationReport<JSONTraversalSummary>`.
- `collect(scope:options:maximumRecords:)` uses that same internal execution authority
  and returns `JSONOperationReport<JSONTraversalCollection>`.
- `JSONTraversalScope.subtree(at:)` and `.virtual(roots:overlap:)` select absolute
  existing typed paths. Virtual defaults to `.rejectAmbiguous`.
- `JSONScopeOverlapPolicy`: rejectAmbiguous, orderedOccurrences, uniquePhysicalNodes.
- `JSONTraversalAction`: continue, skipDescendants, stop.
- `JSONTraversalOptions`: depthLimit, includeScopeRoot, emitKinds, includeSourceSpans.
- `JSONTraversalHit`: absoluteLocation, scopeRootIndex, occurrenceIndex, relativeDepth,
  kind and optional coherent sourceSpan. It contains no JSON subtree or cursor.
- `JSONTraversalSummary`: visitedCount, emittedCount, maximumDepthVisited,
  scopeRootCount, deduplicatedCount, prunedSubtrees, depthLimitedSubtrees, completion.
- `JSONTraversalCompletion`: complete, restricted, visitorStopped.
- `JSONTraversalFailure`: collectionLimitExceeded(limit:), ambiguousRoots(first:second:).

The [DocC guide](../../../Sources/JSONNavigation/Documentation.docc/Traversal.md)
contains three externally compiled/executed before/after examples. The actual
[consumer](../../../Tools/NavigationQualification/Consumer.swift) uses public JSON
and Navigation declarations, not package meters. Its external-module compiler
probes check core import isolation, hidden meters, non-Sendable cursor rejection
and absence of a fabricated missing kind in both build configurations.

## Exactness and coverage

DFS preorder is the only order offered: object insertion and increasing array
positions. Depth counts edges from each selected root. Full source admission is
mandatory even for a scalar selection, depth zero, filtered-empty selection or
early stop. Root omission/kind filtering changes emission only. Pruning/depth
omission marks coverage restricted, and explicit stop marks visitorStopped. Errors
and cancellation throw. Reports are conservative per-occurrence coverage, not a
union-coverage proof or a global absence query.

All virtual roots resolve before any callback. Reject mode then checks every pair
for equal or ancestor/descendant typed prefixes. Ordered mode preserves root order,
then each subtree's DFS, including repeats. Unique mode remembers **first examined**
typed paths, even excluded/filtered roots, preserving their first depth/origin. It
still explores revisited descendants under the current occurrence's depth policy.
Two equal-valued siblings or scalar-distinct keys never merge. A virtual selection
does not invent a new source root, array index, durable ID or revision fingerprint.

Mapped spans are opt-in core lookups, never synthesized. An unchanged captured old
document continues to describe its old root after another traversal captures a
replacement. No record resolves against a caller-supplied newer root automatically.

## Finite policy and implementation costs

All 49 core metrics/profiles/weights remain unchanged. Existing core read-scope
admission covers root, source bytes/label and source maps. Path records reuse its
pointer, diagnostic and retention policies. The N1 logical overlay reserves 128
bytes for summary/staging, 16 for root-list staging, 64 per planned root or frontier
frame, 64 per ephemeral hit or collected record, and 16 per unique-path reference.
Retained collected paths additionally charge the published 32-byte indexSlot per
component and its key UTF-8 bytes. These are logical weights, not allocation/RSS
measurements; caller-retained callback copies remain caller storage.

Collection has an independent inclusive default of 100,000 records; zero prohibits
emission but allows a genuinely empty result. Negative bounds/depth reject as
configuration errors. Its next-record refusal throws a typed traversal capacity
error and publishes no collection. Source admission uses existing node capacities;
visits do not misleadingly re-charge source nodes, and work stays cumulative across
roots, pair scans, dedup, emitted paths, source-span lookups, output and cleanup.

Initial reject/unique modes use exact metered linear comparisons. Pair validation
and unique-node scans can be quadratic. Core path snapshots along a deep frontier
can also use quadratic path metadata. The prototype intentionally makes no
linear-total-time, indexed-lookup, zero-copy or speed claim. Every owned comparison
loop is cancellable/budgeted, so exhaustion is an operational error, never a partial
success. A future compact representation/index needs its own measured review.

The invocation and its synchronous scope never escape into a callback. JSONTraversal,
metadata/options and collected values are checked Sendable; each simultaneous call
creates its own scope. A package-only nil-by-default checkpoint observer supports
owned-loop cancellation qualification; no public consumer can install it.

## Qualification and promotion boundary

The reviewed new inventory is 36 nonparameterized Navigation tests, including the
three pinned synthetic packet documents. Existing function identities and all 325
native/Linux parameter invocations remain; WASI retains its separate 288. Full roots
become 582 native, 566 Linux and 478 WASI, and shared-state counts 42/41. All 126
maintenance identities, corpus policies and 49 cap probes remain required.

`Scripts/ci.py --lane navigation` checks exact focused discovery, Debug/Release,
explicit strict-memory compilation and external compiler/consumer/DocC probes.
Native/Linux run the new consumer and full existing suites; safety includes Navigation
ASan plus its shared-root TSan function. WASI uses the updated exact root inventory.
Current commands/receipts, failures and platform gaps accompany the return; this
decision document does not assert a pending platform run passed. Full release-gate
qualification and explicit product review precede promotion to an installable product.

BFS, scalar-sorted order, prefix snapshots, JSONInspection, classifiers, snapshots,
semantic/durable digests, projections, editing, retrieval, actors, rendering and CLI
verbs are explicitly deferred. No EngineBench implementation or performance claim.
