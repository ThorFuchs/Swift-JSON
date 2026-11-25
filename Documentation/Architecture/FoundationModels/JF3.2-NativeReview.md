# JF3.2 — Native reverse-schema evidence review

**Decision: APPLE_REVERSE_SCHEMA_MATRIX_PASS.** Focused Apple qualification
passed, including the existing JF3.1a and JF2.2 regressions. Public product
admission remains NOT_ADMITTED. Reviewed 2026-11-25.

## Source-bound evidence

- Archive: jf32-f4s1shvc.tar.gz
- SHA-256: 766c77e5776e28ad6af6479591faee140864b83687695fb8bdc34d2e59325007
- Exact source: `318b8b2cc6cfdc04dd7cf17257b00c665bda051f`
- Parent review: `441d273380cf93da45c5150073bf1225f3e3e7dc`
- Manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- Fixture blob: `8196a8178452da60729e3e7762429504d79efd72`
- Fixture SHA-256: 9e8d6b50ae8c407f8d4d42632cbd66c5f381f3bf7bef53fd36b6659e8134bb47
- Runner blob: `88e48b60b79634ce8699067f4ff31e9a83302192`
- Native Darwin arm64, macOS 27.3, Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9), Xcode 27.2 (27B52), SDK 27.2.

Read archive regular members directly; did not extract or execute content.
All eight recorded subprocess exits are zero; no failure.txt. Replayed
the locally available byte-verified JF3.2 runner's receipt verification
on the two native logs and exact fixtures, then reconciled results with
reverse-matrix.json. All records and mode stability checks agree.
Separately executed offline unittest stdout is not included in this
archive; no new 15/15 offline execution claim from this receipt.

| Suite | Debug | Release |
| --- | ---: | ---: |
| JF3.2 | 4/4 | 4/4 |
| JF3.1 regression | 11/11 | 11/11 |
| JF2.2 regression | 14/14 | 14/14 |
| Total | 29/29 | 29/29 |

58 cumulative native method executions. Both manifest steps also passed.
No skip, known issue or compiler warning observed in the six test logs.
38 reverse observations and 72 exact preflight rejection rows (12 fixtures
under portable, Apple exact and Apple opt-in paths per mode).
The 62 canonical instance cases per mode are loop cases, not independent
Swift test methods. JF3.2 test run timings 39.488s Debug and 3.918s
Release are incidental, not a controlled performance qualification.

## Independent validation and regression reconciliation

Python jsonschema 4.26.0 Draft202012Validator replayed all recorded
instance verdicts: canonical 124, raw Apple schemas 124, accepted exact
projections 90 and accepted annotation-opt-in projections 96, total 434.
All agree with the native verdicts. Use Decimal for parsing and exact
integral conversion to Python int for integer type checks; no binary
floating conversion. All 31 original fixture schemas and 38 actual raw
schemas pass independent schema checks (per-mode replay of raw schemas).
Independent validation is supplemental, not another native run or an
equivalence theorem.

JF3.1 and JF2.2 regression logs/receipts reconcile with the previous
qualified JF3.1a archive (jf3-nqa9vlk4.tar.gz). The three native schema
receipts per mode have identical semantic values; all 104 raw value
observations, 104 bridge dispositions, 28 guide verdicts and two typed
optionality receipts match the prior native results. Each mode retains
23 accepted value exports, 15 changedValue and 14 incompleteContent.
No changed value accepted; no observed regression.

## Reverse matrix outcomes, per mode

All 19 source schemas decoded to actual GenerationSchema and re-encoded;
all 19 returned schemas compiled natively. No codecRejected or
nativeInvalid cases. Three raw schemas fail only the narrow reference-free
profile. Strict projection accepts 13/19; allowGeneratedAnnotations
accepts 14/19. Debug/Release semantic schemas and dispositions agree.

| Fixture | Exact | Annotation opt-in |
| --- | --- | --- |
| simple | annotationAdditionDenied | accepted, title and x-order |
| prepared | accepted | accepted |
| empty | accepted | accepted |
| nested | unsupportedDeclaration /$defs | same |
| nested-generated | unsupportedDeclaration /$defs | same |
| string-array | accepted | accepted |
| object-array | unsupportedDeclaration /$defs | same |
| nested-array | accepted | accepted |
| boolean | accepted | accepted |
| integer-range | accepted | accepted |
| large-integer-bound | accepted | accepted |
| int64-bound | accepted | accepted |
| number-range | accepted | accepted |
| precise-decimal-bound | changedConstraint /properties/n/minimum | same |
| optional | accepted | accepted |
| enum | accepted | accepted |
| metadata-names | accepted | accepted |
| required-order | changedConstraint /required | same |
| mixed | accepted | accepted |

All 12 out-of-profile fixtures are valid native schemas and reject at
the expected issue/path, in all three preflight routes and both modes.
All admitted projections retain canonical schema and have unchanged
instance verdicts. The four conservative rejections described below
are distinguished from the one demonstrated numeric constraint loss.
The fixed matrix is not a population estimate or general Apple capability
guarantee.

## Numerically exact integers versus decimal loss

The large integer bounds 9007199254740992 and 9007199254740993, as well
as Int64.min (-9223372036854775808) and Int64.max
(9223372036854775807), survive exactly through the native Codable
GenerationSchema path. This differs from GeneratedContent's previously
measured JSON-value behavior; no internal Apple representation inferred.
The enum containing z, a, U+00E9 and U+0065 U+0301 also survives exactly.

The precise-decimal-bound fixture changes BOTH endpoints:
- canonical minimum 0.12345678901234567890123456789
- canonical maximum 0.12345678901234567890123456791
- returned minimum and maximum 12345678901234568e-17
  (0.12345678901234568).

Canonical verdicts [true,true,false,false] become [false,false,false,false]
in raw Apple output. Both strict and annotation-opt-in projections
reject with changedConstraint at /properties/n/minimum. The returned
interval has collapsed and both originally valid endpoint values are
invalid; this is an observed semantic change, not merely formatting.
Do not relax the exact numeric check.

## Observed structural changes

Three fixtures are rejected at /$defs because the current profile is
intentionally reference-free:
- nested: inline Child becomes a pure reference #/$defs/Child.
- nested-generated: inline child becomes #/$defs/properties.child;
  generated titles and x-order appear at root and child.
- object-array: inline Row item becomes #/$defs/Row.

All raw verdicts for those fixtures agree with canonical. A separate
finite diagnostic expansion of the actual simple local aliases (not a
production normalizer) substitutes the referenced definition at each
pure reference position, then removes the fully used root $defs table.
For these three captured shapes only, the schema-position delta is:
nested none; object-array none; nested-generated four additions
/title, /x-order, /properties/child/title,
/properties/child/x-order. This is direct evidence of the specific
structural transformation, not qualification of arbitrary references.
The original actual Apple schema should remain inspectable.

required-order changes [b,a] to [a,b]. The native schema compiler
accepts both and the two fixture verdicts agree. Draft 2020-12 required
is an unordered set of distinct property names; this particular reorder
does not change that assertion. JF3.1 deliberately rejects it as a
declaration-value change. Do not conflate required with x-order (model
property ordering) or enum order (potential model guidance).

## Proposed next increment: JF3.3, before JF4

Recommend a separate, explicit structural-equivalence policy rather
than relaxing the current exact/default or annotation-only behavior.
Qualify a bounded proof for this narrow SDK transformation: closed
reference-free canonical source, returned root-local definitions,
pure local references, no siblings, no URI scope changes, no dynamic
references, no external resolution. Resolve exact JSON Pointer paths,
reject unresolved, recursive/cyclic, ambiguous or unreachable definition
graphs; meter traversal and expansion cumulatively with native budgets,
avoid uncontrolled expansion and check cancellation. Keep canonical
validation plan, untouched actual returned schema and typed diagnostics
of structural rewrites and optional metadata additions. Treat required
permutations only after verifying exact distinct name-set equality; do
not reorder or strip enum, x-order, annotation or numeric constraints.
Review whether distinct local refs to identical shapes can be shared
without weakening any constraint. Test equal titles with distinct schemas,
escaping/URI fragments, dangling and cyclic refs, unused defs, sibling
constraints, depth/work/retention limits, cancellation and changed
numeric bounds inside a referenced object. Do not admit general
reference-bearing canonical input or general schema equivalence based on
these examples. JF3.3 is a recommendation, not implemented in this review.

## Packaging and limits

Manifests independently reconcile: 13 -> 14 products, 31 -> 33 targets;
existing declarations and all other semantic fields (except packageKind
root path) unchanged, zero external dependencies, macOS 15/iOS 18 floors.
Candidate adds only experimental library and test target, including the
copied fixture resource. Not a new ordinary-consumer link or portable
execution gate. No Linux/WASI or actual model-generation claim. Full
existing product/floor/docs/Linux/WASI gates and explicit API admission
still required. No code, manifest or historical runner changes, merge,
tag, CI or release. Reproduce JF3.2 on the exact original source SHA,
not this documentation tip.
