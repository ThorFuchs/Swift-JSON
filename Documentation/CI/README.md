# Native CI

The Native CI workflow uses GitHub-hosted arm64 `xcode-27` runners, documented
by GitHub as macOS 27. It selects the installed Xcode 27.2 toolchain and runs
preflight before any qualification. The actual OS, compiler, SDK and Xcode build
are recorded; macOS/SDK 27 and Swift 6.4 remain minimums.

Pushes to main, pull requests and manual dispatch run three lanes:

- Native: public inventory, manifest/dependency graph, release build, debug and
  release Swift Testing, five-product example, rooted JSON/JSONSchema consumer,
  public cap tests and pinned independent suites under an external timeout.
- Safety: full Address Sanitizer tests, targeted shared-state Thread Sanitizer
  tests, and strict memory safety compilation with warnings as errors.
- Documentation: public symbol graphs, complete authored API/parameter comments,
  executed README examples, seven native DocC catalogs with warnings as errors,
  native static-hosting transforms and site route/asset checks.

Actions are pinned by commit. Jobs have read-only repository permissions and
checkout persists no credentials. Every lane uploads its receipts and logs even
on failure, with 30-day retention. No secrets, private records, local archives,
tagging, package-release publication or self-hosted workstation access is configured.

On `main`, a separate Pages job publishes the exact documentation artifact only
after all three matrix lanes pass. Its narrowly scoped `pages: write` and
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

## S3 G1 focused native lane

`python3 Scripts/ci.py --lane schema-examples` checks the exact eight-product
manifest, empty dependencies, all 49 unchanged finite core policies, 21 functions
in JSONSchemaExamplesTests, all 69 existing JSONSchemaTests functions with their
12 exact parameter invocations, and the real standalone public consumer (12 cases and
2 expected package-boundary compiler rejections). This focused lane supplements
the unchanged required Native checks; it does not establish G7 platform release
qualification. It records source hashes, toolchain, commands, exits and events.

The full root lane now requires 440 functions on Mac (424 on Linux), with the
same 325 parameter invocations. TSan adds one shared-generator function for a
Mac total of 16. New tests are also included in the exact WASI bundle inventory;
changing an expected inventory does not claim a WASI execution pass. All 49 core
cap behavior probes, pinned independent-suite policies and existing discovery
checks remain required in the full lanes.

`--lane schema-examples-safety` supplements full safety with Release ASan (all
21 G1 functions), TSan (the one shared-generator function) and strict memory-safety
compilation of the new target and dependencies. Native Swift 6.4's observed
`--test-product JSONSchemaExamplesTests` selects the generated test product; this
does not add a public library product or change full-lane cardinalities. No
filtered lane substitutes for the full release/conformance/platform gates.

The schema-examples consumer qualifier preserves its 15 public cases/two compiler
negatives and additionally requires ten synchronized DocC snippets in two processes.
The docs lane checks those source bytes before compilation. Exact marker/cardinality
checks reject missing documentation outcomes; all 49 baseline cap probes and the
96 generator/515 full-root/19 sharing-function requirements remain unchanged.
