# Select explicit population positions

Evaluate the existing query language over finite indices, preserving original
positions even when values are identical. Selection convention V1 supplies
`[0,...,N-1]` as input and the complete population in the reserved `$values`
binding. Declare `values` at compilation; supply exactly the remaining names
through explicit bindings. Stored values acquire no engine metadata.

```swift
import JSON
import JSONTransform

let definition = try JSONTransformProgramDefinition.prepare(
    source: ".[] | select($values[.].enabled)", variables: ["values"]).result
let plan = try definition.compile().result
let row = try JSON.parse(#"{"enabled":true,"amount":9007199254740993}"#)
let report = try plan.withSelection(population: [row, row]) { scope in
    var positions: [JSONTransformSelectionPosition] = []
    while let position = try scope.next() { positions.append(position) }
    return positions
}
let ordinals = try report.result.map { try report.completion.ordinal(of: $0) }
precondition(ordinals == [0, 1])
precondition(report.completion.populationCount == 2)
precondition(report.completion.outputCount == 2)
```

The evaluator is the ordinary Transform VM. Queries must emit exact nonnegative
UInt64 ordinals within the population and the native Int range. Mathematical
integer spellings such as 42.0 and negative zero convert exactly. Fractions,
negative values, overflow, other JSON kinds and out-of-range outputs fail without
Double conversion. Order and repeats are preserved. Sort tie rules belong in
the query. The engine supplies no arbitrary transformed-value provenance.

## Completion and ownership

Pull nil explicitly. Returning after a prefix, even an empty prefix, throws
``JSONTransformSelectionFailure/incompleteSelection``. A late invalid output,
resource failure, cancellation, provider failure or reentry latches outside query
catch handling; a caller catch cannot create a completion witness. Ordinary query
language catches continue to work. A first operational failure takes precedence
over a later caller-body error. An otherwise uncaught body error keeps its identity.

Only ``JSONTransformProgram/withSelection(population:bindings:limits:source:_:)``
creates a report and completion after EOF. Their initializers and position/scope
construction are inaccessible to public callers. Completion verifies a position's
invocation identity through ``JSONTransformSelectionCompletion/ordinal(of:)``;
identical population values from another invocation still throw foreignPosition.
That constant metadata inspection is caller work and does not reopen the VM or
retroactively change a completed invocation.

A position retains the admitted population and its output-slot lease after scope
exit. A completion retains identity/report storage, not the population. Copies
share reservations. Escaped scopes and closures cannot resume pulls after close.
Use ``JSONTransformSelectionScope/report()`` to settle deferred ARC refunds and
observe actual native counts after success, failure or cancellation. Work never
refunds. Completion statistics are the successful close-time snapshot, not an
automatically updating post-ARC view. Keep the appropriate handles alive while
using accounted aliases. Scope, positions and completion are non-Sendable;
immutable compiled plans are Sendable and support independent concurrent scopes.

## Policy and providers

``JSONTransformSelectionLimits`` defaults to 65,536 population values and balanced
Transform/native limits. Population admission, index slots, all VM pulls, native
numeric validation, output slots, provider admission and completion storage share
one invocation ledger. A query producing no results still admits the whole
population. The original 49 core caps remain additional finite policies.
Logical weights are not heap allocation sizes or process RSS.

An optional explicit source callback serves the existing input/inputs operators.
Nil provider output means EOF; JSON null is a value and fails if emitted as an
ordinal. Providers may influence selection but cannot enlarge the declared
population. Their own instructions and already allocated values are caller work.
Provider values and calls triggered by evaluation remain subject to cumulative
native/Transform admission and input/work limits. Provider failure/cancellation
stops further callbacks; a caught reentrant pull also fails the invocation.
During the callback, report/used/remainingWorkUnits expose a prepaid entry snapshot.

This is a finite selection channel, not a stable Content ID, locator, read grant,
persistent execution, unbounded sort/stream guarantee or downstream admission.
The selection convention revision is separate from the definition/dialect revision
and the complete effective compilation/execution policies.
