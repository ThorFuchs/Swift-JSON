# P2-D store — design only, no engine

NAV9 adds no store, resolver, index, traversal or persistent identity. A future
profile must explicitly select a collections object, records arrays and relative
typed exact string-ID fields. No `id`/`_id` fallback. Absent/null/wrong-kind IDs are
distinct errors; duplicate IDs within an exact collection are refused. Collection
and record identities use decoded scalars, not Swift String canonical equivalence.
Strict JSON parsing already refuses duplicate exact member names; scalar-distinct
collection names stay distinct. Equal records at separate positions are not IDs.

References are disabled by default. Only explicit selected reference fields may
interpret a future strict marker with an exact collection and ID. A JSON `$ref`
elsewhere remains ordinary data; it is neither automatically a store edge nor a
schema resolver. Missing optional fields, explicit null, malformed markers,
unknown collections, absent target IDs and ambiguous references need separate
policies/failures, not ignored references or null defaults. Literal field names
containing slash/tilde obey existing typed paths and escaped JSON Pointer syntax.

Reference cycles may be represented as data. Future following would require
visited physical record positions, bounded queues, deterministic collection and
record source order and a complete one-ledger operation. No recursive unmetered
resolution, network fetches, alternate schema engine or generalized identity map.
Persistent snapshots/digests and edits are independent gates; edits use JSONPatch.

Design fixtures cover duplicate/absent/null IDs, both `id` and `_id`, malformed and
dangling markers, ordinary `$ref`, scalar-distinct collections, cycles and escaped
selectors. Oracle checks are data-premise checks, not store conformance claims.
