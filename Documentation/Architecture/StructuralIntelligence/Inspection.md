# Array evidence public-product candidate

JSONInspection is an opt-in library depending on JSON and JSONNavigation. Core
never re-exports it. This isolated promotion candidate is unmerged and unreleased.
It reports observations rather than table/schema admission. Navigation public
declarations and semantics are unchanged. See [public surface review](N2Promotion.md)
and the [DocC guide](../../../Sources/JSONInspection/Documentation.docc/ArrayEvidence.md).

`JSONShapeInspector(document:limits:)` captures one canonical source.
`inspectArray(at:sampling:maximumColumns:includeSourceSpan:)` selects an existing
array using exact JSONLocationComponent keys/indices and returns the existing
JSONOperationReport envelope. JSONShapeSampling supports complete rows or
`prefix(maximumRows:)`. The column bound defaults to 100,000, inclusive. Negative
sampling or column configuration fails before admission, a deliberate new-API
precedence contract. Valid operations always admit the full captured root/source/map
once, even for a zero prefix, scalar selection error or unseen suffix.

The [exclusive reducer](A0Recovery.md) runs observation and finalization inside
Navigation's original read scope and meter. No nested public operation, new
resource context, parsing, default reset or additional root admission occurs.
Selection and wrong-kind failures use core access errors. Column capacity,
resource exhaustion and cancellation throw and cannot publish partial evidence.

## Evidence and coverage

Row coverage and traversal coverage are independent. The walker explores the
selected array root and rows at depth one, and the reducer inspects object cells
directly. Row descendants are pruned; complete row evidence can therefore have
restricted traversal coverage. An incomplete positive prefix intentionally stops
at its final observed row. A zero prefix has no positive traits. A prefix reaching
the final row has complete **row** coverage, without certifying descendant shape.

Reports retain source selection, optional coherent selected-array span, full-source
admission completion, total/examined row counts, six exact row kinds and deterministic
first-seen columns. Column present includes explicit null; explicitNull is separate;
missing uses observed object rows only. Nonobject rows contribute no missing cells.
Decoded scalar-distinct keys stay distinct and retain source insertion order.
No String hash/set, normalization, numeric projection or replacement JSON is used.

Observed-all-objects and uniform-kind traits describe examined rows only. Empty
evidence yields nil traits. Array length range describes observed array rows;
rectangular width requires all examined rows to be arrays of that length. It says
nothing about numeric cells, a matrix, schema validity or an unexamined suffix.
Numbers remain canonical JSONNumber values in the unchanged source. Replacement
documents retain no stale original span.

## Finite work and ownership

All 49 core profiles and metric definitions remain unchanged. The inspector uses
their source, path, work, key, retention and cancellation limits. Its additional
inclusive column bound is finite by default. Logical overlay version 1 reserves
256 bytes for report/reducer summary, 192 per returned column, exact UTF-8 key
bytes, and core path-slot/key weights for returned selection. Reservations precede
collection growth. Output slots transfer from reducer to report; they remain
charged at handoff. These are declared logical weights requiring calibration,
not heap layout, allocation count or process RSS guarantees.

Every row/member/column scan and finalization step charges the original meter;
key comparisons delegate to core scalar comparison, including inner cancellation.
Counters are bounded by admitted row/member counts and work before increments.
Column lookup can be quadratic. No indexing or speed claim is made.

The seventeen I01–I17 Swift Testing functions cover empty, wrong-kind, missing,
complete/mixed/late-counterexample/zero-prefix rows, permutations, scalar key identity,
typed numeric paths, null/absence denominators, exact numbers/lexemes, ragged and
nonnumeric arrays, full-source admission, inclusive work/retention/column limits,
inner cancellation, source coherence and independent shared-source invocations.
`Scripts/ci.py --lane inspection` enforces exact discovery and compiler outcomes.
Current native/Linux/WASI/platform receipts must qualify final source; this document
does not turn an unexecuted lane into a pass. No N2 merge or release is authorized.

Snapshots, persistent indexes, projections, retrieval, BFS, JSONPath, HTML/CLI
integration, schema inference and numeric matrices remain deferred.
