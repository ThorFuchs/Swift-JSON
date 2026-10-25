# ``JSONValueDSL``

Typed authored JSON objects and arrays over the existing exact value model.

## Overview

Use ``object(limits:_:)`` or ``array(limits:_:)``
for trusted source-authored declarations. ``Field`` contributes one literal key,
``Element`` contributes one array value, and ``Elements`` explicitly expands a list.
Missing conditional content emits nothing. Nested arrays remain single elements.
Integer input is exact; decimals require an explicit JSONNumber. There is no implicit
Float/Double, Optional or dictionary conversion and no dotted-path interpretation.

Callbacks, typed wrappers, IR collection and staging are unmetered trusted authoring.
Only finalization is a checked operation. It uses one invocation-owned finite ledger
with iterative frames and the engine's exact admission and key index. Staging is not
an untrusted-input boundary, a live-retention/RSS cap or a whole-pipeline work report.
Use JSON's checked accumulators or strict parser for dynamic untrusted input.

## Topics

### Authoring
- <doc:AuthoredValues>
- ``object(limits:_:)``
- ``array(limits:_:)``
- ``Field``
- ``Element``
- ``Elements``
