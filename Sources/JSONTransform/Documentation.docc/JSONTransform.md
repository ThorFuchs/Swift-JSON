# ``JSONTransform``

Compile the existing exact query dialect and pull bounded native JSON results.

This is the optional transformation library in the unpublished 1.7.0 release candidate.
Publication requires a separate maintainer decision. It shares one private compiler
and VM with `swift-json query`; it does not introduce a new interpreter or numeric
authority. Plans are immutable and Sendable. Each synchronous invocation has one
finite cumulative meter and a guarded, non-Sendable execution handle.

## Topics

### Start an invocation

- <doc:ScopedTransforms>
- ``JSONTransformProgram``
- ``JSONTransformExecution``
- ``JSONTransformOutput``

### Limits and failures

- ``JSONTransformLimits``
- ``JSONTransformFailure``
