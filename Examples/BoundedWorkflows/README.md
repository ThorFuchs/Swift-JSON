# Bounded structural workflows

A public SwiftPM consumer for the unreleased 1.8 source. It imports JSON,
JSONSchema, JSONNavigation, JSONInspection, JSONPatch and JSONTransform; no private
meter/runtime module or external dependency is used. Swift6.4/language6 and the
supported platform baselines still apply. Released1.7 does not supply the new APIs.

From the repository root:

```sh
swift run --package-path Examples/BoundedWorkflows BoundedWorkflows
swift run -c release --package-path Examples/BoundedWorkflows BoundedWorkflows
```

The twelve original witnesses preserve exact values, request order/repetition,
missing versus null, source-local ownership, bounded follow and public reports.
Six additional witnesses compose native schema validation, source interpretation,
transformation and Patch. They check a golden exact-decimal byte sequence, a new
owner/source wrapper after Patch, ordinary invalidity versus operational refusal,
root removal versus null, and terminal transform completion after a caught error.
The separate Swift Testing Integration cases also exercise declared-link corruption,
scalar-distinct collection names, awaited-sink cancellation and concurrent plans.

Each stage is its own native operation, not one implicit global pipeline ledger.
Caller array assembly and callbacks are ordinary caller work. Validate a schema
against its explicit offline registry/selected root before interpreting a source;
the store does not infer schema requiredness. Rebuild after Patch and obtain new
positions. Atomic publication into a sink is a caller staging decision.

## Counter and capacity observations

```sh
swift run -c release --package-path Examples/BoundedWorkflows BoundedWorkflows --capacity /tmp/swift-json-capacity
```

Use a new output directory. This writes cells.json and five deterministic fixture
files. The frozen matrix is in Documentation/Qualification/StructuralWorkflows1.8Matrix.json.
The qualification script independently verifies fixture hashes, cell identities,
expected results and exact/one-below request/work/retention boundaries.
Batch cells use1/8/64/512 requests against eight records. Follow cells use growing
chains with frontier1 and explicit depth/visited/results bounds; native balanced
and store construction defaults stay unchanged. A typed diagnostic refusal is
recorded as an incomplete capacity observation, never a successful closure.

Independent singular invocations report summed work/admission counters and the
maximum of their per-invocation retention. A batch reports its one original ledger.
Those quantities do not measure elapsed time, heap allocations, process RSS,
caller-held copies or jointly achievable default maxima. No performance improvement
or policy change follows from the counter experiment. The controlled native
performance gate remains a separate final-source requirement.
