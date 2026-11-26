# Swift-JSON documentation

Latest published stable: [1.10.0 — Exact Interchange](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.10.0).
Twelve libraries plus CLI, thirteen catalogs, macOS 15 / iOS 18 deployment minima,
Swift 6.4+. See the [release notes](ReleaseNotes/1.10.0.md),
[publication record](Qualification/Release1.10Publication.md), and
[source-line matrix](Qualification/ReleaseLines.md). The site tracks main;
matching release assets provide the frozen reference.

Start with the [package README](../README.md) for installation, product selection
and executable examples. This index links the behavioral contracts and qualification.

## API references and guided reading

The thirteen native DocC catalogs include twelve product references and the shared non-product JSONDSLCore reference:

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
| JSONInspection | [JSONInspection](../Sources/JSONInspection/Documentation.docc/JSONInspection.md) | [Bounded workflows](../Sources/JSONInspection/Documentation.docc/BoundedWorkflows.md) |
| JSONTransform | [JSONTransform](../Sources/JSONTransform/Documentation.docc/JSONTransform.md) | [Indexed selection](../Sources/JSONTransform/Documentation.docc/IndexedSelection.md) |
| JSONValueDSL | [JSONValueDSL](../Sources/JSONValueDSL/Documentation.docc/JSONValueDSL.md) | [Authored values](../Sources/JSONValueDSL/Documentation.docc/AuthoredValues.md) |
| JSONSchemaDSL | [JSONSchemaDSL](../Sources/JSONSchemaDSL/Documentation.docc/JSONSchemaDSL.md) | [Authored schemas](../Sources/JSONSchemaDSL/Documentation.docc/AuthoredSchemas.md) |
| JSONDSLCore (shared) | [Reference](https://thorfuchs.github.io/Swift-JSON/JSONDSLCore/documentation/jsondslcore/) | Shared generic structure; no standalone product |

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
- [Inspection history](Architecture/StructuralIntelligence/Inspection.md) records the earlier N2 stage; Inspection, Transform and the authored DSLs shipped in 1.7.0. Historical admission records retain their original scope.

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

The released Inspection and Transform catalogs link current guides. The earlier
1.6.1 maintenance line lacks these products; source-bound receipts define each
release's tested scope.

## Optional authored DSLs (historical design and current guides)

- [Integration plan and source boundary](Architecture/DualDSL/Plan.md)
- [Resource, naming and compiler decisions](Architecture/DualDSL/Decisions.md)
- [Real-engine acceptance mapping](Qualification/DualDSL/README.md)
- [Typed value guide](../Sources/JSONValueDSL/Documentation.docc/AuthoredValues.md)
- [Typed schema guide](../Sources/JSONSchemaDSL/Documentation.docc/AuthoredSchemas.md)
