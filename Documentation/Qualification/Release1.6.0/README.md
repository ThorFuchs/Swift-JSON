# Swift-JSON 1.6.0 qualification scope

This release adds bounded synchronous composition with a borrowed, noncopyable,
non-Sendable scope handle and a scope-bound admitted-root handle. Root ownership is
retained through the callback; exact owner identity rejects cross-scope use before
navigation. A trusted graph and a parsed document root share one admission on the
same cumulative ledger. Selecting a root or subtree still reserves the logical
output graph, and monotone reservations keep aliases charged until completion.

The focused native lane exercises 20 core functions in Debug, Release and ASan,
two concurrent-scope functions under TSan, strict-memory-safety compilation, public
consumers and external adapter fixtures. Its synthetic scale consumer resolves
1,000 pointers from 50,000-value trusted and parsed roots. This measures that
admitted-root lookup avoids repeated root admission; it does not establish protocol
conformance, arbitrary callback instruction limits, process RSS or broad application
capacity. The separate reference adapter still refuses its direct
`balanced-128-128` capacity target.

Compiler ownership qualification includes 18 semantic-negative cases and 14
actual call-site forms. Explicit borrowing method declarations prevent two
Swift 6.4 aborts: the bound-method escape is correctly rejected, while the
nonescaping bound-method positive remains unsupported. Four original inferred
capture forms still abort, including the root-only escaping capture. Five added
explicit-parameter counterparts verify ordinary invalid-capture diagnostics and
supported local-function/closure-literal helpers. The original positive
requirements and all inferred crash cases remain in the gate. Compiler robustness
is still blocked; package tests and consumers pass independently. See the
[compiler diagnosis](../../Architecture/CompositionCompiler.md).

The Swift-OpenAPI package may pin this release and use the public composition API,
but a complete importer remains a separate downstream qualification. Its source
preservation, dialect behavior, complete cumulative accounting, first-error
behavior, usable-capacity goals, and live composed retention peak require their own
implementation and evidence. The synthetic consumer here does not close those C2
gaps.

Logical retained bytes are owned accounting quantities, not process RSS. Work units
describe owned operations, not arbitrary caller instructions or wall-clock limits.
