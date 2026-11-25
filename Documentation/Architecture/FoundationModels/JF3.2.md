# JF3.2 — Extended reverse GenerationSchema compatibility

**Status:** diagnostic implementation, native qualification pending. Parent
review: `441d273380cf93da45c5150073bf1225f3e3e7dc`. JF3.1a's 50 native
method executions remain source-bound at `addb0045911e4082d8f8678c6ad822a8be82284c`.
Neither existing bridge, root manifest, profile nor historical runner changes.
No product admission or general Draft 2020-12 equivalence claim.

## Purpose

Measure the real SDK's reverse Codable behavior inside the current narrow
profile, without changing that profile on the basis of a successful decode.
Compare canonical native source, independently observed raw Apple export,
strict projection and explicit generated-annotation opt-in. On acceptance
retain and validate the canonical plan; verify the actual returned schema
and its instance verdicts. Native compiler, bounded exact comparison and
resource accounting remain the production authority. This experiment uses
fixed synthetic fixtures and does not invoke a language model.

## Matrix

One shared resource `ReverseMatrix.json` contains 19 in-profile schemas
and 62 authored instance cases (at least one valid and one invalid per
schema). The two known JF3.1 anchors require exact prepared success and
explicitly authorized generated title/x-order respectively. The other 17
shapes are measurements, not predictions of Apple capability:

- Empty and nested closed objects, including generated nested annotations.
- String arrays, arrays of objects and nested arrays.
- Boolean, integer and number properties; inclusive bounds, 2^53+1,
  Int64 extrema and high-precision decimal bounds.
- Optional nonnullable fields, string enum including scalar-distinct
  Unicode values, property names title/x-order/description, required
  ordering and a mixed tool-arguments schema.

The same resource contains 12 valid native schemas outside the current
profile: nullable unions, open objects, pattern, composition, const,
$defs, format, unknown annotation, explicit dialect, non-ASCII property
name, invalid x-order metadata and boolean root. Each must compile in
Swift-JSON and reject with its exact fixed issue and typed key path,
under the controlled portable Codable boundary and both actual Apple
projection policies. This is profile rejection, not invalid JSON/schema.

## Observation and acceptance

Four new Swift Testing methods: native canonical fixtures, outside-profile
preflight, actual Apple reverse matrix, actual Apple preflight. For each
in-profile fixture, first require all expected canonical verdicts. Capture
raw GenerationSchema decoding/encoding before checking the returned native
schema. Record complete raw schema JSON before compilation. Separately run
both real public bridge projections. Accepted projection must keep the
original native plan, return the actual encoded schema, retain exact
roundtrip representation, and yield all expected native instance verdicts.

The standard-library receipt verifier independently checks the raw schema
against the conservative profile and compares declarations at schema
positions using Decimal, scalar-aware and type-aware equality. Only title
and x-order additions are allowed with explicit consent. Existing metadata
changes, all changed constraints, reordered arrays, removed/added properties
and unsupported declarations cannot silently pass. Require the exact set
of allowed addition paths; first-error diagnostics may be any actual
incompatible path if multiple deltas coexist. Both policies must reject
consistent raw codec rejection or native schema invalidity. Only Codable
errors or FoundationModels error types are classified as codec rejection;
resource failures, cancellation and unexpected errors fail the run. Native
schema compilation is still authoritative; the independent profile checker
is not a second JSON Schema engine. Preserve actual raw values, expected
and observed verdicts and error categories. Require consistent semantic
raw/accepted schemas and dispositions across Debug/Release; differences
in the first valid diagnostic path or object order are not semantic drift.

A green matrix means fidelity policy passed for these measurements, not
that all 19 schemas were accepted by Apple. Review the actual disposition
inventory before widening or publishing the profile. No hidden framework
state, generation IDs or model-output behavior is qualified.

## Qualification and provenance

Run only at the exact new source commit. The dedicated runner materializes
a disposable candidate from tracked source, grafts the existing experimental
product/test target, and adds only a copied synthetic resource and direct
JSONSchema test dependency. The evaluated old targets/products/floors and
empty external dependency graph must remain identical. The existing public
manifest and historic runners are untouched. Apple lane uses native ARM64
macOS 27+, Swift 6.4.2 and SDK 27.2. For each Debug/Release configuration:
4 new methods, 11 JF3.1 regression methods, 14 JF2.2 regression methods.
Total 58 intended native method executions; 38 reverse rows, 72 preflight
rejection rows, 124 canonical instance verdicts in the new matrix. Accepted
and raw schema validation counts depend on observed representability.
Retain evidence logs, exits, fixture SHA-256, exact commit and receipts.
No hosted CI or release. Linux/WASI and all old full qualification gates
remain separate prerequisites for actual public product admission.

Local editing-host evidence (not Apple qualification): Python 3.13.5,
15/15 offline unittest methods on synthetic receipts; both Python files
compile. Independent jsonschema 4.26.0 Draft202012Validator verifies all
31 native schema documents and 62 authored instance verdicts (no float
conversion of decimals; integral Decimal converted exactly to int for
integer checking). The new Swift source passes Swift 6.2.1 frontend syntax
parsing both as guarded source and with the Apple guard removed. A separate
minimal Swift Testing package under Swift 6.2.1 confirms the regression
filter jf3[A-Z] selects the old method, not jf32. No new native Swift-JSON
or FoundationModels compilation/test execution on this editing host.

## Run

    python3 -I -B Scripts/test_foundation_models_reverse_matrix.py
    python3 -I -B Scripts/qualify_foundation_models_reverse_matrix.py "$(git rev-parse HEAD)" /path/outside/checkout/JF32-Evidence

Use the established external volume/TMPDIR and 20 GiB workspace preflight.
Outcome `APPLE_REVERSE_SCHEMA_MATRIX_PASS` still records `NOT_ADMITTED`.
Keep archive even on ordinary failure. Reproduce historic runs at their
original commits; do not use this tip with older exact-delta runners.
After review, decide which measured reverse shapes to admit, whether an
additional profile increment is necessary, and then JF4 typed conveniences.
