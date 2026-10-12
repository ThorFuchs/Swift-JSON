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

The public runtime harness now executes exact numeric/scalar conversion, offline
plans/native regex, integrity-checked packaged schemas, Patch/Merge Patch, payload
fixtures, stream completion/terminal pulls, awaited sinks and cancellation. Mac
Swift Testing and isolated iPhone/iPad iOS 27 simulators execute three-process
disk save/reopen/update checks. The physical iPhone is connected with iOS 27.2
and developer mode enabled; signing/runtime/performance are separately qualified.
The original R5 scope required a physical iPad. The maintainer's 2026-10-12
[qualification policy](QualificationPolicy.json) now accepts the executed iPad
simulator public/disk checks for 1.1.0 and defers physical iPad testing without
blocking release preparation. Physical iPhone evidence remains required.

A development-signed qualification wrapper now executes the exact public harness
on physical iPhone14ProMax/iOS27.2. Public smoke, eight fixtures, three separate app
processes for disk save/reopen/update and nine release measurements are materialized
as run-ID-bound files retrieved from its own container. The temporary app is
removed afterward. Core consumers/source remain independent of UIKit/signing;
no public UI product or server semantics are added. Physical iPad runtime,
performance, memory and energy remain untested. Simulator evidence qualifies the
agreed 1.1 iPadOS acceptance scope and makes no physical-device measurement claim.
