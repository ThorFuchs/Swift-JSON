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
runners and matching Linux shared objects plus the merged profile; the exporter
runs against those copies.
Generated tables, unmapped declarations, and unavailable branch/MC/DC counters
remain separate. Existing Linux/native lane names and 49 metric probes remain.

Initial focused native verification passed 32 functions (including one existing
reader case) on Apple Swift 6.4 / Xcode 27.2 / macOS SDK 27.2. The Python harness
passed all ten negative/discovery cases. The prior accepted atomic coverage baseline is 6753/6929 lines and 7156/7691
regions. [Actual outcomes](CoverageWaveOutcomes.json) retain commands, source
identities, materialized receipt hashes and distinct platform scopes.

The structural streaming completion alternative and unused private helpers keep
their denominators. Proposed 98% line / 95% region per-module review targets,
remaining public end-to-end/mutation work and deferred device scopes stay open
until evidence justifies closure.

## Qualified outcomes

Native/debug/release/full ASan passed 276 functions / 173 parameterized
invocations; targeted TSan passed 22 functions. Native/docs passed all 582
authored public symbols and compiled examples/catalogs. Both Linux architectures
passed full qualification/safety, 49 caps, consumers, corpus policies and clean
source reproduction. Both corrected coverage jobs passed; their original
runners-only exports remain failed evidence. Swift Build's Linux test/shared
objects contain the library code, so exports preserve five runners plus five
DSOs. Actual LLVM replay from preserved objects/profiles reproduces the totals.

WASI's scoped lane passed 38 commands: Node full debug/release roots, 103
QA functions on each Node/WasmKit configuration, and strict-memory compilation.
This scoped lane does not refresh separate independent corpora/consumer/cap
qualification; it does not claim unavailable WASI sanitizers.

| Module | Authored lines | Authored regions |
| --- | ---: | ---: |
| JSON | 3369/3443 (97.85%) | 3252/3427 (94.89%) |
| JSONSchema | 2389/2417 (98.84%) | 2953/3091 (95.54%) |
| JSONRegexRuntime | 650/659 (98.63%) | 668/695 (96.12%) |
| JSONStreaming | 228/232 (98.28%) | 256/269 (95.17%) |
| JSONPatch | 184/185 (99.46%) | 210/212 (99.06%) |
| Total | 6820/6936 (98.33%) | 7339/7694 (95.39%) |

Native and ARM64/x86_64 Linux totals agree. No denominator was reduced. Core's
unused JSONFingerprint and JSONOperationContext remain included; other public
and guarded paths still need separate review/tests. Execution percentages do
not establish assertion completeness; branch and MC/DC counters are unavailable.

## Performance review and remaining work

The required correctness fix was measured against its parent on an authored
32-issue complete-diagnostic workload. Three short paired runs have a +1.19%
median with a noisy +149% pair. Five longer paired runs have a +11.98% median,
crossing the unchanged 10% review trigger; paired changes range from -0.53%
to +73.21%. All samples remain retained. Logical peaks and owned work are equal.
The correctness repair is retained; timing attribution is inconclusive amid
large variance. Controlled quiet-host recalibration remains pending before a
1.2.1 release decision. No optimization, threshold or quota was changed.
This does not replace the full historical performance baseline or streaming
regression disposition.

The 98/95 per-module targets remain open for core JSON, and the broader
end-to-end/mutation acceptance plan is unfinished. This closes the Linux export
and current behavior wave, not the whole proposed 1.2.1 program. Closing records
are a documentation successor; runtime/tests match the qualified heads.
