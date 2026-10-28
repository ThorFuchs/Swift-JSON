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
in this unreleased source line; it is absent from stable 1.6.1.

## Shared language reference

The library and CLI execute the same jq-inspired subset. The shared
[command/filter reference](https://github.com/ThorFuchs/Swift-JSON/blob/15aa7e432cbb7173aa94b91e32badd1ab2695068/Documentation/Architecture/Release1.4/CLIReference.md),
[exact arithmetic contract](https://github.com/ThorFuchs/Swift-JSON/blob/15aa7e432cbb7173aa94b91e32badd1ab2695068/Documentation/Architecture/Release1.4/Arithmetic.md)
and [advanced filter contract](https://github.com/ThorFuchs/Swift-JSON/blob/15aa7e432cbb7173aa94b91e32badd1ab2695068/Documentation/Architecture/Release1.4/Advanced.md)
are pinned to the admitted consolidation source. This is not universal jq
compatibility. Unsupported syntax/functions produce typed compilation failures.
CLI options govern its host; they are not additional library parameters. In
particular, the public library has exact division and explicit caller-supplied
bindings/providers, with no ambient files or process input.

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

Accounting observations are snapshots, not ARC synchronization barriers. Output
leases enqueue refunds when their last handle is released; the invocation drains
that queue at its next checkpoint. `next()` performs that checkpoint even when it
must then throw the latched failure or `configuration/scopeClosed`. Reading
`statistics` or `used(_:)` alone does not drain pending refunds.

A returned operation report is an immutable observation at scope completion. It
may include a source reservation still held by an output handle at that time;
releasing the handle later does not rewrite that report. An escaped execution can
observe the drained refund after a guarded checkpoint, while data access remains
invalid. These logical observations do not delay ARC reclamation or measure RSS.

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

## Callback health

Input callbacks may read accounting observations and request cancellation. Their
observations are the fixed snapshot captured on callback entry, with the same
cumulative owned ledger. Snapshot work is charged before caller code runs.
Re-entering `next()` on the same execution throws `configuration/reentrantExecution`
and latches terminal health even if the callback catches it. Cancellation after
owned progress is checked before a callback value or EOF can be accepted.
The invocation reserves 1,152 logical bytes for owner/health/observation storage;
this logical weight is neither an allocation measurement nor a process RSS cap.
ASCII identifier names follow the compiler grammar and omit the `$` prefix.

## Reusing a plan under tighter limits

Compilation and execution have separate finite policies. Before publishing each
public output, native JSON admission checks that value under the execution's
policy, including compiled literals. A plan compiled with larger number/text
bounds cannot bypass a tighter invocation. This handoff traversal shares the same
work ledger. Per-value capacities retire into cumulative statistics; work never
resets. Temporary traversal reservations are refunded even on terminal failure.
The CLI retains its existing native writer admission on the shared job ledger.
