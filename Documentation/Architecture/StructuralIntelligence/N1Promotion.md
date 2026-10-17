# Reconciled public-product gate

## Published-status annotation — 16 October 2026

JSONNavigation N1 is included in the published [1.6.0 release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.6.0)
at `f975ac1c5a18af9b422db0994cbc551fd37eee2f`. Its 56 authored public declarations
belong to the opt-in JSON-only library. The package has eight libraries plus the
CLI and eight DocC catalogs; see the [source authority map](SOURCE-AUTHORITY.md)
and [release qualification](../../Qualification/Release1.6.0.md).

The reconciliation and candidate decision below are preserved historical editions.
Their no-transition, qualification and separate-publication clauses describe those
sources and authorization boundaries, not the current availability of N1.
Later N2/N3/private P1 candidates have not been admitted by this annotation.
The A0 compiler failure below remains adverse evidence; publication of traversal
does not qualify a borrowed-context escape or repair a compiler failure.

The historical candidate decision below belongs to 5cf7897. Its no-transition
statement records that earlier authorization boundary. The owner subsequently
authorized one fresh-main Navigation integration and guarded merge after full
current-source qualification and protected review. The reconciliation preserves
all 56 declarations and adds no A0 interface. See [Integration](Integration.md)
for source mapping and the current gate; tagging/publication remain separate.

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
