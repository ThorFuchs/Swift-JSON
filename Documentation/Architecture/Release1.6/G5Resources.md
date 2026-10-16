# G5 cumulative accounting and lifecycle

G5 retains `s3-candidates-v4`, SplitMix64 v1 and all existing byte transports.
Candidate order, values, trace bytes and semantic authority are unchanged. The
accounting correction removes an unmatched 32-byte refund during trace hashing.
Successful logical retention may therefore increase by 32 bytes relative to G4;
a previously marginal retention cap may now fail correctly. Historical receipts
and goldens remain available. This changes neither the 49 default caps nor the
version 1 logical weights.

## Invocation boundary

Public `generate(seed:profile:)` creates one noncopyable JSONWorkMeter with the
intersection of generation and validation limits. Its internal borrowed-meter
entry is also used by behavior tests. That entry requires the identical policy
and core domain; it is not a public accumulator API. Discovery, reference and
branch expansion, typed staging, exact writer/parser materialization, every native
validation and trace finalization borrow that same ledger. There is no nested
meter and no replacement of a failed ledger. Preparation separately shares one
compiler-domain ledger across compilation and source/corpus/policy hashing.
Caller construction of documents, registries and corpora precedes these operations.

Completed false verdicts consume evaluation/numeric/regex work, diagnostic bytes
and issue counts. Only their discarded live ownership is released. No failure
report is fabricated from a throwing validator. Operational errors, cancellation,
search exhaustion, unsupported construction and trivial proofs leave the search
terminal. The boundary latches even errors that originate outside the meter
(such as nonproductive native reference evaluation). Catching them in trusted
internal code cannot resume that invocation. A new public call has independent
health; the immutable prepared generator remains reusable and Sendable.

Work, numeric work, evaluation work, aggregate regex work, issue counts and
trace/diagnostic charges are cumulative. Per-value input/output/node/text ceilings
are retired between materializations; retirement preserves lifetime report totals
and never refunds work. Per-search regex work resets only its per-search ceiling;
aggregate regex work remains cumulative over all candidates. Active depth, frame,
container cardinality and individual token capacities keep their existing meanings.
They are not cumulative generated-node or total-depth counters. There is no new
unlimited setting and no arbitrary-schema completeness claim.

## Ownership and reports

Search uses a conservative invocation arena: some construction scratch reservations
are held until the containing proposal/invocation ends even when Swift can release
an individual temporary earlier. Rejected proposal and verdict ownership is
released at their existing boundaries. Complete trace bytes remain charged until
hashing; SHA-256 scratch and the 64-byte digest overlap are checked. No trace
truncation or retained error-history array is introduced.

A successful report snapshots counts at certification, including the returned
value/verdict, receipt metadata and any still-reserved invocation staging. Before
the borrowed entry returns, it releases its remaining logical reservations as the
result transfers to the caller. On failure it releases all invocation reservations
without changing charged work, diagnostics, retired admission or terminal health.
The caller's preexisting live reservations are preserved. The report's retained
count is a conservative certification snapshot, not a post-return heap measurement.
Peak logical bytes are neither allocated bytes nor process RSS. Callback execution
in the package-only checkpoint test observer is trusted test work, not an owned
instruction quota or a public generator callback.

No result retains a generator, plan handle, mutable trace or search stack. Its
JSON value, native verdict and policy/identity values remain usable after the
preparation/source/registry scope ends. Immutable preparation retains its admitted
source/registry/corpus/plan until the caller releases it. There is no global mutable
cache. Native sanitizers and concurrent failure/success tests qualify this code;
there is no allocator-independent proof of immediate physical memory reclamation.

## Qualification boundary

`LifecycleAndAccountingTests.swift` adds real-engine cases for exact successful
quota/one-short boundaries (seven work/diagnostic/retention metrics), trace ownership,
repeated borrowed calls, source-scope result lifetime, multiple false verdicts,
zero work, exact preparation quota, cyclic construction, exhausted branches,
native evaluation errors, checked overflow and deterministic cancellation.
Cancellation uses actual charged checkpoints rather than sleeps: decimal division,
discovery/construction/native regex and final trace hashing. Every interrupted
search checks terminal latching and reservation cleanup. Separate concurrent
invocations mix cancellation and success without poisoning preparation.

The focused native/safety/docs receipts qualify this increment only. Full release
G7/G8, main repair integration, Linux/WASI/mobile and controlled performance remain
separate. See G5Qualification.md for observed commands/counts, not inferred passes.
