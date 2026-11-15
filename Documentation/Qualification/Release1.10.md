# 1.10.0 qualification

Status: **prepared, not published.** The maintainer approved the 1.9.1–2.0.0
release train on 2026-11-12 (see the [roadmap](../ReleaseRoadmap.md)) and chose
the digest design of the envelope on 2026-11-15. Approval of the train is not
approval to tag or publish. A tag and GitHub release need an explicit maintainer
instruction, and the release qualification asset must then record the exact
release commit, tree and lane outcomes.

## Scope

1.10.0 adds to published 1.9.0 (`f2a0d12d`):

| Area | Addition | PR |
| --- | --- | --- |
| JSON | `JSONCanonicalWriter` (RFC 8785) with `NumberPolicy` | #95 |
| JSONPatch | `JSONPatch.difference(from:to:options:)`, `differenceWithReport` | #96 |
| JSONHTML | `JSONHTMLRenderer.renderDifference(from:to:)`, `renderDifferenceWithReport` | #97 |
| JSON | Package `JSONDifferenceWalker` shared by JSONPatch and JSONHTML | #97 |
| JSONStreaming | `JSONTextSequence`, `JSONTextSequenceOptions`, `JSONTextSequenceWriter` (RFC 7464) | #98 |
| JSON | `JSONEnvelope`, `JSONEnvelopeOptions`, `JSONEnvelopeEncoding`, `JSONEnvelopeFailure` | #99 |

The roadmap update is #94. Maintenance collected as 1.9.1 hygiene (the
`platform-floor` lane, the CLI identity without DocC catalogs, developer kit
0.2.0) ships in 1.10.0, because 1.9.1 was not published.

No product, product dependency or root package dependency is added. JSONHTML
still depends on JSON only. Platforms and toolchain requirements are unchanged.

## API compatibility

`swift package diagnose-api-breaking-changes 1.9.0` on the preparation branch
(based on `8090589`), with Swift 6.4.2, exited 1 with two findings, both in JSON:

- `JSONNumber.binaryConversionText(meter:)` → `binaryConversionText(meter:chargesOutput:)`
- `JSONNumber.doubleValue(policy:meter:)` → `doubleValue(policy:meter:chargesOutput:)`

Both are `package` declarations, not public API. #95 gave them a defaulted
parameter so canonical number spelling does not charge output bytes twice. As
with the single package-only finding for 1.9.0, these are false positives for
consumers. The eleven other library modules report no breaking change. The
public change is additive.

## Format commitments

- `JSONEnvelope` format version 1 is fixed: the six member names, the marker
  `swift-json-envelope`, SHA-256 over the RFC 8785 payload bytes and the
  `sha256:` lowercase hexadecimal digest. Tests pin bytes and digests computed
  independently with Python `hashlib`.
- `JSONCanonicalWriter` output is pinned by the RFC 8785 Appendix B number
  vectors, the RFC's sample document and its key-sorting example.
- The patch difference is deterministic but not minimal. Its operation order is
  part of the tested behavior (paired changes, then removals from the highest
  index, then additions), not a compatibility promise of minimality.

## Lane results

Toolchain: Swift 6.4.2 (`swiftlang-6.4.2.1.9`) via swiftly, Xcode 27.2 macOS SDK,
language mode 6, run with `python3 Scripts/ci.py --lane <lane>`.

Each feature PR passed the local `docs` (4 commands) and `native` (62 commands)
lanes with every command exiting 0, and all 20 GitHub checks (Native, Native
execution, Linux execution on x86_64 and arm64, platform-floor, composition,
safety, archive) before merging. On #98 the first local docs run failed on a
cross-module DocC link; the fix changed a doc comment only and the docs lane then
passed. Native for #98 ran on the commit before that fix; GitHub CI ran on the
merged state.

The `wasm` lane was not run locally for 1.10. The release commit needs its own
exact CI receipts and a WASI run before tagging.

## Performance gate: open

No timing, allocation, RSS or throughput measurement was made for 1.10.0, and
the release claims no performance improvement or parity. The 1.9.0 exception
covered 1.9.0 only. Before tagging, the maintainer decides whether to measure the
controlled-performance gate or record a new explicit exception for 1.10.0.

## Not yet done

- Tag, GitHub release and qualification asset (maintainer instruction required).
- Developer kit update to 1.10.0: the kit pins the exact published commit and
  tree, so it follows the tag.
