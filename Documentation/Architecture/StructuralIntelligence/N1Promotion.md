# N1 public-product candidate decision

Approved for implementation: preserve all 56 existing public declarations, now
resolvable as the opt-in JSONNavigation library product. N1PublicAudit.json lists
the source-aware per-declaration decisions. New visibility is additive; this is
not a package version, merge approval or a published release.

The immutable traversal captures its source; paths describe that source, not a
replacement. Mutable options configure each independent invocation. Selection
indices and occurrence ordinals retain their zero-based, first-examined semantics.
Filters affect emission; coverage is per occurrence rather than a union proof.
Errors/cancellation throw; callback computation and retained copies are caller work.
Package read scopes, state, meters and qualification observers remain hidden.

P07 decision: keep the existing source-admission-before-depth/record-validation
precedence. An oversized source can therefore report its admission resource error
before an invalid option. Small-source invalid options report configuration errors.
No error precedence is changed during promotion. N2 sampling configuration has a
separate pre-admission check because it is a new contract.

Public SwiftPM consumer Debug/Release, isolation negatives, docs, all platform
lanes and Git-free reproduction must qualify the final source before recommending
release readiness. Actual outcomes accompany the return; this document is an API
review decision, not a claim that unfinished qualification has passed. Draft #34
and the immutable N1 anchor remain untouched. No PR-ready/merge/release transition.

A0 is independently blocked in the separate e11f93f borrowing spike: Apple Swift6.4
accepts an escaping borrowed capture at type checking and aborts in SILGenCleanup
during full compilation. A compiler crash is not a valid negative proof. No borrowed
context or JSONInspection code is included in this product candidate. Its executor
is byte-identical to the reviewed N1 anchor. The return preserves exact reproducer
commands, positive/runtime results and failed diagnostic outcomes.
