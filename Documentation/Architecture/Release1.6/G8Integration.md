# G8 combined-source reconciliation

The S3 caller-lifetime repair ends at `8d0e83037cb1e82b33e1dec862123c890b9b9bc7`.
Its standalone Native run 38824896580 and ARM64/x86_64 Linux run 38824893590 passed,
including ASan/LSan without suppressions. Those receipts and the earlier G0–G7
records remain immutable evidence of their named source.

This successor integrates main `7d72c8825982550f0ee87218136fda12d8bae13b`:
composition #35 and Navigation #38. It changes neither implementation’s semantics.
No sibling branch or checkout is modified. The feature-branch integration does
not merge PR #39 into main, tag, publish or deploy documentation.

## Conflict decisions

- Preserve all nine products: eight libraries and swift-json. JSONSchemaExamples
  depends only on JSON/JSONSchema; Navigation only on JSON. Core imports neither.
  The root dependency graph stays empty and private runtime targets stay private.
- Union exact root, shared-state, coverage and WASI inventories. Composition adds
  12 integration functions; Navigation adds 39 functions and one sharing function.
  All 98 S3 functions, four sharing functions, 126 restored maintenance identities,
  per-function parameter cardinalities and 49 baseline cap probes remain required.
- Preserve focused composition, Navigation, S3 ownership/public-consumer/matrix
  and lifetime probes. The composition five-success/three-refusal capacity policy
  remains explicit. No quota, sanitizer, exclusion, timeout or review trigger changes.
- Union eight DocC catalogs, routes, public API/resource descriptions and original
  contribution notices. Keep stage-specific qualification history source-bound.
- Recompute CLI identity from the combined Package.swift and Sources bytes.
  Neither parent’s old generated stamp describes this successor.

The exact combined requirements are 695 Mac / 679 Linux / 591 WASI root functions,
325 Mac/Linux / 288 WASI parameter invocations and 47 Mac / 46 Linux TSan functions.
These are inventories, not claims that an unexecuted lane passed. Required check
names and protection settings remain unchanged. All native/safety/docs/archive and
both Linux architecture receipts must bind to this combined source. Available WASI
and Apple consumer checks supplement those gates. G8 acceptance and remaining
limitations are recorded with the final source/archive and materialized receipts;
Progress.json is updated only from actual outcomes.

Logical retention remains distinct from process RSS. No controlled throughput,
caller instruction or arbitrary-schema completeness claim is added. Physical iPad
qualification retains the previously accepted simulator policy. Tagging and release
publication remain separate owner decisions.
