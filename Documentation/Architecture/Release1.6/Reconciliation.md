# S3 source and input reconciliation

Observed on 2026-10-15. The private raw receipts and probes are retained under
ignored `Artifacts/SchemaExamplesS3` in the isolated checkout. This record closes
orientation; it does not claim a generator implementation or release qualification.

## Releases and independent trains

GitHub reports 1.5.0 published and latest at
`8a5cf73dfe9b674f7c635f5f6d21a7051d66bb51`. The protected 1.4.0 tag points to
`e8c3e4bd9ae40d797f07a527ea98879acee3c057`; its separate release remains draft.
The CLI's frozen `1.4.0-dev`/unknown-revision metadata is an explicitly disclosed
1.5.0 release limitation, not grounds to rewrite published source or old receipts.

Initial local main and origin/main matched 1.5.0 and were clean. All 23 registered
worktrees, including the newly created S3 checkout, were inspected; no visible
local changes were found at that observation. Historical qualification worktrees
were retained. E2 and the CLI are already integrated into main; old branch ancestry
alone is not evidence that squash-merged features remain unintegrated.

During orientation, the sibling session merged HTML previews PR #30 as
`507dbf9ad4b545a5d60d7d6acf6b814795ec3099`. Only the new, still-clean S3 branch
was fast-forwarded before its first tracked edit. Original main was left at
1.5.0. JSON, JSONSchema and JSONRegexRuntime source trees are byte-identical
between those commits. The manifest delta adds JSONHTMLTests fixture resources;
the seven products, empty dependency graph and JSON/schema target edges are unchanged.
The HTML/CLI behavior delta and its current CI belong to that separate merged train.

Dual DSL PR #31 remains draft at `64264218dc0073a5738ab557bfa25b3bb9f6fa7a`
and reports conflicts after main advanced. Neither its files nor its state were
changed. S3 imports neither proposed DSL product. Future main movement requires
an explicit integration check; this feature does not continuously reset to it.

Strict required checks remain `Native / native`, `Native / safety` and
`Native / docs`, with PRs, resolved review threads and no bypass. No protection,
tag, release or remote branch configuration was changed by this kickoff.

## Actual baseline evidence

The downloaded published source is SHA-256
`b3ec3ede09b448a32dceaf8ba89f97f99458e3dade9e3c4236d043e30e1d4389`,
1,501,990 bytes, 995 source files plus manifest. A local sorted normalized archive
of the untouched initial checkout reproduced those exact bytes.

The materialized 1.5.0 evidence archive is
`afe7ac0ebd07c7fe963f9f042db090a6e547e9abbdd2898bf174a9d7fc528a76`.
Verification covered 455 manifested evidence files, seven hosted CI receipts and
one clean-extraction native receipt, 120 command logs and 24 structured event
streams. All 995 source hashes matched the released checkout. This reuses actual
passed baseline evidence; no new uninterrupted full Native/S3 lane is inferred.
Linux receipts omit direct Git SHA; their complete source hashes and published
workflow identity remain the documented identity evidence.

This machine passed native preflight: macOS 27.0 arm64, Xcode 27.2 build 27B5019j,
Apple Swift 6.4 (swiftlang-6.4.0.34.1), SDK 27.2, language mode 6. Probes explicitly
select the matching Xcode/SDK, complete strict concurrency and warnings as errors.
No global developer-directory selection or compatibility flag was introduced.

## Packet and fixture amendment

Packet SHA-256 is
`f67ec2f5d0bfd223f54a3577f93c03951a7992ecab524910ba44f6bc8621c4a1`;
all 26 non-manifest files verified. Its inspected baseline was 9517233, before
the merged E2, CLI/provider and structured-preview increments. It contains design
proposals and research receipts, not implemented generator source.

The unmodified Python 4.26.0 oracle passes its 44 cases/154 witnesses. Native replay
found one incorrect expectation: `exact-integer-beyond-2pow53/invalid_3` marks
numeric `9007199254740994.0` invalid for integer bounds 9007199254740993 through
9007199254740995. It is mathematically integral and within those bounds. This agrees
with [Draft 2020-12 type semantics](https://json-schema.org/draft/2020-12/json-schema-validation#section-6.1.1).

The packet parses fractional tokens as Decimal, while python-jsonschema's default
integer binding excludes Decimal. The [oracle's own type-checking documentation](https://github.com/python-jsonschema/jsonschema/blob/main/docs/validate.rst)
describes this Python representation boundary. An exact research decoder now maps
only exactly integral Decimal tokens to exact Python int; other fractions remain
Decimal. No binary floating-point conversion is used. Eight separate binding
regressions include integral lexemes, negative zero, large values, a nonintegral
large value and Boolean exclusion.

The original packet and its failing native comparison remain immutable. A separate
derived fixture corrects that verdict to true and adds `9007199254740994.5` as a
genuinely fractional negative. All original case classifications remain: 24 G3
must-generate, 10 G4 must-generate, 8 G4 may-fail-explicitly and 2 G3 sound proofs.
All 155 amended witnesses agree between native Swift 6.4 and the exact-bound Python
oracle. This is fixture validation, not 155 generated examples or proof of completeness.
Original fixture SHA-256 is
`6f2bfd4fdb7c7e206b6570c2156ca8e248831840733b0258aa8cd5938b35649f`;
the derived hash and exact amendment are in the private receipt.

## Compiled source boundaries

A separate public-only consumer compiles against real JSON/JSONSchema, retains a
checked-Sendable plan/registry pair, exercises explicit registry resources, native
report and direct validation, and normalized scalar-order writer roundtrips.
Initial probe accessor/autoclosure errors and the original fixture failure are
retained separately from successful amended runs.

Compiler-driven package probes pass with the actual SwiftPM package identity:
shared noncopyable meter validation, accounting-domain changes and portable
SHA-256 are accessible. Compiled node arrays are package-visible, but node.raw and
reference/child fields are internal. Intended negative probes fail for internal
node access and external package-plan access. G1 therefore needs a narrow
read-only qualified-node bridge, not a guessed URI resolver or broad graph exposure.
