# JF3.1 — Strict bidirectional GenerationSchema bridge candidate

**Status:** implementation candidate; native compilation and qualification
pending. No root product admission or published API. Parent native review:
`dda2274598d823d311c587d280f00444b3c1fc68`. The JF2.2 qualification at
`f081536bfb63b7f35e327812882ffa2cd298b631` remains immutable.

## Contract and API

Import Foundation Models `GenerationSchema` through the native Codable encoder,
retain its exact JSON representation in a JSONSchemaDocument, compile offline,
and check the narrow JF3.1 profile. Return the compiled native plan. Import
preserves the representation Apple exposes, not an earlier source declaration
or hidden framework state. There is no automatic tool execution or model call.

Reverse projection: accept a canonical JSONSchemaDocument, compile the
original offline, check the profile, decode with the native Codable decoder,
encode the actual resulting GenerationSchema again, compile/check that schema,
and compare the supported declarations at their actual schema positions.
The result carries the actual GenerationSchema, original CompiledJSONSchema,
roundtripped JSONSchemaDocument and typed paths of admitted additions. The
canonical plan always remains the runtime validation authority. Both directions
have report variants. Candidate availability: macOS/iOS 27+, conditional
FoundationModels import. Earlier OS deployment floors remain unchanged.

`JSONGenerationSchemaMetadataPolicy.exact` is the default. It requires complete
semantic JSON value identity, not original bytes or object insertion order.
`allowGeneratedAnnotations` explicitly allows only new `title` and `x-order`
at schema nodes. Report every addition, retain both schema documents, and
never delete or change an existing annotation (including description). Require
x-order to name every declared property exactly once. Property names which
happen to be title, description or x-order are not annotations. The first
incompatibility throws a typed issue/path; no partial projection is returned.
Unknown metadata is unqualified, not silently stripped. Annotation addition
is a model-guidance change, not a claim of identical generation behavior.

## Frozen candidate subset

Reference-free object root; nested closed objects with explicit properties,
required list and additionalProperties:false; homogeneous arrays with items;
string, integer, number, boolean. String enum, inclusive numeric bounds,
minItems/maxItems, title, description and validated x-order. Maximum 16
schema levels, 128 properties or enum values per node; nonempty ASCII
property names. The native compiler remains responsible for schema validity.
Reordered required/enum arrays are conservatively rejected even when validation
semantics could be equivalent. Type unions/nullability, open objects, boolean
schemas, refs/defs, explicit dialect declarations, compositions, regex, format,
other keywords and custom annotations are rejected in this profile. Native
compilation may reject a malformed declaration or unresolved reference before
profile inspection. No network resources. Preserve original retrieval identity
and source map in canonical plan. The portable profile is a proposed contract;
actual reverse Apple coverage beyond the pinned simple schema is unqualified.

## Native accounting and failure policy

One invocation-owned noncopyable JSONWorkMeter in JSONCodingState through
native compilation, coding, profile inspection, second compilation, bounded
comparison and report creation. Use existing package-scoped native helpers,
not independent public operations which reset budgets. Check cancellation
throughout native work. Retention is logical and conservative; opaque framework
Codable callbacks, hidden allocations and caller code are not instrumented or
preemptible. A native resource/compilation/cancellation or Codable failure throws
without successful report. Structured incompatibility is distinct from instance
invalidity and operational error. No fallback, no rounded-number comparison,
no general schema equivalence theorem, no new runtime dependencies.

## Qualification matrix

Eight portable Swift Testing methods exercise actual native compilation,
identity Codable, controlled metadata addition, exact numeric constraint
changes, required omission/change, nested schema-node annotation scoping,
unsupported shapes/declarations, malformed native schemas, exact cumulative
N/N-1 work/retention and cancellation. The controlled Codable peer is test
code, not a fake FoundationModels implementation. Three Apple methods use
actual GenerationSchema: guided macro import with valid and invalid instances,
known JF1 reverse metadata addition (default rejection, explicit acceptance),
and exact roundtrip of the known augmented simple schema. Record complete
actual schema JSON, validate against exact expected values using Decimal and
scalar-aware independent comparison. Run the previous JF2.2 tests unchanged
in both modes (14 per Apple mode, 8 portable on Linux), with separate receipts.
The new test matrix is 11 per Apple mode and 8 per Linux mode. Apple: 50
cumulative intended method executions including regressions; Linux: 32.
Preserve historical runner exact source sets. The new runner only grafts a
candidate product and test target into a disposable exact source copy, with
unchanged package floors/old targets/zero external dependencies. It archives
native logs, exits, provenance and receipts; the root manifest is untouched.

Actual editing-host results: Python 3.13.5, eight offline receipt-control
methods passed; both new Python files compiled. Swift 6.2.1 Linux frontend
syntax parsing passed for both Swift files, including the active Apple branch
with conditional guards removed for syntax only. Native Swift 6.4.2
compilation, Swift tests, Apple SDK Codable and resource boundary behavior
have not been executed. Offline receipts are synthetic, not native results.
No claim of final product admission or qualification of every allowed shape.

## Native run

From the exact clean JF3.1 commit (not any later tip):

    python3 -I -B Scripts/test_foundation_models_schemas.py
    python3 -I -B Scripts/qualify_foundation_models_schemas.py "$(git rev-parse HEAD)" /path/outside/checkout/JF3-Evidence --lane apple

Native macOS ARM64 27+, Swift 6.4.2, SDK 27.2. Linux 64-bit Swift 6.4.2 uses
`--lane linux`; no Apple capability inferred. Default 20 GiB free workspace
reserve is not a bound. Use an external volume, retained worktrees and evidence
archives as before. No hosted CI launch. Source-bound decision remains
NOT_ADMITTED regardless of test result. Full existing native, floor, Linux,
WASI and documentation gates plus product API/inventory review precede actual
promotion. Next after native JF3.1: widen only from evidence; qualify the real
reverse nested/array/numeric/boolean shapes and explicit diagnostics, then JF4
native typed conveniences. No existing product, Core/HTTP change or release.
