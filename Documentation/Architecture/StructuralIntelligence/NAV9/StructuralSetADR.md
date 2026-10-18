# NAV9 D0 — experimental structural set decision

Status: D0 compiler/one-ledger gate passed on Swift6.4 in Debug and Release.
This ADR preceded prototype code; final-source qualification remains required. Branch B starts at main0cb8ca40eb3c3bcf479006c2dcd88672f0a9b83b;
NAV8 N1/N2/N3/P1 is preserved. No public API/product, merge or release is approved.

A structural set is an immutable view over one strict physical array. Retain the
original JSONDocument, exact selected typed path and first representative **array
indices**, in source order. These are local source positions, not snapshot ordinals,
IDs or hashes. Null is a real member. Exact JSON decimal equality, decoded scalar
strings/keys, order-independent object equality and ordered arrays are unchanged.

Source authority is package JSONComparison.equals(_:_:meter:), which already owns
iterative deep comparison, exact object lookup, text/numeric work, scratch and
cancellation. JSONTraversal.inspectOwned owns the single original JSONReadScope
and full root/source/map admission. Its exclusive mutating-inout context cannot
escape or cross tasks. Proposed narrow addition: package mutating
`equalArrayElements(at:lhs:rhs:)` in JSONTraversalContext, selecting the already
admitted original array through scope.select and calling the existing metered
comparator. It returns Bool only; it exposes neither scope, meter nor a JSON alias.
All failures use existing perform/terminal health. No new meter/root admission.
Compile legal and forbidden method captures with full Debug/Release codegen before
D1. Existing 2-positive/20-negative reducer proofs remain mandatory.

Build visits every physical item, compares each index to first representatives
under that same context and skips redundant descendant walking. Full source
admission still covers every descendant. Preserve only the first matching index;
no synthetic JSON, Set<JSON>, unmetered ==, Swift String hashing or alternate equality.
Worst-case comparison work is quadratic in items, with depth/text/numeric costs;
selection adds path cost. Existing work quotas, not asymptotic promises, bound it.

`maximumUniqueItems` (default100000, inclusive) bounds retained representatives;
input length remains bounded by core arrayItems/nodes/work. A nonempty duplicate
suffix must still be examined, even at the unique cap. Negative configuration
fails before admission. Version1 logical output overlay:128 fixed +8/index +core
retained typed selection, plus the original source transferred once at complete
finish. Reserve before append; checked counters precede increments. Temporary
comparator frames use the existing core weights and refund rules. No persistent
representative JSON aliases or parallel caches exist. These are logical policy
units, not physical heap/RSS or arbitrary caller instruction bounds.

Construction emits only a complete artifact. Missing/wrong-kind paths, quotas,
cancellation and caught terminal failures throw. A later member read is a new,
explicit finite whole-source-admitted operation returning the original JSON value.
Metadata counts/indices are immutable local reads; copying an immutable view is
caller-owned aliasing, as for existing snapshots.

Defer contains with external arbitrary candidates until candidate admission/alias
accounting is separately established; it is not required for deduplication proof.
Keyed/ID equality, union/intersection/difference, normalization, materialized sets,
persistence and public promotion remain deferred. Legacy SetProjection.swift was
read only for failure examples; no legacy source is adapted.

Acceptance: SSET-01..18 and CORE-01..10, unchanged Navigation56/Inspection95 compiler
surface, exact original ownership proofs, inclusive limits/retention, inner
comparison cancellation and terminal-source cleanup. An unproved comparator or
compiler crash stops D1, leaving this design and minimal helper proposal only.
