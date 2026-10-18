# Pull exact transformation results

Compile explicit source, then pull zero, one or many ordered native values.

```swift
import JSON
import JSONTransform

let plan = try JSONTransformProgram.compile(".[] | . + 1")
let root = try JSON.parse("[9007199254740993,0.1]")
let report = try plan.withExecution(input: root) { execution in
    var values: [JSON] = []
    while let output = try execution.next() { values.append(output.value) }
    return values
}
```

`empty` yields no result. `null` yields one present output containing JSON null.
The plan uses the same exact decimal and decoded-scalar rules as JSON and the CLI.
Nonterminating division is a language error; no approximate arithmetic is added.
The standalone public consumer at `Tools/TransformQualification` is available
in this feature candidate; it is absent from stable 1.6.1.

## Ownership and completion

All copies of an execution handle share one meter. A handle cannot replace the
owner of another invocation. Scope exit clears frames and the provider, releases
owned root reservations and invalidates data access through escaped handles.
Escaping is permitted but `next()` afterwards throws `configuration/scopeClosed`.
Only plans are Sendable; handles and output leases are not. The native compiler
rejected an initializer shape and crashed on a rejected borrowed escaping-closure
experiment; neither result is represented as a compiler fix or successful negative.

Keep each output handle alive while using its accounted source alias. A JSON copy
extracted from it, or a value handed off when the scope ends, is caller-owned.
A callback may stop early. Transform completion does not drain or certify an
external source: the CLI separately checks syntax, closing boundaries and EOF.

## Finite work and explicit providers

`JSONTransformLimits` supplies finite native and transform ceilings. Compilation
has its own bounded ledger. Each execution conservatively reserves compiler-held
plan bytes and shares work across root admission, pulls, provider values and
results. `used(_:)`, `statistics` and `remainingWorkUnits` expose cumulative counts
without exporting a mutable meter. Logical bytes are not RSS. Provider callback
instructions and upstream allocations are caller work.

Use `variables` at compilation and matching exact `bindings` at execution.
The optional `source` callback returns `JSON?`: nil means provider EOF; `.null`
is an input value. Only that callback supplies `input` and `inputs`. The engine
opens no files and reads no ambient process input. Async providers are not offered.

`JSONTransformFailure` distinguishes compilation, language, resource, cancellation,
provider and configuration errors. Operational failures bypass language catches
and latch. Catching a failed pull cannot yield a successful operation report.
`cancel()` likewise prevents later pulls and successful scope completion.
