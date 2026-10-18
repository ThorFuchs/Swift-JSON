# Version and product selection

Kit 0.1.0 validates exactly library 1.6.1, commit
`e431f157ececc0cf3d061192420b0e36a9062f83`, tree
`9d4c3969fad53f4734265ff585dc482ebea943d3`.
The repository is https://github.com/ThorFuchs/Swift-JSON.git.
Inspect Package.swift and Package.resolved as text before selecting a recipe.
Preserve an existing range, tag or revision unless its change was requested.

For a new reproducible consumer the exact requirement is `exact: "1.6.1"`.
The [executable manifest](../assets/consumer/Package.swift) demonstrates that
requirement, language mode 6 and all eight product spellings. Add only needed
products to a real target. The acceptance consumer deliberately imports all eight.

JSON is the core. Schema depends on JSON and a private regex runtime. Examples
depends on JSON and Schema. Streaming, Patch, HTML, Bridges and Navigation depend
on JSON. There are no external root SwiftPM dependencies. Private runtimes are
not public products and are never imports for an independent consumer.

The [stable release](https://github.com/ThorFuchs/Swift-JSON/releases/tag/1.6.1)
has eight library DocC catalogs plus swift-json. Its DocC asset matches the tag.
The [development website](https://thorfuchs.github.io/Swift-JSON/) tracks main,
currently unreleased 1.7.0-dev, and includes JSONInspection as a ninth library.
Do not substitute its Inspection APIs into a stable recipe. Navigation observes
typed physical/virtual paths and coverage; it does not infer table columns.

Swift tools/compiler 6.4+ and language mode 6 remain required. Native Apple
qualification uses macOS/SDK 27+; iOS/iPadOS minimum is 27. Library Linux scope
is Swift 6.4+ on 64-bit Ubuntu 24.04/glibc. Full-language wasm32-unknown-wasip1
has its own qualified core scope; it is not browser, Embedded Swift or full CLI
support. Kit recipe execution on one platform does not qualify every host.

An unfamiliar version/revision is **unverified by this kit**, not automatically
incompatible. Read matching installed source/public declarations and compile the
adaptation. Keep that evidence distinct from the exact 1.6.1 recipe result.
