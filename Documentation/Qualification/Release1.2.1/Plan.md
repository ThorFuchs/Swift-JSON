# 1.2.1 test expansion plan

Build on the audited `1.2.0` snapshot without changing its public API, products,
finite profiles, dialect or supported-platform scope. The release focus is tests,
qualification harnesses and accurate evidence. This document proposes work; the
new suites are not implemented or qualified yet. See [audit](Audit.md),
[measured baseline](CoverageBaseline.json) and [acceptance matrix](AcceptanceMatrix.json).

## Definition of completion

The aim is near-complete evidence for observable contracts and high-risk decisions,
not a promise to execute every possible JSON input. Every matrix row needs positive,
negative and applicable resource/cancellation cases with an independent expected
result. Every meaningful new defect gets a minimized regression. Existing tests,
fixture pins, policy counts and release history remain intact.

Use these proposed numerical review targets, alongside semantic acceptance:

- At least 98% authored executable-line and 95% region coverage **per module** on
  the supported native root suite, with no regression in covered obligations.
- Every zero/unmapped or remaining uncovered source path has a recorded disposition:
  missing test, declaration/data-only mapping, platform-specific path, verified
  unreachable guard or genuinely unused implementation. Exemptions need reasoning
  and evidence; do not broadly exclude error handling or generated lookup algorithms.
- All documented high-risk contract/decision rows and all 49 metric-owner rows
  have meaningful assertions. Branch/MC/DC percentages cannot gate this compiler
  because it emits no counters for them.
- Coverage is a review trigger. A narrowly justified path may remain uncovered;
  no weaker assertion, source removal or test-only call is allowed to make a badge green.

The two unreferenced helpers require disposition before deciding an active-code
denominator. Keep the unadjusted baseline visible even if a later reviewed cleanup
removes them. Generated tables remain a separate stratum with integrity/vector
evidence. Documented public-symbol coverage is not test coverage.

## Work packages and sequence

### T00 — trustworthy measurement and contract ledger

Implement a coverage lane/export helper with exact module and executable membership.
Collect all five binaries and the merged profile on this Xcode backend; support the
actual observed Linux layout separately. Normalize public paths and bind exports
to source hashes, compiler/SDK, command exits and exact test discoveries. Verify
that an intentionally omitted binary is rejected by the harness. Retain raw output
and classify unavailable branch counters explicitly.

Maintain a machine-readable expected discovery map. Update native, safety, QA and
WASI consumers together when adding tests; preserve required check names, all 49
cap probes and exact parameter/vector cardinality. Do not replace existing checks
with nonzero/exit-zero assertions. Record the two unused-helper decisions separately.

Deliverable: measured baseline/diff, complete contract rows and reliable public
coverage artifacts. No dependency on new product behavior.

### T01 — native Codable, foreign bridges and exact value entry points

First implementation wave, because it addresses the largest measured active gap:

- Explicit keyed/unkeyed/single-value models; nested keyed/unkeyed containers from
  both parents; superEncoder/superDecoder with and without a key; empty containers,
  decodeNil index movement, end-of-container and wrong-kind paths.
- Nonthrowing container operations that latch an owned failure: catch attempts
  must not certify a result or reset the invocation ledger. Distinguish recoverable
  ordinary type/caller errors from terminal owned failure/cancellation.
- Verify CodingKey identity, contains/allKeys and complete coding paths, including
  scalar-distinct and numeric keys, unknown keys and absent/null/model mismatch.
- Controlled foreign Decoder/Encoder probes: Int64→UInt64→Decimal fallback, exact
  rejection when none can represent a number, six JSON kinds and nested paths.
  Preserve external-coder ownership/fidelity boundaries; no hidden Double fallback.
- Exercise literal/convenience and overload paths through observable values and
  bounded admission, not only direct constructor calls. Extend integer-width,
  finite rounding/extreme/tie and Decimal precision matrices with fixed expected
  vectors. Compile any additional generic integer type before claiming support.

Favor parameterized Swift Testing matrices. Suggested scope: 25–40 focused
functions covering many named vectors; this is sizing, not a final cardinality gate.

### T02 — diagnostics, source maps and operation-specific budgets

Check category/code/metric, attempted usage or overflow nil, full typed path and
UTF-8 byte coordinates for contractual errors. Cover CR/LF/CRLF, multibyte scalars,
escaped keys, nested arrays and source invalidation. Test preview redaction before
traversal, byte/depth/node exhaustion, completeness and marker-fit boundaries.

Extend the existing 49-owner matrix with small real-operation N−1/N/N+1 vectors
where meaningful. Preserve exceptions: zero scratch succeeds; invalid quantum is
configuration failure. Test admission, active peaks, scratch refund, nonrefunded
work, subsystem/aggregate composition and terminal refusal after caught errors.
Use synthetic ledgers for UInt64/Int overflow; never allocate Int.max-sized fixtures.
Calibrate success and failure with the **same complete operation**, avoiding the
earlier exact-versus-rounded calibration mistake.

### T03 — schema and regex decision combinations

Add a bounded decision matrix for applicators, references and annotations:
successful/failed branches, anyOf multiple successes, oneOf zero/one/multiple,
not/if/then/else, contains/min/max, dependencies and unevaluated locations.
Combine with flag/basic output, collected annotations and complete/best-effort
diagnostics. Ordinary invalidity remains a completed result; an exhausted branch
must never become invalidity or a passing alternative.

Expand lexical base/resource transitions, Pointer/anchor and percent-decoding,
dynamic shadowing, productive recursion, immutable registry replacement and plan
reuse after success/invalidity/operational failure. Test raw/compiled inspection
without inference/default insertion, including absent/null metadata and budgets.
Existing nine cumulative schema-builder regressions remain; add only new composed
interactions rather than duplicate them.

Regex expansion targets private VM decisions: nullable/count repetition, nested
lookarounds, capture reset/unset/rollback, forward/backreferences, directional
lookbehind, anchors/line terminators, exact Unicode identifiers/properties and
candidate/start-position quotas. Expand paired positive/no-match and malformed
cases using independently produced, pinned oracle fixtures. A newer Node parser
does not redefine the advertised ECMA-262 2020 grammar. Preserve Unicode 13 and
the unavailable WASI sanitizer disposition. No engine, flag or fallback expansion.

### T04 — strict streaming and transactional Patch

Build reusable finite, checked-Sendable actor gates for a held source/sink. Assert
pull/generation/handoff counts while suspended, then release, throw or cancel.
Always unblock gates in cleanup; use an external process watchdog for hangs.
No arbitrary sleeps and no shared mutable test singleton. Include repeated next
after terminal errors where defined, no later pulls/writes, no completion and
the already accepted prefix. Do not claim to cancel an arbitrary caller producer.

Extend every-single-split cases with bounded seeded multi-part partitions and
empty chunks. Cover UTF-8/escapes/exponent/duplicate boundaries, trailing whitespace,
CRLF/final NDJSON line, malformed later records, lifetime quotas and exactly-once
root-array completion. Generated large streams retain at most admitted chunks and
current elements; no preloaded large fixture is memory evidence.

Patch matrices cover each operation against objects, arrays, existing/removed
roots, missing parents/targets, same-path move, descendant moves, index ordering,
escaped/scalar keys and wrong/missing operation fields. Expand normative RFC 6902
and all selected RFC 7396 Appendix vectors with provenance before adaptation.
Add bounded model/oracle sequences, copy independence, intermediate failure
rollback and repeated-stage work/retention checks. Root absence never becomes null.

### T05 — portable end-to-end Swift Testing suite

Prefer a new **test target only**, dependent on the four public products, without
@testable/private-meter imports. JSONRegexRuntime participates through public
schema pattern evaluation; its direct private unit suite stays separate. An
additional test target creates no library product or runtime dependency.

Implement at least these independent scenario families:

1. Strict bytes→exact value→scoped model/presence→offline schema→Patch/Merge Patch
   →awaited writing→strict reparse, with golden final value/bytes and reports.
2. Exact Version 1 transport around the workflow, including scalar-distinct keys,
   number lexemes, large integers and absent/null state.
3. Immutable shared plan and independent worker invocations, mixing valid,
   ordinary-invalid and operational-error instances, then recovery on a new call.
4. Root-array/NDJSON ingestion into a **caller-owned staged** sink; a malformed
   tail, quota failure or cancellation prevents the test application's commit.
   Accepted chunks remain accepted; this adds no persistence/transport semantics
   to the library.
5. Public remaining-work composition with success at N and failure at N−1,
   separate subsystem ceilings and accounting version. Stop a failed composition
   because failed public work supplies no successful report; never reset its budget.
6. Fresh packaged resource/distribution consumer, including structured missing or
   corrupted resources and exact installed bundle layouts.

Use named deterministic fixture IDs and fault points before/after each owned
boundary or await. Aim for 12–20 focused functions; derive actual final counts
from discovery, not from this estimate. Existing examples/20 frozen vectors remain
independent consumer gates and do not establish downstream MCP conformance.

### T06 — adversarial assurance and assertion quality

Add bounded, fixed-seed valid-model generators and invalid-byte mutations with
minimized replay files. Use explicit oracles: mathematical fixed vectors, ordered
member lists, normative results and independent regex fixtures. Round trips through
the same implementation alone cannot rule out matching encoder/decoder bugs.

Run a pilot of 20–40 deliberate single-site mutants in disposable worktrees:
inclusive bound, dropped charge/checkpoint, swallowed operational error, erroneous
annotation merge, canonical key collapse, early completion and staged publication.
Record selected/killed/survived/equivalent/unbuildable/timed-out separately.
An unbuildable mutant is not a behavioral kill. Minimize and add real assertions
for surviving non-equivalent mutants. Expand the pilot only if it finds useful gaps;
do not make an arbitrary mutation percentage the release's sole evidence.

### T07 — platform qualification and closeout

Run affected native/debug/release, ASAN, strict memory safety, broadened targeted
TSan, docs/consumer and independent lanes with exact new counts. Execute actual
Linux ARM64/x86_64 and the pinned WASI hosts with their established distinct scopes.
Apple SDK/simulator and disk tests follow the existing policy; physical iPad remains
deferred. New native percentages do not imply Linux/WASI/device coverage. Source
changes discovered during tests need their own regression/fix/requalification.

Produce the revised coverage/contract ledger, case/policy counts, raw commands,
toolchains, source/fixture identities, mutant dispositions and test runtime/flake
observations. Preserve required Native check names and the existing 10% performance
review policy. Tests-only changes need no invented production benchmark rerun;
any production fix receives affected validation/calibration. Release tags and
publication remain separate maintainer actions.

## Execution and review structure

Recommended local/PR decomposition: T00 harness; T01+T02 core; T03 schema/regex;
T04 Patch/streams; T05 public integration; T06+T07 acceptance/evidence. Start the
first executable increment with explicit Codable containers and precise failures,
then held I/O gates. Keep test additions cohesive and reviewable; do not author all
new tests in one unreviewable batch or add functions merely to meet a count.

Use fast deterministic PR matrices, full independent/native/Linux lanes for
acceptance, and bounded larger adversarial runs separately. Preserve every
baseline case/pin. Explicitly record scheduling/quota budgets for tests themselves.
No new library dependency is needed for a small seeded generator or test gates.

The patch work stays on the 1.2.0 base. If main advances to a new feature release,
prepare 1.2.1 from a maintenance branch; do not incorporate or revert later
features to make a patch. Port applicable test commits forward only after reviewing
new semantics, counts and CI conflicts. The exact target branch/merge/release
actions are resolved at the release step; this plan does not authorize them.

## Scope preserved

Swift tools/compiler 6.4+, Swift language mode 6, Apple SDK/platform 27+, qualified
Linux/WASI hosts, four products, private regex, empty root dependency graph,
Apache-2.0/notices, exact number/scalar identity and finite cumulative budgets.
No JSONHTML/1.3 features, MCP/HTTP/UI implementation, new platform/backend,
online schema resolver, E11/E12 or optimization selection belongs in 1.2.1.

The exhaustive-input problem is unbounded. Completion means every agreed contract
row and critical decision is evidenced, every uncovered path is accounted for,
and independent/operational/platform gates pass with honest limitations.
