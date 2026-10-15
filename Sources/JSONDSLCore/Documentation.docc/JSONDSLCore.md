# ``JSONDSLCore``

Shared typed structure for the two optional DSL products.

## Overview

This supporting module has no standalone SwiftPM product. Its public structural types
appear in the generic signatures of JSONValueDSL and JSONSchemaDSL. It imports JSON
only, with no framework result builder, parser, validator or external dependency.

The builder preserves typed tuples, optional content, choices and loop iterations.
Conditional context conformances decide which declarations are eligible in each domain.
There is no runtime shape inference, String dictionary merge or semantic interpretation.
Protocol implementations and staging are trusted authored code. JSONDSLNode factories
assemble a flat IR; only materialize performs finite iterative finalization. The schema
facade uses a package continuation of the same ledger through engine document admission.

## Topics

### Structural composition
- ``JSONContentBuilder``
- ``JSONContentTuple``
- ``JSONContentOptional``
- ``JSONContentChoice``
- ``JSONContentLoop``

### Trusted staging
- ``JSONDSLNode``
- ``JSONDSLMember``
- ``JSONValueFieldsContent``
- ``JSONValueElementsContent``
- ``JSONSchemaClausesContent``
- ``JSONSchemaPropertiesContent``
- ``JSONSchemaDefinitionsContent``
- ``JSONSchemaPatternsContent``
- ``JSONSchemaDependentSchemasContent``
- ``JSONSchemaDependenciesContent``
- ``JSONSchemaNodesContent``
