# ``JSONTransform``

Compile the existing exact query dialect and pull bounded native JSON results.

This is a provisional 1.7.0 feature-branch product. It shares one private compiler
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
