# Native CI

This main-based forward-port retains seven products and restores the entire
1.2.1 regression inventory. The experimental composition increment adds 12 functions; current native root discovery is 558 functions and
325 parameter invocations; Linux is 542/325. Full ASan uses the same roots;
TSan checks 42 native or 41 Linux functions. QA requires the original 145-function
maintenance subset. Exact per-module counts are in
[the discovery contract](../Qualification/TestDiscovery.json); parameter-function
identities remain independently checked from Swift Testing events. All 49 public
cap outcomes remain required. Native runs 32 commands; Linux runs 28. The 126
pinned maintenance function identities must all complete in full-root and QA runs. These are acceptance expectations, not a claim that
a pending run passed. The dated counts below remain historical stage evidence.

The restored ownership/reader probes identify only their own checkout; a clean
source archive outside Git reports null rather than failing or borrowing a parent
commit. Native/Linux also run the installed-resource consumer against intact,
missing and same-size-corrupt bundles. CLI source identity is checked before build.
Manual coverage lanes restore the complete instrumented-object denominator and
reject a deliberately incomplete export. They do not imply branch/MC/DC coverage.


The Native CI workflow uses GitHub-hosted arm64 `xcode-27` runners, documented
by GitHub as macOS 27. It selects the installed Xcode 27.2 toolchain and runs
preflight before any qualification. The actual OS, compiler, SDK and Xcode build
are recorded; macOS/SDK 27 and Swift 6.4 remain minimums.

Pushes to main, pull requests and manual dispatch run four lanes:

- Native: public inventory, manifest/dependency graph, release build, debug and
  release Swift Testing, six-library example, rooted JSON/JSONSchema consumer,
  public cap tests and pinned independent suites under an external timeout.
- Safety: full Address Sanitizer tests, targeted shared-state Thread Sanitizer
  tests, and strict memory safety compilation with warnings as errors.
- Archive: deterministic source archive, Git-free extraction, the complete 32-command
  native lane including real ownership/reader probes, and a byte-equal rebuild
  after execution. The extracted receipt must have null Git identity and the same
  complete source manifest.
- Documentation: public symbol graphs, complete authored API/parameter comments,
  executed README examples, six native DocC catalogs with warnings as errors,
  native static-hosting transforms and site route/asset checks.

Actions are pinned by commit. Jobs have read-only repository permissions and
checkout persists no credentials. Every lane uploads its receipts and logs even
on failure, with 30-day retention. No secrets, private records, local archives,
tagging, package-release publication or self-hosted workstation access is configured.

On `main`, a separate Pages job publishes the exact documentation artifact only
after all four matrix lanes pass. Its narrowly scoped `pages: write` and
`id-token: write` permissions apply only to deployment. The `github-pages`
environment admits only `main`. PRs verify the site without publishing it.
The deployment runner does not establish any native gate; all compilation and
qualification occur on the supported Mac runners before publication.

Checkout reads the full branch history. The public inventory check rejects known
internal input paths in reachable history and tracked files outside the reviewed
source distribution, preventing an old-history merge from passing unnoticed.

Receipts include source content hashes and Git identity. Nonzero expected root
and consumer test counts are required. Corpus policy exclusions remain explicit.
A hosted preview-image change can fail preflight; repair the toolchain selection
only after inspecting the new image. Never lower the package baseline.

Timing qualification runs separately on an idle native host; shared hosted jobs
cannot establish a controlled performance comparison. The existing reviewed
streaming regression is documented in ../Performance/README.md.

Run locally with `python3 Scripts/ci.py --lane native`, `--lane safety` or `--lane docs`.
The first hosted result must be inspected before marking CI qualified.

## Linux development lanes

The additive Linux workflow selects the pinned official Swift 6.4.0 Ubuntu 24.04
multi-architecture image on ARM64 and x86_64 hosted runners. It runs `linux` and
`linux-safety` with separate runtime preflight, source receipts and exact test,
consumer, corpus and 49-cap discovery checks. SwiftData/Apple compiler probes
remain in Native CI. The existing required `Native / native`, `Native / safety`
and `Native / docs` names and protection settings are preserved. This workflow
does not publish artifacts to a release or deploy documentation.

Local ARM64 VM execution qualifies its observed Linux environment; an unexecuted
x86_64 job is pending evidence. Workflow preparation does not establish hosted
success. Read the [Linux contract](../Architecture/Linux.md) before extending
distribution, architecture or libc claims.

## Local WASI lane

`python3 Scripts/ci.py --lane wasm` requires the matching Swift.org 6.4.0 compiler,
SDK and WasmKit plus Node. It records cross-build and runtime outcomes separately.
Node executes the complete 256-function/173-parameter portable root suites,
independent corpus policies and all 49 cap outcomes. Both hosts execute the frozen
public consumer; WasmKit retains its separately recorded 14-function consumer scope. The
[WASI contract](../Architecture/WebAssembly.md) defines host/safety scopes.
This local lane neither activates hosted CI nor substitutes for Apple/Linux gates.

## JSONHTML export development lane

`python3 Scripts/ci.py --lane export` requires 38 focused Swift Testing functions
in both configurations, 65 public consumer outcomes, eight artifacts, six pinned fixtures and three
Apple SDK declaration probes. It builds all five products in iPhoneOS and
simulator consumers. A bounded offscreen WebPage region experiment remains outside
the production API. The lane establishes native API/file transport and SDK builds,
not share sheets or receiving-editor UI. Explicit paginated PDF and simulator/device execution have separate materialized receipts.
Current root discovery is 270 functions on Mac (75 HTML) and 256 on Linux/WASI
(61 HTML). The focused export lane requires 38 functions on Mac. Ten Mac shared
functions, including independent PDF cancellation, run under Thread Sanitizer. All 49 cap checks
and the 173 baseline parameterized invocations remain required.

## Structured Swift Testing receipts

Swift 6.4's supported event stream records discovered, started and completed
function identities and parameterized case completions. CI checks these identities,
exact bundle cardinality and every baseline parameterized function's count (173
invocations total), and rejects missing/duplicate/skipped/issue/malformed events.
Human console summaries are retained as diagnostics; observed hosted runs can
truncate those summaries even with exit zero. JSONL is split on LF so Unicode line
separators inside valid message strings are preserved. Nineteen harness regression
probes test these failures; they supplement the Swift Testing behavior suite.
This change does not reduce discovery, cases, sanitizer coverage or the 49 caps.

Historically, the styled RTF increment added five portable functions and one native decode/style
function, retaining all existing cases. Mac root counts are 107/51/14/12/11/47;
Linux counts are 107/51/14/12/11/44. Optional `qualify_rtf_runtime.py` executes the
public consumer on isolated iPhone/iPad simulators; SDK compilation is separate
from those outcomes and from physical-device/receiver UI qualification.

## Integrated 1.3 portable qualification

The five-product WASI lane requires six exact bundles: JSON 107, schema 51, private
regex 12, streaming 14, patch 11 and portable HTML 61. Its public consumer requires
14 functions and six explicit HTML/export outcomes in both Node and WasmKit. All
173 parameter cases, 49 cap outcomes, pinned independent suites and rooted vectors
remain required. The first failed inherited expectations are retained; no blanket
nonzero/exit-zero replacement is used. Real receiving-app and physical-device UI
observations remain separate from automated SDK/API and portable execution.

## Experimental composition lane

`python3 Scripts/ci.py --lane composition` executes 12 composition functions in
Debug and Release, a distinct-package JSON/JSONSchema consumer in both modes,
and eight compiler-negative ownership fixtures. It supplements the full native,
safety and docs lanes. On a CLT installation that does not discover TestingMacros,
set `SWIFT_JSON_TESTING_PLUGIN_PATH` to the installed testing plugin directory;
CI records the explicit `-plugin-path` arguments and preserves the original failure.
No language, SDK, platform, discovery or sanitizer baseline changes.
