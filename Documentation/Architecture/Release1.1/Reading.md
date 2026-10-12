# Scoped reads and native coding

The additive public surface is JSON/JSONDocument `read(limits:_:)` and
`readWithReport(limits:_:)`, JSONReadCursor and JSONAccessFailure. Throwing read-only
String/JSONKey/Int brackets preserve typed selection. Required value/string/Boolean/
number/object/array access never coerces, defaults or manufactures null. Integer
conversion is exact; Double/Decimal require an explicit `.exact` or `.rounded`
choice. Both key overloads provide raw/scalar/model typed presence.

The supported compiler requires experimental features for the intended returned
nonescapable shape. The public implementation uses the qualified guarded fallback.
A handle owns only its bounded typed path and a synchronous non-Sendable scope.
Scope exit invalidates it and releases root/document/source/coding-state references.
A caller-thread guard runs before accessing mutable state; a cross-thread attempt
fails with configuration/invalidOperation. This introduces no actor isolation or
Sendable escape hatch. Public compiler probes and guarded misuse tests are required.

One noncopyable core-domain meter admits the full root once. Navigation, equivalent
Pointer path text, overlapping path copies, text extraction, numeric work, source
lookup and native model projection use that ledger. Dead path ownership is refunded
at the next owned boundary; work is never refunded. Paths retain literal scalar keys
and integer indices; missing intermediate parents fail at their first missing hop.
Grouping calls amortizes root admission. It does not selectively parse the input or
make all deep navigation, root admission, edits or arbitrary caller work constant-time.

Coding options temporarily select native strategies and userInfo while their limits
permanently tighten the scope's ceilings. Prior cumulative usage and already admitted
capacities must fit that restriction; live retention is checked against current live
ownership. No state/meter copy or new decoder facade resets the budget. Numeric
temporary storage is released after primitive projection. Returned values and caller
model computation retain the ordinary caller-work and retention boundaries.

Resource/cancellation failure is latched at the owned meter/scope. Even a caller
Decodable that catches an owned conversion refusal cannot certify successful scope
or native facade completion. Ordinary access/type/conversion errors can be caught
explicitly. JSONAccessFailure holds a complete bounded typed path and structured
cause, with no rejected value or document. Mapped missing members use their parent
span; replaced/unmapped roots have no invented location. Diagnostic classification
uses the cause and never renders arbitrary caller descriptions.

JSON `init(encoding:coding:)`, `decode(_:coding:)` and `decodeWithReport(_:coding:)`
delegate to the existing native facades. Natural foreign JSON Codable keeps its
representation and fidelity limitations. Exact persistence uses a separate explicit
Version 1 wrapper. No new kind, dictionary authority, defaulting, dynamic-member
lookup, mutation bracket or projection parser is introduced.

The new modern-date compatibility case exposed an existing ISO-8601 strategy bug:
the formatter selected only time fields. Both native writer and reader now explicitly
select year/month/day plus fractional UTC time. Baseline epoch-only tests could not
detect losing the calendar date. Record this as a real affected coding qualification
failure and refresh its native/safety/consumer/DocC evidence; do not redefine it as
permitted rounding or silently reduce the assertion.

Native coding and read scopes explicitly enable accepted-capacity history because
projection/payload limits may tighten after prior admission. Fixed-policy operations
retain terminal health/work accounting but skip history they cannot consume. Work
counters and live ownership supply their own restriction checks; no meter copy or
quota reset is introduced. The final integrated performance review records this
measured correction and retained regressions.
