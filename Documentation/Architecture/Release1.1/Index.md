# Exact-key construction and publication

Ordered members remain the public collection and writer authority. Each published
object also owns immutable exact-key metadata. The index stores decoded JSONKey
identity and insertion positions, never canonically equating String dictionary keys.

The R0 release-native comparisons favored controlled open addressing for wide
objects. The current candidate uses a linear index below 32 keys, then a power-of-two
table with occupancy at most one half. Lookups keep the scalar path for small
objects and the first eight members. A wide lookup hashes its query once, probes
the table and confirms exact UTF-8 on every candidate hit. Collision scans are
finite and metered; this is no adversarial constant-time guarantee.

Each metadata capacity slot retains the existing Version 1 `indexSlot` weight of
32 logical bytes. Unused capacity is included. New capacity is admitted while old
capacity remains live; copying, initialization, rehashing and exact probes consume
the same meter. Rejected growth releases its replacement reservation and leaves
prior metadata valid. Logical capacities do not assert allocator or RSS ceilings.

The shared grammar maintains its own duplicate index at decoded key recognition.
A duplicate still fails at the second encoded key's start before its colon/value.
Materialized objects maintain separate metadata as keys arrive. Checked
construction and the accumulator maintain their index before publication; consuming
nonthrowing `finish` transfers it without search, allocation or a fresh budget.
Editing, native materialization and schema inspection/output build metered metadata
before returning a value. Empty Merge Patch targets use an explicit empty index.

Grammar duplicate capacity and DOM metadata are distinct live owners. Full owned
graph admission includes the published index's actual logical capacity and member
slots separately. The metric and weight meanings stay at Version 1; capacity/work
counts legitimately differ with the algorithm, and defaults are not raised.

Native keyed encoding now keeps one invocation-owned mutable storage object and
maintained exact index. Updating a field no longer extracts and rewrites the entire
member array. Member growth admits old/new capacities together. Materialization
charges key traversal and builds immutable output metadata under the same meter.
This source observation alone makes no claim of one allocation per field.

`IndexPublicationTests` covers all JSON publication routes, scalar-distinct keys,
forced collisions, failed rehash, duplicate timing and cancellation. The separate
release construction benchmark measures checked, parser, accumulator and native
keyed paths over 120 cells, using the matched finite offline profile. It records
resource refusals separately, and allocator snapshots separately from timing and
logical retention. A successful SDK build does not establish a mobile crossover.

Full R1 closure requires the actual final native/safety/consumer measurements and
review receipts. The test-only AVL/scalar alternatives remain qualification
references; no table, platform or throughput result is inferred from this prose.
