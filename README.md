# Swift-JSON

This is **unreleased 1.7.0-dev consolidation source**. Latest stable remains
**1.6.1**; no new tag or release is implied. It combines the existing Navigation
and Inspection projections with the reviewed source-bound graph, JSONTransform
and optional JSONValueDSL/JSONSchemaDSL proposals. The manifest has twelve library
products plus the CLI. The shared JSONDSLCore module has no standalone product;
its reference makes thirteen DocC catalogs. Stable 1.6.1 keeps eight libraries.

Each combined source must pass fresh qualification; predecessor green checks do
not qualify a new tree. See the [consolidation contract](Documentation/Qualification/Consolidation2026.md).

See the [release-line matrix](Documentation/Qualification/ReleaseLines.md) for exact
source scopes and publication boundaries. Version metadata identifies source; the
[official releases](https://github.com/ThorFuchs/Swift-JSON/releases) establish publication.

**Exact JSON values, offline schema validation, transactional patches, pull streams, HTML exports and bounded queries for modern Swift.**

Swift-JSON gives applications one consistent JSON model from input bytes to validated,
transformed and encoded output. It keeps decimal values exact, preserves the identity
of Unicode scalar sequences, and makes resource limits and cancellation part of the
operation contract. Use it when rounding a number, collapsing a key or accepting a
partially read document would change the meaning of your data.

[![Native CI](https://github.com/ThorFuchs/Swift-JSON/actions/workflows/native.yml/badge.svg)](https://github.com/ThorFuchs/Swift-JSON/actions/workflows/native.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

[Read the documentation →](https://thorfuchs.github.io/Swift-JSON/)

Maintained by [Thorsten Fuchs](https://github.com/ThorFuchs). Swift-JSON follows
semantic versioning. Use a released version and retain `Package.resolved` for
reproducible builds; `main` tracks ongoing development.

**1.6.1** is the latest stable maintenance release: eight libraries plus CLI,
eight DocC catalogs and the unchanged 1.6 API/runtime. The optional verified schema
examples, structural traversal, structured HTML previews and bounded composition
were introduced in 1.6.0. Exact JSON and offline schema validation remain the
semantic authorities.
The published CLI reports `1.6.1`; this development source reports `1.7.0-dev`.
Both use a deterministic source-content digest.
The [published 1.6.1 release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.6.1)
is pinned to `e431f157ececc0cf3d061192420b0e36a9062f83`. Use its matching eight-catalog
DocC and qualification assets for the stable reference; see the
[maintenance qualification notes](Documentation/Qualification/Release1.6.1.md).
Historical N0/N1 plans and later candidates are distinguished in the
[source authority map](Documentation/Architecture/StructuralIntelligence/SOURCE-AUTHORITY.md).

This development source includes opt-in Inspection, Transform and authored DSLs:
twelve libraries plus the CLI, thirteen products in total. Inspection, Transform and DSLs are absent from stable 1.6 releases. Pin a reviewed
unreleased source commit to use those products; the compatible stable installation
requirement below does not supply them. Integration into main does not publish 1.7.0.

The 1.5.1 maintenance repairs remain included: best-effort schema diagnostics,
the complete 1.2.1 regression suites and Git-free qualification. See the
[1.6 qualification and compatibility notes](Documentation/Qualification/Release1.6.0.md)
for source-bound evidence, finite-capacity boundaries and known DocC limitations.

## Why Swift-JSON?

JSON is simple on the wire, but its meaning can become less precise as it moves
through an application. A large integer may be rounded by a binary floating-point
bridge. Swift String equality may merge keys with different scalar spellings.
Schema failure may be confused with an exhausted evaluator. A stream may yield a
value before the enclosing document's final bytes have been checked.

Swift-JSON keeps those boundaries explicit:

- **Exact decimal meaning.** `9007199254740993` remains distinct from
  `9007199254740992`. Equivalent decimal spellings compare mathematically.
- **Faithful text and keys.** Strings and keys compare decoded Unicode scalars,
  without canonical normalization. Objects preserve insertion order while equality
  ignores member order.
- **One strict codec.** Complete documents and streams use the same UTF-8 grammar.
  Malformed input, duplicate decoded keys and trailing data produce errors.
- **Offline schema plans.** Compile Draft 2020-12 schemas and explicitly supplied
  resources once, then share immutable plans across independent validations.
- **Finite, observable work.** Every default profile is finite. Bounded operations
  enforce cumulative quotas and offer public reports of charged work and logical
  retention.
- **Clear completion.** Patch results are staged; stream completion certifies the
  framing boundary; awaited sinks make acceptance and backpressure explicit.

The package fits data processing, configuration, schema-driven tooling and
applications handling untrusted JSON. Its native Codable layer also provides a
familiar route from Swift models to the exact value model.

## Requirements and products

| Requirement | Supported baseline |
| --- | --- |
| Swift tools and compiler | 6.4 or later |
| Swift language mode | 6 |
| Platform and SDK | macOS 27, iOS 27 or iPadOS 27 and later |
| Runtime dependencies | None outside the package and platform SDK |
| License | Apache-2.0 original code, with retained upstream notices |

Choose the products your application needs:

| Product | Use it for |
| --- | --- |
| **JSON** | Exact values, strict parsing/writing, native Codable, Pointer, presence, checked construction, source documents and diagnostics |
| **JSONSchema** | Draft 2020-12 compilation/evaluation, offline registries, bounded regex, annotations and raw declaration inspection |
| **JSONSchemaExamples** | Opt-in deterministic exact candidates, conservative typed construction and native schema certification, introduced in 1.6.0 |
| **JSONStreaming** | Pull syntax events and values, strict NDJSON, root-array elements and awaited output chunks |
| **JSONHTML** | Exact HTML and immutable exports; structured forms/cards and bounded previews in 1.6.0 |
| **swift-json** | Bounded command-line JSON workflows (available since 1.5.0) |
| **JSONBridges** | Opt-in native integer, Double and Foundation Decimal conversions (available in the 1.4.0 tag and 1.5.0 release) |
| **JSONNavigation** | Opt-in exact many-node DFS, physical/virtual scopes, finite metadata and explicit coverage, introduced in 1.6.0 |
| **JSONInspection** | Unreleased source: array evidence, complete source-attached snapshots, selected trees, strict sparse object-row tables and exact set/numeric-matrix views |
| **JSONTransform** | Candidate library: exact query plans, guarded pull execution and finite cumulative limits; see the [extraction checkpoint](Documentation/Architecture/Release1.7/JSONTransform.md) |
| **JSONValueDSL** | Trusted authored exact objects and arrays; finite checked finalization |
| **JSONSchemaDSL** | Trusted authored Draft 2020-12 documents using the native compiler/validator |
| **JSONPatch** | Staged RFC 6902 JSON Patch and RFC 7396 Merge Patch |

`JSONSchema`, `JSONStreaming`, `JSONPatch`, `JSONHTML` and opt-in `JSONBridges` build on `JSON`. The package-private
`JSONRegexRuntime` is an implementation detail and has no public product. The root
SwiftPM dependency graph is empty. Qualification and benchmark tools are separate
packages. The unreleased JSONInspection product depends only on JSON and
JSONNavigation; core never re-exports it.

The optional `JSONSchemaExamples` product depends only on JSON and
JSONSchema. It prepares immutable offline resources and offers exact declared hints
and conservative typed candidates. Every returned value has passed native validation
against the original root. The supported subset includes exact numeric/string bounds,
required objects, positional arrays, static references, composition hints, contains
minima and bounded anchored ASCII-pattern proposals. Unsupported or exhausted search
is explicit and does not establish unsatisfiability. See [generate verified examples](#generate-verified-schema-examples)
and the [compiled public guide consumer](Examples/SchemaExamplesConsumer/README.md).

The inherited Linux increment adds portable schema integrity for its qualified products
without runtime dependencies. Its initial qualification scope is Swift 6.4+,
64-bit Ubuntu 24.04/glibc; see the [Linux contract](Documentation/Architecture/Linux.md)
for execution gates and limits. Apple platform requirements remain unchanged.

The separately qualified WASI core scope targets full-language Swift 6.4
`wasm32-unknown-wasip1`, with finite defaults and exact persistence. Its
[platform contract](Documentation/Architecture/WebAssembly.md) documents resource
packaging, execution hosts, qualification scope and safety limitations. Browser
and Embedded Swift hosting require separate qualification. JSONSchemaExamples has native
source-bound G1–G7 and caller-lifetime repair evidence. The released combined-source
qualification is recorded in [G8 integration](Documentation/Architecture/Release1.6/G8Integration.md)
and the [1.6.0 qualification notes](Documentation/Qualification/Release1.6.0.md);
earlier stage receipts retain their original source and unfinished gates.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/ThorFuchs/Swift-JSON.git", from: "1.6.0")
```

Then add products to your target dependencies:

```swift
.product(name: "JSON", package: "swift-json"),
.product(name: "JSONSchema", package: "swift-json")
```

Add `JSONStreaming`, `JSONPatch`, `JSONHTML`, `JSONBridges`, `JSONNavigation`
or `JSONSchemaExamples` in the same way when needed. A local checkout can
use `.package(path: "../Swift-JSON")`. The requirement above accepts compatible 1.x
releases. See the [eight-library source consumer](Examples/Consumer) for a complete buildable
manifest. The website tracks `main`; release assets include compiled DocC catalogues
for the exact released source. JSONInspection requires this unreleased source
checkout; the 1.6.0 tag does not contain it.

## Quick entry points and native bridges (available in the 1.4.0 tag and 1.5.0 release)

The released ergonomic entry points provide a shallow discovery hub. Existing parser/writer and
report APIs remain the semantic authorities; no migration is required.

```swift
let quick = try JSON.parse(#"{"n":9007199254740993,"note":null}"#)
let quickCount = try quick.read { try $0["n"].requiredInteger(as: UInt64.self) }
precondition(quickCount == 9_007_199_254_740_993)
let quickDecimal = try JSON.number(parsing: "0.1")
precondition(quickDecimal.numberValue != nil)
```

Add the optional `JSONBridges` product dependency and import it explicitly:

```swift
import JSONBridges

let bridgeCount: UInt64 = 9_007_199_254_740_993
let bridgeNumber = bridgeCount.jsonNumber() // Trusted, unmetered integer construction.
let bridgeRecovered = try UInt64(jsonNumber: bridgeNumber)
precondition(bridgeRecovered == bridgeCount)
let bridgeTenth = try JSONNumber(parsing: "0.1")
let bridgeRounded = try Double(jsonNumber: bridgeTenth, policy: .rounded)
precondition(bridgeRounded == 0.1)
```

Exact Double projection rejects decimal 0.1. A finite Double's round-trip decimal
text is distinct from its exact binary rational. Read the
[entry-point guide](Sources/JSON/Documentation.docc/QuickEntryPoints.md),
[numeric fidelity guide](Sources/JSONBridges/Documentation.docc/NumericFidelity.md)
and [before/after crosswalk](Documentation/Ergonomics/README.md).

## Typed authored DSLs (P1.2 development)

Select the optional `JSONValueDSL` and `JSONSchemaDSL` products explicitly. They add
syntax over the same exact model and schema engine; neither is imported by core.
These APIs are development additions on main's feature line, not additions to older tags.

```swift
import JSONValueDSL
import JSONSchemaDSL

let authoredTenth = try JSONNumber(parsing: "0.1")
let authoredJSON = try JSONValueDSL.object {
    Field("amount", exactNumber: authoredTenth)
    Field.array("nested") { Element.array { Element(1); Element(2) } }
}
let authoredSchema = try JSONSchemaDSL.document {
    Schema.type(.object)
    Schema.properties {
        Property("amount") { Schema.type(.number); Schema.minimum(authoredTenth) }
    }
    Schema.required("amount")
}
let authoredPlan = try JSONSchemaCompiler().compile(authoredSchema)
let authoredResult = try JSONSchemaValidator().validate(authoredJSON, against: authoredPlan)
precondition(authoredResult.isValid)
```

This syntax is for **trusted authored configuration**. Callbacks, wrapper collection
and staging are unmetered. Only iterative finalization and schema-document admission
share a finite ledger; there is no staging/RSS bound or whole-DSL cumulative report.
Use checked accumulators or the parser for dynamic untrusted input. Exact duplicates
throw, scalar-distinct keys remain distinct, omitted branches emit nothing, and arrays
expand only through explicit `Elements(contentsOf:)`. There is no implicit Float/Double
bridge, requiredness inference, default application or custom schema validator.

See the [value guide](Sources/JSONValueDSL/Documentation.docc/AuthoredValues.md),
[schema guide](Sources/JSONSchemaDSL/Documentation.docc/AuthoredSchemas.md),
[public-only consumer](Examples/DualDSL) and [qualification scope](Documentation/Qualification/DualDSL).
The shared JSONDSLCore module has no standalone product; its typed composition contracts
support the two optional APIs. Typed schema synonyms and an umbrella import remain deferred.

## Parse, inspect and write exact values

```swift
import JSON

let parser = JSONParser()
let value = try parser.parse(#"{"count":9007199254740993,"note":null}"#)
let count = try JSONPointer(parsing: "/count").resolve(in: value)
let exact = try count.numberValue!.integer(as: Int64.self)
precondition(exact == 9_007_199_254_740_993)

let encoded = try JSONWriter().write(value)
let roundTrip = try parser.parse(encoded)
precondition(roundTrip == value)
```

The optional accessors inspect the value kind without coercion. This example unwraps
a number from known input; applications should handle a missing or mismatched kind.
`requiredMember` requires presence, while `JSONPresence` distinguishes absence from
explicit null:

```swift
let note = try value.presence(of: "note")
let missing = try value.presence(of: "missing")
precondition(note == .null)
precondition(missing == .absent)
```

Scalar identity also survives object construction:

```swift
let keys = try JSONObject(members: [
    JSONMember("\u{e9}", value: 1),
    JSONMember("e\u{301}", value: 2)
])
precondition(keys.count == 2)
```

`JSONNumber` supports bounded exact integer, Double and Decimal conversion. Exact
Double conversion rejects decimal `0.1`; choose `.rounded` explicitly when finite
rounding is appropriate. Preserved writing uses original numeric lexemes when
available. Scalar key sorting is deterministic output, without a cryptographic
canonicalization claim. See [numbers and Unicode](Documentation/Architecture/NumbersAndUnicode.md).

## Use native Codable

```swift
struct Reading: Codable, Equatable {
    let count: UInt64
    let label: String
}

let reading = Reading(count: 9_007_199_254_740_993, label: "sensor")
let bytes = try JSONWriter().encode(reading)
let decoded = try JSONParser().decode(Reading.self, from: bytes)
precondition(decoded == reading)
```

`JSONValueEncoder` and `JSONValueDecoder` work directly with JSON values.
The byte conveniences compose parsing/coding or coding/writing under one cumulative
meter, using the intersection of their configured limits. Direct JSON, JSONObject
and JSONNumber coding preserves exact payloads. String dictionaries fail when Swift
key equality would collapse scalar-distinct JSON keys.

Integer projections are exact; native Float and Double decoding performs finite
rounding. Data uses strict metered Base64 by default. Date uses its Codable behavior
by default; explicit ISO-8601 uses bounded UTC text with fractional seconds and
four-digit years. Foreign Codable encoders/decoders determine their own numeric and
key fidelity. Caller callbacks remain caller-owned work.

## Scoped reads and exact persistence

Release 1.1.0 includes scoped reads, native value-coding conveniences,
exact Version 1 persistence and a measured private wide-object index.
iPadOS acceptance uses the SDK and iPad simulator, including disk persistence;
physical iPad qualification is deferred and nonblocking. Physical iPhone checks
remain required. Simulator results make no physical-device performance claim.
See the [release plan](Documentation/Architecture/Release1.1/Plan.md) and
[qualification policy](Documentation/Architecture/Release1.1/QualificationPolicy.json).

```swift
let scoped = try value.readWithReport { root in
    let exactCount = try root["count"].requiredInteger(as: UInt64.self)
    let optionalNote = try root.stringPresence(of: "note")
    return (exactCount, optionalNote)
}
precondition(scoped.result.0 == 9_007_199_254_740_993)
precondition(scoped.result.1 == .null)
precondition(scoped.statistics[.workUnits] > 0)
```

Throwing String/JSONKey/Int brackets preserve literal scalar keys and typed array
indices. Required access never coerces or defaults. Presence distinguishes absent,
null and a non-null value; native model projection shares the scope's cumulative
meter. Double/Decimal getters require an explicit exact or rounded policy.
Escaped cursors invalidate at scope exit and retain no selected root/source.

```swift
import Foundation

let payload = try JSONCodablePayload(preserving: value)
let transported = try PropertyListEncoder().encode(payload)
let restored = try PropertyListDecoder().decode(JSONCodablePayload.self, from: transported)
let restoredValue = try restored.value()
precondition(restoredValue == value)
```

The explicit wrapper transports a fixed ASCII envelope with strict Base64 of
complete JSON, preserving exact decimals, scalar sequences, order and admitted
number lexemes. It retains validated bytes only. Automatic coding uses finite
balanced limits; explicit limits can tighten them. Foreign coder work remains
caller work. For SwiftData, use `@Attribute(.codable)` in your application target;
see the [executed disk example](Tools/MobileQualification/README.md).

## Compile and validate schemas offline

```swift
import JSONSchema

let schema = try JSONSchemaDocument(parser.parse(
    #"{"type":"object","properties":{"count":{"type":"integer"}},"required":["count"]}"#
))
let plan = try JSONSchemaCompiler().compile(schema)
let result = try JSONSchemaValidator().validate(value, against: plan)
precondition(result.isValid)

let output = try result.output()
precondition(output.objectValue?["valid"] == true)
```

A `false` verdict means a completed validation found an invalid instance. Malformed
schemas, unresolved resources, nonproductive reference cycles, quota exhaustion and
cancellation are operational errors and throw. They propagate through schema branches.

Supply external resources through `JSONSchemaRegistry`; compilation and validation
perform no online resolution. Packaged official meta-schemas retain their pins and
integrity checks. Plans are immutable and Sendable; evaluations own separate state.
A schema containing only `$defs` does not select an instance schema: explicitly root
validation with a `$ref` to the intended definition.

Format is annotation by default. A required format-assertion vocabulary or explicit
`formatAssertion` enables the documented native recognizers. Content keywords remain
metadata. Flag/basic output reflects the diagnostics actually collected; a flag-only
result cannot be upgraded to invent basic errors. Raw declaration inspection exposes
exact constraints and metadata without inferring effective schemas or applying defaults.

The private regex VM uses ECMA-262 2020, fixed Unicode 13.0.0, case-sensitive
u-equivalent behavior and unanchored searches. Compilation, candidate scanning,
states, captures, matching work and cancellation are budgeted. Exact-spelling programs
share immutable storage within a plan. See the [schema and regex contract](Documentation/Architecture/SchemaAndRegex.md)
and [public consumer interface](Documentation/ConsumerInterface.md).

## Generate verified schema examples

Add the optional `JSONSchemaExamples` product to your target alongside JSON and
JSONSchema, using version 1.6.0 or later. The generator is useful for deterministic test
fixtures, documentation samples and schema-driven tooling; it is a conservative
search, with complete native validation required for every returned value.

```swift
import JSONSchemaExamples

let exampleSchema = try JSONSchemaDocument(JSONParser().parse(
    #"{"type":"integer","minimum":9007199254740993}"#
))
let exampleGenerator = try JSONSchemaExampleGenerator(document: exampleSchema)
let schemaExample = try exampleGenerator.generate(seed: 42, profile: .minimal)
let exampleMinimum = try JSONNumber(parsing: "9007199254740993")
precondition(schemaExample.validation.isValid)
precondition(schemaExample.value.numberValue == exampleMinimum)
precondition(schemaExample.statistics[.evaluationWorkUnits] > 0)
```

Preparation owns a separate finite compilation/snapshot ledger. Each generation
shares one cumulative budget across discovery, staging, invalid candidates, native
validation and final trace hashing. Defaults/examples are hints; no defaults,
requiredness or format assertion are invented. A `$defs`-only document needs an
explicit root `$ref` to the desired definition. Registries remain offline and
immutable. `.demonstration` uses a versioned seeded synthetic corpus, without an
AI service or network access.

The result binds source, ordered corpus, policies, algorithm and complete trace
identities. Search exhaustion or unsupported construction can occur for satisfiable
schemas. Operational errors and cancellation terminate the call with no candidate
or successful report. Logical retention snapshots certification and conservative
staging reservations; it is not heap size or RSS. Read the [getting-started guide](Sources/JSONSchemaExamples/Documentation.docc/VerifiedCandidates.md),
[supported subset](Sources/JSONSchemaExamples/Documentation.docc/TypedConstruction.md),
[policies and limits](Sources/JSONSchemaExamples/Documentation.docc/PoliciesAndLimits.md)
and [current API contract](Documentation/Architecture/Release1.6/API.md).

## Apply transactional patches

```swift
import JSONPatch

let patch = try JSONPatch(operations: [
    .replace(path: JSONPointer(parsing: "/count"), value: 42)
])
let changed = try patch.applying(to: value)
let expectedChange = try parser.parse(#"{"count":42,"note":null}"#)
precondition(changed == .document(expectedChange))

let merged = try JSONMergePatch(.null).applying(to: value)
precondition(merged == .null)
```

RFC 6902 operations stage changes and admit each intermediate value before exposing
one complete result. A failure leaves the caller value unchanged. `test` uses exact
value equality; `move` removes its source before resolving its destination.
`JSONPatchResult.removed` means there is no root and differs from `.document(.null)`.
RFC 7396 null object members remove properties, while a root null replaces the root
with JSON null. See the [Patch contract](Documentation/Architecture/Patch.md).

## Pull streams and await sinks

```swift
import JSONStreaming

func inspectArray<Source: AsyncSequence>(_ source: Source) async throws -> UInt64
where Source.Element == JSONByteChunk {
    var elements: UInt64 = 0
    var completed = false
    for try await event in JSONTopLevelArraySequence(source) {
        switch event {
        case .element(let index, _):
            precondition(index == elements)
            elements += 1
        case .documentCompleted(let summary):
            precondition(summary.records == elements)
            completed = true
        }
    }
    precondition(completed)
    return elements
}
```

Each iterator pulls one owned chunk at a time with exclusive state and no detached
producer queue. Root-array elements and syntax events remain provisional until
completion. A document completes only after its closing syntax, trailing whitespace
and EOF. `JSONValueSequence` waits for its framing boundary before yielding a value;
`NDJSONValueSequence` rejects blank/malformed physical records and never skips them.

`JSONAsyncWriter` awaits acceptance of every bounded chunk. Error or cancellation
stops later pulls/writes; previously accepted bytes remain accepted. Stage them in a
caller-owned sink when publication must be atomic. Source allocations and sink code
are caller work. See [streaming](Documentation/Architecture/Streaming.md) and
[concurrency](Documentation/Architecture/Concurrency.md).

## Set finite limits and observe charged work

```swift
var limits = JSONLimits.conservative
limits[.inputBytes] = 1_048_576
limits[.workUnits] = 2_000_000
let report = try JSONParser(options: .init(limits: limits))
    .parseWithReport(Array(#"{"ready":true}"#.utf8))
precondition(report.result.objectValue?["ready"] == true)
precondition(report.statistics[.workUnits] > 0)
```

The 49 metrics cover document capacities, owned logical retention, compilation,
evaluation, regex, streaming, Patch and cancellation. `.balanced` is the default;
`.conservative` and `.offline` are also finite. Limits are inclusive and checked
before growth. Subsystem work is already included in aggregate work.

Composed owned operations share cumulative budgets. For separate public calls, carry
checked remaining work forward from successful reports and retain subsystem ceilings
separately. Treat an error or cancellation as terminal for the composition: a failed
call provides no successful accounting report, so retrying with a fresh full budget
would lose the cumulative bound. The [runnable downstream consumer](Tools/MCPReadiness)
demonstrates this with public APIs only; it does not establish MCP server conformance.

Logical retained bytes are reproducible accounting quantities, distinct from RSS,
heap size and caller retention. Work units describe owned primitive operations,
distinct from wall-clock deadlines or arbitrary caller instruction quotas. The finite
profiles remain initial policy with native boundary and calibration evidence, without
hard RSS or throughput guarantees. Read the [resource contract](Documentation/Architecture/ResourceLimits.md),
[machine-readable profiles](Documentation/Architecture/ResourceProfiles.json) and
[49-cap ownership matrix](Documentation/Qualification/LimitsMatrix.json).

## Standalone HTML

`JSONHTML` presents the exact value as ordered object forms, indexed array cards and
small scalar flow lists. The direct renderer defaults to interactive structured
inspection. Static presentation is script-free; syntax is an explicit alternate.

```swift
import JSON
import JSONHTML

let valueForHTML = try JSONParser().parse(#"{"amount":9007199254740993,"note":"**Hello** $x_i^2$"}"#)
let interactiveHTML = try JSONHTMLRenderer().renderWithReport(valueForHTML)
precondition(interactiveHTML.statistics.copyJSONBytes > 0)
let staticHTML = try JSONHTMLRenderer(options: .init(
    layout: .structured, presentation: .formatted, valueProfile: .complete)
).render(valueForHTML)
let syntaxHTML = try JSONHTMLRenderer(options: .init(
    layout: .syntax, presentation: .formatted)
).render(valueForHTML)
```

Inspection string prefixes are labelled and capped at 512 decoded scalars, 2048 UTF-8
bytes and 512 escaped-display scalars. Original values and full JSON source remain
accessible without JavaScript. Keys, numbers and node structure remain complete.
Copy/download use exact native writer bytes. Complete printing expands all values
independently of collapsed screen state or selected tab.

The bounded native preview dialect adds supported sRGB swatches, declared canonical
PNG/JPEG, star emphasis, inert links and atomic mini-math as MathML Core. It keeps
unsupported/malformed spans literal. There is no full Markdown/TeX engine, remote
media, raw markup or mandatory schema/browser dependency. Native image header admission
is distinct from browser raster decoding and process memory.

Prepared export defaults to static structured complete values and light colors;
JSON/text/Markdown/RTF bytes and strict JSON import retain their contracts. Explicit
Apple PDF consumes prepared HTML, awaits fonts/media and reports its backend and
page strategy. Generation and PDF preparation each have an explicit cumulative budget;
transport, receiver and opaque SDK work are separate.

Read the [structured preview guide](Sources/JSONHTML/Documentation.docc/StructuredPreviews.md),
[formatted syntax guide](Sources/JSONHTML/Documentation.docc/FormattedRendering.md),
[prepared export guide](Sources/JSONHTML/Documentation.docc/PreparedExport.md) and
[API/policy freeze](Documentation/Architecture/Release1.3/StructuredPreviews/APIAndPolicy.md).
The consolidated design revision is not a package release number. Version 1.6.0
adds these structured previews; choose the explicit syntax layout when upgrading
an application that requires the earlier syntax-first presentation.

## Documentation and examples

Browse the [public documentation site](https://thorfuchs.github.io/Swift-JSON/):
[JSON](https://thorfuchs.github.io/Swift-JSON/JSON/documentation/json/),
[JSONSchema](https://thorfuchs.github.io/Swift-JSON/JSONSchema/documentation/jsonschema/),
[JSONSchemaExamples](https://thorfuchs.github.io/Swift-JSON/JSONSchemaExamples/documentation/jsonschemaexamples/),
[JSONStreaming](https://thorfuchs.github.io/Swift-JSON/JSONStreaming/documentation/jsonstreaming/) and
[JSONPatch](https://thorfuchs.github.io/Swift-JSON/JSONPatch/documentation/jsonpatch/),
[JSONHTML](https://thorfuchs.github.io/Swift-JSON/JSONHTML/documentation/jsonhtml/) and
[JSONBridges](https://thorfuchs.github.io/Swift-JSON/JSONBridges/documentation/jsonbridges/) and
[JSONNavigation](https://thorfuchs.github.io/Swift-JSON/JSONNavigation/documentation/jsonnavigation/).
The site tracks `main` and publishes only after all four native CI lanes pass.
For the exact 1.6.0 interface, use its
[tagged source documentation](https://github.com/ThorFuchs/Swift-JSON/tree/1.6.0/Sources).
Matching compiled catalogs accompany the published 1.6.0 GitHub release. Preserved
draft-preparation receipts retain their historical status and are not new release
claims. Known
web-client limitations and direct-link/reload guidance are recorded in the
[qualification notes](Documentation/Qualification/Release1.6.0.md#documentation).

The [documentation index](Documentation/README.md) links the behavior contracts. The eight released DocC catalogs
provide public API references, focused guides, parameter descriptions and failure
contracts, compiled from the native Swift public symbol graphs.

This development source has thirteen catalogs: twelve library references and the
shared JSONDSLCore structure reference. Build the source catalogs on a supported native host:

```sh
python3 Scripts/ci.py --lane docs
```

[Documentation tooling](Documentation/DocumentationTooling.md) describes outputs,
coverage checks and local viewing. README Swift examples are compiled and run by
[Examples/Consumer](Examples/Consumer). The public API contracts and generated
references describe observed interfaces; the source remains inspectable.

## Quality, performance and scope

[Native CI](https://github.com/ThorFuchs/Swift-JSON/actions/workflows/native.yml)
checks manifest/dependency boundaries, debug/release behavior, public consumers,
finite-cap probes, pinned independent suites, sanitizers, strict memory safety and
documentation. Receipts record actual commands, toolchains, source hashes and case
counts. Policy exclusions are reported separately from evaluated successes. See
[qualification](Documentation/Qualification/README.md) and [CI](Documentation/CI/README.md).

Performance is measured separately on native release builds. The released 1.0
streaming comparison is approximately **11% slower**, exceeding the unchanged 10%
review trigger, with its accepted disposition and measurement limits documented in
[performance notes](Documentation/Performance/README.md). Logical retention remains
separate from process RSS. Scalar scanning and plan-local immutable regex sharing
are the qualified choices. Projection and JSON text-sequence framing remain deferred.
The 1.1 candidate's separate matched stream comparison is **15.76% slower**; its
[integrated review](Documentation/Architecture/Release1.1/IntegratedPerformance.md)
retains the accepted disposition. The [additional QA wave](Documentation/Architecture/Release1.1/QA.md)
records conformance coverage and the Base64 accounting correction.

## Contributing, support and licensing

For optional agent assistance in an application using this package, see the
[developer kit](Documentation/AgentDeveloperKit.md) and its
[0.1.0 preview downloads](https://github.com/ThorFuchs/Swift-JSON/releases/tag/developer-kit-v0.1.0).
The standalone skill and skills-only plugin target released library 1.6.1 and
keep unreleased Inspection separate from stable recipes. Plugin installation
and public directory availability retain the limits described in the kit guide.

Focused improvements, reproducible issues and documentation corrections are welcome.
Read [CONTRIBUTING](CONTRIBUTING.md) for the native development workflow:

```sh
python3 Scripts/ci.py --lane native
python3 Scripts/ci.py --lane safety
python3 Scripts/ci.py --lane docs
```

Use [GitHub Issues](https://github.com/ThorFuchs/Swift-JSON/issues) for public bugs
and feature discussion. Report vulnerabilities through
[GitHub private vulnerability reporting](https://github.com/ThorFuchs/Swift-JSON/security/advisories/new),
following [SECURITY](SECURITY.md); see [SUPPORT](SUPPORT.md) for maintenance and help.

Original code is licensed under [Apache-2.0](LICENSE). Adapted code and qualification
inputs retain their applicable [notices](NOTICE), [third-party notices](THIRD_PARTY_NOTICES.md),
[licenses](Licenses) and [extraction provenance](Documentation/Architecture/ExtractionManifest.json).

## Command-line tool (released in 1.5.0)

`swift-json` accompanies the eight libraries in published 1.6.0. It provides strict formatting, validation, Pointer selection, staged
Patch and qualified HTML/text/Markdown rendering. See the [CLI plan](Documentation/Architecture/Release1.4/Plan.md)
and [foundation contract](Documentation/Architecture/Release1.4/Foundation.md)
for command semantics, cumulative budgets and qualification boundaries. The pull
query increment adds navigation, generators, control, bindings and exact decimal
arithmetic; see the [query](Documentation/Architecture/Release1.4/QueryCore.md) and
[arithmetic](Documentation/Architecture/Release1.4/Arithmetic.md) contracts. The [advanced filter increment](Documentation/Architecture/Release1.4/Advanced.md)
adds lexical functions, reductions, bounded collections/strings, path mutation and
interpolation. Apple and Linux qualification is recorded in the release assets. Full CLI/WASI
execution and Apple model/schema helpers remain outside the qualified scope.

```sh
swift build -c release --product swift-json
.build/release/swift-json format --compact input.json
.build/release/swift-json validate --schema schema.json input.json
.build/release/swift-json render input.json --output inspection.html
```

### Run exact pull queries

Published 1.6.0 has eight libraries plus the executable; this development source has twelve
libraries plus the executable, with no external root
dependencies. Build the selected source version
with Swift6.4+ (`swift build -c release --product swift-json`), or use
`swift run swift-json help`. Native qualification requires macOS/SDK27+.

```sh
swift run swift-json query --compact '.items[] | select(.active) | .name' input.json
swift run swift-json stream check --framing ndjson records.ndjson
swift run swift-json render input.json --presentation static --output output.html
```

Numbers use bounded exact decimal arithmetic; repeating division requires explicit
`--division-scale N --rounding half-even`. Text and keys preserve decoded Unicode
scalars. Work is cumulative across compilation, inputs, filters and output. All
profiles are finite; logical retention is distinct from process RSS. The CLI is
a specified filter dialect with documented exclusions, rather than a blanket jq
compatibility claim. It never executes shell filters or fetches references.

See the [CLI reference](Documentation/Architecture/Release1.4/CLIReference.md),
[integration contract](Documentation/Architecture/Release1.4/Integration.md) and
[acceptance ledger](Documentation/Architecture/Release1.4/Acceptance.json).
The frozen 1.5.0 CLI reports `1.4.0-dev` and revision `unknown`, as disclosed in
its release notes. Version 1.6.0 reports its source version and a
deterministic source digest; see the [CLI guide](Documentation/CLI.md).
Versioned release assets identify the exact qualified platform and source scope.

### Offline provider fragments (available since 1.5.0)

The released CLI supports `swift-json schema provider openai-format schema.json --name summary`
and `openai-tool`. The public JSONSchema facade `OpenAIJSONSchemaBridge` checks a frozen strict
Responses base-model subset and returns native request fragments, with exact values and finite
cumulative reports. It makes no requests and never rewrites optional properties, keys or numbers.
Incompatibility exits1; operational errors remain errors. Apple schema/model bridges are separate.
See the [provider contract](Documentation/Architecture/Release1.4/Providers.md) and
[compiled public consumer](Tools/CLIQualification/Sources/ProviderConsumer/Main.swift).

## Exact structural navigation

`JSONNavigation` adds many-node DFS preorder over a captured canonical document,
with insertion-order object members, increasing array indices and exact typed
locations. Physical and virtual scopes, explicit overlap/stop/pruning policies,
bounded metadata collection and coverage share one finite cumulative core budget.
Add the JSONNavigation product and import it explicitly. Existing one-node reads
remain in JSON. Full source admission precedes traversal option validation.
See the [compiled traversal guide](Sources/JSONNavigation/Documentation.docc/Traversal.md)
and [real external SwiftPM consumer](Tools/NavigationQualification). Navigation is
opt-in in the published 1.6.0 release; one-node lookup remains in JSON. This source
also includes unreleased N2 inspection. N3 snapshots and P1 tree/sparse-table projections are admitted in this candidate;
other proposals remain separate;
see the [source authority map](Documentation/Architecture/StructuralIntelligence/SOURCE-AUTHORITY.md).
They do not expand the released Navigation API or promote public E11 projection.

## Inspect array evidence (unreleased source)

Add the opt-in JSONInspection product and import it explicitly. Inspect a complete
array or a deterministic prefix without changing its exact values. Column counts
use observed object rows: present includes null, while missing excludes nonobject
rows. Prefix observations make no statement about an unseen suffix.

```swift
import JSONInspection

let shapeSource = try JSON.parse(#"[{"name":"Ada","note":null},{"name":"Grace"},false]"#)
let shapeReport = try JSONShapeInspector(document: JSONDocument(root: shapeSource))
    .inspectArray(sampling: .prefix(maximumRows: 2))
precondition(shapeReport.result.rowCoverage == .prefix(examined: 2, total: 3))
precondition(shapeReport.result.firstSeenColumns[1].explicitNull == 1)
precondition(shapeReport.result.firstSeenColumns[1].missing == 1)
precondition(shapeReport.statistics[.workUnits] > 0)
```

Full source admission still includes the unobserved suffix. Complete row evidence
can have restricted descendant traversal; structural rectangular width is not
numeric matrix or schema admission. See the [compiled evidence guide](Sources/JSONInspection/Documentation.docc/ArrayEvidence.md),
[public consumer](Tools/InspectionQualification) and [accounting contract](Documentation/Architecture/StructuralIntelligence/Inspection.md).

## Complete source-attached structural views (unreleased)

Opt-in JSONInspection in this candidate combines array observations with a
complete parent-linked snapshot, selected physical tree views and strict sparse
all-object tables. Use core Pointer/read for one value and Navigation for many-node
traversal. Inspection keeps exact typed locations, source order and numeric/key
meaning. Sparse cells distinguish missing, explicit null and values; positive
prefix observations never certify the complete table.

Read the [compiled structural guide](Sources/JSONInspection/Documentation.docc/StructuralProjections.md),
[public consumer](Tools/ProjectionQualification) and [NAV8 source/API decision](Documentation/Architecture/StructuralIntelligence/NAV8Completion.md).
Every construction has one cumulative finite ledger. Each later catalogue/cell/
location/value/span lookup is an explicitly separate full-source-admitted operation.
Ordinals are snapshot-local trusted positions, not durable identity. Logical
retention is not RSS; G4 controlled performance remains HOLD, with no speed claim.
These additions are absent from published 1.6.1 and do not publish 1.7.0.

The current development branch also contains package-private structural set and
exact numeric matrix experiments. They add no public API; see the
[NAV9 qualification contract](Documentation/Architecture/StructuralIntelligence/NAV9/PrototypeQualification.md).

### Exact set and numeric matrix views (development source)

JSONInspection now includes immutable first-occurrence structural sets and completely
admitted exact numeric matrices. Sets preserve original representatives and scalar/decimal
identity; matrices retain original JSONNumber values and zero-width transpose metadata.
Every later member/cell read independently admits the whole captured source with finite
limits and an operation report. These are structural views; no set algebra, matrix
arithmetic or performance claim is included. See the [compiled public guide](Sources/JSONInspection/Documentation.docc/ExactProjections.md),
[independent consumer](Tools/ExactProjectionQualification) and [public boundary](Documentation/Architecture/StructuralIntelligence/NAV10/PublicAPI.md).
Batch access remains explicitly deferred to NAV13. Stable 1.6.1 is unchanged.

NAV11 experiments with a package-only, exact source-backed directed simple graph
inside JSONInspection. Graph construction and BFS are not public API and are not
part of stable 1.6.1. The [experimental contract](Documentation/Architecture/StructuralIntelligence/NAV11/GraphADR.md)
records finite capacities, source/error precedence and one-ledger ownership. There
is no graph product, performance claim or automatic promotion.

## Source-bound graph candidate (unreleased)

This development candidate extends JSONInspection with an explicit directed simple
graph view of two disjoint physical arrays. An immutable `JSONGraphProfile` names
exact typed paths and direct string ID/endpoint keys. Checked construction rejects
duplicate scalar-exact IDs, dangling endpoints and repeated directed pairs; self
edges, cycles, reverse edges and isolates remain valid data. BFS returns the complete
reachable component in source-edge order or throws. Node/edge values and original
node spans stay attached to the captured source.

Each later read or query has its own explicit finite whole-source admission.
Build defaults to 10,000 nodes/50,000 edges; BFS defaults to 10,000 frontier,
visited and result entries. Storage and reducers stay private. Construction can
require quadratic work, and repeated reads re-admit the source. Logical retained
bytes are not RSS; controlled G4 performance remains HOLD with no speed claim.
See the [compiled graph guide](Sources/JSONInspection/Documentation.docc/SourceBoundGraphs.md)
and [standalone public consumer](Tools/GraphPublicQualification). This candidate
adds no product and does not establish a published release or merge approval.

## Public transformation library candidate

The JSONTransform 1.7.0 candidate exposes the existing query compiler and pull VM
without CLI imports. The CLI uses the same engine. Plans are immutable and Sendable;
scoped handles share one cumulative ledger and invalidate on scope exit. The public
[guide](Sources/JSONTransform/Documentation.docc/ScopedTransforms.md) and
[standalone consumer](Tools/TransformQualification) document the accepted API.
See the [1.7.0 candidate qualification contract](Documentation/Qualification/Release1.7.0.md)
for source-bound gates, the explicit allocation-instrumentation exception and
platform limits. A path or revision consumer is preparation evidence; exact 1.7.0
tag consumption is a postauthorization check.
This product is absent from stable 1.6.1 and must pass qualification on its final versioned source before publication.
