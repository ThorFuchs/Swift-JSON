# JSONTransform extraction and release-candidate history

## Current 1.7.0 candidate disposition

The accepted 42-declaration public API and one compiler/VM are frozen in the
unpublished 1.7.0 candidate. CLI adapters preserve the original cumulative job
ledger. The former prototype/checkpoint descriptions below remain historical;
the final guarded engine includes terminal refunds and native output admission.
[Candidate qualification](../../Qualification/Release1.7.0.md) requires fresh
source-bound final QA and records the one-time explicit allocation-instrumentation
waiver. Unknown allocation events/bytes/overhead are not passed measurements.
No merge, tag or publication is implied.

## Historical extraction checkpoints

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

## Callback re-entry repair

A subprocess reproduced an exclusivity trap when an input provider re-entered
its public handle during the VM's inout context loan. This is a concrete rejected
checkpoint, not a passing negative case. The successor uses a separate private
health cell to reject re-entry before context access and latch the first failure.
The provider adapter observes health before/after callback execution. Callback
statistics are a bounded entry snapshot; cancellation does not borrow the loaned
context. Snapshot work (66 units) and fixed owner/health/snapshot storage (1,152
logical bytes) are admitted in the same invocation. No unsafe isolation, lock or
alternate evaluator is introduced. Public reports use the existing core domain.
Twenty-one public-engine behavior functions cover the repaired boundary, typed runtime
caps and a twenty-row exact dialect matrix. Independent qualification remains
source-bound; older successful receipts cannot qualify changed code.

## Common-scope ownership review

The common private context deliberately retains the CLI-only limits-file marker,
issue cap and committed-result report counters. Public construction cannot set or
observe those host fields. The shared context imports JSON only. Existing kernel files retain portable
Foundation utilities; the facade performs no ambient file/process I/O. Numeric division policy and frame/binding/collection
ownership remain kernel concerns. Retaining this one private scope preserves the
CLI's aggregate parse/compile/execute/write/diagnostic budget and refund authority;
creating a second public-runtime meter would break that composition. The health
cell stores only terminal state and observations, never a second quota ledger.
This is the selected extraction boundary, rather than a pending source move.

## Terminal output refunds

A separate public-consumer probe demonstrated that a last output alias released
only after scope failure could leave a pending reservation in observations. The
public pull now drains the existing deferred ARC refund queue before rethrowing
terminal health; work is never refunded and the original error still wins.
A regression covers resource, explicit-cancellation and uncaught-language failures,
including live alias ownership across scope exit and zero live bytes after release.

## Independent execution value policy

A separate real-engine consumer at 61125ed demonstrated that literals admitted
at compilation could bypass tighter invocation number-digit, string-byte and
exponent bounds. The public output boundary now uses native JSON admission on
the existing execution meter before publishing/counting a result. Per-value
capacity retirement preserves cumulative work/statistics. A failed traversal
refunds only its temporary frame reservations. The private compiler/VM and CLI
host path remain unchanged. Regressions qualify inclusive literal boundaries,
terminal latching, zero publication, cumulative traversal work and cleanup.
