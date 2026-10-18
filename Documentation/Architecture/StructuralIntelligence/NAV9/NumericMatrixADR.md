# NAV9 D0 — experimental exact numeric matrix decision

Status: source-reviewed design; compiler/one-ledger gate pending. Written before
prototype code. Package-only in existing JSONInspection; zero public additions,
products or dependencies. Main0cb8ca4/NAV8 and immutable stable1.6.1 are preserved.

Admit one existing physical array completely, with every row an array of the same
width and every cell an original JSON.number(JSONNumber). Use the original
JSONTraversal.inspectOwned exclusive reducer/context and one full source admission,
selection, cumulative validation, output accounting and one-shot source transfer.
N2 prefix traits never certify a complete matrix. No Double/Float/Foundation
numeric conversion, flattening, omitted cells, padding, null/default zero or
synthetic JSON is permitted. Exact original numbers and lexemes stay in source.

Empty [] is0×0. [[],[]] is2×0; transpose must be0×2. [ [] ] similarly becomes0×1.
The immutable view stores original dimensions and orientation, swapping logical
counts and mapping each logical (r,c) to the original (c,r) for transposed reads.
A second transpose is metadata identity. No JSON materializer is exposed: plain []
cannot encode an independent nonzero column dimension at zero rows. This explicitly
avoids claiming a lossless JSON shape round trip. Transpose is a fixed-size local
value copy like an ordinary immutable struct copy; caller aliases do not create a
new owned scanning operation or claim an RSS bound. Validation is never repeated
or weakened by orientation.

Factory defaults:100000 rows,100000 columns,1000000 cells, all inclusive and finite,
in addition to all49 unchanged core limits. Negative configuration precedes full
admission. Checked row×column multiplication and signed-to-capacity conversion
precede any growth or successful publication; overflow is a typed core resource
failure. No dense grid is allocated. Version1 logical overlay:128 fixed plus core
retained selection, original source and bounded walker state. Charge each actual
row/cell and finalization under the original meter; every row must be examined.
These are declared logical weights, not allocator layouts or wall-time/RSS caps.

The cell accessor is a new explicit whole-source-admitted JSONReadScope operation.
It checks logical bounds, maps orientation with checked metadata, constructs the
exact typed physical path through existing scope.append/select and returns the
original JSONNumber and cumulative report. It never spends a hidden constructor
remainder or opens nested public operations. Captured source/map remain coherent;
replacingRoot cannot preserve a stale map. Invalid shape/bounds, quotas and
cancellation throw; no partial successful view is published.

Arithmetic, row/column materialization, JSON export, setters, persistence and public
promotion are deferred. Legacy MatrixProjection.swift was read for negative
examples only; its Double/zero fallback and empty-shape transpose are rejected,
with no source adaptation. Graph/store engines are separately design-only.

Acceptance: MAT-01..18 and CORE-01..10, exact numeric/Unicode/path differential
fixtures, overflow without huge allocation, inclusive counts/work/retention,
inner validation cancellation, terminal cleanup and concurrent immutable views.
Full native/strict/safety/Linux/WASI/SDK and external isolation receipts must bind
to the eventual prototype head. A source/ownership gate failure keeps design only.
