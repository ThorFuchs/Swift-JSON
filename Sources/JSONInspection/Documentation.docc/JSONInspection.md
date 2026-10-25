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

### Capture complete source structure

- <doc:StructuralSnapshots>
- ``JSONStructuralSnapshotBuilder``
- ``JSONStructuralSnapshot``
- ``JSONStructuralRecord``
- ``JSONStructuralSnapshotFailure``

### Use complete structural projections

- <doc:StructuralProjections>
- ``JSONTreeProjection``
- ``JSONSparseTableProjection``
- ``JSONProjectionFailure``

### Use exact set and numeric shape views

- <doc:ExactProjections>
- ``JSONStructuralSetProjection``
- ``JSONNumericMatrixProjection``
- ``JSONP2ProjectionFailure``

### Experimental scope

- <doc:GraphExperiment>

### Source-bound directed graphs

- <doc:SourceBoundGraphs>
- ``JSONGraphProfile``
- ``JSONGraphProjection``
- ``JSONGraphFailure``
