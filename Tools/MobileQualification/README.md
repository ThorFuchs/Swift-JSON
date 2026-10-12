# Public Apple runtime and SwiftData example

This separate package imports all four public products and SwiftData. It adds no
SwiftData dependency to the root package. Native host requirements remain Swift
6.4/language 6/macOS and SDK 27; the mobile minima are iOS/iPadOS 27.

```sh
swift test --package-path Tools/MobileQualification
swift run -c release --package-path Tools/MobileQualification MobileQualification
python3 Scripts/qualify_mobile_runtime.py --output .build/ci/mobile-runtime/receipt.json
```

Three Swift Testing functions check exact public APIs/fixtures, stream/sink
completion/cancellation and disk persistence. Eight frozen Version 1 fixtures
preserve scalar bytes, exact decimals beyond UInt64/Decimal, order and lexemes.
The model uses explicit nonoptional/optional `@Attribute(.codable)` payloads and
independent applicationSchemaVersion. Query/sort ordinary name fields; embedded
JSON predicates and cloud synchronization are not claimed.

Each disk phase runs in a separate exited process: save, reopen/check/update,
reopen/check updated data. All use one disk URL. This ensures prior models,
contexts, containers and SDK-retained references are gone. A first simulator
release probe found SDK container retention beyond lexical scope; its weak-reference
failure remains evidence. Mac test-bundle layouts locate the actual built runtime
within five ancestor checks. The simulator controller creates/deletes only its own
isolated iPhone/iPad devices and records exact outcomes and source hashes.

SDK compilation, simulator runtime and physical-device performance are distinct
claims. The [1.1 qualification policy](../../Documentation/Architecture/Release1.1/QualificationPolicy.json)
accepts iPad SDK/simulator behavior and disk persistence for this release.
Physical iPad checks are deferred and nonblocking; physical iPhone checks remain
required. No physical iPad performance, memory or energy claim follows.
