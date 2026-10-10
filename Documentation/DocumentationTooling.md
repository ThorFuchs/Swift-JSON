# Building and maintaining the documentation

Swift source comments are the API documentation authority. DocC compiles native
Swift declarations and links into four product references. The Doxygen catalog
uses those same compiler symbol graphs to provide a searchable HTML/XML inventory
with Swift signatures, inline prose and source links. The catalog emits escaped Doxygen documentation pages to avoid its Swift-unaware
Markdown lexer. Doxygen does not parse Swift natively; the catalog does not invent C++ bindings or duplicate a hand-written API.
See the [official Doxygen language list](https://www.doxygen.nl/manual/starting.html)
and [Swift DocC documentation](https://www.swift.org/documentation/docc/).

## Build locally

Use macOS/SDK 27+, Swift compiler/tools 6.4+ and Swift language mode 6. Select the
supported Xcode through DEVELOPER_DIR if it is not the system default. Python 3
uses only its standard library. Install **Doxygen 1.18.0** as a development tool
outside the package; the docs lane verifies that exact version. No Graphviz or
root-package dependency is required.

```sh
python3 Scripts/ci.py --lane docs
```

The lane records native preflight, extracts fresh public symbol graphs, requires
summaries and named-parameter documentation on every authored public declaration,
checks README Swift fences against their executable consumer source, runs that
consumer, compiles all four DocC catalogs with warnings as errors, and builds
Doxygen with warnings as errors. It verifies the emitted XML page inventory against
every extracted declaration, so an empty or partial catalog fails.

Outputs:

| Output | Purpose |
| --- | --- |
| `.build/handoff/docc/JSON.doccarchive` | JSON API and guides |
| `.build/handoff/docc/JSONSchema.doccarchive` | Schema API and guides |
| `.build/handoff/docc/JSONStreaming.doccarchive` | Streaming API and guides |
| `.build/handoff/docc/JSONPatch.doccarchive` | Patch API and guides |
| `.build/handoff/docc/coverage.json` | Counts and documentation-coverage failures |
| `.build/handoff/docc/receipt.json` | Commands, toolchain, counts, exits and diagnostics |
| `.build/handoff/doxygen/site/html/index.html` | Searchable local public API catalog |
| `.build/handoff/doxygen/site/xml/index.xml` | Verified machine-readable page inventory |
| `.build/handoff/doxygen/symbols.json` | Relative source paths, actual signatures and comment hashes |

Open a DocC archive in Xcode, or serve its generated web content with your chosen
local static server. Open the Doxygen index in a browser. Generated output is
ignored and uploaded as a Native CI artifact; source catalogs and build scripts
are versioned. Hosted artifact retention is 30 days. The repository does not yet
publish a documentation website; no hosted URL is implied.

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

## Keep examples and tooling reproducible

README installation snippets are manifest fragments. The following Swift fences
are compiled in `Examples/Consumer/Sources/Consumer/READMEExamples.swift`, in order.
The array helper is also exercised with the consumer's one-byte chunk source. After
editing a fence, regenerate that source with `documentation_catalog.readme_examples`
and review the change; the docs lane rejects drift.

The Doxygen config lives in `Documentation/Doxygen/Doxyfile`. A tool upgrade needs
an explicit version change, inspection of new warnings and a native catalog rebuild.
CI installs the available Homebrew formula and the build rejects a different version;
if the formula advances, update or provide the reviewed version rather than accepting
a silent tool change. Doxygen is GPL-2.0-only build tooling, not linked or bundled
into the Apache-2.0 library. No Doxygen executable is shipped in source archives.

Run native and safety lanes when code changes; required branch checks also run on
public documentation PRs. Preserve published source/evidence identities and create
a distinct successor archive when source content changes. Performance evidence is
reused only when its measured implementation and workload remain applicable.
