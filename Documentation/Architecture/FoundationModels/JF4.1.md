# JF4.1 — Prepared generation and native Swift typed ergonomics

**Status:** implementation candidate; native Swift 6.4.2 / SDK 27.2
compilation and execution pending. Parent native review:
`7f63b2c38a578b1fd8c49bb64c95a4d7c98bb3f0`. JF3.3a's 78 passing native method executions remain
source-bound at 1841c8bcc244c1d1304fc06834900ef44e02644e.
No new public product or released API admitted.

## Design: prepare once, use exact values repeatedly

Expose two complementary entry points, no custom macros or second DSL.
JSONPreparedGeneration accepts an existing JSONSchemaDocument; the
caller explicitly selects the existing compatibility policy (default
exact). JSONGenerableCodec<Value: Generable> obtains the actual
Value.generationSchema once and imports it through the qualified JF3
reference-free import profile. No constructor allows pairing a typed
codec with an arbitrary external canonical schema. No implicit structural
opt-in. These candidate types do not declare Sendable for framework-held
state; cross-actor transfer, nested macro-generated reference-bearing
schema import, partial content, generation IDs, dynamic schema widening,
model invocation and tool dispatch remain outside this increment.

Prepared state retains actual GenerationSchema, original CompiledJSONSchema,
actual roundtripped JSONSchemaDocument, annotation additions, structural
rewrites and the selected finite limits. The typed import has no reverse
rewrite: roundtripped is the actual imported schema document and the two
diagnostic arrays are empty. Runtime validation authority remains canonical.
Preparation, authoring the source document, and each subsequent operation
are distinct invocations, not a cumulative session budget. All prepare,
validate, value import/export, typed decode and encode entry points have
WithReport variants reporting their successful native operations.

### Swift-first

```swift
import FoundationModels
import JSON
import JSONFoundationModels

@Generable
struct SearchArguments {
    @Guide(description: "Search query")
    var query: String
    @Guide(.range(1...20))
    var limit: Int
    @Guide(.anyOf(["date", "title"]))
    var sort: String
    @Guide(.count(2))
    var tags: [String]
    var note: String?
}

let codec = try JSONGenerableCodec<SearchArguments>.prepare()
let arguments = try codec.decode(json)
let returned = try codec.encode(arguments)
// For completed GeneratedContent, use the same codec.decode(content).
// codec.prepared.schema is the actual GenerationSchema.
```

The examples require the candidate Apple availability (macOS/iOS 27+)
and an available JSON or GeneratedContent input. The tested form lives
in DeveloperExperienceTests.swift with public imports, not @testable
access. Generic init/content APIs use Apple's Generable protocols, not
a simulated Apple macro.

### Document/DSL-first

```swift
import JSON
import JSONSchema
import JSONSchemaDSL
import JSONFoundationModels

let document = try JSONSchemaDSL.document {
    Schema.type(.object)
    Schema.properties {
        Property("query") { Schema.type(.string) }
    }
    Schema.required("query")
    Schema.additionalProperties(false)
}
let prepared = try JSONPreparedGeneration.prepare(
    document, metadata: .allowGeneratedAnnotations
)
let content = try prepared.generatedContent(from: json)
let returned = try prepared.json(from: content)
```

JSONSchemaDSL is an independent authored-document product; no DSL import
or dependency in JSONFoundationModels. Explicit opt-in for generated
annotations or structural equivalence only. No implicit schema rewriting,
default filling, null removal or unknown keyword dropping.

## Runtime boundary

- JSON -> GeneratedContent: validate original against canonical, then
  JF2 exact export. A schema-valid value may still be unrepresentable.
- GeneratedContent -> JSON: require complete, strictly parse exposed
  JSON, validate canonical. Does not recover any earlier hidden value.
- JSON -> typed Value: validate original before Apple construction; exact
  JF2 export; initialize Value; render its exposed content; require
  complete, strict JSON and exact equality with the validated original.
- GeneratedContent -> typed Value: import complete JSON snapshot and
  validate it before typed initialization; compare typed re-render with
  that snapshot. No hidden pre-framework fidelity assertion.
- typed Value -> JSON: require complete exposed typed representation,
  parse it exactly, validate canonical. No assertion about other Swift
  state or previously discarded input.

Ordinary validate returns JSONValidationResult, including a false verdict.
Conversion rejects invalid arguments with JSONGenerationArgumentFailure
.invalidArguments(result), retaining native bounded keyword/location
diagnostics; a successful schema-valid but changed typed roundtrip throws
.typedValueChanged. JF2 incompleteContent/changedValue/frameworkRejected
remain separate. Native syntax/resource/evaluation failures, cancellation,
and typed callback errors propagate, not a false ordinary verdict.
No partial successful result or report. A typed result may be mutated
later; encoding it again revalidates its exposed representation.
No assumption that a typed initializer alone enforces Guide constraints.

## Accounting and minimal refactor

Extract the existing JF2 import/export internals to borrowed-scope overloads;
the original report entry points still create their one scope and delegate
through exactly the same writer, foreign construction/read, parser and
comparison steps. Reuse the same Apple constructor/error policy and
completion reader. No public JF2 API or JF3 source change. JF4 borrows the
native schema evaluator and JF2 boundary in one JSONCompositionScope across
each composed operation. No nested independent budget or report between
validation, conversion and typed re-render. Check cancellation before and
after opaque callbacks; callback instructions and hidden allocations are
not native-metered, nor does this claim a process RSS bound.

## Qualification

Eight portable-policy Swift Testing methods: validation before foreign
callbacks; complete/invalid/malformed imports; typed roundtrip and
ordering; valid-but-changed typed values; encode validation; schema-valid
but lossy conversion; cumulative work and retention N/N-1; cancellation
after typed callback. Controlled strings are policy peers, not fake
FoundationModels. Four additional Apple methods use the actual public
Candidate API with @Generable/@Guide and JSONSchemaDSL:

- Both absent and present optional note roundtrips from JSON and completed
  GeneratedContent, and typed export.
- Six invalid cases (null, range, enum, count, required, extra property)
  through all four input routes; mutated typed range on encode; nested
  required rejection from DSL. 26 exact route/keyword receipts per mode.
- Nested closed DSL schema matches prior JF3.3 Child rewrite, retains
  canonical and actual Apple schema, and roundtrips a valid instance.
- DSL numeric bounds 2^53 and 2^53+1 survive schema projection, both
  endpoints are schema-valid, but the latter must be rejected by JF2's
  exact value guard. The former must roundtrip.

The runner independently verifies the two typed exact roundtrip receipts,
26 invalid-route receipts, actual guide schema, nested DSL projection
against the same mode's JF3.2 raw schema, and numeric fidelity receipt.
Use the prior exact Decimal/scalar-aware evidence helpers. Mode stability
and all historical JF2.2, JF3.1, JF3.2 and JF3.3 receipt contracts remain
required. Test fixtures and historical runners remain byte-identical.
Existing qualification runner builds in a disposable candidate manifest
with one extra direct JSONSchemaDSL dependency on the TEST target only;
the experimental library still depends only on JSON and JSONSchema.
Zero external package dependencies, original 13 shipping products,
existing target declarations and macOS 15/iOS 18 floors remain unchanged.

Per Debug/Release: 12 JF4.1 methods, 10 JF3.3, 4 JF3.2, 11 JF3.1,
14 JF2.2 = 51 per mode / 102 intended native method executions.
12 subprocesses including both evaluated manifest steps. Preserve exact
source, toolchain, fixture hash, raw logs, exits and separate receipts.

Actual editing-host verification: exact Git blobs of the two Python files
and all four changed/new Swift files checked locally. Python 3.13.5:
12/12 offline unittest methods passed (11 synthetic receipt controls,
one complete Swift frontend syntax preflight covering all four files).
Both Python files compile. Linux Swift 6.2.1 parsed all four Swift files,
and syntax-only copies of the three files with the Apple guards removed.
No native Swift-JSON build or Apple SDK typecheck/execution occurred here.
A failed local compressed transfer was discarded; source reconstructed
directly and verified against exact blob hashes before executing controls.

## Native run

From the exact clean JF4.1 commit:

    python3 -I -B Scripts/test_foundation_models_ergonomics.py
    python3 -I -B Scripts/qualify_foundation_models_ergonomics.py "$(git rev-parse HEAD)" /path/outside/checkout/JF41-Evidence

Native ARM64 macOS 27+, Swift 6.4.2, macOS SDK 27.2; 20 GiB minimum
free workspace (not a bound). Preserve evidence archive on ordinary
failure. Expected outcome APPLE_ERGONOMICS_CANDIDATE_PASS; product
admission NOT_ADMITTED. No merge, tag, hosted CI, public release or
promotion. Review native results before extending the type-first import
profile, external standalone consumer qualification and full platform/
product gates. MF1/MF2 may build on this API once the candidate's native
results and remaining admission gates justify it.
