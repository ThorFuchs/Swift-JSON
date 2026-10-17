# Experimental exclusive traversal reducer

The original borrowed noncopyable callback at e11f93f is blocked: an escaping
capture aborts Swift 6.4 code generation in SILGenCleanup in Debug and Release.
Type checking alone accepts it and cannot establish ownership safety.

The isolated recovery first tried an inout capability and Copyable reducer.
Explicit closure capture, consuming return, storage and copying
were rejected normally, but returning a bound nonmutating method still aborted.
That form is rejected. A standard-library-only reduced reproducer preserves the
failure. Nonescapable lifetime attributes also require experimental features on
the supported compiler; no flags or unsupported lifetime attributes are adopted.

The selected experiment uses a package-only `JSONTraversalOwnedReducer` with
mutating observation/finalization and an `inout JSONTraversalContext`. All exposed
capability operations are mutating: they require exclusive access to the one
invocation's mutable ledger, and Swift forbids turning them into bound method
values. The scope field is private; initialization is internal to Navigation.
Reducer state and Result remain Copyable, so neither can own the noncopyable
capability. No general borrowed owned-callback entry point is exposed.

`JSONTraversal.inspectOwned(scope:options:reducer:)` calls the existing traversal
executor, which creates exactly one original JSONReadScope and admission. The
context only delegates to that scope. No meter, admission, limit default, cursor
or mutable scope reference is returned. Owned errors latch on the original
health; finalization preserves the original failure even after a caught error
or attempted replacement. Scope invalidation runs on every exit.

At the isolated 31879e8 checkpoint, actual full Debug/Release `swiftc -c` passed
two positives and eighteen qualified ordinary negative diagnostics: return,
escaping closure, Sendable capture, forge, long-lived storage, bound method,
global storage, copy and external-package access per configuration. Final review
found that the two additional Task cases had stopped on an unused-throwing-task
warning, not the required ownership diagnostic. That evidence gap is preserved.
The corrected probe explicitly discards the Task handle and requires an actual
escaping-inout primary diagnostic. Every negative now matches the primary error
text, never echoed source or an unrelated warning. The complete matrix remains
two positive and twenty negative code-generation cases. All 47
Navigation functions passed Debug/Release, strict compilation and the public
consumer/DocC lane. The eight new functions prove every-counter no-op parity,
same-ledger work/finalization, inclusive quotas, output retention, terminal error
priority, cancellation, exact paths/spans and post-invalidation root/state release.
These are architecture-specific proofs, not a claim that the compiler bug is fixed.

The new capability is experimental and absent from the independent public
Navigation integration. Subsequent inspection work must reuse it without adding
an inner composition scope. All actual command/source/toolchain receipts remain
bound to their own checkpoint; later source needs its own applicable qualification.

Qualification provenance follows the established checkout_head helper: source
archives and Git-ownership refusals record null Git identity, with exact source
input hashes. They still execute the complete positive/negative codegen matrix.
No global safe.directory or repository-trust setting is changed. The initial
archive/container harness failures are preserved as failures in the return.
