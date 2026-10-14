# Linux coverage and behavior-gap wave

This wave stays on the isolated `codex/1.2.1-test-plan` branch from 1.2.0.
It preserves the prior wave receipts and the sibling 1.3.0 checkout.

Add 31 Swift Testing functions: JSON 10, JSONSchema 10, private regex 4,
streaming 3 and Patch 4. Exact root discovery becomes 276 functions / 173
parameterized invocations; affected QA is 103 functions and shared-state safety
is 22. Authored fixed vectors, exact public failures and inclusive/cumulative
limits provide the oracles; tests do not call unreachable private guards.

A regression case exposed best-effort diagnostic sizing latching a terminal
meter failure before an issue could be omitted. An invocation-local omission
signal now permits the contracted invalid result with incomplete diagnostics.
Required work, annotation, retention, overflow and cancellation still throw;
no meter is reset. Default complete diagnostics retain their strict refusal.
No public signatures, dependencies, products, profiles or fixtures change.

Add `linux-coverage` to the existing two-architecture pinned Linux matrix.
It retains exact discovery and source-denominator checks, atomic counters and
the actual omitted-schema negative exporter probe. Exports preserve the five
actual objects plus merged profile; the exporter runs against those copies.
Generated tables, unmapped declarations, and unavailable branch/MC/DC counters
remain separate. Existing Linux/native lane names and 49 metric probes remain.

Initial focused native verification passed 32 functions (including one existing
reader case) on Apple Swift 6.4 / Xcode 27.2 / macOS SDK 27.2. The Python harness
passed all ten negative/discovery cases. Full platform/safety/coverage outcomes
are pending; this document is not a qualification claim. The previous accepted
atomic coverage baseline is 6753/6929 lines and 7156/7691 regions.

The structural streaming completion alternative and unused private helpers keep
their denominators. Proposed 98% line / 95% region per-module review targets,
remaining public end-to-end/mutation work and deferred device scopes stay open
until evidence justifies closure.
