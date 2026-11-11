# 1.9.0 candidate qualification

Status: prepared 1.9.0 source on `main` after 1.8.0 (`66718f1`). The maintainer
gave explicit tag and publication approval on 2026-11-10. PR #83 (1.8.1) was closed
without release; the platform floor ships in 1.9.0 only.

## Scope

1.9.0 adds to 1.8.0:

- The read-only configured store, ordered value batches, exact-ID lookup and
  complete bounded BFS follow in JSONInspection. The maintainer admitted these
  as public API on 2026-11-10 (see [Release1.8.md](Release1.8.md)).
- Refinements made before release: typed `JSONStoreFailurePhase` and
  `JSONStoreCapacity`, an `Equatable` `JSONStoreFailure`, integer record IDs
  (`JSONStoreIDKind`, `JSONStoreRecordID`), `collectionIndex(named:)`,
  `.strict(marker:)` without `validateTargets`, and
  `JSONInspectionBatch.optionalValues(at:maximumRequests:)`.
- `JSONTransformProgram.selectIndices(in:bindings:limits:source:)`.
- Transform source definitions, compile reports and indexed selection scopes.
- Composition accounting fixes salvaged from PR #63.
- Apple deployment minimums lowered to macOS 15 and iOS 18 (below).

The configured store's public API is new in 1.9.0, so its 1.9-only refinements
do not break any published API.

## Platform floor

The deployment minimums move from macOS/iOS 27 to **macOS 15 and iOS 18**, matching
Swift-MCP-Server-Core, which depends on Swift-JSON and supports macOS 15, iOS 18
and Linux. The change was first prepared as the 1.8.1 candidate PR #83 on
`release/1.8.x`, and the same commits are carried onto 1.9.

- Development still needs Swift 6.4 and the macOS 27 SDK (Xcode 27).
- JSONHTML's WebKit `WebPage` PDF backend is `@available(macOS 26, iOS 26, *)`.
  Before 26, PDF preparation throws the existing
  `JSONPDFFailure.backendUnavailable`.
- Before macOS/iOS 27, the Markdown transfer type uses the system-declared
  `net.daringfireball.markdown` identifier.
- Linux and WASI are unchanged.

Evidence is compile-time only, on `49d1c93` with Swift 6.4.2:

- `swift build --build-tests` against the macOS 15 floor with the macOS 27.2 SDK
  built every product and test target (exit 0).
- `swift build --target <library> --triple arm64-apple-ios18.0` with the iOS 27.2
  SDK built all twelve library targets (exit 0 each).

No test has run on an actual macOS 15–26 or iOS 18 system or simulator, and this
record claims no such runtime pass. CI checks the manifest minimums but does not
build for iOS. After the release, the `platform-floor` lane (1.9.1 hygiene) added
this compile-time evidence to CI; it still runs nothing on an older OS.

## Performance gate: maintainer exception

On 2026-11-10 the maintainer chose to **record an exception** for the 1.9.0
controlled-performance gate instead of measuring it. The gate is
`excepted_explicitly`, not passed.

- No timing, allocation, RSS or throughput comparison against 1.8.0 was measured
  for 1.9.0. The release claims no performance improvement or parity.
- Finite-budget, memory-safety and logical-retention evidence are not performance
  data and are not presented as such.
- The earlier 1.7.0 P4 allocation waiver, loaded-host timings and partial profiles
  stay historical. This exception does not convert them into passes.
- The exception covers 1.9.0 only. It does not carry over to later releases.

## Local lane results

Toolchain: Swift 6.4.2 (`swiftlang-6.4.2.1.9`) via swiftly, Xcode 27.2 macOS SDK
27.2, language mode 6, run with `python3 Scripts/ci.py --lane <lane>`.

Before the platform change, on `3284782` (docs, structural-workflows, inspection,
native) and `2f83b70` (store, wasm), all lanes passed and every command exited 0:
docs 2, structural-workflows 9, store 8, inspection 19, native 62, wasm 2
commands. `2f83b70`→`3284782` changed guide wording and the CLI identity only.

The platform-floor commits are rechecked by the GitHub CI lanes on the PR. A later
candidate commit needs its own exact CI receipts before tagging.
