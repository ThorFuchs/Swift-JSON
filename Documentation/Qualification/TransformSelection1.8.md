# Transform indexed selection — Sprint 2

Status: implemented with scoped native qualification complete; full 1.8 release
qualification remains PARTIAL. This local candidate extends sealed Sprint 1
`70df9ba8d47322abf0d4aec1439256d7a5e97e94` on
`codex/1.8-transform-selection-s2`. The previous branch/checkpoint, batches/store
PR and all source-bound receipts remain intact. No merge, tag, publication or
Content source-lock change is implied.

The [contract](../Architecture/Release1.8/TransformBindings.md) and
[compiled public guide](../../Sources/JSONTransform/Documentation.docc/IndexedSelection.md)
define selection convention V1. The input is an owned index array and `$values`
is the completely admitted population. Bindings supply exactly the other declared
names. The finite population cap defaults to 65,536, alongside existing native
and Transform policies. One private invocation context owns population admission,
projection/index slots, evaluation, provider/output admission, exact conversion,
position leases and completion. No engine language or numeric authority changes.

## Ownership and failure decision

Positions have private construction, exact ordinals, invocation identity and a
joint population/output-slot lease. Completion/report construction is inaccessible
to public callers. Explicit evaluator EOF and successful cleanup are mandatory;
an abandoned prefix never certifies. A completion retains only identity/report
storage. Its constant identity check rejects foreign positions even for identical
populations. It does not reopen or retroactively fail a completed invocation.

Scopes, positions and completions are deliberately non-Sendable. Escaped handles
are guarded after close; plans remain checked Sendable for independent concurrent
scopes. Providers are optional and explicit. Their values may influence selection
but cannot enlarge the population. Callback work and prior caller allocations
remain caller work. During callbacks, observation uses an admitted entry snapshot
and reentry/cancellation touches health before the loaned context.

Boundary invalidity, resources, uncaught language/provider failures, cancellation
and reentry latch. Query catches retain their ordinary semantics but cannot catch
boundary/operational failures. A first operational cause wins over a later caller
error; otherwise caller errors retain identity. report() settles actual deferred
refunds after failure/close without resetting work. Completion statistics are a
close-time snapshot, not a later ARC settlement. Logical weights are not RSS,
allocation-event measurements or arbitrary caller instruction quotas.

## Actual native qualification — 29 October 2026

Host: macOS 27.0 arm64, Apple Swift 6.4.2 (`swiftlang-6.4.2.1.9`, driver 1.168.6),
Xcode 27.2/27B48, SDK 27.2, language mode 6. Private receipts/logs/events/source
manifests are retained under `Artifacts/TransformBindingsS2`.

| Check | Observed outcome |
| --- | --- |
| `Scripts/ci.py --lane transform-bindings` | Passed: 57 functions in Debug and Release, original 41 preserved, 32 Python harness cases, privacy/source identity and both public consumers |
| `Scripts/ci.py --lane transform-bindings-safety` | Passed: 57 Release ASan functions, four shared-plan TSan functions, strict-memory target build with warnings as errors |
| New outside-Git JSON/JSONTransform consumer | Passed: ten witnesses/configuration, exact compiled DocC guide, fourteen ordinary constructor/non-Sendable compiler refusals and two guarded-alias positives across Debug/Release |
| Original source-definition public consumer | Passed: six witnesses/configuration and its four ordinary compiler refusals |
| Original public Transform consumer and ownership compiler cases | Passed: twelve witnesses/configuration and all seven compiler cases |
| `Scripts/ci.py --lane cli` | Passed: thirteen commands, 88 functions/37 parameter invocations and all existing command/vector/provider outcomes |
| Existing manifest/dependency/cap commands | Passed through unchanged CI comparators: thirteen products, empty root external graph and all 49 exact cap outcomes |
| Native Transform graph/DocC | Passed: 93 authored declarations/parameters documented, all 67 Sprint 1 identities/declaration fragments unchanged, 26 additions, warnings as errors |

Sixteen new Swift Testing functions cover explicit duplicates/order/repeats/ties,
exact scalar/number behavior, empty/EOF/null/incomplete distinctions, malformed/
negative/fractional/overflow/native-width/out-of-population outputs, late invalidity
outside query catch, foreign owners, final aliases and report-only settlement,
reserved/invalid/missing bindings, complete unused-tail admission and zero/exact/
one-over/overflow policies. Tests also pin cumulative work/retention/collection
slots, completion-allocation failure, terminal quota/cancel refunds, provider error/
EOF/null/reentry snapshots, caller/provider release, deterministic inner-projection
task cancellation, uncaught language failure and independent concurrent reuse.

The first test compilation retained ordinary errors in throwing assertion inference
and one incorrect native metric name. Its corrected 13-case run passed before the
final 16-case increment. No production semantic failure or compiler crash occurred.
A supplemental private runner initially lacked its output directory and executed
no command; the raw setup failure remains, and the diagnosed successor runs the
same three commands. No failed attempt is relabeled as a pass or hidden.

## Final binding and remaining gates

The checkpoint binding separately maps this qualification closeout and the API
index paragraph after passing receipts. Product, test, fixture, manifest, DocC,
generator, identity and executable harness bytes match those checked. Native
receipts are scoped to this actual source. No independent human review or broad
platform acceptance is inferred. The scripted graph comparison is exact for all
67 predecessor declaration fragments; full thirteen-catalog graphs remain separate.

The private return retains deterministic source/checkpoint/diff and reproduction
results. Full final-source Native/Linux ARM64+x86_64/safety/docs/WASI/relevant Apple
SDK/runtime/API/archive gates and branch reconciliation remain release work.
No new hosted CI, Linux, WASI or device pass follows from this sprint. Preserve
main's independent documentation automation when deliberately reconciling later.
No push/merge/tag/publication is performed by local qualification.

The current expected discovery is 57 Transform roots/four sharing functions; all
other populations and 390 native/portable parameter invocations (353 WASI) remain.
Existing 49 policy probes preserve their exact distinctions, including zero-scratch
success and invalid cancellation configuration. The population cap is additive
policy, not a replacement metric or a calibrated RSS bound.

No benchmark/allocation campaign ran. Earlier 1.8 loaded-host observations and
unresolved regressions remain bound to 5e27899. Allocations remain unmeasured/
unwaived for 1.8; the 1.7 waiver and historical holds are not promoted. Content's
S06/S13 profile mapping and deliberate public source re-resolution remain separate
acceptance work. This implementation supplies no Content IDs, locator/read grants,
persistence, provenance propagation, online resolution or unbounded streaming.
