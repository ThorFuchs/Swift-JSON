# Apple mobile qualification

The 1.1 feature manifest declares macOS 27 and iOS 27 minimum deployment versions.
iPadOS uses the iOS declaration. The native host still requires macOS/SDK 27 and
Swift tools/compiler 6.4, language mode 6. SDK compilation alone does not qualify
mobile runtime or physical-device behavior.

The schema resource rule copies `Resources/Draft2020-12` as `Draft2020-12` at the
resource root. It retains every pinned schema byte and provenance/license record.
The loader uses the same path relative to `Bundle.module.resourceURL` on each
platform. A flat iOS bundle with a root directory literally named `Resources` and
a root Info.plist failed native codesign. A temporary-copy experiment reproduced
the failure and signed successfully after removing that extra directory level.
No signing bypass, custom plist, resolver or dependency is introduced.

The mobile probe builds a public consumer of all four products, the private regex
implementation and packaged schemas with the default Swift Build engine for both
iPhoneOS and iPhoneSimulator. Required subsequent evidence includes iPhone/iPad
simulator behavior/cancellation, physical-device smoke and measurements, and real
disk-backed SwiftData teardown/reopen using the exact payload. Keep every not-run
row explicit; this document does not certify those later runs.
