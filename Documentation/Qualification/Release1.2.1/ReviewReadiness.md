# 1.2.1 review readiness

This branch is based on published 1.2.0, `25fb04f747e583209b4c4511abf39e11ef5b4f80`.
The completed [acceptance wave](AcceptanceWave.md) remains unchanged. This
closeout adds review records; it changes no library, test or qualification-harness
code and incorporates no sibling 1.3.0 work. Merge, tagging and publication remain
separate maintainer decisions.

## Proposed patch

The branch adds 126 Swift Testing functions to the 192-function baseline:
318 root functions, 173 parameterized invocations, 145 affected QA functions and
32 targeted shared-state functions. Six test targets cover five implementation
modules. Twenty integration functions depend only on the four public products.

The two production repairs are deliberately narrow:

- Best-effort schema diagnostics can omit oversized optional output without
  latching an owned resource failure. Ordinary invalidity remains a completed
  result; required work, retention and annotation failures remain terminal.
- A completely missing native schema resource bundle produces structured
  metaSchema failure instead of SwiftPM's generated Bundle.module fatal error.
  Location search is finite; all nine integrity pins remain enforced.

The public products, signatures, empty root dependency graph, Swift 6.4/language 6,
Apple 27 minima, Linux/WASI scopes, exact values/scalars, cumulative limits and
upstream notices remain unchanged. Typed Int128/UInt128 Codable remains explicitly
unsupported; exact JSONNumber projection is separately qualified.

## Fresh quiet-host attempt — 2026-10-14

Native preflight passed on macOS 27.0 ARM64, Swift 6.4
`swiftlang-6.4.0.34.1`, Xcode 27.2 `27B5019j`, SDK 27.2.
The third readiness attempt exited **2**. All five observations failed the
unchanged gate: CPU idle 14.84–30.72%, load1 17.56–19.29 on ten logical cores,
with competing Swift compiler/test processes. The gate requires every sample to
have at least 80% idle CPU, load1 at most five, no competing compiler/test/WasmKit
process, successful observations and no thermal warning. No other process was
stopped or reprioritized. **No new benchmark timings were taken.**

Both frozen release benchmark binaries match their original SHA-256 receipts;
the parent/current authored workload sources are identical. All evaluation/runtime
sources match the qualified diagnostic repair, except the later resource locator,
which is outside the timed validation loop. Plan compilation occurs before timing.
The retained protocol uses 32 issues, three warmups, nine samples of 1024 validations
and five alternating parent/current pairs; it discards no timing sample.

The previous longer diagnostic median remains **+11.9833%**, with pair changes
from −0.5332% to +73.2086%, above the unchanged **10% review trigger**. Retain the
correctness repair; attribution remains unresolved. A qualifying quiet-host
comparison is still needed before a 1.2.1 release decision. This branch can be
reviewed as a draft while that blocker remains. Historical streaming +10.9932%
and its existing reviewed disposition are unchanged. Equal logical retention and
owned work in the diagnostic pairs establish neither RSS nor caller-work caps.

## Subsequent measurement under competing load

The maintainer then explicitly requested running despite the busy host. The
unchanged frozen workload completed all ten processes, five alternating pairs,
and all nine samples per process without discarding any sample; the command
exited **0**. Median-of-run medians were 0.5761326 ms per validation for the parent
and 0.5664125 ms for the repaired evaluator: **−1.6871%**. Individual pair changes
were −10.7312%, +3.6821%, +0.3776%, +0.3787% and −2.1811%.

Fifty before/during/after host observations recorded CPU idle 2.61–58.56% and
load1 21.98–31.69 on ten cores. All before/during/after quiet classifications
failed. Every pair retained 32 issues, 7726 diagnostic bytes, 23833 evaluation
work units and 7152 peak logical retained bytes. Process CPU/context-switch
observations are scheduling context only.

Disposition: this loaded-host aggregate is below the unchanged 10% trigger, but
does not establish an intrinsic improvement or resolve the earlier +11.9833%
comparison. Preserve both observations and the correctness repair. The explicit
authorization to measure under load does not turn it into quiet-host evidence.
No threshold, quota, optimization or release gate was relaxed.

## Qualification and review scope

The passed [Native run](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38621245405)
and [Linux run](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38623417029)
remain bound to their actual historical heads. Fresh file comparisons confirm
754 library/test/consumer inputs are unchanged. Older Native receipts predate
some harness repairs; their reuse does **not** assert identical harness bytes.
Later native coverage, clean distribution/reproduction, Linux and WASI receipts
cover those repairs. The PR reruns current required Native checks and Linux lanes.

Five-module native coverage meets the 98% line / 95% region review targets without
removing unused-helper lines. Both Linux architectures retain their own complete
exports. Branch/MC/DC counters remain unavailable. The native mutation pilot
killed 26 selected behavioral mutants; it is bounded assertion evidence, not
exhaustive assurance. Fixed-seed replay tests are portable; the mutation pilot
itself was executed natively. WASI scoped QA is not a new sanitizer/corpus claim.
Physical iPad qualification remains deferred under the existing policy.

Review checks found no additional production/API change. Exact six-target
discovery, all five coverage denominators, actual exporter omission rejection,
49 finite cap probes, policy exclusions and invalid/error distinctions remain
explicit. Fresh Python harness tests (12 cases), public-distribution/privacy
checks and whitespace checks passed. Repository protection remains strict
`Native / native`, `Native / safety`, `Native / docs`, with resolved review threads
and no bypass; no settings were changed.

[Machine-readable readiness and receipt hashes](ReviewReadiness.json) bind this
attempt to materialized local evidence. Earlier source archives and evidence
bundles remain immutable. Current PR checks must pass before a separate merge
decision; this record grants no merge or release approval.
