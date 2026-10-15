# Concurrency and ownership

Immutable values, number components, object storage, Pointer tokens, documents,
settings, diagnostics and compiled schema snapshots have checked Sendable
conformances. Mutable evaluation/coding/parser/regex state belongs to one owned
invocation. A configuration facade must not hide a shared mutable coder or cache.

| Boundary | Contract |
| --- | --- |
| Synchronous parse/code/validate | Bounded work on the caller executor; async spelling alone does not offload |
| Async byte source | Caller-owned AsyncSequence of owned JSONByteChunk; one pull outstanding |
| Iterator | Exclusive mutation; sequence conditional Sendable only when all actual stored state qualifies |
| Borrowed bytes/Span | Synchronous local borrow, no storage in public results or crossing await |
| Async sink | Await full acceptance of each chunk; no queued fire-and-forget writer |
| Shared schema plan | Immutable; separate work/dynamic-scope/annotation/regex state for each evaluation |
| Scratch | Iterator/invocation-owned, finite live capacity and boundary reuse ceiling |

Caller-decoded non-Sendable models are valid in synchronous APIs. UserInfo needs
a bounded checked-Sendable representation; do not erase arbitrary Any into an
unchecked box. Operation reports are Sendable only when their result qualifies.
Library work has no default MainActor isolation or CPU-offloading convenience.
Synchronous calls use the caller executor.

Experimental composition root handles are borrowed, noncopyable and non-Sendable.
Their immutable graph is admitted once by the owning invocation; a private owner
reference prevents another invocation from using that admission. Root callbacks
hold no inout meter borrow across caller code. Handle lifetime never refunds
logical ownership. Scope and handle captures remain subject to compiler ownership
checks; the composition qualification records known Swift 6.4 call-site compiler
aborts separately from expected semantic rejections.

Cancellation checks occur at operation entry, before growth/suspension, on await
return and at most 1024 owned charged units apart. Native tests must exercise
inner numeric, codec and regex loops, not only wrapper cancellation. A clock
deadline is no substitute for enforceable inner checks. User callback work is
outside the library's instruction quota; document this boundary.

Run shared-plan and independent-facade concurrency tests. Verify sanitizer
options against the installed compiler before recording a lane as supported.
Broad @unchecked Sendable, preconcurrency imports and actor wrappers that merely
hide races are not acceptable repairs. If unsafe byte fast paths are chosen,
confine them, explain lifetime/alignment/tail invariants and prove scalar parity.
