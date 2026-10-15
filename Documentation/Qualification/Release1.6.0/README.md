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

Compiler ownership qualification includes 18 semantic-negative cases and nine
actual call-site forms. On Swift 6.4, six call-site probes currently abort the
compiler, including the root-only escaping capture. The classifier preserves those
as compiler-robustness blockers and does not count them as ownership rejections;
three supported borrowing call sites compile. This release therefore does not claim
that arbitrary closure/capture forms are compiler-robust. The package test and
consumer lanes pass independently of that compiler-robustness blocker.

The Swift-OpenAPI package may pin this release and use the public composition API,
but a complete importer remains a separate downstream qualification. Its source
preservation, dialect behavior, complete cumulative accounting, first-error
behavior, usable-capacity goals, and live composed retention peak require their own
implementation and evidence. The synthetic consumer here does not close those C2
gaps.

Logical retained bytes are owned accounting quantities, not process RSS. Work units
describe owned operations, not arbitrary caller instructions or wall-clock limits.
