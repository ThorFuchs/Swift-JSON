# Current authority — 1.8 candidate

Published 1.7.0 has twelve libraries plus CLI and thirteen catalogs. This isolated
1.8.0-dev branch adds bounded batches and a public immutable store inside
JSONInspection. See [current qualification](Qualification/Release1.8.md).
The dated predecessor inventories below are historical, not 1.8 pass evidence.

# Current documentation authority

Unreleased 1.7.0-dev consolidation has twelve libraries plus CLI and thirteen DocC
catalogs (including the shared non-product JSONDSLCore reference). Stable 1.6.1
remains eight libraries. [Combined qualification](Qualification/Consolidation2026.md)
separates current requirements from all preserved predecessor records below.

# Swift-JSON documentation

The [release-line matrix](Qualification/ReleaseLines.md) separates the eight-library
1.6 maintenance source from this unreleased twelve-library 1.7.0-dev source.
See [combined qualification and holds](Qualification/Consolidation2026.md);
[the frozen JTX10 candidate](Qualification/Release1.7.0.md) is historical. The website tracks
development main; use matching release assets for a stable compiled reference.

Start with the [package README](../README.md) for installation, product selection
and executable examples. This index leads from everyday usage to the exact
behavioral contracts and native qualification procedure.

## API references and guided reading

The latest stable [1.6.1 package](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.6.1) provides eight libraries plus the `swift-json` executable.
JSONNavigation is included. The eight native DocC catalogs combine inline API
documentation with focused guides:

| Product | Catalog source | Guide |
| --- | --- | --- |
| JSON | [JSON](../Sources/JSON/Documentation.docc/JSON.md) | [Exact values and native coding](../Sources/JSON/Documentation.docc/ExactValuesAndCoding.md) |
| JSONSchema | [JSONSchema](../Sources/JSONSchema/Documentation.docc/JSONSchema.md) | [Offline schema validation](../Sources/JSONSchema/Documentation.docc/OfflineValidation.md) |
| JSONSchemaExamples | [JSONSchemaExamples](../Sources/JSONSchemaExamples/Documentation.docc/JSONSchemaExamples.md) | [Verified candidates](../Sources/JSONSchemaExamples/Documentation.docc/VerifiedCandidates.md) |
| JSONBridges | [JSONBridges](../Sources/JSONBridges/Documentation.docc/JSONBridges.md) | [Opt-in native conversions](../Sources/JSONBridges/Documentation.docc/NumericFidelity.md) |
| JSONStreaming | [JSONStreaming](../Sources/JSONStreaming/Documentation.docc/JSONStreaming.md) | [Completion and backpressure](../Sources/JSONStreaming/Documentation.docc/CompletionAndBackpressure.md) |
| JSONHTML | [JSONHTML](../Sources/JSONHTML/Documentation.docc/JSONHTML.md) | [Formatted rendering](../Sources/JSONHTML/Documentation.docc/FormattedRendering.md) |
| JSONNavigation | [JSONNavigation](../Sources/JSONNavigation/Documentation.docc/JSONNavigation.md) | [Exact traversal](../Sources/JSONNavigation/Documentation.docc/Traversal.md) |
| JSONPatch | [JSONPatch](../Sources/JSONPatch/Documentation.docc/JSONPatch.md) | [Choosing and applying patches](../Sources/JSONPatch/Documentation.docc/ApplyingPatches.md) |

[Browse the public documentation](https://thorfuchs.github.io/Swift-JSON/) or
[build and view the DocC catalogs locally](DocumentationTooling.md). The site
tracks `main` and publishes after native, safety and documentation CI pass.
Compiled archives and public symbol graphs remain available in CI artifacts.

The [CLI guide](CLI.md) covers executable workflows and release/source metadata.
Online references track main; tagged releases include matching compiled catalogues.

## Behavioral contracts

- [Actual public API and ownership](Architecture/API.md)
- [Exact numbers, conversion and scalar identity](Architecture/NumbersAndUnicode.md)
- [Finite resource accounting](Architecture/ResourceLimits.md), [49 metric policies](Architecture/ResourceProfiles.json) and [cap ownership](Qualification/LimitsMatrix.json)
- [Draft 2020-12, regex dialect and declaration inspection](Architecture/SchemaAndRegex.md)
- [Strict streaming and certified completion](Architecture/Streaming.md)
- [Pointer, JSON Patch and Merge Patch](Architecture/Patch.md)
- [Concurrency, cancellation and caller-work boundaries](Architecture/Concurrency.md)
- [Linux platform and portable schema integrity](Architecture/Linux.md)
- [WebAssembly audit and unresolved qualification boundary](Architecture/WebAssemblyAudit.md)

- [CLI implementation history](Architecture/Release1.4/Plan.md) and [foundation contract](Architecture/Release1.4/Foundation.md)

## Consumers, qualification and maintenance

- [Eight-library compiled source example](../Examples/Consumer/README.md)
- [Schema example public API](Architecture/Release1.6/API.md), [resource scope](Architecture/Release1.6/SchemaExamplesLimits.md) and [runnable guide examples](../Examples/SchemaExamplesConsumer/README.md)
- [Published Navigation and historical N0/N1 source authority](Architecture/StructuralIntelligence/SOURCE-AUTHORITY.md), [original traversal decisions](Architecture/StructuralIntelligence/API-DECISIONS.md) and [N1 promotion history](Architecture/StructuralIntelligence/N1Promotion.md). JSONNavigation is released in 1.6.0; the original N0/N1 stage gates remain dated history.
- [Unreleased N2 Inspection source](Architecture/StructuralIntelligence/Inspection.md) adds opt-in observed array evidence. This development source has thirteen catalogs including the DSL structure reference; stable 1.6 release tags and assets retain eight.
- The source authority map distinguishes this unreleased Inspection source from the dated unmerged-candidate record. Snapshots, public projections and set/matrix APIs are admitted development capabilities. Graph, Transform, authored DSLs and private store construction require combined-source qualification. Composition/root and lower deployment proposals retain their held gates.

- [Downstream JSON/JSONSchema interface](ConsumerInterface.md) and [runnable public consumer](../Tools/MCPReadiness/README.md)
- [Independent-suite policies and qualification](Qualification/README.md)
- [Native CI lanes and receipts](CI/README.md)
- [Release performance and reviewed streaming comparison](Performance/README.md)
- [Development scripts](../Scripts/README.md)
- [Contribution workflow](../CONTRIBUTING.md), [security reporting](../SECURITY.md) and [support](../SUPPORT.md)
- [Release preparation](../RELEASING.md) and [changelog](../CHANGELOG.md)

## Provenance and licenses

Original code is Apache-2.0. See the [license](../LICENSE), [notice](../NOTICE),
[third-party notices](../THIRD_PARTY_NOTICES.md), [license directory](../Licenses),
[adaptation manifest](Architecture/ExtractionManifest.json) and
[pinned inputs](Architecture/UpstreamPins.json). Qualification inputs are separate
from the empty library dependency graph.

- [Offline provider schemas and request fragments](Architecture/Release1.4/Providers.md), [frozen profile tables](Architecture/Release1.4/ProviderProfiles.json) and the [DocC guide](../Sources/JSONSchema/Documentation.docc/ProviderSchemas.md).

The candidate also provides [Inspection](../Sources/JSONInspection/Documentation.docc/JSONInspection.md)
and [Transform](../Sources/JSONTransform/Documentation.docc/JSONTransform.md):
their guides are joined by the optional DSL catalogs and shared generic reference.
Derive the complete authored inventory from current compiler graphs. These products are
absent from stable 1.6.1. Candidate docs do not establish publication or a platform
runtime pass; source-bound qualification receipts define the tested scope.

## Optional authored DSLs (P1.2 development)

- [Integration plan and source boundary](Architecture/DualDSL/Plan.md)
- [Resource, naming and compiler decisions](Architecture/DualDSL/Decisions.md)
- [Real-engine acceptance mapping](Qualification/DualDSL/README.md)
- [Typed value guide](../Sources/JSONValueDSL/Documentation.docc/AuthoredValues.md)
- [Typed schema guide](../Sources/JSONSchemaDSL/Documentation.docc/AuthoredSchemas.md)
