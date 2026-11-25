# JF3.3a — Successful native structural-equivalence qualification

**Decision: APPLE_STRUCTURAL_SCHEMA_PASS.** The corrected JF3.3 candidate
passes the complete focused native Apple qualification, including all
unchanged JF3.2, JF3.1 and JF2.2 regression methods. Product admission
remains NOT_ADMITTED. Reviewed 2026-11-25.

## Source-bound evidence

- Archive: jf33-u7mkc3bi.tar.gz
- SHA-256: 8d923f21c96cf2cd6aeee9324624bd1e9cee01ffc7802aeaac69855f3780ee4f
- Exact source: `1841c8bcc244c1d1304fc06834900ef44e02644e`
- Base review: `e9f401e5f428740346ddf6d0c44d69a61aa50073`
- Root manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- SchemaBridge blob: `bce3c3965e210d4f5ee8db4b5cecc8f63e407b04`
- StructuralProof blob: `ed07244f0d6370498b119a4f97aeb7ba59a7f2af`
- Repaired test blob: `e93cd15052afc66391ff2d645cec3298bf34628a`
- Runner blob: `71857c97df439a9a84487b6bb39046696f2040e5`
- Reverse fixture SHA-256: 9e8d6b50ae8c407f8d4d42632cbd66c5f381f3bf7bef53fd36b6659e8134bb47
- Native Darwin arm64; macOS 27.3; Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9); Xcode 27.2 (27B52); SDK 27.2.

Read regular archive members directly, without extracting or executing
archive content. All ten recorded subprocess exits are zero. No
failure.txt. The preceding failed compile remains documented in
JF3.3-NativeReview.md; no failed result was overwritten. Separate offline
control stdout is not included, so this archive provides no new
execution receipt for the sixteen Python controls.

## Native execution

| Suite | Debug | Release |
| --- | ---: | ---: |
| JF3.3 structural proof | 10/10 | 10/10 |
| JF3.2 reverse matrix regression | 4/4 | 4/4 |
| JF3.1 schema bridge regression | 11/11 | 11/11 |
| JF2.2 value fidelity regression | 14/14 | 14/14 |
| Total | 39/39 | 39/39 |

78 cumulative method executions. Both manifest steps pass. All eight
test logs contain the expected unique method names and completed passing
totals, with no observed compiler warnings. JF3.3 test execution
22.759 s Debug and 2.260 s Release, incidental log timings, not a
controlled performance qualification.

All eight portable-policy methods and both actual Apple methods passed:
paired proof and canonical authority; reference grammar/escaping;
siblings/scopes/unused definitions; cycles and per-use sharing;
required-set versus ordered guidance; numeric/metadata loss;
cumulative budget N/N-1; cancellation during proof; Apple structural
matrix and Apple outside-profile preflight.

## Structural outcome

| Policy | Accepted per mode | Rejected per mode |
| --- | ---: | ---: |
| exact | 13 | 6 |
| allowGeneratedAnnotations | 14 | 5 |
| allowStructuralEquivalence | 18 | 1 |

38 new structural matrix observations, 36 accepted projections and two
expected changedConstraint rejections across Debug/Release. All 24
new canonical preflight rows have the specified issue and typed key
path. Together with the 72 JF3.2 regression preflight rows, 96 profile
rejection receipts reconcile. The 18 accepted cases account for 58
instance verdicts per mode (116 in total). These are fixed loop cases,
not separately counted Swift test methods.

The following four previously rejected schemas now pass under the
explicit new policy in both modes:

| Fixture | Rewrite kind | Effective path | Definition |
| --- | --- | --- | --- |
| nested | localReference | /properties/child | Child |
| nested-generated | localReference | /properties/child | properties.child |
| object-array | localReference | /properties/rows/items | Row |
| required-order | requiredPermutation | /required | n/a |

Four rewrite receipts per mode, eight total. Six annotation additions
per mode, twelve total: simple adds root title and x-order;
nested-generated adds root title/x-order and title/x-order at
/properties/child. All other accepted rows contain no additions.
Canonical and raw actual Apple schemas remain separate and inspectable.
The preceding two policies retain their prior acceptance counts.

The remaining precise-decimal-bound schema is rejected in both modes
with changedConstraint at /properties/n/minimum. Both original
endpoints 0.12345678901234567890123456789 and
0.12345678901234567890123456791 still collapse in raw Apple output
to 12345678901234568e-17. Independent exact comparison identifies
both changed endpoints. The structural policy does not weaken numeric
fidelity or admit an otherwise changed declaration.

## Independent evidence reconciliation

Reparse native structural/reverse/value receipt lines using Decimal,
duplicate-key rejection, exact scalar strings and recursive type-aware
equality. Compare them against structural-matrix.json,
reverse-regressions.json, value-regressions.json and schema-regressions.json.
All reconciled receipts agree. An independent bounded diagnostic expansion
of the 38 recorded raw schemas verifies the local definition targets,
every used definition, required permutations, annotation paths and
all constraint comparisons. All accepted returned schemas match the
actual raw representations semantically; all accepted native instance
verdicts equal the canonical ones. Debug and Release schemas, outcomes,
rewrites and additions agree. Diagnostic replay is separate from the
native paired proof and is not a general equivalence engine.

Verify the fixture SHA-256, then use jsonschema 4.26.0 Draft202012Validator
to independently check the actual recorded schema/instance cases:
124 canonical, 124 raw Apple, 90 exact, 96 annotation opt-in and 116
structural projection verdicts = 550/550 matching results. Parse
numbers as Decimal and convert integral values exactly to Python int
for the validator's integer check; no binary floating conversion.
These are supplemental validations, not extra Swift test executions.

Compare the actual JF3.2 archive jf32-f4s1shvc.tar.gz with the current
regressions. All 38 raw schemas, canonical/returned instance verdicts,
old policy dispositions and permitted addition sets agree, ignoring
object member order and number spelling. All six historical JF3.1
schema receipts agree semantically. All 104 JF2.2 source/raw values
and equality/completeness/bridge dispositions, 28 guide verdicts and
two typed optionality observations agree. Each mode retains 23
accepted value exports, 15 changedValue and 14 incompleteContent.
No observed regression in these measured cases.

## Packaging and decision

Evaluated manifests independently compared: 13 -> 14 products,
31 -> 33 targets, zero external dependencies, macOS 15 and iOS 18
floors unchanged. Every preexisting product and target and all other
semantic manifest fields unchanged. Only candidate library and test
target with copied ReverseMatrix.json added. Not a new ordinary
consumer link, deployment-floor or portable qualification.

JF3.3a completes the focused native schema-bridge milestone. The
constructive structural proof remains narrowly scoped to reference-free
canonical input and the documented permitted returned transformations.
No general JSON Schema equivalence, arbitrary reference support,
generation-behavior equivalence or real model execution claim.
The 18/19 result describes the authored matrix, not a general success rate.

Next recommended increment: JF4 typed conveniences and native
Generable/Guide integration, retaining original native validation and
explicit conversion-fidelity checks. Full existing native/floor/docs/
Linux/WASI lanes and public product/API inventory admission remain open.
This review adds documentation only. Reproduce the successful native
candidate at its exact source SHA, not this later documentation tip.
No merge, tag, release or CI launch.
