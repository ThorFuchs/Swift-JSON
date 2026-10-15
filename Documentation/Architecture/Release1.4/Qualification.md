# Foundation qualification boundary

The foundation code and harness were qualified together under source manifest
`864d9b3dd8e1d79a0a6cbec862476843ddca2ff8a1582471b80fba54b863459e`.
The receipts identify the renderer base HEAD plus the actual edited-file hashes;
this is pre-commit evidence, not a claim that the parent commit contains the CLI.
Only this ledger, progress and qualification prose were subsequently updated.
Production Swift, the package manifest and executed scripts match those receipts.

Native environment: arm64 macOS 27.0; Swift 6.4
(swiftlang-6.4.0.34.1), language mode 6, Xcode 27.2 (27B5019j), SDK 27.2.
The configured beta Xcode is required on this host; the default CLT attempt was
unqualified and is retained separately. No baseline or compiler check was lowered.

| Command | Actual outcome |
| --- | --- |
| `python3 Scripts/ci.py --lane native --output .build/ci/cli-c1-reviewed-native` | Exit 0; all 18 commands passed; debug/release each 232 functions, 177 parameter invocations |
| `python3 Scripts/ci.py --lane safety --output .build/ci/cli-c1-reviewed-safety` | Exit 0; ASan 232 functions/177 parameter invocations; TSan seven shared-state functions; strict-memory-safety build with warnings as errors |
| `python3 Scripts/ci.py --lane docs --output .build/ci/cli-c1-reviewed-docs` | Exit 0; five DocC catalogues, coverage checks and compiled examples |
| `python3 Scripts/qualify_cli.py --binary .build/release/swift-json --output …` | Exit 0; 53 real subprocess cases, no exclusions |
| `python3 Scripts/qualify_cli_ownership.py --output …` | Exit 0; three compiler probes: borrow compiles; double consume and cross-package access fail with required diagnostics |

The inherited 173 parameter cases remain unchanged; four CLI parameter cases are
additional. All 49 baseline cap probes keep their recorded outcomes. Independent
syntax qualification observes 318 cases: 287 evaluated successes and 31 policy
cases. Schema qualification observes 2,337: 2,300 evaluated successes and 37 policy
cases. Authored suites retain 82 public semantics, nine budget/counter cases and
4,396 deterministic malformed-input replays. The downstream consumer retains 20
explicitly rooted outcomes: eight positive, twelve negative, with two operational
error outcomes distinguished from ordinary invalidity. These do not establish MCP
server conformance.

The three final lane receipts report unchanged source inputs while running. Earlier
failed compiler, SIGINT actor-isolation, EOF-race, normalized-spelling expectation
and strict-pointer-annotation attempts are retained alongside successful corrections.
The expected normalized `1e-1` spelling follows the existing coefficient/exponent
contract; no existing test was weakened.

This is a reviewable foundation milestone. All 94 acceptance IDs remain in
Acceptance.json. Partial/not_run rows are not successes: complete filter IR/VM,
arithmetic/richer filters, all 16 CLI cap boundaries, split/slow/no-progress I/O,
selected mobile/portable consumers and clean candidate reproduction remain pending.
The renderer prerequisite is PR #21 at `3c1e8a1`; transfer/PDF work and the parallel
1.2 train are unchanged. Provider bridge APIs are absent at this base; qualification
and integration must precede their advertisement. No tag, merge or publication is
performed by this boundary.

Materialized receipts and their exact source-input records are in the local
foundation evidence bundle. Run the listed commands to regenerate evidence; local
build outputs and private input packets are excluded from public Git/source archives.

## Pull query-core milestone

Base foundation f469f1d (draft PR #23), stacked query branch
`codex/1.4-json-cli-query-core`. Native Swift 6.4/Xcode 27.2/SDK 27.2/macOS 27
qualification ran through Scripts/ci.py on source manifest
`c8f09d2eaa6cf14f3efb11e8a2645796075c54274fa6b8af9db464fe27b173aa`.
Native: 20 commands, exits 0; debug/release each 256 root functions and 199 parameter
invocations. Safety: ASan same full counts; TSan eight shared-state functions;
strict memory safety/warnings as errors compiled cleanly. DocC: five catalogs.
All three receipts record unchanged source inputs. Receipts/logs/event streams:
`.build/ci/cli-c2-native-serial`, `cli-c2-final-safety`, `cli-c2-final-docs`.

Foundation subprocess cases remain 53/53; authored C2 cases 38/38, policy 0.
The public exact comparator uses JSON/JSONStreaming. Original 49 cap probes,
318 JSON cases (287 evaluated, 31 policy) and 2,337 schema cases (2,300 evaluated,
37 policy), authored 82/9/4,396 and the 20 rooted downstream cases are preserved.

Additional review tests verify quota failure cleanup during keys/slices/maps,
objects and catch-message construction. Cancellation after a first yield checks
terminal behavior plus zero live frames/collections/input storage. A first test
retained a second optional alias; it was corrected to release that reference.
An initial parallel native/docs invocation failed because SwiftPM's lock-wait
banner preceded dump-package JSON. The complete serial native rerun passed;
the failed receipt is retained and is not a package qualification pass.

These receipts precede only the milestone ledger/prose update. Runtime/test/harness
source remains identical; final C5 qualification will use the integration head.
The inherited 168 corpus rows and auxiliary binding modes still need their complete
mode-specific dispositions. Arithmetic and advanced filters have separate gates.
No simulator/device, Linux or WASI CLI success is inferred from this local run.


Hosted C2 Linux runs on x86_64/ARM64 passed 256 root functions/199 parameter cases,
ASan/TSan safety and the 53 CLI subprocess cases, then the comparator failed to
compile: Glibc's mutable `stderr` global is not concurrency-safe in async main.
The qualification tool now writes bounded failure text through
FileHandle.standardError. No unsafe annotation/flag or library behavior changed.
Failed run 38593758299 and its actual compiler log are retained; a fresh hosted
run is required before Linux closure. Local comparator rebuild and all 38 C2
vectors verify the diagnostic-only fix on the supported Mac.


## Exact arithmetic milestone

Branch `codex/1.4-json-cli-exact-arithmetic` starts at query core 6e8f145
(draft PR #24). Native/safety/docs passed on the same unchanged source manifest
`33439f5716ac7e33e01e477db4cb018547618fa7b74885867bb2b290ba43d7e0`.
Native: 22 actual commands, exits 0; debug/release 266 root functions and 199
parameter cases. Safety: ASan same counts, eight TSan shared functions and clean
strict memory safety/warnings-as-errors build. DocC: five catalogs. Receipts are
`.build/ci/cli-c3-handoff-{native,safety,docs}`; the CLI lane additionally passed
46 functions, 53 historical foundation subprocesses, 38 C2 vectors, 17 C3 vectors,
and 18 operation-site/report checks covering all sixteen CLI metrics.
The ten arithmetic functions evaluate the 738 independent integer/Fraction cases,
actual digit/exponent/token/work/retention boundaries, host narrowing and inner-loop
cancellation. Original suite/cap/exclusion/downstream counts are preserved.

Failed predecessor receipts are retained: negative-leading vector argv lacked `--`;
a release integration exposed queued coefficient refunds crossing output's scratch
baseline. The corrected domain handoff drains refunds before a new stage. Tests keep
live result reservations, reclaim dead scratch and preserve cumulative work/health.
No tests or accepted output expectations were lowered. The initial host-width probe
was mathematically wrong about 2*D+2 overflow for D<Int.max and was corrected to
exercise the actual Int.max allocation/narrowing boundary.

The pinned Swift 6.4 WASI SDK is installed (swift sdk list exits 0), but this milestone
has not executed its arithmetic kernel on wasm32. Native macOS evidence does not
close that row. The final C5 candidate still requires precise matching compiler/host,
selected mobile library consumers, CLI installation/reproduction/performance and
all inherited corpus dispositions. Provider helpers are not advertised or inferred.
These receipts precede only this milestone ledger/prose update; runtime, tests and
harness are unchanged. Final integration must refresh the affected final-source checks.
