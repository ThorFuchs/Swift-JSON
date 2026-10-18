# JSONTransform extraction checkpoint

This feature-branch API is provisional. Stable 1.6.1 and development main remain
separate authorities. This source adds JSONTransform to the nine development
libraries; it does not remove JSONInspection or import another candidate.

The chosen extraction prototype uses one private JSONFilterRuntime kernel. JSONTransform owns an
opaque Sendable `JSONTransformProgram` and scoped guarded
`JSONTransformExecution`. An execution pulls `JSONTransformOutput?`: nil means EOF,
while a present handle may contain JSON null. Handles share source leases and are
not Sendable. JSON extracted from a handle is caller-owned; the scope's logical
accounting is not RSS and does not meter arbitrary callbacks.

`compile(_:variables:limits:)` has its own finite compilation ledger. The plan
conservatively reserves its compiler-retained bytes in each standalone execution.
`withExecution(input:bindings:limits:source:_:)` owns one cumulative native meter
across admission, every pull, provider value and result. It returns a native
operation report. `used(_:)`, `statistics` and `remainingWorkUnits` expose counters
without exporting a meter. `cancel()` latches an operational failure. Catching a
failed pull cannot make scope completion successful. Provider EOF is distinct from
JSON null; callback work and upstream allocations remain caller-owned.

For CLI composition the same program offers package-only `compileAccounted` and
`makeAccountedExecution` adapters borrowing the existing noncopyable operation
context. They invoke the same compiler and VM. There is no fresh per-record meter
and no second evaluator. The host still owns files, framing, source draining,
output, process statuses and the sixteen original CLI metric names. All 49 core
metrics remain unchanged. Package-only CLI aliases preserve existing host tests
and ownership probes during migration; these are not public API.

Option B (one common private operation scope) is selected for the spike over a
second transform sub-ledger or per-next meters. Borrowing only the raw native
meter would also need to carry live frame/binding/collection counters and the
refund queue; splitting them risks two health/ownership authorities. The current
common scope preserves those invariants. Host metadata still stored in that
private context needs further ownership review before final API freeze.

Swift 6.4 rejected a throwing initializer that conditionally initialized a
noncopyable owner across a catch. A factory now fully initializes the owner before
fallible preparation. No unsafe annotations or compiler flags were introduced.
A standalone external consumer in Tools/TransformQualification and eleven Swift
Testing functions exercise the actual engine. The private execution receipts bind
their exact source revisions; a working spike is not full release qualification.

JTX-2 through JTX-7 remain separate qualification gates. No merge, tag, publication,
Linux/WASI runtime support, complete conformance, controlled performance or final
API acceptance follows from this checkpoint.

## Rejected ownership experiments

The first inout execution callback compiled but allowed nested scope swapping:
two results escaped an outer results cap of one. Its local prototype checkpoint
is retained as rejected; its green behavior tests do not qualify ownership.
A noncopyable borrowing facade prevented replacement and passed eleven behavior
tests. However Swift 6.4 (swiftlang-6.4.0.34.1) crashed with exit -6 in SILGenCleanup
when a callback captured the borrowed facade into an escaping closure. That is
a failed compiler gate, not a valid negative diagnostic or a compiler fix.
The next bounded experiment is a guarded, non-Sendable reference handle; copies
must share one state and scope exit must invalidate it and release root/provider.

## Guarded-handle successor

The current provisional API uses a final, non-Sendable reference handle. Copies
share exactly one private noncopyable ledger. Callback parameters cannot substitute
the invocation owner. Scope exit invalidates next(), clears provider/VM state and
releases reservations; observation remains available. This trades static lifetime
rejection for explicit guarded invalidation. Thirteen real-engine behavior cases
include same-ledger aliases, escaped-handle invalidation and weak provider release.
The rejected noncopyable compiler crash remains an unresolved toolchain finding.
The full native/safety/docs/Linux/WASI/performance/reproduction gates remain open;
source-bound receipts, including failures, are in the private return. Do not infer
release readiness or final API freeze from the prototype.
