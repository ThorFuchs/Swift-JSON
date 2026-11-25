# JF1/JF2.1 — Native Apple evidence review

Reviewed 2026-11-25. **JF1 Apple observations complete; JF2.1 focused Apple
candidate tests pass.** Prefer the monorepo product based on the measured
Apple result, conditional on remaining platform/product admission gates.
No root product, public API, final package placement or release admitted.

## Source-bound receipts

| Receipt | SHA-256 | Exact source |
| --- | --- | --- |
| jf1-9fywwrth.tar.gz | 4306d087a104b3cba995e02f23c57f02d0e8d5965239686fd2dbab5239c51846 | 53133cae207916c6f97d4087ff177d8c37a8ac9c |
| jf2-epa6qjec.tar.gz | f0a0ea1ea026003927d3e1b3f47371d2edd5ee823751d9e8283d9cc6fd04afbe | 1772e1e173713c9361e2ecfcae8b4a5b8a7344d9 |

Read archive members directly without extracting executable content. Both
provenance records identify Darwin arm64, Apple Swift 6.4.2
(swiftlang-6.4.2.1.9), target arm64-apple-macosx27.3.0, Xcode 27.2 (27B52),
SDK 27.2 and unchanged manifest blob 088e256101f1f5f330e20ba5c915cd5e188ba11f.
The JF1 logs show external-volume workspaces. Original machine-local paths
and raw artifacts remain private and are not committed.

JF1: 21/21 recorded subprocess exits zero, 13 observations in each mode,
reverse Codable executable complete. Runner decision OBSERVATIONS_READY_FOR_REVIEW,
packaging_decision NOT_ADMITTED. JF2: 4/4 recorded subprocess exits zero,
10/10 Swift test methods per mode, 20 cumulative executions, no failure or
known issue/skip in test logs. APPLE_CANDIDATE_TESTS_PASS, product_admission
NOT_ADMITTED. The separately run Python control logs are not part of these
archives; do not infer a new offline test count from native receipts.

## Apple packaging evidence

Compared evaluated manifest objects, including existing target/product values
and all package-level fields apart from packageKind's root path.

| | Baseline | JF1 candidate | JF2 candidate |
| --- | ---: | ---: | ---: |
| Public products | 13 | 14 | 14 |
| Targets | 31 | 32 | 33 |
| External package dependencies | 0 | 0 | 0 |
| macOS/iOS floor | 15/18 | 15/18 | 15/18 |

All existing products and targets exactly unchanged. JF1 adds only
JSONFoundationModels -> JSON, JSONSchema; JF2 adds its dedicated test target
as well. No other semantic manifest field changes. Both plain consumer
resolver graphs contain just the local Swift-JSON package without descendants.
Both verbose consumer build logs contain zero JSONFoundationModels references.
Both actual otool lists contain the same 11 dylib/framework entries, none
FoundationModels; the two consumer executables emit JF1_PLAIN_PASS. The
macOS 15 deployment-target builds execute on macOS 27.3, not macOS 15.
The candidate target and plain consumer target both compile for iOS 18
device and simulator; no iOS runtime execution. Both real Apple bridge
executables compile/link/run in Debug and Release; reverse executable
compiles/links/runs. This supports monorepo-first on the Apple SDK without
new external dependencies. It does not establish Linux/WASI execution or
all existing product/platform lanes. The consumer package is a disposable
local-path package, not a remote published product.

## GeneratedContent observations

Independent comparison of the raw JSON logs using Python decimal parsing
and scalar-distinct strings agrees with all reported equality flags.
Debug and Release observations are semantically identical.

| Case | Complete | Native semantic equality | Observed effect |
| --- | --- | --- | --- |
| ordinary | true | true | Object order changes only |
| explicit-null | true | true | Null member preserved |
| absent | true | true | Empty object preserved |
| large-integer | false | false | 9007199254740993 -> 9007199254740992 |
| int64-max | false | false | 9223372036854775807 -> 9223372036854776e3 |
| decimal | false | false | 0.12345678901234567890123456789 -> 0.12345678901234568 |
| exponent | false | true | 1e100 remains equal |
| unicode-keys | true | false | U+00E9 key and U+0065 U+0301 key collapse to one |
| unicode-value | true | true | Decomposed string preserved |
| nested | true | true | Nested containers preserved |

5/10 satisfy BOTH completeness and exact value equality. Four values
change (three overlap with incomplete); one additional value is equal
but incomplete. Fixed adversarial probes, not a distribution of real
workloads. The root scalar completeness observations must not be generalized
to complete nested values: test the same numbers inside objects and arrays.
The Unicode-key example directly demonstrates why isComplete is necessary
but not sufficient. The numeric observations are consistent with binary64
rounding, not proof of Apple's internal numeric implementation.

## Schema and typed-value observations

Both GuidedArguments.generationSchema and DynamicGenerationSchema:
native JSONValueEncoder and Foundation JSONEncoder export semantically
equal objects (member order may differ); native JSONSchemaCompiler
compiles both. Guided schema serializes range minimum=1/maximum=20,
sort enum date/title, tags minItems=maxItems=2, query description,
additionalProperties=false, and stable x-order [query,limit,sort,tags,note].
The optional note is not in required, and has type string rather than
a union with null. Dynamic property isOptional produces the analogous
optional/nonnullable schema.

The guided probe called its note:null input "valid", but validation is
false in both modes; omitting note is true. All three original range,
enum and count negatives also contain note:null, so their false verdicts
do NOT isolate those constraints in the native engine. Typed
GuidedArguments construction accepts the supplied content with note:null,
then generatedContent omits note; typed conversion is not automatically
a lossless JSON bridge. Do not infer validation from successful typed
initialization or treat optional and nullable as equivalent.

Independent supplemental check (editing host, Python jsonschema 4.26.0,
Draft202012Validator, captured schema objects from BOTH modes):
absent note true; note string true; note:null false (type);
limit=21 with note absent false (maximum); sort=other with note absent
false (enum); one tag with note absent false (minItems); unknown extra
property false (additionalProperties). This corroborates the exported
schema semantics, but is not a new Swift-JSON native execution.

Reverse Codable probe: canonical object with query string, required query,
closed properties decodes to GenerationSchema and re-encodes; native
compilation succeeds. Export adds title "Object" and x-order ["query"].
Native value equality false. This is an observed annotation delta for
this one simple schema; neither arbitrary Draft 2020-12 compatibility
nor a general validation-equivalence theorem follows. JF3 must retain
canonical schema and distinguish semantic constraints from metadata.

## JF2.1 exact Swift test set

Both modes ran all eight portable-policy methods and both Apple methods:
jf2ExactNativeRoundtrips, jf2RejectsSemanticLoss,
jf2AcceptsOnlySemanticNotTextIdentity, jf2MalformedForeignJSONRejected,
jf2IncompleteForeignSnapshotRejected, jf2InputOutputLimitsDoNotReset,
jf2CumulativeBudgetBoundary, jf2CancellationAfterForeignCallback,
jf2AppleOrdinaryValueRoundtrip, jf2AppleExactOrExplicitRejection.

The cumulative native N/N-1 work/retention and cancellation controls
passed. These do not establish budgets for opaque Foundation Models
callbacks. The actual Apple ordinary value roundtrip passed; difficult
Apple cases either passed equality or threw an allowed bridge error.
The test is deliberately disjunctive and emits no per-vector error
receipt, so the archives do not separately identify actual JF2 error
categories for each vector. Source shows incompleteContent has precedence
before parsing/comparison, and changedValue is required for a complete
but altered representation. Qualify exact dispositions in JF2.2.

## Next increment and admission boundary

JF2.2 targeted fidelity matrix: distinguish complete/incomplete scalar
and object/array numeric values; add exact boundary values around 2^53,
Int64, fractions, exponent and scalar-distinct keys; record actual
per-vector raw equality/completeness/bridge result with fixed failure
codes. Test real complete unicode-key loss rejection specifically.
Isolate guide negatives using a known valid base without note:null,
add present-string, absent and null and unknown-member cases. Preserve
x-order and schema annotations as observations. Review generation IDs
and typed conversion losses separately. Do not make opaque framework
work appear native-metered.

Then JF3: constrained reverse schema projection and loss diagnostics,
original validation authority retained. No arbitrary schema lowering.
Run JF1 Linux and matched WASI lanes (WASI compile only), followed by
actual required portable/runtime and full existing native, platform-floor,
Linux and WASI gates before public-product admission. No API freeze.
No model generation, live sampling or MCP integration executed here.

This receipt adds documentation only; the original JF1/JF2 runners
enforce their exact changed-file sets. Reproduce the prior native results
using the two immutable source SHAs above, not this later document tip.
