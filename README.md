# Swift-JSON

This source is the **1.7.0 release candidate**, still unpublished. Latest stable
remains **1.6.1**; no 1.7.0 tag or release is implied. It retains the
admitted JSONInspection array-evidence API plus source-attached snapshots and
tree/sparse-table projections alongside the unchanged 56-declaration Navigation API. This candidate adds the accepted JSONTransform library: ten libraries, eleven products and ten source catalogs.
The stable 1.6 line has eight libraries and eight catalogs. Do not use a main
snapshot as a 1.6 maintenance release.

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
The published CLI reports `1.6.1`; this candidate source reports `1.7.0`.
Both use a deterministic source-content digest.
The [published 1.6.1 release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.6.1)
is pinned to `e431f157ececc0cf3d061192420b0e36a9062f83`. Use its matching eight-catalog
DocC and qualification assets for the stable reference; see the
[maintenance qualification notes](Documentation/Qualification/Release1.6.1.md).
Historical N0/N1 plans and later candidates are distinguished in the
[source authority map](Documentation/Architecture/StructuralIntelligence/SOURCE-AUTHORITY.md).

This candidate includes opt-in JSONInspection and JSONTransform:
ten libraries plus the CLI, eleven products in total. Inspection is absent from stable 1.6 releases. Use this
source checkout for Inspection; its inclusion in main does not publish 1.7.0.

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
