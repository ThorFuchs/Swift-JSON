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
- Documentation: public symbol graphs, complete authored API/parameter comments, executed README examples, four native DocC catalogs with warnings as errors.

Actions are pinned by commit. Jobs have read-only repository permissions and
checkout persists no credentials. Every lane uploads its receipts and logs even
on failure, with 30-day retention. No secrets, private records, local archives,
tagging, release publication or self-hosted workstation access is configured.

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
