# 1.8 bounded structural workflow qualification

Status: implemented local milestone, broader release qualification PARTIAL, on
isolated `codex/1.8-batches-and-store`.
No merge/tag/release/publication is commissioned or claimed. Source base is
published 1.7.0 `8557badef562cf2f059e964c113d4a7f60ecbe6c`, tree
`c914b8914c9130a3a07a3ed82fb41dde33c37402`.

The [contract](../Architecture/StructuralIntelligence/BoundedWorkflows1.8.md)
and [compiled public example](../../Examples/BoundedWorkflows) define this additive
wave. Twelve library products plus CLI, thirteen catalogs, empty root dependencies,
Swift6.4/language6 and Apple27 minima remain. Original NAV12 fixtures and49 metric
policies are unchanged. Current discovery adds24 named nonparameterized behavior
functions and one shared-state function to JSONInspection (214 roots,11 shared).
Original390 native/portable and353 WASI parameter invocations are unchanged.

## Milestone evidence

Private raw receipts stay in ignored `Artifacts/Release1.8` in the feature worktree.
Initial compiler reconciliation passed `swift build --target JSONInspection --jobs 2`
and20 then22 targeted native behavior functions. Those were unfrozen-source probes,
not final qualification. The independent sibling review requested native path-limit
admission on store reads and deterministic inner-loop cancellation. Both are
addressed in source; the final24 cases also pin nested snapshot scratch cleanup,
metadata aliases, self-cycles and narrow chains. Final gates must record exact
source manifests/commands/environments/events; no index entry implies a pass.

## Completed local milestone — 28 October 2026

Apple Swift6.4.2, Xcode27.2, macOS/SDK27 supported native preflight passed.
`Scripts/ci.py --lane structural-workflows` passed:24 exact new functions in
Debug and Release, original12 store functions with65 native-build parameter
invocations plus the separate strict-parser case in each configuration, preserved
26-command store compiler/consumer receipt, and12 public SwiftPM witnesses per
configuration. The new public qualifier also compiles the DocC example and six
ordinary public-boundary refusals per configuration. Policy/compile-only vectors
remain distinct from native evaluated outcomes.

`--lane structural-workflows-safety` passed24 ASan functions, one shared-state
TSan function and strict-memory compilation. Supplemental exact-event regression
passed all57 Navigation and214 Inspection functions in Debug/Release. The existing
CLI version case passed. The harness passed28 checks; site regressions passed12.
The affected Inspection DocC catalog compiled with warnings as errors. Compiled
public graphs contain301 authored Inspection declarations (139 added, none removed)
and56 Navigation declarations (unchanged), all documented. Three legacy Self versus
concrete-owner graph renderings were explicitly compared against unchanged owning
source files; no byte-identical graph claim is made. Full13-module extraction remains
pending. The independent sibling source review closed its path-limit/cancellation
findings; this is scoped agent review, not human release approval.

Preserve the original failed external-consumer attempt: its fixture placed a null
field outside the configured collections object and was correctly refused as an
unconfigured collection. The harness trapped on that uncaught error; it was not a
library/compiler crash. The successor scopes collections explicitly and passes.
Original attempt logs and source manifests remain in private evidence.

This status update changes only this qualification document after the passing
runtime receipts. Final checkpoint evidence must show that all product, test,
fixture, DocC and harness bytes match those receipts, and record the documentation
successor separately. No broader qualification pass follows from these local results.

## Required gates

- Scoped Debug/Release: `Scripts/ci.py --lane structural-workflows`, including
  original12 store functions/65 vectors, ordinary compiler refusals, public
  SwiftPM consumer and compiled DocC example.
- Scoped safety: `--lane structural-workflows-safety` (ASan24, TSan1, strict memory).
- Complete native, safety and docs lanes, current public API graphs and no
  removed public declarations; preserve Navigation's original56 and Transform42.
- ARM64/x86_64 Linux, supported WASI and Apple SDK/runtime scopes on the final
  source. Unavailable environments/storage remain blocked, not inherited passes.
- Clean source inventory, deterministic archive and Git-free external consumer.
- Measured capacity/performance before any improvement claim. Original1.7 P4
  waiver, loaded-host timing, partial Instruments profiles, streaming disposition
  and graph G4 HOLD remain historical and cannot qualify changed1.8 source.

The maintainer chose to continue implementation without reclaiming other
sessions' files. At kickoff about1.4GiB was free; fresh broad safety/docs/platform
builds may remain storage-blocked. Record actual attempts and unrun commands in
the private milestone report. No cleanup, weaker check or gate waiver is implied.

## Read-only store decision

The public surface promotes typed configuration, immutable admitted store/metadata,
owner-bound positions and typed failures. New operations are exact-ID lookup,
ordered value reads and complete finite BFS follow. Construction uses the original
eight phases, one exclusive ledger, duplicate timing and marker/target precedence.
The prior compiler-negative asserting profile invisibility is superseded by an
external private-read-scope refusal; the other original seven negatives and all
65 original vectors remain. Store/position forging is still forbidden. This is
an intentional additive promotion; it adds no product or runtime dependency.

Fixed metadata access and supplied callbacks are trusted caller work. Each later
query is independent of construction and other queries. Logical retained bytes
are conservative owned reservations, not process memory. No persistence, mutable
store, online resolution, asynchronous batch scheduler or durable token exists.
