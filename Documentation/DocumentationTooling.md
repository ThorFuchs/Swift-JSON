# Building and maintaining the DocC catalogs

Swift source comments are the API documentation authority. Native compiler symbol
graphs supply the declarations and links for eight Swift DocC catalogs. Each catalog
combines the product reference with curated Topics and a focused usage guide.
See the [Swift DocC documentation](https://www.swift.org/documentation/docc/).

## Build locally

Use macOS/SDK 27+, Swift compiler/tools 6.4+ and Swift language mode 6. Select the
supported Xcode through `DEVELOPER_DIR` if it is not the system default. DocC comes
with that toolchain; the Python scripts use only their standard library. No extra
documentation engine or root-package dependency is required.

```sh
python3 Scripts/ci.py --lane docs
```

The lane records native preflight, extracts fresh public symbol graphs, requires
summaries and named-parameter documentation on every authored public declaration,
checks README Swift fences against their executable consumer source, runs that
consumer, and compiles all eight DocC catalogs with warnings as errors. Zero public
symbols, missing comments, stale examples or a failed catalog fail the lane.

The lane also executes the standalone schema-examples consumer (15 preserved cases and two
expected compiler rejections), plus every Swift block in all five JSONSchemaExamples
guides (ten independently scoped snippets, executed in two processes). Every successful consumer value, including the
offline-reference case, receives an independent native verdict and strict
roundtrip check. Remaining work is derived from public limits and cumulative
statistics; the consumer imports no private meters.

| Output | Purpose |
| --- | --- |
| `.build/handoff/docc/JSON.doccarchive` | JSON API and exact values/native coding guide |
| `.build/handoff/docc/JSONSchema.doccarchive` | Schema API and offline validation guide |
| `.build/handoff/docc/JSONSchemaExamples.doccarchive` | Certified candidates, conservative construction, deterministic provenance and finite lifecycle |
| `.build/handoff/docc/JSONStreaming.doccarchive` | Streaming API and completion/backpressure guide |
| `.build/handoff/docc/JSONHTML.doccarchive` | Exact formatted HTML API and rendering guide |
| `.build/handoff/docc/JSONPatch.doccarchive` | Patch API and choosing/applying patches guide |
| `.build/handoff/docc/JSONBridges.doccarchive` | Opt-in native numeric conversion and fidelity guide |
| `.build/handoff/docc/JSONNavigation.doccarchive` | Opt-in exact structural traversal and coverage |
| `.build/handoff/docc/symbols/` | Public compiler symbol graphs grouped by product |
| `.build/handoff/docc/coverage.json` | Counts and documentation-coverage failures |
| `.build/handoff/docc/receipt.json` | Commands, toolchain, counts, exits and diagnostics |
| `.build/handoff/docc/compiled-catalogs.tar.gz` | All eight compiled catalogs with their exact native filenames |
| `.build/handoff/docc/compiled-catalogs.MANIFEST.sha256` | Independently verifiable hashes for every archived catalog file |
| `.build/handoff/pages/site/` | Static site, landing page and all eight references under the project base path |
| `.build/handoff/pages/receipt.json` | Native transformations, input/output hashes and route/asset verification |

Open a `.doccarchive` in Xcode for the compiled reference. To preview a source
catalog in a local browser after the lane has produced its symbol graphs:

```sh
xcrun docc preview Sources/JSON/Documentation.docc \
  --additional-symbol-graph-dir .build/handoff/docc/symbols/JSON \
  --fallback-bundle-identifier org.swift-json.JSON \
  --port 8770
```

Use the URL printed by DocC. Substitute another product's catalog, graph directory
and bundle identifier to preview it. Generated output is ignored and uploaded as
Native CI artifacts, with 30-day hosted retention. Source catalogs and build scripts
are versioned. [GitHub Pages](https://thorfuchs.github.io/Swift-JSON/) serves the
same qualified references from `main`.

CI transports the compiled catalogs in a tar archive because native DocC filenames
can contain colons, which GitHub's artifact uploader rejects as individual files.
On the supported Mac, extract `compiled-catalogs.tar.gz` into an empty directory
with `tar -xzf compiled-catalogs.tar.gz`, then open the desired `.doccarchive` in Xcode.
The manifest and receipt preserve file-level and archive-level digests.

## Publish and preview the website

The docs lane uses native `docc process-archive transform-for-static-hosting` to
prepare each qualified archive under `/Swift-JSON/<product>`. A shared landing
page links all eight references and guides. The build verifies product/guide routes,
local HTML links and assets, rejects private-path/credential markers and symlinks,
and records a file manifest. Only the generated site is packaged for Pages;
source graphs, command logs and private maintainer records are not website content.

Authored guide URLs retain `/documentation/documentation/<guide>/`. The native
DocC client requests `index/documentation/index.json` on those pages, while its
static export supplies `index/index.json`. The site builder copies each catalog's
native index byte for byte to that additional path. It preserves existing guide,
symbol and asset URLs and does not modify DocC's JavaScript. Qualification rejects
missing, stale or foreign-catalog indexes, missing indexed routes and guides absent
from the index. The Pages receipt records both index paths, their shared digest and
the covered guides for each product. Focused regression fixtures run inside the
native docs lane; run them separately with `python3 -B Scripts/test_documentation_site.py`.

Browser acceptance must also open a guide directly, confirm the sidebar has links
without a fetching error, follow a sidebar symbol link and return to a guide.
Repeat direct guide navigation for all eight catalogs and the five schema-example
guides. A successful article render or static HTML-link check alone does not prove
that the client fetched its navigator index.

The Native CI workflow uploads the exact static artifact. Its separate deployment
job runs only on `main`, after all native, safety and docs matrix jobs succeed.
Only that job receives `pages: write` and `id-token: write`. The `github-pages`
environment restricts deployments to `main`; action versions are pinned by commit.
PRs build and check the site but cannot deploy it. The deployment job performs no
Swift compilation or native qualification. See
[GitHub's custom Pages workflow documentation](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

For a browser preview, preserve the project base path with a local alias:

```sh
mkdir -p .build/handoff/pages/preview
ln -sfn ../site .build/handoff/pages/preview/Swift-JSON
python3 -m http.server 8771 --directory .build/handoff/pages/preview
```

Open `http://localhost:8771/Swift-JSON/`. The preview alias is local only and is
not included in the deployment artifact. `build-info.json` identifies the source
commit, native compiler/SDK and CI run; the site tracks the current `main`, without
claiming a tagged package release. Generated files remain ignored by Git.

## Write useful API comments

Use native Swift `///` comments: a concrete summary, semantics that affect callers,
named parameters, return meaning and relevant throws behavior. Explain admission,
limits, exactness, missing/null distinctions, provisional completion and ownership
at the API where they matter. Do not copy a function name into a placeholder summary.
Use checked DocC symbol links for related API and curate guides under Topics.
Document protocol conveniences honestly when they are unmetered.

Coverage includes authored public types, members, enum cases and methods added to
external types. Compiler-synthesized members and extension container nodes are
excluded: they have no independent authored declaration to document. Complete
coverage establishes presence and parameter coverage; semantic review and native
examples are still required for accuracy. The private regex target is excluded.

## Keep examples and evidence reproducible

README installation snippets are manifest fragments. The following Swift fences
are compiled in `Examples/Consumer/Sources/Consumer/READMEExamples.swift`, in order.
The array helper is also exercised with the consumer's one-byte chunk source. After
editing a fence, regenerate that source with `documentation_catalog.readme_examples`
and review the change; the docs lane rejects drift.

Run native and safety lanes when code changes; required branch checks also run on
public documentation PRs. Preserve published source/evidence identities and create
a distinct successor archive when source content changes. Performance evidence is
reused only when its measured implementation and workload remain applicable.

### Keep schema example guides executable

Every Swift fence in `Sources/JSONSchemaExamples/Documentation.docc/*.md` is counted,
hashed and synchronized with the separate public consumer. The current contract is
ten snippets across five guides, covering exact values/keys, offline definition
selection, deterministic replay, format/default policy, remaining work and explicit
search failure. The docs/native consumer qualifiers require both process completions
and preserve all original 15 consumer cases and two compiler negatives.

```sh
python3 -B Scripts/schema_example_documentation.py --write
python3 -B Scripts/verify_schema_example_documentation.py
swift run --package-path Examples/SchemaExamplesConsumer SchemaExamplesConsumer --documentation
```

Review the generated DocumentationExamples.swift diff after editing a guide. Missing,
extra, empty or foreign-import snippets and source drift fail qualification. The
`#sourceLocation` directives map compiler errors to the authored guide. The root
README has fourteen executable Swift fences in its separate seven-library consumer;
installation fragments remain manifest examples, checked by real package manifests.
Native DocC checks symbol links and the site verifies the new limits-guide route.
