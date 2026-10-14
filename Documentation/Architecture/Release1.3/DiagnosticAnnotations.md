# Typed renderer diagnostics and coherent document input

This increment closes the previously unimplemented JH20/JH21 API slice on the
existing JSONHTML feature branch. It preserves the 43bdb456 receiving candidate and
its materialized evidence as a parent; a successor must be qualified separately.

Final declarations: JSONHTMLAnnotation (Sendable) owns immutable typed path, severity
and message; its Severity has information/warning/error cases. RenderingOptions adds
an empty annotations property. HTMLLimits adds maxAnnotations = 128 without replacing
existing initializer shapes. Statistics adds accepted annotations. The four existing
value methods retain their function-reference shapes and gain JSONDocument overloads.
No JSONSchema dependency, source-byte archive, implicit validation, parser, line-number
API or automatic Error-description conversion is introduced.

Binding validates the whole attempted path, resolves its longest existing prefix,
then uses a bounded iterative preorder walk to bind generated ordinals. Scalar-byte
comparisons distinguish keys; negative indices are rejected before resolution. The
qualified initial algorithm can cost nodes times annotations; finite cumulative work
bounds that cost. No asymptotic performance claim or unchecked dictionary/index is
used. Annotation records reserve 64 logical bytes each; traversal/path frames reuse
16-byte core frame policy. Caller payload is borrowed during rendering; result HTML
contains only safely encoded presentation and no root/source ownership.

Package-scoped source-map scans borrow the same writing meter. Only coherent parsed
mapping yields value spans; missing targets display parent spans explicitly. Mapping
entry/input capacities admit borrowed document metadata before scans. Message/key/index
payload consumes cumulative diagnosticBytes; attempted paths use pointer capacities.
All token/output/escape/DOM/copy work and retention remain cumulative. Failure releases
invocation scratch, preserves enclosing reservations and latches the original error.

The independent span regression caught optional-nil inference through JSON's nil
literal conformance: a ternary accidentally created a present JSON null for an absent
array element. Explicit optional branches corrected this before qualification; the
failed receipt is retained. The test still expects a missing target and parent span.

Evidence is recorded in the successor return, including commands, environment,
source manifest, 12 new behavior functions, public consumer, mapped/inert browser
fixtures, exact CI discovery and all 49 baseline probes. Compiler failures and early
failed probes are historical receipts, not passes. Receiver UI/device filename gates
remain separate; no merge/tag/publication is authorized by this increment.
