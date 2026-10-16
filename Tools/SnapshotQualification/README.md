# Public snapshot consumer

This independent SwiftPM package imports only public JSON, JSONNavigation and
JSONInspection APIs. Run `swift run -c release --package-path
Tools/SnapshotQualification SnapshotConsumer` on a qualified Swift 6.4 platform.
Its fourteen named checks exercise exact source-bound metadata and separate
bounded lookups, including negative capacity, bounds and quota cases. It does
not establish a release or physical-device qualification. The associated
`Scripts/qualify_snapshot.py` executes all three DocC examples and full-codegen
external-access rejections, with source-bound receipts.
