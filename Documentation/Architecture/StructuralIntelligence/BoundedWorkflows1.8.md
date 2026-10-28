# 1.8 bounded structural workflows

Implementation contract for the maintainer-authorized 1.8 feature branch from
published1.7.0 (8557bade). This is an additive implementation, not merge or release
approval. Original NAV12 construction fixtures, failures and qualification retain
their source-bound historical meaning; public promotion adds its own evidence.

## Batch reads

JSONInspectionBatch returns exact values for ordered typed paths. Snapshot values
accept ordered snapshot-local ordinals. Store values accept owner-bound positions.
Repeats are preserved and charged; empty requests still admit the complete source.
An invocation returns all results or throws, never publishes a partial result and
never substitutes null for an invalid selection. Explicit JSON null remains a value.

Each batch creates one original native read/traversal scope. Profile/request work,
one complete canonical source/source-map admission, every selection and output
slot share its ledger. It does not loop over independently admitted public reads.
Request counts are inclusively capped (default1024); native path/work/retention/
cancellation caps remain. Output JSON aliases follow existing requiredValue/read
semantics; subsequent caller copies/work are outside library-owned quotas. Logical
slot accounting is conservative policy, not heap/RSS or throughput measurement.

## Immutable public configured store

Promote the existing typed closed construction profile and checked store facade
inside JSONInspection; no new product, parser, database, resolver or index engine.
References stay disabled unless explicitly configured. Strict markers retain exact
collection/id spelling; only declared fields are interpreted. Preserve all eight
construction phases, duplicate/error precedence, first/second locations, source
spans, source-local owner tokens and the original one-ledger preparation/admission.
The twelve existing construction ceilings remain finite policies, not calibrated
joint capacity guarantees; the49 core metrics and all fixtures remain unchanged.

Fixed record/collection/reference metadata access is trusted bounded-memory access.
Lookup, value batches and follow are separately reported operations, independent
of construction. Each admits the captured source once and reserves its immutable
metadata aliases; helpers cannot reset budgets or attach another source. Lookup
uses decoded scalar names/IDs, returns nil for a missing ID in a known collection,
and throws unknownCollection for an undeclared collection. Position construction
and the fully admitted store initializer remain inaccessible to external callers.

Follow is deterministic breadth-first over configured link slots in field order,
including its starting position exactly once. Absent/null slots remain distinct
metadata and contribute no edge. Cycles use visited physical positions, not string
normalization or recursive callbacks. Depth, frontier, visited and result ceilings
are inclusive and finite. An unvisited reachable node exceeding any ceiling throws;
no depth-truncated or partially successful closure is returned. Owner mismatch is
an error. This operation performs no I/O and creates no persistent identity.

## Compatibility and qualification

Existing singular reads/traversal/graph/Transform semantics and public signatures
remain unchanged. A caller pipeline is not implicitly one global ledger. New
source needs actual Debug/Release, public consumer and compiler-boundary evidence,
cancellation/late-failure/resource cases, supported safety/platform lanes and DocC.
Update exact discovery identities/cardinalities rather than relaxing them. Reuse
original independent fixtures and49 caps; add explicit new batch/follow policy
cases. Keep partial profiling/G4 HOLD and the1.7-only P4 exception historical;
1.8 performance is unqualified until measured or explicitly dispositioned.

No persistence, public mutable store, online lookup, new query grammar, lower
platform floor, parallel batch execution or wider retrieval belongs to this wave.

## M2 application acceptance and counter observations

Schema validation, store construction, reads, transformation and Patch remain
separate public operations with independent reports. A recipe does not attach a
replacement ledger or claim a pipeline-wide budget. Ordinary schema invalidity,
operational quota failure and root removal remain distinct. Patches require a
new source wrapper/store; old positions and source spans do not silently migrate.
Accepted bytes of an awaited sink cannot be recalled after cancellation.

The authored public examples and Integration behavior cases qualify those
boundaries without changing any engine API. The capacity matrix in
Documentation/Qualification/StructuralWorkflows1.8Matrix.json records fixed
fixtures, exact boundaries and separately reported diagnostic refusals. Its
counter comparisons are not elapsed-time, allocation or RSS evidence. Existing
49 core metrics, twelve construction caps, profile defaults, fixture identities,
performance review trigger and controlled-performance holds are unchanged.
