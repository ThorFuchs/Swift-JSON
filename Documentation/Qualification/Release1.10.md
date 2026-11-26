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

On the preparation commit `deb16f5` (CLI version 1.10.0), `docs` passed 4 of 4
commands. The first `native` run failed one command:
`Scripts/qualify_cli_limits.py` hit its 30-second subprocess timeout on a
`swift-json query` call while the host load average was about 56. Run alone,
that call took 9 ms and the script passed 33 of 33 observations. A full `native`
rerun on the same commit (load average falling from about 22) passed 62 of 62
commands with exit 0. The failure is recorded here rather than omitted.

The `wasm` lane was not run locally for 1.10. The release commit needs its own
exact CI receipts and a WASI run before tagging.

## Performance gate: maintainer exception

On 2026-11-16 the maintainer chose to **record an exception** for the 1.10.0
controlled-performance gate instead of measuring it. The gate is
`excepted_explicitly`, not passed.

- No timing, allocation, RSS or throughput comparison against 1.9.0 was measured
  for 1.10.0. The release claims no performance improvement or parity, including
  for the canonical writer, the envelope, the difference walker and text
  sequences.
- Finite-budget, memory-safety and logical-retention evidence are not performance
  data and are not presented as such.
- The 1.9.0 exception, the earlier 1.7.0 P4 allocation waiver and partial
  profiles stay historical. This exception does not convert them into passes.
- The exception covers 1.10.0 only. It does not carry over to later releases.

## Not yet done

- Tag, GitHub release and qualification asset (maintainer instruction required).
- Developer kit update to 1.10.0: the kit pins the exact published commit and
  tree, so it follows the tag.

## 2026-11-26 — WASI release gate: RED, fixed-width version candidate

The full release WASI attempt at `c2e4aea7cf63bdf8236c22cc9ba0c6a3abeb5201`, tree
`2e483c24b4efb3e7b7f73b2ce2ef76bea712a539`, did not pass.
The exact source was still the unreleased 1.10.0 preparation commit.
The source-bound return archive (86,175 bytes) has SHA-256
`95c6c09f0fcf6ef7c9a233ac70a2353352224d8f23e2bc8ccabbf6377d5820fa`.
The source-input manifest hash
`8cce0bbd3ebd2ed9a9f026bd469e1e0ef2f549d35d5bb254a8db88d0f68e7b9e`
recomputes over all 1,580 entries, and source_inputs_unchanged is true.
All eight referenced command-log SHA-256 values reconcile. Private
absolute host paths are not copied to this public record.

Actual ARM64 macOS 27.3; Swift.org 6.4.2, matching full-language WASI
SDK, WasmKit 0.3.1, Node 26.5.0, Xcode 27.2. Public inventory
and evaluated root manifest passed. Five of the six WASI subprocesses
passed; root-build-debug exited 1 while emitting the JSON module:
`JSONEnvelope.swift:30:56: integer literal '9007199254740991' overflows when stored into 'Int'`.
No WASI runtime tests or Release build occurred in this attempt.
The earlier 21 successful GitHub checks remain bound to the original
commit and do not qualify any corrected successor.

Candidate correction: the unpublished JSONEnvelope schema-version
API uses Int64 consistently (range, stored property, initializer and
exact integer decoding). The fixed formatVersion value, accepted wire
range 1...2^53-1, six members, canonical bytes, payload digest and
operational-error distinctions remain unchanged. Do not cap the range
at Int.max, clamp, or round metadata. This is an API adjustment to the
unpublished 1.10.0 surface, not a change to a previously published API.
Callers of the preparation branch using typed Int variables will need
explicit Int64 conversion. The existing generic JSONNumber constructor
and checked fixed-width integer decoder are reused.

Extend existing EnvelopeTests with six pinned version roundtrips
(1, 2^31-1, 2^31, 2^32-1, 2^32, 2^53-1), exact canonical bytes and
unchanged digest; explicit Int64 bounds, negative and overflow
rejections, and large formatVersion rejection. Existing five
test functions remain; no discovery exclusions or decreased coverage.
DocC, release notes and changelog describe the platform-independent type.

Editing-host supplemental probe: Swift 6.2.1 Linux Embedded
wasm32-unknown-none-wasm, standalone minimal range declaration.
Old ClosedRange<Int> fails with the observed overflow; corrected
ClosedRange<Int64> and stored Int64 initializer compile to a WASM
object. This is not a full-language WASI package build or a runtime
qualification. Independently verify six accepted values are exactly
representable in binary64 and the pinned payload SHA-256. Regenerate
CLI source identity from the ordered 243 input-file SHA-256 values
in the source-bound failed receipt (original identity
99a750404f5c4af53abe83fb52194c296a09e9e69387be2d4a3984b09551e327
reproduces exactly); replace only the changed non-DocC source hash.
New expected identity:
7e58faad4a37141b4fabc6bba4d684a9f6d5ea0d574d9cae92ea8d01da98a81d.
The normal generator --check on the clean corrected checkout remains
required. Native SDK typecheck and all actual envelope behavior tests
on the corrected package are pending.

Next: run complete WASI lane on the corrected source, preserve RED
evidence, require native, Linux, safety, platform-floor, composition,
docs and archive evidence on the exact final release commit, review
the applicability of the documented 1.10-only performance exception
to that final source, verify public API and assets, then tag/publish
only the qualified commit. No release or product admission performed.
