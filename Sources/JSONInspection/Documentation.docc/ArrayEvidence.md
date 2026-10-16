# Observe array evidence

Select an existing array with exact typed components and distinguish source,
row and descendant coverage.

## Examine a complete array

```swift
let source = try JSON.parse(#"[{"x":null},{"y":1}]"#)
let report = try JSONShapeInspector(document: JSONDocument(root: source)).inspectArray()
precondition(report.result.rowCoverage == .complete)
precondition(report.result.traversal.completion == .restricted)
precondition(report.result.firstSeenColumns[0].present == 1)
precondition(report.result.firstSeenColumns[0].explicitNull == 1)
precondition(report.result.firstSeenColumns[0].missing == 1)
```

Rows are examined completely, while cell descendants are deliberately pruned.
Present includes explicit null. Missing uses observed object rows as denominator,
so scalar rows never create missing cells. Columns retain first-encounter source
order and decoded Unicode scalar identity, without Swift String normalization.

## Sample without certifying a suffix

```swift
let source = try JSON.parse(#"[{"x":1},{"x":2},false]"#)
let report = try JSONShapeInspector(document: JSONDocument(root: source))
    .inspectArray(sampling: .prefix(maximumRows: 2))
precondition(report.result.rowCoverage == .prefix(examined: 2, total: 3))
precondition(report.result.observedAllObjects == true)
precondition(report.result.traversal.completion == .visitorStopped)
precondition(report.result.sourceAdmissionComplete)
```

The full captured source is admitted once even for a zero prefix. Positive traits
describe only examined rows; the boolean suffix above disproves any whole-array
object claim. Empty evidence has nil positive traits. Structural rectangular width
says nothing about numeric cells, JSON Schema validity or projection admission.

## Select and bound owned work

```swift
let source = try JSON.parse(#"{"":[{"0":9007199254740993}]}"#)
let report = try JSONShapeInspector(document: JSONDocument(root: source))
    .inspectArray(at: [.key("")], maximumColumns: 1)
precondition(report.result.sourceSelection == [.key("")])
precondition(report.statistics[.workUnits] > 0)
precondition(report.result.firstSeenColumns[0].key == JSONKey("0"))
```

Root [] differs from the empty key. Numeric keys differ from array indices. Missing
and wrong-kind selections throw core JSONAccessFailure. Negative sample/column
configuration fails before admission. The default column cap is 100,000 inclusive;
zero is valid until an observed object field would be added. Quota exhaustion,
overflow and cancellation throw, with no partial successful evidence.

The inspector delegates to one original traversal read scope. Overlay v1 retains
256 logical bytes for summary, 192 per column plus exact UTF-8 key bytes, and core
path weights. Work includes row/member scans, exact key comparisons and finalization;
first-seen column lookup can be quadratic. Logical retained bytes are policy units,
not RSS or caller instruction quotas. Source spans require a coherent captured map;
a replacement root has no stale span. Every invocation owns independent mutable state.
