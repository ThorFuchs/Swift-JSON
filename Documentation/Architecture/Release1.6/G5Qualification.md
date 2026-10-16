# G5 native qualification

G5 extends G4 commit 304f900489dc6c24bce862eccf6adc9865df1027 on the isolated
`codex/1.6-schema-examples` branch. G0-G4 history/archives are preserved. See
[G5 resources and lifecycle](G5Resources.md) and [progress](Progress.json).
G6-G8 and main's independent repair integration remain open.

## Actual native outcomes

The supported host was macOS 27.0 arm64, Xcode 27.2 (27B5019j), Apple Swift 6.4
(swiftlang-6.4.0.34.1 clang-2100.3.34.1), SDK 27.2, language mode 6.
Every command explicitly selected DEVELOPER_DIR/SDKROOT; no global selection changed.

* `python3 -B Scripts/ci.py --lane schema-examples-advanced --output Artifacts/SchemaExamplesS3/G5/native-qualified`
  exited 0, all nine commands passed. Exact manifest/product isolation and empty
  dependencies passed. All 96 generator Swift Testing functions passed in Debug
  and Release, including 17 added G5 functions.
* `python3 -B Scripts/ci.py --lane schema-examples-safety --output Artifacts/SchemaExamplesS3/G5/safety-qualified`
  exited 0, all three commands passed: 96 Release ASan functions, four TSan sharing
  functions (32 invocations each, including mixed success/cancellation), and
  strict-memory-safety compilation with warnings as errors.
* Public consumers again passed 15 cases/two processes, two access-control compiler
  negatives, one trusted ownership positive/eight compiler negatives, and independent
  byte-transport/SHA vectors. G3 again passed 192 required calls plus two proofs per
  process; G4 passed 144 calls per process (112 certified, 32 explicit incomplete).
  All 44 schemas/155 witness expectations received native checks. Two processes
  matched outcomes, exact values, digests and successful accounting. Incomplete
  search is not a validity verdict or an unsatisfiability proof.
* Harness mutations passed 26 acceptance/rejection cases and the event parser passed
  19 regressions. Exact full-lane requirements become 515 functions, 325 parameter
  invocations and 19 sharing functions; all 49 baseline metric probes remain.
  These focused runs do not claim execution of later full release/platform gates.

The final clean-head docs receipt records seven native DocC catalogs, authored API
coverage, README examples, actual public consumer and static-site validation for the
committed snapshot. SourceEvidenceMap verifies full critical file-set/hash equality
for native/safety and exact clean-head equality for DocC. Private materialized
receipts retain commands, exits, toolchain, source inputs, logs and event hashes.
No controlled timing, throughput or RSS result is claimed on this shared host.

## Review findings and boundaries

Removed a real unmatched 32-byte refund from trace finalization. A new direct
reservation test proves the transport leaves precisely its 64-byte SHA hex result;
a separate policy transport test proves its real temporary array slots are released.
Candidate values/order, algorithm v4 and trace v2 bytes are unchanged. G4 comparison
receipts verify exact outcomes, traces and work; logical peaks may increase by 32.
No cap, logical weight, public signature, dependency, core/schema or regex source
was changed. Some staging reservations deliberately remain conservative until the
proposal or invocation ends; no exact heap/liveness or RSS guarantee is asserted.

The actual invocation boundary now latches every terminal error and releases its
remaining logical reservations on success/transfer and failure. Tests preserve a
caller's earlier reservation, repeatedly reuse a borrowed successful ledger without
resetting work, use results after source/registry scope exit, prove false-verdict
work/diagnostics and exact/one-short quotas for seven metrics, and check zero work,
preparation quota, overflow, nested cycles and exhausted branches. Cancellation is
triggered at charged checkpoints in discovery/construction/native regex, long decimal
division and final trace hashing; cleanup cannot clear terminal health or publish a
partial certificate. The prepared immutable generator remains independently reusable.

Exploratory failures are preserved separately: an initial missing try in a new
assertion, a comparison using a different number representation, and a TSan compiler
rejection of a loop task capture. Final tests use identical parsed exact candidates
and explicit checked Sendable value captures. Diff review restored a legitimate
policy-buffer release accidentally removed alongside the trace refund, and added its
own regression case. The superseded native Release job was deliberately stopped;
its partial receipt is never relabeled a pass. No failure was skipped or silenced.

A complete unchanged 654-file scope reuses G2's separately passed schema command:
69 functions, 12 parameter invocations, 2300 pinned evaluated cases and 37 separately
classified policy exclusions. The old aggregate failed a stale consumer marker;
that status is preserved. Reused logs/events/source are materialized in the return.
All original/amended fixture bytes and classifications remain unchanged.

G6 final public documentation, G7 full/platform qualification and G8 release review
remain open. Reconcile main's 1.5.1 repairs and counts before those release gates.
No sibling source, remote branch, PR, merge, tag, release or deployment was changed.
