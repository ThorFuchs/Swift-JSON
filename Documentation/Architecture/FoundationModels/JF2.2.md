# JF2.2 — Extended native fidelity qualification

**Status:** diagnostic matrix implemented; 12 offline receipt-control tests
pass. Native Apple compilation and execution pending. No product admission.
The previously qualified JF1 and JF2.1 sources and runners are unchanged.

Parent: `084d740ecbb4a40562da276212cb7dfa82b17010`. Reproduce the historical Apple observations at JF1
`53133cae207916c6f97d4087ff177d8c37a8ac9c` and the previous 10/10 tests
per mode at JF2.1 `1772e1e173713c9361e2ecfcae8b4a5b8a7344d9`.
See [the immutable native review](JF1-JF2-NativeReview.md).

## Why this increment exists

Native JF1 evidence showed mathematical rounding of large integers and a
high-precision decimal, an incomplete but mathematically equal exponent,
and collapse of two scalar-distinct Unicode keys even with isComplete=true.
JF2.1's 20 native Swift test executions passed, but its actual Apple
difficult-vector test permits either exact output or an explicit rejection.
It did not record each vector's disposition. The original guided-schema
negative inputs also shared an unintended note:null violation.

JF2.2 makes these distinctions inspectable and adds no bridge behavior.
Use the actual previously tested ValueBridge.swift, not a new converter,
a fake framework or a new JSON implementation.

## Value matrix (52 vectors in each build mode)

14 numbers each at root, as an object member, and as an array element
(42 vectors): zero, one, 2^53-1, 2^53, 2^53+1, -(2^53+1), Int64.min,
Int64.max, UInt64.max, 0.125, 0.1, a 29-digit fractional decimal,
1e100 and 1e-100. Ten additional vectors cover ordinary containers,
explicit null, absence, scalar-distinct keys in both insertion orders
and nested in a container, decomposed text, nested mixed containers,
root null and root boolean.

Each fixture is parsed and written by Swift-JSON. Construct real
GeneratedContent from that native text. Record its raw jsonString and
isComplete, then compare parsed raw with the original using bounded
JSONComparison. Exercise the actual public export with report, independently
constructing its own content; exercise the actual public import on the
first raw content. Check exact equality of every accepted export after
import and of every accepted import against the raw exported JSON.
Positive work counts are required. Do not infer original fidelity on
import: an already altered Apple representation may be a valid JSON value.

| Raw observation | Required export | Required import of raw content |
| --- | --- | --- |
| Framework initializer rejects | frameworkRejected | notAttempted |
| Incomplete (even if equal) | incompleteContent | incompleteContent |
| Complete but changed value | changedValue | accepted raw value |
| Complete and equal | accepted | accepted raw value |

Unexpected native parsing, quota or cancellation failures on these small
synthetic inputs fail for review rather than being caught as acceptable
bridge errors. Raw text is printed before parsing so a failed probe
does not hide it. The known JF1 complete Unicode collision is independently
reproduced: two keys become one, and export must throw exactly changedValue.

Require ten historical completeness/equality anchor outcomes from the
actual JF1 logs. For the 42 other cases do not guess representability:
measure and require the corresponding strict bridge policy. SDK behavior
drift (even an improvement) is a review event, not evidence of a broken
bridge by itself. Require consistent Debug/Release dispositions, without
requiring identical object order or numeric spellings or the same survivor
for a rejected key-collision case.

## Guide and typed semantics

A new macro-generated type repeats the previously observed public guides:
description, range 1...20, enum date/title, count 2, optional String note.
Compile its native-encoded schema once and require 14 isolated verdicts.

Four valid cases: baseline with note absent, inclusive upper endpoint,
alternate enum member, note string. Ten invalid cases: note null,
lower/upper range violation, invalid enum, too few/too many array items,
wrong item type, absent required query, extra property and wrong query
type. Each negative changes only one property of the known valid base.
The receipt validator checks the actual instance and verdict for every case,
the exported schema's property constraints, required array, closed object
and x-order; it also preserves the complete actual schema JSON.

Separate typed test: reproduce JF1's acceptance of note:null by the
Generable initializer and subsequent omission of note by generatedContent.
Require original validation false, returned validation true, unequal
canonical values and typed note nil. This is not a permitted loss in the
strict JSON Value Bridge. Generation IDs and their nested metadata,
streaming partial values, schema-guided typed publication and future
projection policy remain separate work; no metadata preservation claim.

## Runner and evidence

`Scripts/qualify_foundation_models_fidelity.py` works from an exact clean
source SHA, using the original JF1/JF2 manifest graft and checks in a
disposable workspace. Only the temporary test target adds an explicit
JSONSchema dependency so the guide tests import its public API. Existing
products/targets and the root manifest remain unchanged. Use native
ARM64 macOS 27+, Swift 6.4.2 and SDK 27.2 (the JF1 anchor SDK).
Other SDKs need an explicit drift review. Run the same 10 original
tests plus four additional Apple tests in Debug and Release: **14 per
mode / 28 intended Swift test method executions**. New vector observations
are loop iterations, not independent Swift test methods. There are 104
value rows, 28 guide rows and two typed rows across the two modes.

An independent Python receipt evaluator uses Decimal, decoded scalar
string identity and type-aware recursion, rather than float or ordinary
Python true==1 equality. Reject missing/duplicate rows, raw text mismatches,
false equality flags, wrong bridge dispositions, wrong fixtures, altered
guide/typed semantics and missing/duplicate/skipped/known-issue tests.
It checks the bounded fixed synthetic evidence format, not arbitrary
untrusted JSON or a general schema validator. Native parser/validator
remain authoritative. Preserve original numeric text in fidelity.json,
not float-converted results.

Actual local verification: Python 3.13.5 compiled the runner and executed
12/12 offline unittest methods using synthetic receipts (not native
Apple results). Swift 6.2.1 Linux frontend parsed the new test source,
including a syntax-only unguarded copy of the Apple branch. This does
not typecheck against Swift 6.4.2 or FoundationModels. Native JF2.2
test methods have not yet executed. No Linux or WASI qualification
in this Apple-focused batch.

From a clean exact JF2.2 commit on the Mac:

    python3 -I -B Scripts/test_foundation_models_fidelity.py
    python3 -I -B Scripts/qualify_foundation_models_fidelity.py "$(git rev-parse HEAD)" /path/outside/checkout/JF22-Evidence

Use the established external-volume workspace and TMPDIR if appropriate.
The default 20 GiB free-workspace preflight is a conservative reserve,
not a bound on build or system caches. Archive retains logs and exits
even after ordinary failure; completed runs contain fidelity.json.
The source delta check is intentionally exact. Run historical JF1/JF2.1
only at their original commits, not this tip. The outcome
APPLE_FIDELITY_MATRIX_PASS means the measured matrix and all strict
controls passed, not that every Apple value is representable or that
the product is admitted.

## After JF2.2

Review actual evidence, then JF3 schema conversion with canonical
validation authority, explicit annotation-versus-constraint distinctions
and fail-closed compatibility. No new public products, platform floors,
dependencies, production runtime changes, tag, merge or CI invocation.
Remaining JF1 portable and full native/platform-floor/Linux/WASI
qualification gates still apply before a real product admission.
