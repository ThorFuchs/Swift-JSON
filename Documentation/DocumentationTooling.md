# Building and maintaining the DocC catalogs

Swift source comments are the API documentation authority. Native compiler symbol
graphs supply the declarations and links for four Swift DocC catalogs. Each catalog
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
consumer, and compiles all four DocC catalogs with warnings as errors. Zero public
symbols, missing comments, stale examples or a failed catalog fail the lane.

| Output | Purpose |
| --- | --- |
| `.build/handoff/docc/JSON.doccarchive` | JSON API and exact values/native coding guide |
| `.build/handoff/docc/JSONSchema.doccarchive` | Schema API and offline validation guide |
| `.build/handoff/docc/JSONStreaming.doccarchive` | Streaming API and completion/backpressure guide |
| `.build/handoff/docc/JSONPatch.doccarchive` | Patch API and choosing/applying patches guide |
| `.build/handoff/docc/symbols/` | Public compiler symbol graphs grouped by product |
| `.build/handoff/docc/coverage.json` | Counts and documentation-coverage failures |
| `.build/handoff/docc/receipt.json` | Commands, toolchain, counts, exits and diagnostics |
| `.build/handoff/docc/compiled-catalogs.tar.gz` | All four compiled catalogs with their exact native filenames |
| `.build/handoff/docc/compiled-catalogs.MANIFEST.sha256` | Independently verifiable hashes for every archived catalog file |

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
are versioned. A public documentation website has not been activated.

CI transports the compiled catalogs in a tar archive because native DocC filenames
can contain colons, which GitHub's artifact uploader rejects as individual files.
On the supported Mac, extract `compiled-catalogs.tar.gz` into an empty directory
with `tar -xzf compiled-catalogs.tar.gz`, then open the desired `.doccarchive` in Xcode.
The manifest and receipt preserve file-level and archive-level digests.

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
