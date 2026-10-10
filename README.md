# Swift-JSON

**Exact JSON values, offline JSON Schema validation, transactional patches and pull-driven streams for modern Swift.**

Swift-JSON gives applications one consistent JSON model from input bytes to validated,
transformed and encoded output. It keeps decimal values exact, preserves the identity
of Unicode scalar sequences, and makes resource limits and cancellation part of the
operation contract. Use it when rounding a number, collapsing a key or accepting a
partially read document would change the meaning of your data.

[![Native CI](https://github.com/ThorFuchs/Swift-JSON/actions/workflows/native.yml/badge.svg)](https://github.com/ThorFuchs/Swift-JSON/actions/workflows/native.yml)
[![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

Maintained by [Thorsten Fuchs](https://github.com/ThorFuchs). The repository is public;
**version 1.0.0 has not yet been tagged or released**. Until a version is published,
use `main` and retain the resolved commit for reproducible builds.

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
| Platform and SDK | macOS 27 or later |
| Runtime dependencies | None outside the package and platform SDK |
| License | Apache-2.0 original code, with retained upstream notices |

Choose the products your application needs:

| Product | Use it for |
| --- | --- |
| **JSON** | Exact values, strict parsing/writing, native Codable, Pointer, presence, checked construction, source documents and diagnostics |
| **JSONSchema** | Draft 2020-12 compilation/evaluation, offline registries, bounded regex, annotations and raw declaration inspection |
| **JSONStreaming** | Pull syntax events and values, strict NDJSON, root-array elements and awaited output chunks |
| **JSONPatch** | Staged RFC 6902 JSON Patch and RFC 7396 Merge Patch |

`JSONSchema`, `JSONStreaming` and `JSONPatch` build on `JSON`. The package-private
`JSONRegexRuntime` is an implementation detail and has no public product. The root
SwiftPM dependency graph is empty. Qualification and benchmark tools are separate
packages.

## Installation

Add the package to your `Package.swift`:

```swift
.package(url: "https://github.com/ThorFuchs/Swift-JSON.git", branch: "main")
```

Then add products to your target dependencies:

```swift
.product(name: "JSON", package: "swift-json"),
.product(name: "JSONSchema", package: "swift-json")
```

Add `JSONStreaming` and `JSONPatch` in the same way when needed. A local checkout can
use `.package(path: "../Swift-JSON")`. After a release is published, select a semantic
version requirement. See the [four-product consumer](Examples/Consumer) for a
complete buildable manifest.

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

## Documentation and examples

Start with the [documentation index](Documentation/README.md). The four DocC catalogs
provide public API references, focused guides, parameter descriptions and failure
contracts. A searchable Doxygen catalog is generated from the same native Swift
symbol graphs; it preserves Swift signatures without treating them as C++ APIs.

Build both references on a supported native host using the pinned documentation tool:

```sh
python3 Scripts/prepare_documentation_tool.py
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

Performance is measured separately on native release builds. The current reviewed
streaming comparison is approximately **11% slower**, exceeding the unchanged 10%
review trigger, with its accepted disposition and measurement limits documented in
[performance notes](Documentation/Performance/README.md). Logical retention remains
separate from process RSS. Scalar scanning and plan-local immutable regex sharing
are the qualified choices. Projection and JSON text-sequence framing remain deferred.

## Contributing, support and licensing

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
