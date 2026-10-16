# N1 candidate WASI scope

The opt-in JSONNavigation product candidate keeps the same full-language Swift6.4
wasm32-unknown-wasip1 scope and empty dependency graph. Exact discovery is481
functions/288 parameters, including39 Navigation functions, with all49 core cap
outcomes and existing independent policies. CLI runtime remains a separate scope.
Actual source-bound execution receipts are required; the historical stage counts
below are preserved, not attributed to this candidate.

# WASI command support

This additive local branch supports the full-language Swift 6.4 SDK target
`wasm32-unknown-wasip1`. All four products and the package-private regex runtime
use the same model, codec and offline schema engine as Apple and Linux. The root
manifest retains four products, no dependencies and Swift language mode 6.
Apple deployment minimums remain macOS/iOS 27. WASI has no SwiftPM platform entry.

The initial pinned execution hosts are WasmKit 0.3.1 and Node 26.5.0/V8 on an
ARM64 Mac. Match the Swift.org compiler and SDK exactly. The SDK pin is
`swift-6.4.0-RELEASE_wasm`, archive SHA-256
`f07b7be3c586d92d7a07051fc6d303b87ebea67eadc40640ba59d5a8b79aa86d`.
The [official setup guide](https://www.swift.org/documentation/articles/wasm-getting-started.html)
explains matching toolchains; newer SDKs need fresh receipts. Run the local lane
with that compiler and WasmKit on PATH:

```sh
python3 Scripts/ci.py --lane wasm
```

A prepared lane is not a pass. Its receipts bind actual exits, module hashes,
source inputs, host versions, discovered counts and materialized case outcomes.
The [original audit](WebAssemblyAudit.md) remains the historical baseline at
`5ca107923766081ef447943a069d3871861d1fe8`; its blockers are not claimed as successes.

## Finite capacities and UInt64 counters

Published profiles and logical weights remain byte-for-byte unchanged. Twelve
metrics are cumulative UInt64 counters, never allocation sizes or array indices:
workUnits, numericWorkUnits, compileWorkUnits, evaluationWorkUnits,
regexCompileWorkUnits, regexSearchWorkUnits, aggregateRegexWorkUnits,
patchWorkUnits, totalWorkUnits, totalInputBytes, totalRecords, totalScannedNodes.
They admit finite maxima below UInt64.max. The other 37 metrics retain the
strict Int.max capacity check and additional cancellation/pending rules.
[WASIMetricPolicy.json](WASIMetricPolicy.json) enumerates all 49 classifications.

This lets balanced and offline validate on wasm32 without clamping defaults.
Exact Version 1 persistence still intersects balanced with explicit limits.
Checked admission includes retired report totals before committing work; a
caught overflow remains terminal. Synthetic ledger boundary tests cross Int.max
without allocating or claiming to execute that quantity of work.

All production Int conversions were inspected: objectMembers caps guard coding
and index reservations; actual array counts guard token positions and Pointer
indices; bounded Unicode tables/byte digits/bit fields guard format and number
helpers; fixed pinned schema sizes guard I/O. Regex backreference integers use
checked arithmetic. Counter exemptions add no narrowing conversions.

## Deploying schema resources

Ship the copied `Swift-JSON_JSONSchema.bundle` directory beside the WASI command.
Pass an absolute guest command path as argv[0] and preopen its containing directory
at that guest path. Preserve all nine pinned Draft2020-12 files and notices.
The package resolves this documented sibling directly on WASI, avoiding SDK
Bundle.main discovery, which can trap without a preopen. Missing resources,
permissions or an invalid command path throw schemaCompilation/metaSchema;
resource exhaustion and cancellation keep their distinct operational errors.
Apple and Linux continue to use their existing SwiftPM bundle discovery.

The runnable [public consumer](../../Tools/WasmAudit/README.md) includes a Node
host and WasmKit commands. Its `--repo` host option is qualification-only access
to frozen fixtures/output. Applications need only their own resource directory.
The [Node WASI documentation](https://nodejs.org/api/wasi.html) explicitly states
that its filesystem implementation is not a security boundary for untrusted code.
Swift-JSON's quotas do not change that host property.

## Execution and safety policy

Tasks run cooperatively on one WASI executor. Immutable plan sharing uses
separate invocation state; synchronous work does not offload or promise
preemption. Portable tests cancel their own task after actual owned numeric,
codec or regex progress; native Dispatch rendezvous tests remain intact.
Awaited-source/sink tests also cover cancellation across suspension and terminal
accounting. Cancellation quantum bounds charged work, not elapsed milliseconds.

The Node lane evaluates all 192 root functions and 173 parameter invocations in
debug and release, including 31,824 independent regex cases, 18,853 normalization
cases/94,265 comparisons and 874 format vectors. Its release independent runner
retains syntax 318 observed/287 evaluated/31 policy and schema 2,337 observed/
2,300 evaluated/37 policy, plus 82 authored, nine budget/report and 4,396 malformed
replays. Policy exclusions are not evaluated successes.

Both engines execute 13 public consumer functions, all 49 metric outcomes,
20 explicitly rooted frozen vectors (eight valid/twelve invalid plus two separate
operational failures), debug/release command parity and missing-resource failures.
WasmKit's scope does not claim the full root or independent corpus executions.
A successful validation false is distinct from an operational failure in every lane.

Strict memory safety compilation with warnings as errors is required. The pinned
compiler rejects Address Sanitizer for this target; SwiftPM's accepted TSan option
does not forward instrumentation. These are unavailable WASI instrumentation,
not sanitizer passes. Apple sanitizer lanes must pass after shared-source changes;
Linux sanitizer refresh remains required on an actual Linux runtime. WASI memory
bounds/traps, adversarial replay and cross-host parity supplement this policy,
without claims of exhaustive memory or race proof.

Release calibration logs separate owned logical peaks/work from allocated linear
memory pages and host RSS. Allocated pages cannot shrink and are not live heap
usage; host process RSS includes VM/compiler overhead. Counts/quotas are not fuel,
RSS caps or throughput guarantees. Existing native performance reviews remain
historical; a matched shared-source review accompanies this change.

## Scope and acceptance

Clean source extraction must rebuild all products and execute public default,
persistence, resource/schema, budget, Patch and streaming behavior with the
same source archive manifest. SDK/host binaries are tools, not package dependencies.
Original code remains Apache-2.0; notices and fixture pins remain unchanged.
Public binary distribution requires reviewing SDK component license obligations.

Browser hosting, DOM/JavaScript bridging, workers, Embedded Swift, wasi-threads,
wasm64 and additional host/SDK versions have no execution qualification here.
There is no online resolver, fallback engine, new product or E11/E12 feature.
The local evidence report records any gate unavailable in this session; missing
native/Linux runtime evidence must never become a pass or lower the baseline.
