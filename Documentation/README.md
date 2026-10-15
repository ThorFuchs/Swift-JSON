# Swift-JSON documentation

Start with the [package README](../README.md) for installation, product selection
and executable examples. This index leads from everyday usage to the exact
behavioral contracts and native qualification procedure.

## API references and guided reading

The six native DocC catalogs combine inline API documentation with focused guides:

| Product | Catalog source | Guide |
| --- | --- | --- |
| JSON | [JSON](../Sources/JSON/Documentation.docc/JSON.md) | [Exact values and native coding](../Sources/JSON/Documentation.docc/ExactValuesAndCoding.md) |
| JSONSchema | [JSONSchema](../Sources/JSONSchema/Documentation.docc/JSONSchema.md) | [Offline schema validation](../Sources/JSONSchema/Documentation.docc/OfflineValidation.md) |
| JSONStreaming | [JSONStreaming](../Sources/JSONStreaming/Documentation.docc/JSONStreaming.md) | [Completion and backpressure](../Sources/JSONStreaming/Documentation.docc/CompletionAndBackpressure.md) |
| JSONHTML | [JSONHTML](../Sources/JSONHTML/Documentation.docc/JSONHTML.md) | [Formatted rendering](../Sources/JSONHTML/Documentation.docc/FormattedRendering.md) |
| JSONBridges | [JSONBridges](../Sources/JSONBridges/Documentation.docc/JSONBridges.md) | [Numeric fidelity](../Sources/JSONBridges/Documentation.docc/NumericFidelity.md) |
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

- [Six-library compiled example](../Examples/Consumer/README.md)
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
