# ``JSONTransform``

Compile the existing exact query dialect and pull bounded native JSON results.

The library was introduced in 1.7.0. This 1.8 candidate adds exact source definitions
successful compile reports and guarded finite indexed selection with owner-bound
positions and explicit completion witnesses.
Source identities and qualification stay separate. Publication requires a separate maintainer decision. It shares one private compiler
and VM with `swift-json query`; it does not introduce a new interpreter or numeric
authority. Plans are immutable and Sendable. Each synchronous invocation has one
finite cumulative meter and a guarded, non-Sendable execution handle.

## Topics

### Start an invocation

- <doc:ScopedTransforms>
- ``JSONTransformProgram``
- ``JSONTransformExecution``
- ``JSONTransformOutput``

### Source definitions

- <doc:SourceDefinitions>
- ``JSONTransformProgramDefinition``
- ``JSONTransformDefinitionLimits``
- ``JSONTransformDefinitionFailure``

### Limits and failures

- ``JSONTransformLimits``
- ``JSONTransformFailure``

### Indexed selection

- <doc:IndexedSelection>

- ``JSONTransformSelectionLimits``
- ``JSONTransformSelectionScope``
- ``JSONTransformSelectionPosition``
- ``JSONTransformSelectionCompletion``
- ``JSONTransformSelectionReport``
- ``JSONTransformSelectionFailure``
