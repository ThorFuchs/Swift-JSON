# Pull query core

The dependent query branch builds on foundation `f469f1d` / draft PR #23.
Its private compiler produces a flat immutable checked-Sendable node/range array.
Token grouping and compilation use explicit work stacks, metered source/token/IR
and scratch admission. The evaluator uses explicit demand continuations and reuses
arena slots. It does not port the previous eager `[JSONValue]` evaluator.

The current core includes ordered comma/pipe generators, exact paths/index/slices,
recursive descent, arrays/object Cartesian construction, conditions, fallback,
short-circuit booleans, bindings, typed try/optional, input/inputs and the C2 primitive
builtin inventory. Constructed duplicates replace values at their first position;
parsed duplicates remain strict errors. Strings/keys use decoded scalar identity.
Comparison uses native exact decimals and metered iterative container walks.
Arithmetic/assignment/richer calls remain explicit compile errors until their gates.

One CLIInputCursor feeds the native JSONTokenMachine/JSONValueAssembler. Values
require real whitespace or file EOF; documents wait for EOF; NDJSON rejects blank
physical lines; root-array elements are provisional until enclosing syntax and EOF
finish. Raw lines use strict UTF-8 and distinct CRLF rules. Driver and input/inputs
share the same cursor. Successful execution drains unconsumed tails, including null
input and short-circuit cases; accepted stdout cannot be recalled.

Invocation-only value leases keep selected aliases and replay/cache values charged
until their final release. New value graphs undergo full owned native admission;
selectors share their source reservation. ARC notifications enqueue checked refunds
in the job's private cell, drained before the next checkpoint. Work never refunds;
terminal storage cleanup cannot replace or reopen the native meter. Plans alone are
Sendable; mutable leases are never presented as shared values. Logical retention is
not process RSS or a claim about framework/kernel instructions.

The 38 byte-identical authored C2 vectors pass using the public JSON/JSONStreaming
CLIExactCompare consumer. It preserves exact decimals and scalar identity, and
handles the CLI's empty result stream explicitly; the library sequence's existing
empty-input behavior is unchanged. Fixture SHA-256:
`6f863f3e98d2dea12e59018e7cf3a074ae0ebee5f1ab950a651df72e5eb18a4c`.

Current tests include sixteen ledger boundary cases, four actual compiler admission
cases, configured depth/frame tests and alias/terminal release. Retention checks over
2,000 and 20,000 records finish with zero input storage and stay within the derived
bound of two 16 KiB buffers plus a scalar/lease reservation. An initial arbitrary
20,000-byte threshold omitted the measured syscall/chunk overlap; the final bound
comes from the actual adapter and additionally checks a tenfold input increase.
An omitted slice bound now explicitly uses Optional.none, avoiding Swift's inference
of JSON null through ExpressibleByNilLiteral. Swift Testing macros evaluate an inout
noncopyable call before #require; no unsafe ownership annotation repairs it.

The complete C0-C5 release boundary remains open. Backend quota rendezvous, pinned independent
oracle/corpus results, all platform consumers and reproduction remain required.

The final milestone ran 36 CLI functions (including 24 new query functions) within
256 root functions, 199 parameter cases, native/release/ASan and eight TSan shared
cases. Failure cleanup tests cover partial constructors/selectors and catch-message
ownership. Arithmetic precedence/Cartesian behavior, full binding subprocess modes,
inherited fixture dispositions and final integration remain open requirements.
