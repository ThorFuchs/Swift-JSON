# 1.2.1 portability and completion review

This increment preserves the published 1.2.0 implementation and both earlier
test waves. It adds one Swift Testing function with 566 fixed completion cases:
eleven root spellings, both framing modes, three trailing-whitespace forms and
every two-chunk byte split, including empty chunks and a split within UTF-8.
The fixed syntax oracles assert the complete event sequence, exactly one selected
completion kind, cumulative record count and repeated terminal nil.

Current discovery is 245 root functions and 173 parameterized invocations,
72 QA functions and 19 shared-state functions. The 566 inner iterations are
reported separately; they are not 566 discovered Swift Testing functions.

## Scoped platform lanes

`Scripts/ci.py --lane wasm-qa` uses the existing pinned Swift 6.4.0 WASI SDK,
Node 26.5.0 and WasmKit 0.3.1. Node executes complete debug/release roots.
Both hosts execute the exact affected QA functions in both configurations.
Strict memory safety compilation remains required. The scoped lane does not
claim fresh independent-suite, cap-consumer, resource-deployment or performance
qualification. The existing full `wasm` lane retains those gates unchanged.

`Scripts/ci.py --lane linux-qa` requires actual Swift 6.4+ Ubuntu 24.04/glibc.
It executes complete debug/release roots, affected ASan and shared-state TSan
cases plus strict memory safety. It starts Swift Testing only, preserving the
documented upstream empty-XCTest-runner leak policy without suppressions.
The full Linux lanes and their independent inputs remain unchanged.

Actual results and any local staging blockers are recorded separately; a
prepared lane or a Mac-host Linux preflight rejection is not Linux execution.
The root dependency graph, four products, private regex target, Apple baselines,
finite profiles, notices and fixture policies are unchanged.

The first actual WASI build rejected an untyped large integer oracle inferred
as 32-bit Int. Its explicit Int64 replacement preserves the same exact expected
value. The next run exposed a pinned Swift Testing timer issue: thirteen async
cases with a one-minute trait timed out together before other async work
progressed. A two-case SDK-only package, with no JSON imports, reproduced this
on both hosts: an immediately returning timed body failed after 60 seconds;
the untimed body passed immediately.

`StreamingTestPolicy.deadline` therefore preserves the one-minute Swift Testing
trait on native/Linux, and supplies an empty tag trait on WASI. No case or
assertion is disabled. WASI streaming root and affected-QA runners instead have
an interruptible 120-second host process-group watchdog, recorded per command.
The host enforces a real termination deadline even if guest cooperative tasks
stop yielding; it does not grant library operations an elapsed-time budget.
Keep the SDK-only failing/passing receipts and revisit this adjustment with a
new Swift Testing/SDK pin.

## Completion coverage disposition

The zero-count alternative is the final `.recordCompleted(summary())` expression
in `Sources/JSONStreaming/JSONEventSequence.swift`, line 82. Source inspection
establishes why that alternative is unreachable for successful current inputs:

1. `JSONTokenMachine.hasCompleteRoot` is `rootComplete && lexer.idle`.
   Every transition setting `rootComplete` returns an event to the driver.
2. At the next loop entry, whitespace-separated framing with a complete root
   takes the earlier framing branch. It certifies a whitespace boundary or EOF
   and returns record completion there.
3. If the final EOF branch is entered with an incomplete root, `finish()` either
   throws or returns the EOF-finalized numeric scalar. The scalar is returned;
   the next invocation takes the earlier framing branch. The lexer can return
   nil at EOF only in its idle state; token-machine finish then requires an
   already complete root, which would have been handled by step 2.
4. Byte-source pulls do not modify token-machine state. After a record reset,
   `betweenRecords` permits terminal nil, not a second completion.

Thus the successful final completion expression serves single-document framing.
The new public matrix covers numeric EOF finalization, all scalar root kinds,
empty/nested containers and closing-delimiter transitions under both modes.
The existing held-EOF tests separately establish causal completion/backpressure.

Disposition: retain the defensive expression and its unadjusted denominator;
record the structural explanation rather than fabricate a private state or
remove code to improve percentages. This closes semantic investigation of this
region, not a claim of 100% region/branch or exhaustive race coverage. Revisit
the invariant if framing or token-machine transitions change.
