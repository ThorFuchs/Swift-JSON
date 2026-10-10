# JSON behavioral tests

Implement with Swift Testing; no passing placeholder tests. Native execution is pending.

Value/presence/construction: all six kinds; absent/null/wrong kind;
scalar-distinct strings and object keys; duplicate exact keys; ordered iteration,
order-independent equality/hash; explicit object/array accumulation and admission.

Numbers: equal decimal spellings and negative zero, beyond 2^53, Int64/UInt64
boundaries, exact Decimal/Double versus explicit rounded policies, 0.1 exact
Double failure, large exponent without dense zeros, all representation/work caps.

Codec: valid/invalid separators, UTF-8, escaped surrogate pairs, controls, every
number grammar boundary, one root/EOF, BOM policy, progress/failed state,
byte-split equivalence, all writer escapes, source map coherence and invalidation.

Coding/Pointer: all containers/super/user errors/paths/strategies, missing/null,
external decoder limitations, native passthrough, one cumulative facade meter,
strict tilde/index/fragment ordering, numeric object keys and token composition.

Budgets/reports: exact boundaries, overflow, refund versus total work, cancellation
inside loops, bounded preview/redaction and stats counts with reporting disabled.

Use authored fixtures and pinned independent suites, plus exact boundary and
adversarial reproductions. Keep case counts and evidence in qualification ledgers.
