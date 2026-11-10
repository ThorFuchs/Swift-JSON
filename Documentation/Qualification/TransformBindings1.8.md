# Transform bindings 1.8 — first sprint

Status: implemented and scoped native qualification complete; full release
qualification remains PARTIAL. This isolated candidate extends
`b8ddeb26042005a06360f50fcf20b1f840e66d1c` on
`codex/1.8-transform-bindings-s1`. The original batches/store candidate, its
PR and all earlier source-bound receipts remain independent and unchanged.
No merge, tag, publication, Content pin or downstream admission is implied.

The [contract](../Architecture/Release1.8/TransformBindings.md) defines the
candidate wire format and next selection boundary. Public additions are the
immutable source definition, finite definition policy, typed definition failures,
codec operations and compile-with-report route. Existing JSON/decimal/Unicode
and query semantics remain authoritative. The indexed-selection feasibility code
exists only in the test target; no public position, completion or selection API
ships in this sprint.

## Observed qualification — 29 October 2026

Supported host: macOS 27.0 arm64, Apple Swift 6.4.2
(`swiftlang-6.4.2.1.9`, driver 1.168.6), Xcode 27.2/27B48, SDK 27.2,
Swift language mode 6. Raw commands, exits, events, source manifests and failed
attempts are retained privately under `Artifacts/TransformBindingsS1`.

| Check | Observed outcome |
| --- | --- |
| `Scripts/ci.py --lane transform-bindings` | Passed: 41 functions in Debug and Release; original 23 preserved; 31 Python harness cases; public privacy/identity checks |
| `Scripts/ci.py --lane transform-bindings-safety` | Passed: all 41 Release ASan functions; three shared-plan TSan functions; strict-memory target build with warnings as errors |
| New public-only consumer outside Git | Passed: six witnesses in each configuration, one exact compiled DocC fence, four ordinary full-codegen constructor/immutability refusals |
| Existing public Transform consumer | Passed: original twelve witnesses in each configuration |
| Existing Transform ownership compiler cases | Passed: seven cases; intended compiler refusals distinguished from import failures/crashes |
| `Scripts/ci.py --lane cli` | Passed: 13 commands, 88 functions/37 parameter invocations and all existing command/vector/provider checks |
| Existing manifest/dependency/cap checks | Passed through unchanged CI comparators: thirteen products, empty external graph, one test reaching all 49 core caps with exact outcomes |
| Scoped JSONTransform native symbol graph and DocC | Passed: 67 authored declarations and parameter comments; original 42 identities/signatures preserved; warnings as errors |

The public graph adds 25 authored declarations. Three historical graph fragment
differences are retained and explicitly reviewed: two nested types acquire their
parent qualification while retaining the same precise type IDs and byte-identical
owning sources; generic Result metadata loses a local preciseIdentifier with
unchanged spelling. The original withExecution declaration/body is byte-identical.
This is a scoped Transform catalog result, not a fresh thirteen-catalog pass.

Initial compiler errors were in new test assertions with throwing expressions;
they remain in the private logs. The first native harness run rejected a stale
30-case self-test expectation after a meaningful 31st case was added. The
successor checks both the new exact population and rejection of stale populations.
The first strict graph comparison retained the three rendering differences above;
its source-backed successor records their precise disposition. No failed attempt
is relabeled as a passed check or omitted from the return.

## Semantic and ownership coverage

D01–D03 pin literal canonical bytes, native escaping, exact decoded source scalars,
UTF-8 name ordering and canonical reload. D04–D06 reject closed-field/type/version/
dialect/name errors, exact duplicates and malformed native JSON. D07–D11 pin zero,
exact, one-over and overflow-policy boundaries, work/retention accounting, compile
reports, compiler errors and deterministic inner-loop cancellation. Shared cases
exercise independent concurrent reuse. The reports describe actual native work;
caller storage/instructions and process RSS remain outside those claims.

The P01–P05 test-only selection prototype exercises explicit indices over duplicate
values, order/repeats/ties, empty completion, invalid late output bypassing query
catch, incomplete-prefix refusal, foreign owner refusal, post-close leases/refunds,
terminal quota/provider failures and cumulative projection/evaluation/cancellation.
It uses the existing VM and private context, not a second evaluator. Its profile,
provider and completion types are experiments, not public contracts or conformance.

## Next bounded increment and held gates

Sprint 2 must freeze reserved binding/provider policy and a versioned selection
convention, implement a guarded public selection scope with private position and
completion constructors, and qualify reentry, public constructor refusals, aliases,
first-cause terminal accounting, exact inclusive capacities and independent plans.
Retain the admitted population through every output's joint lease. Full EOF is
required before an owner-produced completion witness. Ordinary execution stays
unchanged. The downstream S06/S13 mapping remains a separate deliberate decision.

Fresh full Native/Linux ARM64/x86_64/safety/docs, WASI, relevant Apple SDK/runtime,
archive reproduction and complete API checks remain final-release gates. The
portable harness is prepared but this sprint makes no new Linux/WASI/device pass.
The existing 49 policies/probes are unchanged; the codec's five finite capacities
are additive policy, not replacements. No new benchmark/allocation campaign ran.
Existing 1.8 loaded-host comparisons, unresolved regressions, unmeasured allocations
and older scoped holds remain visible; the 1.7 waiver does not apply to 1.8.

The final checkpoint binding separately records this documentary closeout and
architecture text polish after the passing receipts. Product, manifest, tests,
DocC, fixtures, generator, CLI identity and executable harness bytes remain equal
to those checked. No independent human review or release approval is claimed.
