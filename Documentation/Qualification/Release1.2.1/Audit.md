# 1.2.0 test audit for 1.2.1

Audited source: tag `1.2.0`, commit
`25fb04f747e583209b4c4511abf39e11ef5b4f80`. This is an audit and proposed
test expansion; no new behavior is selected or new acceptance gate declared passed.
The scope is four public products and the private JSONRegexRuntime target.

## Measured native baseline

The source inventory has **192 root Swift Testing functions in 52 files**, plus
**173 parameterized invocations**. These numbers are separate from the thousands
of vectors executed inside individual functions. A fresh instrumented native run
passed the same exact discoveries using Swift 6.4, Swift language mode 6,
macOS 27.0, Xcode 27.2/SDK 27.2 and Apple LLVM 21.0.0.

| Implementation module | Functions | Test files | Authored executable lines | Covered lines | Line coverage | Region coverage |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| JSON | 104 | 19 | 3,443 | 3,243 | 94.19% | 88.85% |
| JSONSchema | 51 | 18 | 2,410 | 2,361 | 97.97% | 93.62% |
| JSONRegexRuntime | 12 | 5 | 659 | 648 | 98.33% | 92.95% |
| JSONStreaming | 14 | 6 | 232 | 225 | 96.98% | 94.80% |
| JSONPatch | 11 | 4 | 185 | 179 | 96.76% | 90.57% |
| Total | 192 | 52 | 6,929 | 6,656 | 96.06% | 91.39% |

These are **native root-suite execution measurements**, not assertion coverage,
branch coverage, public-consumer coverage or proof of every platform path.
Compiler-emitted executable lines differ from physical source lines.
Generated Unicode tables are reported separately. The regex table's emitted
lookup regions were covered; that does not prove every table entry was exercised.
The generated IDNA data file has no emitted executable mapping in this export.
Five declaration-only enum files also have no mapping; their observable cases
remain part of behavioral tests rather than being silently treated as covered.

### Coverage tooling finding

On this toolchain, `swift test --enable-code-coverage --disable-xctest` passed all
five bundles, but SwiftPM's default JSON export contained only JSON/Patch mappings.
An explicit LLVM export against **all five instrumented test executables** and the
merged profile produced the table above. Any future coverage lane must verify
module/file membership and reject a partial export before calculating percentages.
LLVM emitted zero branch and MC/DC counters for Swift here: these metrics are
**unavailable**, not 0% failure or 100% success. Regions provide a useful signal,
with semantic decision matrices and mutation checks supplying additional evidence.

The machine-readable [baseline](CoverageBaseline.json) retains counts, exact
numerators, hashes, toolchain and export limitations. Raw profiles/exports and
command receipts remain local maintainer artifacts, outside source archives.

## What is already strong

- **Exact values and codec:** scalar-distinct keys, ordered objects/equality,
  duplicate timing, machine boundaries, binary halfway/subnormal fixtures,
  compact exponents, exact divisibility, malformed UTF-8/grammar, controls and
  representative every-byte splits. Wide-object tests cross real metadata
  thresholds and inject collisions, growth refusal and cancellation.
- **Coding and persistence:** native/foreign fidelity distinctions, presence,
  string-key collapse rejection, guarded read scopes, caller errors, Base64
  canonicality, calendar strategies and exact Version 1 fixtures. The existing
  QA wave includes 192 seeded documents, 772 small-integer spellings, 259 Base64
  fixtures and 1,152 padding-bit mutations.
- **Schema and regex:** full selected Draft 2020-12 input execution, productive
  versus nonproductive references, dynamic scopes, evaluated locations,
  successful-branch annotations, output policies, exact assertions, formats,
  declaration inspection and immutable plan sharing. Nine schema-builder cases
  already test cumulative construction/admission, retention and terminal failure.
- **Budgets and safety:** all 49 profiles/arithmetic boundaries, all 49 active
  public cap outcomes, UInt64 versus Int capacity classification, aggregate work,
  refunds/peaks, atomic overflow and inner cancellation after counted progress.
  Native/Linux ASAN and six shared-state TSan functions passed for this source.
- **Patch and streaming:** all six RFC 6902 operations, root removal versus null,
  staged rollback, intermediate caps, RFC 7396 examples, index transitions,
  malformed tails, strict NDJSON, lifetime quotas, generated large streams and
  accepted-prefix sink cancellation.

The independent evidence is substantive and must be preserved:

| Input or lane | Existing executed scope |
| --- | --- |
| JSONTestSuite | 318 observed; 287 evaluated successes; 31 policy cases |
| JSON Schema suite | 2,337 observed; 2,300 evaluated successes; 37 policy exclusions |
| Regex oracle | 31,824 cases over 442 patterns |
| Unicode normalization | 18,853 cases / 94,265 comparisons, Unicode 13 |
| Authored qualification | 82 semantic cases, nine budget/report cases, 4,396 malformed replays |
| Public schema consumer | 20 explicit roots: eight valid, twelve ordinary-invalid; two separate operational errors |
| External consumer | Four products, exact values/Codable/Pointer, schemas, Patch, streams/sinks and reports |
| Mobile qualification tool | Three Swift Testing functions, eight frozen public fixtures and real three-process disk phases |
| WASI tool | 13 public functions on both hosts; Node full roots/independent suites; narrower WasmKit scope |

Case counts are not added together as a coverage score. Some workloads overlap.
Policy exclusions never count as evaluated successes; validation false remains
distinct from compilation, evaluation, resource and cancellation errors.
The tools are separate packages; they do not add root dependencies or products.

## Concrete gaps and review items

| Priority | Observation | Evidence and implication |
| --- | --- | --- |
| P0 | Codable container paths need explicit matrices | Encoding containers: 37.80% lines / 44.32% regions; decoding: 75.61% / 56.52%. Existing superclass/synthesized models do not exercise every nested/unkeyed/super-for-key and latched nonthrowing-container path. |
| P0 | Foreign bridges need controlled coder probes | JSONCodableBridge: 66.67% lines / 62.73% regions. Native passthrough is strong; explicit external decode/encode fallback and failure paths need precise assertions without treating Foundation as JSON authority. |
| P0 | Suspended I/O needs stronger causal tests | Existing successful sink uses Task.yield; failure and cancellation tests are useful. A held sink/source gate can prove no extra generation/pull/handoff occurs before acceptance, including error/cancellation on resume. |
| P0 | Some errors are asserted only by broad type | `#expect(throws: JSONFailure.self)` is often appropriate but can miss the wrong category/code/metric/location. Expand high-risk guard assertions to the contractual fields. |
| P1 | Cross-product workflows are mostly helper smoke tests | Consumers/qualification already provide integration evidence. Add portable Swift Testing workflows with late failure injection, repeated invocation isolation and public cumulative accounting. |
| P1 | Patch deserves a systematic operation/state matrix | Most RFC operations occur in one chained function; same-path move, root-state transitions, malformed operation fields and more normative vectors should have independent expectations. JSONPatch.swift region coverage is 87.42%. |
| P1 | Schema output/reference combinations need decision coverage | High execution coverage does not prove all interactions among branch annotations, dynamic scope, output mode and diagnostic exhaustion. Shape classification has 77.66% region coverage. |
| P1 | Regex needs deeper behavioral checks, not more easy patterns | Authored line coverage is already 98.33%. Focus on capture rollback, nullable repetition, directional lookarounds and budget/cancellation combinations; preserve the ECMA-262 2020/Unicode 13 dialect. |
| P1 | Source/preview and overloads need focused expansion | Preview regions 82.99%, JSONDocument 86.49%, read cursor 87.06%, convenience entry points 66.67%. Check exact byte paths, completeness/redaction, wrong-type recovery and equivalent facade behavior. |
| Review | Two package-private helpers have no call sites found | JSONOperationContext and JSONFingerprint appear only at their declarations across Sources/Tests/Tools/Examples and have 0% coverage. Classify intended use or remove separately after review; do not fabricate test-only callers just to increase coverage. |

The 49 public cap probes currently verify active rejection at a zero cap, with the
explicit quantum/scratch exceptions. Arithmetic N/N+1 and overflow are already
tested for all profiles. The additional need is **operation-specific** N−1/N/N+1
and composed-lifetime coverage, not a claim that the 49 metrics lack tests.

## Boundaries of this audit

This is the 1.2.0 implementation audit. It neither audits nor edits later feature
work. Existing Linux ARM64/x86_64, native safety and WASI receipts are reused for
unchanged source; this fresh coverage run is a native debug measurement only.
It supplies no new Linux/WASI coverage percentages, device/RSS/performance claims
or independent security certification. Physical iPad remains deferred under the
approved policy. E11/E12 and unselected optimizations stay deferred.

Next: the [test expansion plan](Plan.md) and its [acceptance matrix](AcceptanceMatrix.json).
