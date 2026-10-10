# JSONStreaming behavioral tests

Implement with Swift Testing; no passing placeholder tests. Native execution is pending.

Every byte split on strict token/event/value framing, NDJSON LF/CRLF,
no silent skipped/empty lines, final record without LF, concatenated-record
whitespace policy, truncation/trailing garbage and terminal failure.

One outstanding source pull and pending value/event; slow source/consumer/sink,
errors/cancellation and full-chunk awaited sink acceptance. Source behavior after
early break is explicitly caller-owned; no claim to cancel arbitrary tasks.

Root-array empty/mixed elements, outer depth, per-element admission versus
document quotas, final completion once only after EOF, malformed tail or early
break without completion, totalScannedNodes/work/bytes/records never reset.
Generate large inputs without preloading, measure bounded owned state, and prove
high-water scratch is trimmed to maxReusableBufferBytes at record boundaries.

Use authored fixtures and pinned independent suites, plus exact boundary and
adversarial reproductions. Keep case counts and evidence in qualification ledgers.
