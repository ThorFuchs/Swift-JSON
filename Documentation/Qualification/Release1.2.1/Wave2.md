# 1.2.1 second test wave

Parent: first-wave head `21d5428793c4a972f3cfbe34471739784d21c2f0`.
This increment adds tests and qualification metadata on the isolated patch branch.
Production implementation, products, dependencies, finite profiles, platform
declarations and pinned fixtures remain unchanged. Sibling 1.3 work is outside
this branch. Later source identities and actual receipts close this record.

## Foreign Codable

[ForeignCodableTests.swift](../../../Tests/JSONTests/ForeignCodableTests.swift)
adds twelve public-API Swift Testing functions. Synchronous, invocation-owned
coder wrappers hide the native coder identity and recursively wrap children,
so nested cases execute the foreign JSON bridge. Controlled primitive attempts
have recorded ordering and injection points. Fixed goldens and exact errors cover:

- Int64, UInt64 and exact Decimal selection, explicitly excluding Double/Float
  fallback; deliberate integer-candidate refusal and NaN Decimal rejection.
- All six JSON kinds, nested objects/arrays, scalar-distinct keys, object order
  and JSONObject's nonobject refusal.
- Exact Decimal range/precision refusal, unrepresentable numbers, direct
  integer sink-error propagation and wrapped Decimal error/path/cause.
- Container acquisition errors and inability to recover values already changed
  by a foreign coder. Caller coder work remains outside owned instruction quotas.

These are controlled coder behavior tests, not a claim that every external
serializer preserves JSON fidelity. Foundation is not the JSON authority.

## 128-bit SDK/compiler probe

[Integer128ProbeTests.swift](../../../Tests/JSONTests/Integer128ProbeTests.swift)
adds five tests. A separately compiled public consumer observed Swift 6.4's
Int128/UInt128 definitions and actual package behavior before expectations froze.
Exact bounded JSONNumber construction/projection supports signed and unsigned
128-bit boundaries, including values beyond 64 bits; overflow/fractional values
fail exact conversion. Native typed Codable uses SDK defaults and refuses both
types even for 1, with EncodingError.invalidValue/DecodingError.typeMismatch.
Exact JSON/JSONNumber passthrough and Version 1 payload transport remain valid.

This is a qualified limitation. No new overload/support is silently selected by
the probe and no supported baseline is lowered. A typed 128-bit implementation
would require its own reviewed behavior, budgets and platform qualification.

## Deterministic streaming

[ControlledStreamingTests.swift](../../../Tests/JSONStreamingTests/ControlledStreamingTests.swift)
adds twelve checked-Sendable actor-gate tests. Each finite fixture admits one
held pull or handoff. Waiters wake on the expected held boundary **or** operation
termination, so an early operational failure is observable rather than leaving
the controller waiting for a callback that never occurs. Tests release/close
held continuations and join their worker tasks. Swift Testing time limits and
an external process watchdog bound focused execution; sleeps never determine
ordering or acceptance.

Cases cover root-array closing syntax, trailing whitespace and held EOF,
provisional elements, malformed tails, source errors, cancellation and terminal
next calls; single-document values, final NDJSON records and separated syntax
events at EOF; early element return without another source pull; held sink
acceptance, throwing sinks, cancellation after acceptance and exact output-cap
refusal. Accepted bytes remain accepted; no completion/report is fabricated.
These are public-observable pull/handoff/completion checks, not a measurement of
arbitrary caller work, invisible internal instructions or process RSS.

The first malformed-tail probe mistakenly expected trailingData for lexical
garbage. Shared grammar reports invalidSyntax for garbage and trailingData for
a valid second JSON root. The final test retains both diagnoses with exact byte
offset 4, terminal nil and no further pulls. No library change or weaker assertion
was used to hide that initial expectation error.

## Discovery and qualification

The shared [discovery map](../TestDiscovery.json) expects 244/173 roots,
QA 51/3/15/2, and targeted TSan 4/1/1/12. All original cases, policies and 49 cap
outcomes remain. Native coverage/acceptance/QA/safety/docs are the affected lanes.
New Linux/WASI/device runs are separate pending evidence; no runtime or package
support expansion is implied. Broader T02/T03/T05/T06 work and global 98%/95%
coverage targets remain open. Historical first-wave outcomes are preserved.

## Actual native outcome

Tested code commit: `090fffd19b40b6c9812a0add199e4ec880d24cc9`.
[Wave2Outcomes.json](Wave2Outcomes.json) binds exact source/receipt identities,
counts, coverage, qualified limitations and remaining scope. All five native
lanes passed; all approved command outcomes were 0. Coverage, native, QA and docs
CLIs exited 0. The safety CLI exited 1 when ENOSPC prevented opening the TSan log
after full ASAN passed. Source, ASAN outcomes and log hashes were revalidated;
the unchanged CI tail resumed with exit 0 after removing only completed task-owned
caches. The original nonzero result remains in local evidence.
Coverage/root debug/release/full ASAN checked 244/173; QA checked 51/3/15/2,
71 total, in debug/release/ASAN; TSan checked 4/1/1/12, 18 total. Strict memory
safety, 49 cap probes, public consumers, independent policies and 582/582
DocC symbols passed. No new Linux/WASI/device result is implied.

The earlier completion-alternative region counter is 0 in this run.
Its denominator remains. Separate causal assertions qualify EOF/closing syntax,
completion exactly once, accepted prefixes and terminal behavior; an execution
counter alone does not certify them. No synthetic private call or branch removal
was used to reach a percentage. Closing documentation changes are separate from
the tested implementation identity.
