# Swift-JSON

Exact JSON values, strict UTF-8 coding, Draft 2020-12 schemas, transactional Patch
and pull streams for Swift **6.4+**, Swift **6** language mode and **macOS 27+**.
Original code is Apache-2.0. The root package has no third-party package dependencies.

Maintained by [Thorsten Fuchs](https://github.com/ThorFuchs). The repository is
public; **1.0.0 has not been tagged or released yet**.

Native tests, independent suites and explicit policies are described in
[qualification](Documentation/Qualification/README.md). The source is prepared
for public development; no version has been released.

| Product | Behavior |
| --- | --- |
| JSON | Exact bounded decimals, decoded-scalar keys/text, ordered objects with order-independent equality, strict codec, native Codable, Pointer, presence, source documents, diagnostics and reports |
| JSONSchema | Draft 2020-12 compilation/evaluation, immutable explicit registry and plans, annotations, flag/basic output and declaration inspection |
| JSONStreaming | Pull events/values, strict NDJSON, indexed root-array elements with explicit completion, and awaited sink writes |
| JSONPatch | Staged RFC 6902 and RFC 7396 over the exact model; root removal is distinct from JSON null |

The package-private regex runtime implements case-sensitive, unanchored Unicode
u-equivalent ECMA-262 2020 matching using fixed Unicode 13 data. Compilation,
forward scans, states, captures, backtracking and cancellation use shared finite
budgets. Identical programs are shared within a compiled schema plan. Mutable
matching/evaluation state belongs exclusively to each invocation.

## Installation

The current public snapshot is available on `main`. Until the first version tag,
add it to your Swift 6.4 package using a branch requirement:

```swift
.package(url: "https://github.com/ThorFuchs/Swift-JSON.git", branch: "main")
```

Select the products your target uses:

```swift
.product(name: "JSON", package: "swift-json"),
.product(name: "JSONSchema", package: "swift-json")
```

JSONStreaming and JSONPatch use the same package identity. A compiled example
importing all four products is in [Examples/Consumer](Examples/Consumer).
For a local checkout, `.package(path: "/absolute/path/to/Swift-JSON")` also works.
Once `1.0.0` is released, use a semantic-version requirement (`from: "1.0.0"`).
Branch requirements follow mutable development; record the resolved commit when
reproducing an issue. No versioned installation is claimed before a tag exists.

## Example

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

Strings and keys preserve scalar spelling: `é` and `e\u{301}` are distinct.
Equivalent decimal spellings compare mathematically. Object iteration preserves
insertion order. Duplicate decoded keys fail parsing. Direct enum construction
is useful for trusted values; every bounded operation also admits caller-built
values and charges its own traversal/copies.

```swift
import JSONSchema

let schema = try JSONSchemaDocument(parser.parse(#"{"type":"object","properties":{"count":{"type":"integer"}},"required":["count"]}"#))
let plan = try JSONSchemaCompiler().compile(schema)
let result = try JSONSchemaValidator().validate(value, against: plan)
precondition(result.isValid)
let output = try result.output()
precondition(output.objectValue?["valid"] == true)
```

Format is an annotation by default. Enable assertion explicitly or through the
format-assertion vocabulary. Content keywords retain metadata without decoding
content. Declarations expose raw constraints rather than inferred schemas.
Flag-only results cannot be upgraded into basic errors they never recorded.

## Limits, ownership and completion

All three default resource profiles are finite. Inclusive capacities, checked
arithmetic, cumulative work and cancellation apply across composed operations;
a nested helper does not restart the budget. The 49 initial policy metrics and
native observations are documented in [ResourceLimits](Documentation/Architecture/ResourceLimits.md).
Logical retained bytes are reproducible accounting quantities, not hard RSS or
throughput guarantees. Reports contain counters and no input payloads or clocks.
User Codable/custom callbacks and upstream sources/sinks remain caller code.

Native JSON/JSONObject Codable round-trips preserve exact values. A typed
String dictionary throws when canonical String equality would collapse scalar-distinct
keys. Native Float/Double projections round to that finite target type; use the
explicit exact number conversion when equality must be proved. External Decoder/Encoder bridges inherit
that coder's numeric and key fidelity. Data defaults to strict Base64. The explicit
ISO-8601 date strategy uses UTC, fractional-second formatting and a finite four-digit
year range; input text is capped at 128 UTF-8 bytes. See the [coding contract](Documentation/Architecture/API.md).

A stream may yield an event or root-array element before the enclosing document
is certified. Root-array completion follows closing syntax, trailing whitespace
and EOF. Blank/malformed NDJSON records fail; records are never silently skipped.
Sink writes are awaited. Cancellation/error stops subsequent work but cannot
recall bytes already accepted by the sink. Callers requiring atomic publication
stage those bytes themselves.

## Develop and qualify

```sh
python3 Scripts/ci.py --lane native
python3 Scripts/ci.py --lane safety
python3 Scripts/ci.py --lane docs
```

Use an Xcode installation that provides the required compiler, SDK and native
Testing runtime. [Qualification](Documentation/Qualification/README.md) records
suite and sanitizer commands. [Benchmarks](Tools/Benchmarks/README.md) use public
APIs and machine-specific release measurements. DocC catalogs cover all four
products. E09 retains the correct scalar path; SIMD/prefilters remain unselected.
Projection (E11) and JSON text-sequence framing (E12) remain deferred.

The independent [JSON/JSONSchema consumer](Tools/MCPReadiness/README.md) qualifies
frozen rooted schema vectors and carries public remaining-work reports across
parse, raw-schema compile, evaluation and write. Its [interface note](Documentation/ConsumerInterface.md)
records actual signatures and integration boundaries.

See the [documentation index](Documentation/README.md), [contribution guidance](CONTRIBUTING.md),
[security policy](SECURITY.md), [license](LICENSE) and
[third-party notices](THIRD_PARTY_NOTICES.md). Report defects through [GitHub Issues](https://github.com/ThorFuchs/Swift-JSON/issues).
Use [private vulnerability reporting](https://github.com/ThorFuchs/Swift-JSON/security)
for security-sensitive reports. [SUPPORT.md](SUPPORT.md) describes the latest-1.x
support policy.
The [native CI workflow](.github/workflows/native.yml) checks supported builds,
behavior, safety and documentation. Version tagging and release publication
remain separate maintainer actions.
