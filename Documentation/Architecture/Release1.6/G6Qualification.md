# G6 native documentation qualification

G6 extends G5 commit 30cf344c674a7514db2a578397ade642c0ab942e on the isolated
`codex/1.6-schema-examples` branch. G0-G5 history/archives remain intact. The
[current API](API.md), [all 49 metric scopes](SchemaExamplesLimits.md) and
[documentation contract](G6Documentation.md) govern the current descriptions.
This closes the native G6 increment, not G7/G8 or a 1.6 release candidate.

## Native outcomes

macOS 27.0 arm64, Xcode 27.2 (27B5019j), Apple Swift 6.4
(swiftlang-6.4.0.34.1 clang-2100.3.34.1), SDK 27.2, language mode 6.
Commands explicitly select DEVELOPER_DIR/SDKROOT; no global toolchain changes.

* `python3 -B Scripts/ci.py --lane schema-examples-advanced --output Artifacts/SchemaExamplesS3/G6/native-final`
  exited 0; all nine commands passed, including 96 Debug and 96 Release generator
  Swift Testing functions, exact eight-product/empty-dependency checks, one ownership
  positive/eight negatives and preserved public/fixture consumers.
* `python3 -B Scripts/ci.py --lane schema-examples-safety --output Artifacts/SchemaExamplesS3/G6/safety-final`
  exited 0; all three commands passed: 96 Release ASan functions, four TSan sharing
  functions, strict-memory-safety compilation with warnings as errors.
* Every Swift block in all five S3 guides is synchronized with its separate public
  consumer: ten snippets execute in two processes, retaining all 15 original cases,
  two public compiler negatives and independent process/transport vectors. The new
  README example compiles in the general seven-library consumer with fourteen fences.
* G3 repeated 192 required certifications/two proofs per process; G4 repeated 144
  calls per process (112 certified, 32 explicit incomplete). All 44 schemas/155 native
  witness expectations were checked. Policy exclusions, incomplete search and
  operational errors are not successes. No failure value/report was fabricated.
* Documentation harness passed eleven mutations and exact 49-metric classification;
  CI harness passed 26 mutations, and the event parser passed 19 regressions. Exact
  96-generator/515-root/325-parameter/19-sharing and all 49 cap requirements remain.

The clean-head docs receipt records actual native symbol graphs, all seven DocC
catalogs with warnings as errors, authored declaration/parameter coverage, compiled
README and public guide consumers, and static-site routes for all five S3 guides.
SourceEvidenceMap binds native/safety critical hashes and exact committed DocC inputs.
Private materialized receipts retain commands, exits, source hashes and log/events.

## API, defaults and source compatibility

All 181 production Swift files match G5 after removing only documentation-comment
lines; only Corpus, Generator and Options comment files differ in exact bytes. Root
Package.swift and every existing test/fixture match G5 byte-for-byte. The native
public compiler graph comparison verifies all 60 authored S3 declarations/signatures
unchanged. The original compiled plan, registry, format/default behavior and v4
algorithm/transport IDs remain authoritative. No product/runtime dependency is added;
only the independent general consumer opts into the existing examples product.

Guides execute exact numbers/scalar keys, optional/default/null distinctions,
offline definition selection, original-root validation and roundtrip, conservative
contains/pattern proposals, seeded replay, remaining work, policy preservation and
honest exhaustion. All new descriptions distinguish constructor hints from native
validator support and logical retention from heap/RSS/caller instruction accounting.
The README clearly labels the API as unreleased 1.6 development.

JSONSchemaDSL is absent from the inspected S3 manifest and main base. The conditional
DSL/manual equality example is deferred until its product is available during later
integration. No shim, speculative import or sibling edit was introduced.

## Preserved evidence and remaining work

An unchanged 654-file core/schema/fixture/policy scope supports reuse of G2's separately
passed 69-function/12-parameter/2300-evaluated-case schema command, with 37 separate
policy exclusions. Its old aggregate failed a stale consumer marker; that status is
preserved. Raw reused command/log/event/source bytes accompany the review return.
No fresh independent oracle, full-package, Linux/WASI/mobile or performance pass is
inferred. G7/G8 and main's independent 1.5.1 repair integration remain open.

An exploratory edit helper had a Python syntax error before applying its patch; the
corrected structured patch was then qualified. An initial harness parser counted a
Markdown divider as a metric and failed its exact assertion; header handling was
fixed while retaining all 49 checks. Raw exploratory outcomes remain separate from
final passed receipts. No native failure was skipped or ignored.

Private evidence/caches stay outside Git and source archives. G5 and earlier archives
remain verified unchanged. No sibling source, remote branch, PR, merge, tag, release,
deployment, publication or external message was changed in this increment.
