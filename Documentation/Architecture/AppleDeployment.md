# Apple deployment candidate

This is an **unreleased** deployment change based on 1.6.0. The published 1.6.0
tag retains macOS/iOS/iPadOS 27 minimums. No released tag or source asset is changed.

| Capability | Candidate deployment boundary |
| --- | --- |
| Eight public libraries, including pure HTML/RTF and exact persistence | macOS 14 / iOS 17 / iPadOS 17 |
| swift-json executable | macOS 14; mobile CLI hosting is not qualified |
| SDK programmatic Transferable import/export convenience methods | macOS 15.2 / iOS 18.2 / iPadOS 18.2 |
| Explicit native PDF preparation | macOS 26 / iOS 26 / iPadOS 26 |
| SwiftData `@Attribute(.codable)` example | macOS 27 / iOS 27 / iPadOS 27 |
| Native qualification tools/host | Swift tools/compiler 6.4+, language 6, macOS/SDK 27+ |

iPadOS shares the SwiftPM `.iOS("17.0")` declaration. These are selected candidate
minimums, not a claim that no older OS could compile any subset. Build-tool host,
SDK version and deployment version are separate: a current SDK can produce a
binary for an older deployment target. Compilation on a new OS does not establish
behavior on the older OS. Swift's [platform support](https://www.swift.org/platform-support/)
describes that distinction. The inspected [Vapor 5 beta.4 manifest](https://github.com/vapor/vapor/blob/5.0.0-beta.4/Package.swift)
declares Swift 6.4 and macOS/iOS 26.2; no Vapor dependency is introduced here.

## Actual availability constraints

The unchanged 1.6.0 source fails a macOS 26.2 compile because `UTType.markdown` is
available only on OS 27. Its documented identifier is `net.daringfireball.markdown`,
conforming to UTF-8 plain text. The candidate declares that exact imported type;
Apple's convenience constant remains the independent OS 27 test oracle. Export
bytes, type identity, selection and filename tests retain their existing assertions.

WebKit's `WebPage` requires OS 26. Its existing backend, private job state and
public PDF methods receive precise availability annotations. The cancellation
mutex stays inside that boundary; no older lock implementation, unchecked Sendable
annotation, alternate renderer or unbounded fallback is added. Earlier applications
can use the pure exports and guard native PDF calls with `if #available`.

The `.codable` SwiftData attribute really requires OS 27 in the inspected SDK.
`Tools/MobileQualification` and its disk-backed example keep their existing minimums.
The core `JSONCodablePayload` has no SwiftData import or OS 27 dependency. Int128
behavior tests retain their actual macOS 15/iOS 18 type availability; all their
assertions still run on the native qualification host.

Apple's programmatic `Transferable` import/export discovery and byte helpers
require macOS 15.2/iOS 18.2. Their two behavior tests carry that SDK availability;
the conformance and NSItemProvider tests are not raised to that floor. Test-only
cancellation/progress locks use OSAllocatedUnfairLock on Apple so the three owned
work/regex assertions remain runnable at the declared candidate minimum; Linux
retains its existing synchronization implementation.

## Qualification and release gate

Run `python3 Scripts/ci.py --lane apple-deployment`. The same check is appended to
the full native lane. It writes actual command exits, compiler diagnostics, source
and public-consumer hashes, Mach-O load commands and logs. The finite matrix is:

- Three real public consumers of all eight libraries, built for macOS 14, iPhoneOS
  17 and iPhoneSimulator 17. Their source is copied from the existing compiled
  examples, not replaced by semantic shims.
- Three consumer executables per build, each with the expected minimum deployment
  load command, all eight library modules/objects and nine packaged meta-schemas.
- Execute all three consumers on the actual Mac host. SchemaExamples retains its
  15 cases, Navigation its 18 and the general consumer its established assertions.
- Six PDF compiler cases: unguarded macOS 14/15 and iOS 17 calls must fail for the
  method's OS 26 availability; guarded earlier-OS and direct macOS 26.2 calls pass.
- Two real public-payload SwiftData cases: OS 27 succeeds; macOS 26.2 rejects the
  attribute for its actual OS 27 availability.

Existing Native, safety, docs, exact discovery/cardinality checks and all 49 finite
metric probes remain required. The empty dependency graph, nine public products,
strict semantics and Linux/WASI scope remain unchanged. Native preflight is not
lowered to turn a missing qualification host into a pass.

Older macOS 14/15/26.2 and iOS/iPadOS 17 runtimes must receive explicit execution
acceptance before the corresponding minimum is advertised as release-qualified.
The available host and simulator can exercise newer-OS behavior only. ABI/load
command checks and successful SDK builds are evidence of compilation and linking,
not substitute device/runtime results. Until those gates close, this branch is a
reviewable compatibility candidate and the released minimum remains OS 27.

Native/safety/docs receipts and any unchanged-source Linux/WASI evidence must retain
their actual source identity. Published 1.6.0 evidence remains historical; it cannot
be relabelled as a new run against this candidate. No platform release, tag or
publication is performed by this qualification tool.

## Separate runtime execution

`python3 Scripts/ci.py --lane apple-runtime-build` prepares a manifest-backed
ARM64 consumer bundle on the unchanged native qualification baseline. Three
existing public consumers exercise all eight libraries, including 15 schema
example and 18 navigation cases. A fourth program executes eight pinned exact
payload fixtures in three separate processes: save, reopen/update, verify update.
The on-disk binary property-list envelope uses the public JSONCodablePayload;
it does not claim SwiftData `.codable` support on older systems. The OS 27
SwiftData tests remain independently required.

The producer records the source manifest, toolchain, command exits, binary and
resource hashes, minimum load commands and copied Swift support libraries. A
relocated macOS run checks the exported bytes. Runtime jobs verify the complete
bundle and its source manifest before execution; artifact transport restores
executable permissions without modifying bytes. Neither an SDK cross-build nor
an omitted consumer can become a runtime pass.

The separate `Apple Runtime Compatibility` workflow runs these exact binaries on
the observed macOS 14 and 15 hosted images, a supplementary rolling macOS 26
image, and both an iPhone and an iPad on an available iOS 17 simulator. Receipts
retain actual OS/build and simulator identities. A rolling macOS 26 result does
**not** close the exact macOS 26.2 gate. An available 26.2 host can run:

```sh
python3 Scripts/apple_runtime.py macos --bundle PATH_TO_VERIFIED_BUNDLE \
  --output Artifacts/macOS26.2-runtime --expected-os 26.2
```

This runtime-only execution needs no Swift compiler on the destination. It
supplements the native Swift Testing, safety, conformance, documentation and
archive lanes; it does not reclassify those compiler/SDK requirements. The
runtime scope is a public-consumer and disk-envelope acceptance matrix, not a
claim that the entire native Swift Testing suite ran on every older OS.

The first actual macOS 14/15 runs exposed a schema-reference compatibility
failure despite successful minimum-target builds: the general consumer passed,
but schema examples raised an operational `missingResource`. Fragment-only and
empty references now inherit the complete base path/query with a finite metered
RFC 3986 construction, including opaque URNs. Platform Foundation resolution is
recorded by the runtime probe beside six explicit identity vectors. Existing
Swift Testing URI and recursive-reference cases add query, encoded fragment,
positive and ordinary-invalid instances; no original assertion is removed.
All schema tests run before producing the runtime bundle. The initial failing
receipts remain distinct from subsequent qualification.

Hosted image versions are observed at execution. macOS 14 hosted runners are
[scheduled for retirement](https://github.com/actions/runner-images/issues/13518);
their availability is not a permanent support guarantee. The verified bundle
and explicit runtime command also support a separately supplied older Mac.
