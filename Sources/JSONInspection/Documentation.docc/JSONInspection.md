# ``JSONInspection``

Observe exact array evidence with explicit row coverage and one finite budget.

## Overview

Import JSONInspection separately from JSON. ``JSONShapeInspector`` inspects one
existing array in an immutable JSONDocument. It preserves exact keys and numbers,
and reports facts about examined rows. It does not infer a schema or admit a table
or numeric matrix. Sampling does not exempt any source from admission.

## Topics

### Inspect an array

- <doc:ArrayEvidence>
- ``JSONShapeInspector``
- ``JSONShapeSampling``
- ``JSONShapeArrayEvidence``

### Interpret the evidence

- ``JSONShapeRowCoverage``
- ``JSONShapeKindCounts``
- ``JSONColumnObservation``
- ``JSONShapeInspectionFailure``
