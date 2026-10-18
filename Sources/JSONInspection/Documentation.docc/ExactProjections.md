# Exact sets and numeric matrices

Build complete read-only views over captured source with exact values and finite work.

These APIs belong to unreleased development source, inside the opt-in JSONInspection
product. Import JSON and JSONInspection. Structural sets retain the first original
position in each exact equality class. Numbers compare mathematically; decoded
Unicode scalars remain distinct; objects compare independently of member order.
Arrays preserve order. Returned representatives keep their original number lexemes
and object member order.

```swift
let source = JSONDocument(root: try JSON.parse(
    #"[0.10,0.1,null,{"x":1,"y":2},{"y":2,"x":1}]"#))
let report = try JSONStructuralSetProjection.build(document: source)
let set = report.result
precondition(set.representativeIndices == [0, 2, 3])
let first = try set.member(at: 0).result
precondition(first.numberValue?.originalLexeme == "0.10")
```

`representativeIndices` are offsets in the original selected array. The argument
to ``JSONStructuralSetProjection/member(at:limits:)`` is a position in that
representative list. Positions are local to the captured source, not durable IDs.
Construction can require quadratic representative comparisons with deep exact
value costs; finite work limits bound the operation. There is no set algebra or
arbitrary-candidate membership API.

A numeric matrix requires every original row to be an array with the same width,
and every cell to be an exact JSONNumber. No string conversion, null padding,
arithmetic or dense numeric buffer is involved.

```swift
let document = JSONDocument(root: try JSON.parse("[[0.0100,9007199254740993],[-2,0.1]]"))
let matrix = try JSONNumericMatrixProjection.build(document: document).result
let transposed = matrix.transposed()
precondition(transposed.rowCount == 2 && transposed.columnCount == 2)
let number = try transposed.element(row: 1, column: 0).result
let integer = try number.integer(as: UInt64.self)
precondition(integer == 9_007_199_254_740_993)
precondition(matrix.transposed().transposed().isTransposed == false)
```

Transpose copies immutable orientation metadata and swaps logical coordinates.
Empty `[]` is zero by zero; `[[],[]]` is two by zero and transposes to zero by two.
The latter has no addressable cells. No JSON materializer claims that a bare empty
array can retain an independent nonzero column dimension.

Each factory owns one complete source admission, selection, validation and source
handoff under the existing traversal ledger. It admits unselected siblings too.
Each later member or cell read is a **new independent operation** that re-admits
the whole captured source. Repeating reads repeats that admission; constructor
remaining work is never silently reused. Budget and cancellation failures throw,
with no successful partial view or value-bearing report.

```swift
let source = JSONDocument(root: try JSON.parse("[[],[]]"))
let report = try JSONNumericMatrixProjection.build(document: source)
let matrix = report.result.transposed()
precondition(matrix.rowCount == 0 && matrix.columnCount == 2)
do {
    _ = try matrix.element(row: 0, column: 0)
    preconditionFailure("No addressable row")
} catch JSONP2ProjectionFailure.rowOutOfBounds(0) { }
precondition(report.statistics[.workUnits] > 0)
```

Negative configuration precedes source admission. Accessor bounds precede source
admission; matrix row bounds precede column bounds. Core selection errors,
``JSONP2ProjectionFailure`` shape/capacity/bounds errors, resource exhaustion and
cancellation remain distinct from JSON null and missing presence.

Defaults are inclusive: 100,000 set representatives; 100,000 matrix rows and
columns; 1,000,000 cells, plus all existing finite JSONLimits. Logical output
weights are 128 bytes per view, 8 per representative, exact typed selection and
one captured source. Read reports use core alias-return accounting; zero final
logical retention does not imply zero caller heap retention. These units describe
library policy, not process RSS or caller instruction quotas.

Batch access is deferred to NAV13 until an aggregate request/output contract is
qualified under one ledger. Independent reads are explicit bounded calls, rather
than an equivalent single cumulative batch. G4 timing remains HOLD; no speed or
throughput claim accompanies these views.
