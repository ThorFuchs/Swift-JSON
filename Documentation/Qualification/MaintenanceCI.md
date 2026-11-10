# Maintenance CI and build incidents

The `main` branch carries development source. The `release/1.6` branch carries
API-compatible maintenance of the eight-library 1.6 line. Version headings and
source branches do not establish publication; official release metadata and
matching assets identify a published stable version.

## Automatic qualification

Native and Linux workflows run on pushes to `main` and `release/1.6`, on pull
requests, and through their existing manual dispatch. Each source line retains
its own product inventory and complete source identity. Require Native native,
safety, docs and Git-free archive checks plus normal/safety Linux checks on both
ARM64 and x86_64. Match receipts and event populations to the actual PR or branch
execution, keeping synthetic merge and admitted commit identities distinct.

The native documentation lane qualifies both lines. Its Pages publication job
keeps the existing main-only condition; maintenance pushes must not replace the
development website. A skipped Pages publication on a maintenance branch is
expected. Required product qualification must still execute and pass.

Composition has a separate execution matrix lane on macOS and on each Linux
architecture. The native, safety, docs, archive and composition commands retain
their existing 60-minute execution limits; no command or fixture is omitted.
The existing `Native / ...` and `Linux / ...` check names are final gates over
their complete workflow execution matrix. They run even after a dependency fails
and accept only its `success` result. Failure, cancellation, a skipped execution
or a missing result cannot produce a successful required context. Consequently,
one failed execution makes all of that workflow's final gates fail. Inspect the
`Native execution / ...` or `Linux execution / ...` job and its receipts for the
specific cause. Pages also waits for the final native gates, with its main-only
condition unchanged. No repository protection setting is changed by scheduling.

This separation follows the 1.8 PR74 execution at `48dca4d`: the normal native and
both Linux lanes passed, but the native and x86 Linux jobs reached their one-hour
job limits during the appended composition step. Native's nine-command composition
receipt had completed just before cancellation; x86 had completed only five of
nine commands. Preserve those cancelled checks and partial receipts. They are not
retroactively green, and the successor must qualify its actual source. Moving
the unchanged composition commands to a separate job does not waive them or
extend a timeout. It does not qualify held runtime/performance/allocation gates.

If an expected automatic run is absent, inspect the branch/event/commit and
workflow filters. Existing manual dispatch may qualify the exact source while
investigation proceeds, but it does not prove that automatic triggering works.
Do not change protections or acceptance criteria to obtain a passing status.

## Interpret observations accurately

A watcher timeout, failed status request or unavailable artifact is an observation
failure. Query the same run and attempt to learn the actual job state. Use completed job conclusions for CI status and the failing command/receipt to
classify build, test or infrastructure failures.
Never request another execution merely because the observer disconnected.

Wait for evidence collectors before comparing their outputs, and complete asset
assembly before checking links/hashes and sealing a return. Record missing
measurements as unavailable rather than assigning inferred values.

## Retain build incidents

One Linux Swift 6.4 build-planning SIGSEGV was observed in
[the original job](https://github.com/ThorFuchs/Swift-JSON/actions/runs/39039959928/job/117417228489).
The complete unchanged normal and composition scope subsequently passed in
[a separately recorded execution](https://github.com/ThorFuchs/Swift-JSON/actions/runs/39039959928/job/117469420886).
[Upstream Swift Build issue 1786](https://github.com/swiftlang/swift-build/issues/1786)
describes a corresponding Linux planning/libdispatch crash family. Signature
correspondence supports investigation; it does not prove the exact corrupting
operation in this incident. No library source repair or upstream fix is claimed.

For a new incident, preserve source/tree, image/tool versions, exact command,
exit/signal, full log and execution identity. Distinguish build-process crashes,
frontend diagnostics, expected compiler rejections, runtime failures and test
assertions. Any justified unchanged-source reproduction is a separate recorded
attempt under a bounded plan. Preserve failures, stop on recurrence, and never
retry indefinitely or weaken gates. A toolchain/backend/flag change needs its
own reviewed qualification; a later pass does not rewrite the original failure.

## Maintenance publication

Use normal reviewed PR integration and qualify the actual resulting maintenance
source. Preserve old candidates and bind final source, documentation, evidence,
notes and checksums to the selected release target. A clean revision consumer is
preparation; verify exact version-tag resolution after publication. Follow
[the release process](../../RELEASING.md) for deliberate tag/release publication.
