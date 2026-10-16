# Composition compiler diagnosis

Swift 6.4 aborts in `SILGenCleanup` when some implicitly named callback parameters
of noncopyable type are captured. The contextual function type says `borrowing`,
but the generated SIL attempts `copy_addr` on a value marked
`mark_unresolved_non_copyable_value [no_consume_or_assign]`. The ownership verifier
aborts before an ordinary ownership diagnostic can be emitted. JSON values,
resource accounting, Foundation and the private owner reference are not required
to reproduce this defect.

The [standalone reductions](../../Tools/CompositionQualification/CompilerReproductions)
use an empty noncopyable `Handle`, a borrowing callback and either an escaping
capture or a synchronous local function. The inferred parameter forms abort;
spelling `(handle: borrowing Handle)` makes the escape produce a normal diagnostic
and makes the synchronous local function compile. The original inferred public
API fixtures remain in the qualification gate.

## Library repair and supported spelling

Every composition instance method now explicitly declares `borrowing`. This
preserves the existing ownership convention and prevents the two bound-method
probes from aborting. `MethodEscape` receives the expected borrowed-self diagnostic.
`MethodBorrow` also receives a borrowed-self diagnostic even though its callee is
nonescaping. Its original positive expectation is retained as an unsupported
compiler call site; a diagnostic does not turn that requirement into a pass.
Use a closure literal instead of a bound method value.

Explicit callback parameter ownership avoids the other capture-lowering defect:

```swift
try JSON.withComposition { (scope: borrowing JSONCompositionScope) in
    try scope.withAdmittedRoot(value) { (root: borrowing JSONCompositionRoot) in
        let pointer = try scope.pointer(tokens: ["name"])
        return try scope.resolve(pointer, in: root)
    }
}
```

Five additional public probes exercise explicit ownership: three invalid escapes
must produce source-backed borrowed-parameter errors, while a local function and
a closure-literal method call must emit objects. They supplement the original
nine call sites and 18 semantic-negative programs.

Swift emits a bound method's primary borrowed-self error at `<unknown>:0`, with
the actual expression in a source note. Only the two bound-method fixtures opt
into that diagnostic shape. Classification requires the exact primary error and
the matching fixture's `closure capturing 'self' here` note. A setup error, a note
from another file, an object emitted for a negative program, or an abort cannot
satisfy the ownership rejection requirement.

## Ownership boundary

The public callback conventions remain borrowed. Scope and root types remain
noncopyable and non-Sendable; private owner identity, cumulative accounting,
selected-output reservations and terminal failures are unchanged. No compiler
feature flag or unsafe annotation is introduced.

Trials with owning callbacks or copyable facades are excluded from the repair.
Owning callbacks allowed a local scope to be moved, swapped with a nested
invocation and restored. That would reopen the accounting substitution boundary.
Adding nonescapability to borrowed noncopyable callbacks alone did not eliminate
the compiler abort. These alternatives cannot replace the current guarantees.

The remaining inferred captures still require an upstream compiler correction.
The gate stays blocked on those aborts and the unsupported bound-method positive;
the explicit spelling is a source workaround, not a claim that the compiler gate
has passed.
