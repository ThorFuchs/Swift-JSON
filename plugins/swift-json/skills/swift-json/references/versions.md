# Version and product selection

Kit 0.2.0 validates exactly library 1.9.0, commit
`f2a0d12da7028edfbcb0cb307f19a921a3a12d03`, tree
`6b5438751352e0e424b133e79d40d32d6f8c8dd7`.
The repository is https://github.com/ThorFuchs/Swift-JSON.git.
Inspect Package.swift and Package.resolved as text before selecting a recipe.
Preserve an existing range, tag or revision unless its change was requested.

For a new reproducible consumer the exact requirement is `exact: "1.9.0"`.
The [executable manifest](../assets/consumer/Package.swift) demonstrates that
requirement, language mode 6, the macOS 15 / iOS 18 minimums and all twelve
product spellings. Add only needed products to a real target.

## Products and dependencies

JSON is the core. Schema depends on JSON and a private regex runtime. Examples
and SchemaDSL depend on JSON and Schema. Streaming, Patch, HTML, Bridges,
Navigation and ValueDSL depend on JSON. Inspection depends on JSON and
Navigation. Transform depends on JSON and a private filter runtime shared with
the CLI. The root package has no external dependencies. JSONDSLCore and private
runtimes are not products and are never imports for an independent consumer.

## What each release added

Use this table when the resolved version is older than 1.9.0. An API listed
for a later release is absent from an earlier one; do not add an import or
upgrade the dependency to satisfy the request without the user's decision.

| Release | Additions a consumer can import |
| --- | --- |
| 1.6.1 | JSON, JSONSchema, JSONSchemaExamples, JSONStreaming, JSONPatch, JSONHTML, JSONBridges, JSONNavigation |
| 1.7.0 | JSONInspection (shape evidence, snapshots, projections, sets, matrices, graphs), JSONTransform, JSONValueDSL, JSONSchemaDSL |
| 1.8.0 | `JSONLocatedTopLevelArraySequence` with UTF-8 byte spans |
| 1.9.0 | `JSONInspectionBatch` and `optionalValues`, `JSONStoreBuilder` / `JSONConfiguredStore` with typed IDs and `JSONStoreFailure`, Transform source definitions, selection scopes and `selectIndices`; macOS 15 / iOS 18 minimums |

Releases up to 1.8.0 require macOS/iOS 27 deployment targets. Releases 1.7.1
and 1.8.0 changed no product list. The kit validates only the 1.9.0 row as an
executable result; earlier rows are boundaries, not separately run recipes.

## Platforms and documentation

Swift tools/compiler 6.4+ and language mode 6 remain required. 1.9.0 declares
macOS 15 and iOS/iPadOS 18 minimums and is developed with Xcode 27 and the
macOS 27 SDK; below OS 27 the evidence is compile-time. JSONHTML's WebKit PDF
backend needs OS 26 and reports `backendUnavailable` earlier. Library Linux scope
is Swift 6.4+ on 64-bit Ubuntu 24.04/glibc. Full-language wasm32-unknown-wasip1
has its own qualified core scope; it is not browser, Embedded Swift or full CLI
support. Kit recipe execution on one platform does not qualify every host.

The [1.9.0 release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.9.0)
has twelve library DocC catalogs plus swift-json. The
[documentation website](https://thorfuchs.github.io/Swift-JSON/) follows main,
which can be ahead of the release; prefer the immutable source links in the
compatibility map or matching installed source for version-exact signatures.

An unfamiliar version/revision is **unverified by this kit**, not automatically
incompatible. Read matching installed source/public declarations and compile the
adaptation. Keep that evidence distinct from the exact 1.9.0 recipe result.
