# G7 production reconciliation and qualification

The isolated `codex/1.6-schema-examples` branch integrates main repair commit
037e735dc6224789e4d04d2c18d15b8d27440198 through local merge
b5bc082f930cad669364de61da4e4191e7bb9cc3. G6 remains at
4368947c0db3831da988b9d8626055a38b42a7e3. The new bounded grammar tests are
cc9ce4f49ca11bbb09273c0102c138c367cba2bc; the consumer scratch-path correction is
6652f9bd65b6f21e1a0c8a22fde5d0ce03b68813. Earlier gates and archives are preserved.

## Source and behavior

Main's best-effort diagnostic omission repair preserves an invalid verdict without
poisoning a cumulative ledger; owned work, annotation limits, overflow and cancellation
still fail operationally. Its native regression cases are retained. All 126 restored
maintenance function identities, structured HTML previews, exact policy counts and
49 core probes remain required. The deterministic CLI identity is regenerated from
this package's actual Sources and manifest.

G7 adds two meaningful Swift Testing functions and a public generated-schema replay:
64 bounded grammar schemas, 512 seed/profile certifications and 64 known-invalid
mutations, plus scalar-key/schema-member permutation checks. A separate seeded
research grammar produces another 64 schemas/512 outputs/64 invalid mutations.
Neither is an exhaustive satisfiability or arbitrary-schema generation claim.

The complete discovery contract requires 644 native functions, 628 Linux functions,
540 WASI functions, 325 native/Linux parameter invocations and 288 WASI invocations.
Native shared-state safety requires 45 functions. S3 itself has 98 functions and four
shared-generator functions. Exact module identities and every earlier parameterized
function count remain checked; policy exclusions never count as evaluated successes.

The full native harness now builds the S3 consumer with the explicit root `.build`
scratch path used by its later ownership/generation/matrix helpers. An inspected
SwiftPM default would otherwise place it under the example package. The fix changes
one command argument pair and no runtime, test, cap or conformance policy.

## Observed qualification

The complete default native lane passed all 37 commands from an actual clean,
Git-free source extraction. Debug and Release each passed all 644 functions and
325 parameter invocations. The full pinned qualification executable passed with
its unchanged 900-second watchdog. All command exits, raw logs and structured
event streams are retained; source hashes were unchanged throughout.


Native host: macOS 27.0 arm64; Xcode 27.2 (27B5019j); Apple Swift 6.4
(swiftlang-6.4.0.34.1 clang-2100.3.34.1); SDK 27.2; language mode 6.
Every native command explicitly selects DEVELOPER_DIR and SDKROOT.

- Focused native lane: all ten commands passed, including 98 Debug and 98 Release
  S3 functions, one ownership positive/eight negatives, 15 original public cases/two
  public-access negatives, ten compiled guide snippets in two processes, G3/G4
  replay and the 512-record matrix in two processes.
- Full safety: 644 Release ASan functions/325 parameter invocations, 45 TSan functions
  and strict-memory-safety compilation with warnings as errors passed.
- Full WASI: all 77 checks passed using Swift.org 6.4.0, the matching WASI SDK, Node
  and WasmKit. Node ran all 540 functions/288 parameter invocations in Debug and
  Release; existing public consumer/49-cap/rooted-vector/corpus/strict-memory checks
  retained their explicit host scopes. This does not claim a WASI CLI runtime.
- Public S3 platform consumer: both mobile SDK builds; physical iPhone 14 Pro Max
  on iOS 27.2; iPhone/iPad iOS 27.0 simulators; Node and WasmKit all passed 15 public
  cases, ten guide snippets and 512 certifications/64 invalid mutations. All 512
  normalized records, including exact values, traces, attempts and work, match byte
  for byte across those five executions and native macOS (six platforms total).

The research oracle remains Python-only tooling. The original packet script reran
44 schemas/154 witnesses. An exact numeric binding reproduces the original known
integral-number expectation error. The preserved G0 amendment evaluates 155 witnesses
with zero disagreements and eight numeric-binding regressions. The generated-value
oracle agrees with all 1,328 checked output records and 128 negative mutations;
32 explicit incomplete-search rows are separate and are not evaluated successes.

## Failures and scope

The first native aggregate rejected a SwiftPM lock-wait preamble before manifest JSON.
A later default root Debug command reached its unchanged 1800-second watchdog on the
busy shared host. A cold pilot completed its Debug command in 1277 seconds but one
Apple PDF case threw timedOut. That unchanged case passed in isolation in 3.05 seconds,
and all 97 HTML functions passed in a subsequent bundle run. Original failed receipts
remain failed and separate from later full default-lane outcomes.

Linux ARM64 preflight/build ran on actual Ubuntu 24.04/glibc with pinned Swift 6.4,
but the guest was interrupted to protect shared disk space. Partial console output
is not a full Linux native/safety pass. The exact pinned compressed input and partial
receipts/build cache are retained for resumption. No native x86_64 host or hosted
qualification was executed for this source. Physical iPad remains deferred under the
existing accepted policy; its SDK/simulator observations do not imply device results.

All logical retention weights remain distinct from heap/RSS. Charged owned work is
not a caller instruction or wall-clock guarantee. No controlled performance result,
new optimization, fallback engine, public API/default, platform expansion, remote
push/PR/merge, tag, publication or deployment is claimed by this increment.

## Gate disposition and replay

G7 is qualified for the observed Apple and WASI scopes and the independent oracle;
its full Linux native/safety portion remains blocked by local storage. The Linux
container command ended with exit 137 after the task-owned guest was stopped;
seven completed commands, including the Release build, had exit zero. The stale
partial receipt still says running and is preserved as interrupted evidence, not
rewritten into a pass. No complete 628-function Linux result or Linux safety result
exists for this source. The task guest was deleted and its temporary runtime was
stopped/unregistered. Pinned compressed inputs, source and build cache are retained.
An x86_64 Linux host is unavailable locally. Physical iPad remains deferred under
the accepted simulator policy. G8 review remains open and release_ready is false.

The final report materializes the clean source archive, full native/safety/DocC
receipts, independent oracle, platform logs and source mappings outside public Git.
Metadata-only successor changes do not alter the qualified runtime/tests/fixtures.
The source/evidence manifest distinguishes those snapshots; it does not present a
metadata mapping as another full native execution. Final DocC outcomes are recorded
in the report after execution; no remote deployment is implied.

Use the repository lanes with the supported native environment selected:

```sh
python3 -B Scripts/ci.py --lane native
python3 -B Scripts/ci.py --lane safety
python3 -B Scripts/ci.py --lane docs
python3 -B Scripts/ci.py --lane schema-examples-qualification
python3 -B Scripts/ci.py --lane wasm
```

On pinned Swift 6.4 Linux, resume both linux and linux-safety after sufficient local
space is available, or use separately authorized hosted execution. Preserve 628
root functions, 325 parameter invocations, 44 shared functions, all 49 caps and the
exact independent-suite policy split. A filtered or WASI pass does not close Linux.
