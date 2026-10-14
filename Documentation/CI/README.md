# Native CI

The Native CI workflow uses GitHub-hosted arm64 `xcode-27` runners, documented
by GitHub as macOS 27. It selects the installed Xcode 27.2 toolchain and runs
preflight before any qualification. The actual OS, compiler, SDK and Xcode build
are recorded; macOS/SDK 27 and Swift 6.4 remain minimums.

Pushes to main, pull requests and manual dispatch run three lanes:

- Native: public inventory, manifest/dependency graph, release build, debug and
  release Swift Testing, four-product example, rooted JSON/JSONSchema consumer,
  public cap tests and pinned independent suites under an external timeout.
- Safety: full Address Sanitizer tests, targeted shared-state Thread Sanitizer
  tests, and strict memory safety compilation with warnings as errors.
- Documentation: public symbol graphs, complete authored API/parameter comments,
  executed README examples, four native DocC catalogs with warnings as errors,
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

## Coverage and test discovery

`python3 Scripts/ci.py --lane coverage` runs the full instrumented native Swift
Testing suite and exports all five test executables against its merged profile.
SwiftPM's default export can contain only a subset of executable modules on the
supported Xcode backend. The lane rejects missing/duplicate source mappings,
stale unmapped classifications, impossible counters and changed discovery. An
actual LLVM export omitting the schema executable must be rejected. Branch/MC/DC
counters are reported as unavailable when the compiler emits none; generated
Unicode data and executable lookup regions remain separate.

[TestDiscovery.json](../Qualification/TestDiscovery.json) is the exact root,
parameterized, QA and shared-state discovery contract. Native, safety and WASI
read that same contract. Native and coverage also run ten Python harness behavior
tests; these check qualification tooling and do not count as Swift library tests.
The existing required Native check names/settings and all 49 cap probes remain.
The coverage lane is available locally; this increment does not activate a new
hosted check or claim a Linux/WASI coverage run.

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
It preserves the exact root discoveries in TestDiscovery.json, independent corpus policies and 49 cap
outcomes; both hosts also execute the frozen public consumer. The
[WASI contract](../Architecture/WebAssembly.md) defines host/safety scopes.
This local lane neither activates hosted CI nor substitutes for Apple/Linux gates.
