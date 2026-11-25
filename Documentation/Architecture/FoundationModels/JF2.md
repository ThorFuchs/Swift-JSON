# JF2.1 — Strict GeneratedContent value bridge candidate

**Status:** implemented diagnostic candidate; native Swift typechecking and
qualification pending. JF1 observations and packaging decision remain open.
No public product or root manifest admission.

JF1's exact commit `53133cae207916c6f97d4087ff177d8c37a8ac9c` and original runner are unchanged.
Run the JF1 experiment on that commit, not on the later feature-branch tip.
This additive JF2 batch is deliberately independent of its native results.
It implements the fail-closed policy before deciding which Apple values are
actually representable.

## Proposed API and fidelity contract

The candidate `JSONGeneratedContentBridge` has four operations:

- generatedContent(from: JSON) -> GeneratedContent
- generatedContentWithReport(from: JSON) -> JSONOperationReport<GeneratedContent>
- json(from: GeneratedContent) -> JSON
- jsonWithReport(from: GeneratedContent) -> JSONOperationReport<JSON>

All throw. The facade is immutable, with explicit finite JSONLimits. Actual
public API admission and availability are separate decisions. The Apple
facade is guarded by platform/import checks and macOS/iOS 27 availability.

Outbound: use the native strict writer, initialize actual GeneratedContent
from its documented JSON-string initializer, require isComplete, parse its
jsonString with the native strict parser, then compare the original and
returned JSON using the existing bounded JSONComparison. Return the actual
GeneratedContent only when mathematical decimal and exact decoded scalar
value equality holds. No lossy fallback or retry with rounded numbers.
Incomplete and changed values throw fixed bridge errors; framework initializer
rejection has a fixed error without original exception text. Native syntax,
resource and cancellation failures remain distinct.

Inbound: accept only completed GeneratedContent and parse its documented
jsonString. This imports the exported JSON value, not the framework's
hidden representation or an earlier pre-conversion source. Do not claim
that an import reverses any precision or metadata loss that happened
before the JSON representation was exposed.

Semantic JSON equality ignores object member order and number lexemes.
It preserves array order, decoded scalar identity, absent vs explicit
null, type identity and exact decimal value. The bridge does not preserve
generation IDs (including nested generation metadata) or guarantee
Generable schema-specific property order. These must be reviewed separately
before typed/streaming adapters. No partial output support in this batch.
The original inbound GeneratedContent remains with its caller.

## Single native composition

Use JSON.withComposition, the package-scoped withMeter helper, native
writer/parser and bounded comparison on one invocation ledger. Reserve
the outbound String and conservatively account visible returned text and
its UTF-8 copy. Check cancellation before and after foreign callbacks.
No JSONSerialization, second JSON grammar, Double coercion, unmetered deep
equality or unsafe Sendable escape. Return no successful report on failure.

FoundationModels owns its initializer, isComplete and jsonString work and
opaque allocations. These synchronous foreign operations are not instrumented
or preemptible by Swift-JSON's native work ledger. The returned text can
already be allocated before native admission; this is not a hard memory,
time or whole-framework resource guarantee. Reports cover the native and
explicitly instrumented adapter-owned work only.

The native boundary uses package-access helpers because the preferred
JF1 placement is inside Swift-JSON. If JF1 requires a separate package,
review a minimal bounded public composition surface in its owning
repository; do not duplicate the meter or expose internals prematurely.

## Test candidate

Eight portable Swift Testing methods exercise the actual native boundary
with controlled callbacks, not a fake FoundationModels framework:

1. Exact integer/decimal, Unicode, null and nested value roundtrips.
2. Seven intentionally changed values (rounding, absent/null, collapsed
   keys, normalized text, reordered arrays, type substitution).
3. Semantic rather than textual identity.
4. Five malformed foreign JSON inputs in both directions.
5. Incomplete snapshot rejection.
6. Native input/output capacity rejection.
7. Exact cumulative work/retention N versus N-1.
8. Cancellation after the foreign callback, before reading its value.

Two Apple tests exercise the actual public GeneratedContent interface:
ordinary values must roundtrip, and difficult values must either retain
native value equality or explicitly reject at the bridge. Unexpected
native parser/limit errors on these tiny fixtures fail for review.
Neither test invokes a model. Real partial-generation behavior and typed
Generable/schema mapping remain separate.

The new runner imports the unchanged JF1 manifest checks, copies exact
source into a disposable directory, grafts the candidate product/target
and one dedicated test target, and runs the focused tests in Debug and
Release. Require the exact passing test names and totals: 10 per mode on
Apple, 8 per mode on Linux (portable native policy only). Reject missing,
duplicate, zero-test or known-issue/skip receipts. No root test inventory
or existing qualification lane is changed.

## Actual verification so far

- Both Swift source files passed frontend syntax parsing with Linux
  Swift 6.2.1. This is not typechecking against the 6.4.2 JSON source or
  the Apple SDK.
- Python syntax and 7/7 offline runner-control tests passed.
- No native Swift test method has executed yet. No Apple value support,
  Linux FoundationModels capability, JF1 packaging success or product
  admission follows from these checks.

## Native execution

First run JF1 at its original pinned SHA. Review its returned archive
before admitting JF2 or fixing any Apple API assumptions. To qualify this
separate candidate on the supported Mac toolchain, from a clean checkout
of its own exact commit:

    python3 -I Scripts/test_foundation_models_values.py
    python3 -I Scripts/qualify_foundation_models_values.py "$(git rev-parse HEAD)" "$HOME/JF2-Evidence" --lane apple

Linux 64-bit Swift 6.4.2 uses --lane linux; it does not qualify the Apple
facade. Default workspace preflight is 20 GiB, not an upper bound. Avoid
running concurrently with JF1 on a constrained machine. The output is an
evidence-only archive with native logs, manifest comparison inputs,
provenance, passed names, process exits and decision. Worktrees are retained.

Before admitting any product, JF1 packaging evidence and the appropriate
existing full Scripts/ci.py lanes remain required. No tag, publication,
merge, external dependency, Core/HTTP change or hosted CI launch.

## Public SDK references

- [GeneratedContent](https://developer.apple.com/documentation/foundationmodels/generatedcontent)
- [isComplete](https://developer.apple.com/documentation/foundationmodels/generatedcontent/iscomplete)
- [jsonString](https://developer.apple.com/documentation/foundationmodels/generatedcontent/jsonstring)
- [Generation ID](https://developer.apple.com/documentation/foundationmodels/generatedcontent/id)

Next: review JF1 actual SDK evidence, qualify/fix this candidate, then
JF2.2 fidelity and metadata decisions before the JF3 schema adapter.
