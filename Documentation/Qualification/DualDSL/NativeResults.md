# Dual DSL P1.2 native qualification

This unreleased integration uses the actual engine, not the packet's signature shims.
Base: `e8c3e4bd9ae40d797f07a527ea98879acee3c057`; implementation:
`917dab492883178b0ea9b57bce3a526b597e6373`; documentation correction:
`8fc83cad69df9f28af133c173391ae677804e304`. Library, manifest and test sources
are identical between the latter two commits. The intervening changes are records,
provenance and documentation tooling. Root dependencies remain empty; existing six
products gain no dependency on the two optional DSL products.

## Observed native results

macOS 27.0 arm64; Xcode 27.2 (27B5019j), SDK 27.2; Apple Swift 6.4
(swiftlang-6.4.0.34.1), Swift language mode 6. Commands select the matching Xcode
and SDK explicitly; no system toolchain setting or baseline is changed.

- Untouched baseline: all 17 production native commands passed, 296 functions
  per configuration and 173 parameter invocations.
- Integration: all 47 DSL Swift Testing functions passed Debug and Release.
  Full root Debug, Release and Address Sanitizer: 343 functions in eight exact
  bundles, retaining all 173 parameter invocations. Shared-state Thread Sanitizer:
  13 functions. Strict memory safety compilation with warnings as errors passed.
- Production native commands 0–12 passed. ENOSPC then interrupted the downstream
  mobile-tool build and receipt writer. The exact remaining six commands passed
  in a source-equivalent continuation with serial builds and cleanup of completed
  task-owned tool caches. This is 19 individually passed commands across retained
  receipts, not a single uninterrupted native-lane exit-zero claim.
- Mobile tool: three behavior tests, eight public fixtures, awaited cancellation
  and three separately exited disk persistence phases with eight rows. This is
  native SDK/tool execution, not a new physical-device qualification claim.
- Rooted consumer: 20 explicitly selected cases, eight positive/twelve negative
  and two operational checks. Independent syntax: 318 observed, 287 evaluated,
  31 policy. Schema: 2337 observed, 2300 evaluated, 37 policy. Authored cases: 82;
  budget cases: nine; deterministic malformed replay: 4396. All 49 cap probes
  passed. Policy cases are not evaluated successes.
- Six compiler-negative fixtures rejected for intended domain typing in Debug
  and Release. The final compiler experiment passed 41 commands and two guide
  fences, including 22 measured strategy/fixture combinations. Qualified-name
  collision consumers passed. See [the compiler decision](../../Architecture/DualDSL/Decisions.md).
- Separate public DSL consumer passed Debug/Release: one valid, two ordinary
  invalid and one missing-resource operational outcome, exact scalar keys and
  nested arrays. SourceKit-LSP returned the required value/schema factories,
  qualified types and Schema keywords in three real completion contexts. No
  interactive Xcode UI session is claimed.
- Documentation lane passed: 1005/1005 authored public declarations with named
  parameters, nine strict DocC catalogs, compiled README examples, 1530 static
  routes and 7636 verified local links. The helper catalog has no public product;
  all eight product guides remain mandatory.
- Matching Swift.org 6.4 WASI SDK: the real public release consumer built and
  passed in Node and WasmKit. This is consumer scope, not a new full WASI or
  host-sanitizer claim. Linux execution remains a separately recorded gate.

The first full ASan run recorded an unchanged PDF cancellation test receiving
`JSONPDFFailure.timedOut` rather than cancellation on a heavily loaded host. The
same case passed independently without edits, followed by a complete passing
safety rerun. Failed receipts remain part of the private return evidence. The
initial SDK mismatch, missing-comment diagnostics, site-route assumption and
concurrent SwiftPM manifest-output contamination are retained with their fixes;
no failure is relabeled as a pass or policy exclusion.

## Public additions and semantic authority

| Addition | Authority and regression coverage |
| --- | --- |
| `JSONValueDSL.object/array`, Field, Element, Elements | JSON/JSONNumber, exact JSONObject admission/index; V01–V07, duplicate tables, literal caps and public consumer |
| `JSONSchemaDSL.document/boolean`, Schema keyword factories and typed tables | JSONSchemaDocument, existing compiler/validator and explicit registry; V08–V17/V20, full prototype examples, annotation/verdict/manual-raw parity |
| JSONDSLCore typed composition and flat node/member staging | Domain-constrained native Swift composition; six negative fixtures, choices/loops/nesting, 16–256 declaration probes |
| Iterative finalization and package schema continuation | Existing invocation-owned engine meter and admission; V18/V19, inclusive work/retention/node caps, terminal error, depth and cancellation tests |
| Immutable declarations and conditional Sendable | Native compiler, 32 independent task invocations, shared immutable plan and exact shared-state TSan discovery |

Trusted callbacks, wrapper construction, emission and IR staging remain unmetered.
There is no whole-DSL cumulative report, staging cancellation/retention guarantee,
RSS bound or caller-instruction quota. Finalization uses one finite ledger through
schema document admission. Compiler/evaluator invocations remain separate explicit
engine operations. The next architecture question is whether an additional bounded
dynamic-authoring API merits metering from the first staged append; it is not
silently added to this authored API.

Runtime throughput is not benchmarked by the compiler experiment. Its loaded-host
compiler elapsed time/RSS observations justify the retained strategy only through
the tested scale. Projection, text-sequence framing, extra numeric coercions, online
resolution and new schema semantics remain outside this wave.
