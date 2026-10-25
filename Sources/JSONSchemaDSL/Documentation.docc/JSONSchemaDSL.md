# ``JSONSchemaDSL``

Typed authored Draft 2020-12 declarations, with the existing engine as authority.

## Overview

``document(limits:_:)`` emits ordinary JSONSchemaDocument.
``Schema`` supplies explicit keyword declarations. Properties, definitions,
pattern properties, dependent schemas and composition rules have distinct typed
contexts; using a declaration in the wrong context fails Swift compilation.
``boolean(_:limits:)`` emits a Boolean schema without inventing an
object or substituting JSON null.

Only JSONSchemaCompiler interprets dialects, references and vocabulary requirements.
Only JSONSchemaValidator produces instance verdicts and evaluation annotations.
Compilation is separate from document admission. Properties infer no requiredness,
defaults never mutate instances, format stays annotation by default, and references
resolve only through the existing explicit offline registry. No DSL validator exists.

Authored callbacks and staging are trusted and unmetered. One finite finalization
ledger continues through JSONSchemaDocument admission; it is not a staging/RSS or
whole-pipeline cumulative-accounting promise.

## Topics

### Authoring and evaluation
- <doc:AuthoredSchemas>
- ``document(limits:_:)``
- ``boolean(_:limits:)``
- ``Schema``
- ``SchemaType``
- ``SchemaClause``

### Typed contexts
- ``Property``
- ``Definition``
- ``PatternProperty``
- ``DependentSchema``
- ``RequiredDependency``
- ``Rule``
