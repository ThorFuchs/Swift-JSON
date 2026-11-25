# JF4.2 — Nested typed ergonomics and external consumer

**Status:** implementation candidate. Native Swift 6.4.2 / Apple SDK 27.2
compilation, macro behavior and runtime qualification are pending.
Parent review: `458f8900d8d3c1c58a8ec1bf4d076c2f7a38f708`. JF4.1a's 102 successful native
method executions remain source-bound at 45b0eb69ce6bb0aca392f082899db73bbee4d46d.
No public product admission or release.

## Type-first local import

Extend the existing typed codec with an explicit import policy, independent
of the existing reverse projection policies:

```swift
@Generable
struct SearchFilter {
    var query: String
    @Guide(.range(1...20)) var limit: Int
}

@Generable
struct SearchRequest {
    var primary: SearchFilter
    @Guide(.count(2)) var alternatives: [SearchFilter]
    var fallback: SearchFilter?
}

let codec = try JSONGenerableCodec<SearchRequest>.prepare(
    importPolicy: .allowLocalObjectDefinitions
)
let request = try codec.decode(content)
let json = try codec.encode(request)
```

The no-policy overload and explicit .referenceFree retain the old JF3
import path. The new overloads also expose WithReport and finite limits.
JSONGenerationSchemaBridge.importSchema(_:policy:) provides the same
explicit option for an actual GenerationSchema independently of a Swift
type. A typed codec still binds only to its own Value.generationSchema,
not a caller-supplied substitute. No cross-actor Sendable assertion,
new macro or new DSL.

Import is not reverse projection: there is no separately authored earlier
canonical document to compare against. Retain the exact exposed native
Codable representation as the canonical JSONSchemaDocument and compile
that graph offline. roundtripped is this same imported document; no
additions or rewrites are invented. The original reference-free input
profile of all three reverse projection policies remains unchanged.

## Narrow closed local graph

The explicit new policy accepts the existing JF3 reference-free profile
plus root-local $defs tables and pure direct $ref uses of concrete object
definitions. The table is nonempty if present, at most 128 distinct
nonempty exact definition names. Every definition must be reachable.
No root ref, ref siblings, alias chains, referenced scalars or arrays,
nested definition tables, unresolved or cyclic references, external
resolution, URI-scope changes, dynamic references, or new constraints.
The existing closed object, homogeneous array, exact name/keyword,
required, x-order, numeric and enum policy is checked at every effective
schema position. Depth at most 16, at most 128 properties or enum
entries per node. Shared targets checked at every use, with active and
used indices. JSONPointer.uriFragment performs percent and RFC 6901
decoding exactly once, and lookup compares exact decoded scalars. No
expanded schema tree is materialized. Preflight the returned graph before
native schema compilation; the compiler remains the authority for
declaration validity and actual offline reference resolution.

Use the same JSONCodingState and noncopyable meter through native
encoding, document admission, graph preflight, native compilation and
report creation. Existing JF3 local shape check is shared via internal
local-only traversal options; the defaults, historical error order and
reverse proof are retained. Work, logical retention, depth and cancellation
are checked on native-owned operations. Opaque framework callback work
and allocations are outside this ledger. Runtime uses unchanged JF4.1
exact argument validation, complete snapshot import, JF2 export and typed
re-render comparison. An invalid or changed value is never deliberately
repaired. Imported graph compatibility is not a claim about framework
hidden state or model behavior.

## Qualification and external consumer

Six new portable-policy methods: exact canonical graph and shared uses,
escaped/single-decoded fragments, unsupported reference forms, scopes,
cycles and unused definitions, unqualified constraints/depth, cumulative
N/N-1 work and retention, and deterministic cancellation during traversal.
Three actual Apple public API methods: nested macro typed roundtrip,
nested validation (six fixtures through four routes), and actual import
of the previously qualified JF3 nested reverse reference graph. Emit
the raw macro schema before attempting preparation; unanticipated SDK
shapes should produce diagnostic evidence, not broaden the profile.

The independently built Consumer package has its own SwiftPM manifest
and executable, uses only public imports, and depends by local path on
the disposable source-bound candidate package. It exercises the same
nested typed example, two exact roundtrips (optional object absent and
present), 24 invalid-route diagnostics, and a simple JSONSchemaDSL
projection, valid value roundtrip and invalid required rejection.
There is no model invocation, network or tool execution. No separate
ordinary-consumer link isolation claim in this gate.

The standard-library verifier independently compares the effective actual
macro schema to an authored minimal inline contract using the existing
bounded fixed-corpus JF3.3 diagnostic expansion. This must preserve every
validation declaration and only admit qualified annotations and structural
differences. It derives each native keyword trace from the actual local
graph, including the $ref and items steps and the false-subschema empty
keyword; exact keyword, keywordLocation and instanceLocation must agree
across all four routes. It checks the native raw import against the same
mode's historical nested anchor. The external package emits its actual
schema and values separately. Each mode must pass its own full contract,
and Debug/Release must agree within both consumer contexts. No assumption
that module-qualified framework titles are identical between packages.

All historical suites and exact receipt verifiers remain required:
9 JF4.2 + 12 JF4.1 + 10 JF3.3 + 4 JF3.2 + 11 JF3.1 + 14 JF2.2
= 60 native Swift methods per mode, 120 total, plus separate external
Debug and Release builds and executions. Eighteen recorded subprocesses
including the two manifest evaluations. Exact source, fixtures, toolchain,
logs, exits, nested-typed.json, external-consumer.json and historical
regression receipts. The root manifest, old tests, old runners, value
bridge and structural proof remain unchanged. The temporary library still
depends only on JSON and JSONSchema; DSL is a direct dependency of the
test and external consumer only.

Actual editing-host checks: exact Git hashes for all ten modified/new
Swift and Python source files. Python 3.13.5: 15/15 offline controls pass,
including 13 synthetic receipt controls, actual fixture-literal checks
and Swift frontend syntax preflight of all eight changed/new Swift files
plus syntax-only copies of active Apple sections. Both Python files compile.
Swift 6.2.1 Linux syntax only; no native Swift-JSON package compilation or
Apple macro expansion on this host. Independent jsonschema 4.26.0
Draft202012Validator confirms the eight authored fixture verdicts
(two valid, six isolated invalid) against the authored inline contract.
The actual JF4.1a historical simple and nested raw schema anchors agree
with independent delta in both modes. No new native receipt claimed.
A failed local compressed transfer was discarded and corrected with
an exact byte-identical reconstruction before running checks.

## Run

At the exact clean JF4.2 commit:

    python3 -I -B Scripts/test_foundation_models_nested.py
    python3 -I -B Scripts/qualify_foundation_models_nested.py "$(git rev-parse HEAD)" /path/outside/checkout/JF42-Evidence

Native ARM64 macOS 27+, Swift 6.4.2, SDK 27.2. Minimum 20 GiB free
workspace is a preflight, not an upper bound. Use a mounted external
volume for workspace and TMPDIR. Expected outcome
APPLE_NESTED_ERGONOMICS_CANDIDATE_PASS; product admission NOT_ADMITTED.
Return the evidence archive even on failure. Native typechecking,
nested macro output, complete diagnostic paths and both consumer builds
are still gates.

## Release recommendation (pending maintainer decision)

GitHub release inventory checked 2026-11-25: latest published stable
1.9.0, source f2a0d12da7028edfbcb0cb307f19a921a3a12d03.
Main c2e4aea7cf63bdf8236c22cc9ba0c6a3abeb5201 retains the prepared 1.10.0
exact-interchange wave, documented in ReleaseNotes/1.10.0.md and
Qualification/Release1.10.md. Finish that independently (exact release
source receipts, CI and WASI, explicitly approved performance exception
for 1.10 only). Existing release roadmap reserves 1.11 for JSONPath and
schema diagnostics. Recommend, subject to owner approval, prioritizing
the additive JSONFoundationModels product in 1.11.0; keep JSONPath and
diagnostic work on the roadmap without making it a dependency of this
integration. Do not rewrite the approved roadmap or increment CLI
version in this experimental change.

JF5 product admission is a separate step after successful JF4.2:
promote from Tools into Sources and Tests, explicit manifest product and
catalog/API inventory, DocC and external examples, requalify old consumer
isolation, Apple deployment-floor builds, Linux ARM64/x86_64 and WASI
lanes, full applicable native/safety/docs and exact release artifact
checks. No new package-wide platform minimum, external dependency or
core re-export. Apple-facing APIs retain macOS/iOS 27+ availability;
actual old-OS runtime availability and non-Apple behavior require their
appropriate evidence. No new performance claim or inherited waiver.
Use the optional product under one normal package version, not a separate
repo/version. After all gates, owner may explicitly authorize a
1.11.0-rc.1 and later the stable release/tag; developer kit follows the
published source. MF1/MF2 can subsequently pin the admitted version.
No tag, merge, hosted CI, release or actual product promotion in JF4.2.
