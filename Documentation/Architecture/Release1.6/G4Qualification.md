# G4 native qualification

G4 extends G3 commit 3951b99bb0f690098cf8bef61ce872119e4835da on the
isolated `codex/1.6-schema-examples` branch. See the accepted
[G4 proposal boundary](G4Construction.md), [capabilities](Capabilities.json) and
[progress](Progress.json). G0-G3 history is preserved. G5-G8 and main's independent
repair integration remain open; this is not a release candidate.

## Actual outcomes

On macOS 27.0 arm64, Xcode 27.2 (27B5019j), Apple Swift 6.4
(swiftlang-6.4.0.34.1 clang-2100.3.34.1), selected SDK 27.2, language mode 6:

* `python3 -B Scripts/ci.py --lane schema-examples-advanced --output Artifacts/SchemaExamplesS3/G4/native-final`
  exited 0; all nine commands passed. Exact eight-product isolation and empty
  dependencies passed, with 79 Swift Testing functions each in Debug and Release.
* `python3 -B Scripts/ci.py --lane schema-examples-safety --output Artifacts/SchemaExamplesS3/G4/safety-final`
  exited 0; all three commands passed: 79 Release ASan functions, three TSan
  sharing functions with 32 concurrent invocations each, and strict-memory-safety
  compilation with warnings as errors. No unsafe conformance or compatibility
  flag was added.
* The actual public G4 consumer passed all ten additional required cases across
  two profiles/four seeds: 80 mandatory successes per process. It also exercised
  all eight may-fail cases: 32 certified calls from four cases, and 32 explicit
  incomplete-search calls from four cases, totaling 144 calls per process.
  Two separate processes matched exact values, outcomes, digests and successful
  accounting. Every success passed independent public native validation and a
  strict roundtrip. No value or successful work report was invented after error.
* All 44 schemas/155 fixture witness expectations received native verdict checks,
  including six negatives attached to the G3 trivial-proof cases. The preserved
  G3 consumer additionally passed 192 required combinations and two proofs in
  each process. The default consumer passed 15 cases twice and two public compiler
  negatives. Independent stdlib byte-format/SHA-256 vectors matched both profiles.
  Trusted implementation compiler probes accepted one positive and rejected eight
  copy/Sendable violations for the expected diagnostics, not missing imports.
* Harness acceptance/rejection mutations passed 26 cases; Testing event parser
  regressions passed 19. The capability ledger classifies all 59 compiled keyword
  cases exactly once, with referenced behavior functions verified to exist.
  Full release lanes still require 498 functions, 325 parameter invocations,
  18 sharing functions and all 49 baseline metric probes. Focused runs do not
  substitute for those later full release gates.

Commands explicitly selected Xcode and its SDK through DEVELOPER_DIR/SDKROOT;
there was no global toolchain switch. Native/safety receipts record G3 HEAD plus
captured G4 working-tree hashes. The final SourceEvidenceMap verifies complete
critical file sets/hashes against committed source. Only maintainer architecture/
progress prose can differ. The final clean-head docs receipt records actual DocC,
consumer and static-site outcomes for the final snapshot. Private receipts retain
all actual command arrays, exits, toolchain, source inputs and log/event hashes.
No controlled-performance or RSS measurement is claimed on this shared host.

## Honest outcomes and semantic authority

The may-fail cases oneof-overlap, recursive-tree, dynamic-ref and
external-offline-ref produced native-certified witnesses. The dynamic case omits
an optional child; constructive dynamic navigation is not qualified. The
conflicting-allof and not-string cases returned candidateConstruction unsupported;
unfulfillable-unique-enum and oneof-overlap-limited exhausted 16 attempts. The latter
has valid fixture witnesses: exhaustion is explicitly not an unsatisfiability
proof. No operational error/cancellation can count as accepted incompleteness.

The new contains hints choose minimum matching positions beside each conjunct's
prefix/items constraints. Native validation alone establishes all matches/maxima
and evaluated locations. The anchored ASCII scanner proposes printable literals,
escaped punctuation, single range classes and exact repeats. It never matches
strings or replaces native regex. General inversion, disjoint contains partitions,
triggered dependency/key synthesis, dynamic scope and satisfiability remain incomplete.
Optional omission satisfying a fixture does not imply broader constructive support.

The 18 added tests cover the full G4 fixture family, ten unsupported grammar forms,
Unicode corpus identity, pattern conjunctions, contains defaults/zero/inactive
siblings, prefix/unique/unevaluated composition, surplus-match failure, cardinality
and scanner work caps, malformed/native regex failures, cancellation latching,
conditional false-verdict work, qualified external anchors/base transitions,
missing resources, reached dynamic scope, recursive depth bounds and concurrency.
The conditional test proves the exact sum of rejected and accepted native evaluation
work, success at that cumulative ceiling and failure one unit below it.
All helpers reuse the one generation ledger; no nested meter or work reset is added.

Algorithm becomes s3-candidates-v4; trace grammar stays swift-json-example-trace-v2
and binds the new algorithm. Source/corpus/policy v1 and SplitMix64 v1 are unchanged.
Historical G3 vectors/archives are retained. The original/amended fixture bytes
and all classifications are unchanged; the manifest adds explicit G4 ID groups.
The amended SHA-256 remains
5b3e6e40e83439a810d0eb7ac412ce158a4e582f36b9d36d6e313c159654ddd3.

## Regression and remaining gates

A 654-file equality proof supports reuse of G2's separately passed schema command:
69 functions, 12 parameter invocations, 2300 pinned evaluated cases and 37 separate
policy exclusions. That old aggregate failed a stale consumer marker and is never
relabeled passed. New S3 fixtures are separately qualified and are not read by
those existing tests. Raw selected-command receipt/log/event bytes accompany the
G4 return. JSON/JSONSchema/regex production source and Package.swift are unchanged.
No fresh external-oracle, Linux/WASI/mobile, full-package or performance pass is
inferred. Logical retention is not RSS; caller work is not an instruction quota.

Main's independent 1.5.1 repair source and discovery counts must be reconciled
before final release qualification. No sibling source, remote branch, PR, merge,
tag, release, deployment or external message was changed in this milestone.
