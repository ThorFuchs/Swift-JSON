# JF2.2 — Native fidelity evidence review

Reviewed 2026-11-25. **APPLE_FIDELITY_MATRIX_PASS.** The existing strict
value bridge meets the measured native contract. Public product admission,
portable qualification, schema bridge and typed ergonomics remain open.

## Source-bound provenance

- Archive: jf22-kv8f7a7k.tar.gz
- SHA-256: d4da777e700b4fbb26b7c98674116dd85415d6486484df4f1b4d599791c9f52d
- Source: `f081536bfb63b7f35e327812882ffa2cd298b631`
- Parent review: `084d740ecbb4a40562da276212cb7dfa82b17010`
- JF2.1 source: `1772e1e173713c9361e2ecfcae8b4a5b8a7344d9`
- Manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- Native Darwin arm64, macOS 27.3, Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9), Xcode 27.2 (27B52), macOS SDK 27.2.

Read regular archive members directly, without extracting or executing
content. All four recorded subprocess exits are zero. The decision records
product_admission NOT_ADMITTED. Each mode reports 14 passing Swift test
methods, including all ten original JF2.1 methods and four new methods.
No skipped/known-issue receipt or build warning observed in the test logs.
52 value cases and 14 guide cases per mode are loop observations, not
separate test methods. Separately run offline control output is not
included in this native archive.

## Independent receipt reconciliation

Independently parse the Debug and Release logs and fidelity.json. Require
all 52 unique source fixtures and corresponding raw strings, all 14
isolated guide inputs and verdicts, schema and typed receipts, and the
14 unique passing test names in each mode. Recompute all 104 source/raw
comparisons using Decimal and type-aware recursive equality, preserving
scalar-distinct strings/keys and rejecting duplicate keys and non-JSON
constants. Every reported equality and import/export disposition agrees.
All 52 raw values are semantically identical between Debug and Release;
schema object member order may vary. No observed disposition drift.

The independent Draft202012Validator from Python jsonschema 4.26.0
also agrees with all 28 guide verdicts from the actual exported schemas.
Each invalid case has exactly one validation error (the intended rule).
This is supplemental independent evaluation, not another native run.

## Value results, per configuration

| Raw state | Equal | Count | Strict export |
| --- | --- | ---: | --- |
| Complete | true | 23 | accepted |
| Complete | false | 15 | changedValue |
| Incomplete | true | 8 | incompleteContent |
| Incomplete | false | 6 | incompleteContent |

Totals per mode: 52 observations, 23 accepted exports, 29 rejected
exports (15 changedValue, 14 incompleteContent), zero constructor
rejections. Import of the actual raw content accepts all 38 complete
representations, including the 15 already altered values, and rejects
14 incomplete values. This import is not recovery of the original input.
Across both modes: 46 accepted exports, 30 changedValue, 28
incompleteContent; 76 accepted raw imports and 28 incomplete imports.
All accepted exports satisfy the native exact equality check.

| Context | Cases | Complete/equal | Complete/changed | Incomplete/equal | Incomplete/changed |
| --- | ---: | ---: | ---: | ---: | ---: |
| Numeric root | 14 | 0 | 0 | 8 | 6 |
| Numeric object member | 14 | 8 | 6 | 0 | 0 |
| Numeric array element | 14 | 8 | 6 | 0 | 0 |
| Structure/Unicode/etc. | 10 | 7 | 3 | 0 | 0 |

On this SDK all tested numeric root values are incomplete, even 0 and 1.
All numeric object/array cases are complete, including twelve changed
values. Root null, root boolean and decomposed root string are complete
and equal. Therefore do not infer a general prohibition on scalar roots.

The six numeric values changed in all three contexts:

| Original | Exported numeric text |
| --- | --- |
| 9007199254740993 | 9007199254740992 |
| -9007199254740993 | -9007199254740992 |
| -9223372036854775808 | -9.223372036854776e+18 |
| 9223372036854775807 | 9.223372036854776e+18 |
| 18446744073709551615 | 1.8446744073709552e+19 |
| 0.12345678901234567890123456789 | 0.12345678901234568 |

The other eight tested numbers retain exact mathematical JSON equality.
In particular 0.1 roundtrips as the same decimal JSON value when nested;
this is not proof of exact internal binary representation. Int64.min
is changed in the exported decimal text even though its mathematical
integer is representable in binary64. Do not infer Apple's implementation
from the observed representation.

All three scalar-distinct Unicode key fixtures are complete but altered.
Both insertion orders and a nested object lose one key. In these fixtures
the first inserted key/value survives; do not generalize survivor policy.
The dedicated real-framework collision test passes and asserts the exact
changedValue error. Decomposed string content without key collision is
preserved. No rounded values, normalized keys or lost members enter an
accepted export. The fixed adversarial corpus is not a population estimate.

## Native guide and typed semantics

All four valid cases and ten individually invalid cases per mode pass:

| Case | Native verdict | Independent error keyword (if invalid) |
| --- | --- | --- |
| base | valid | |
| upper-bound | valid | |
| enum-title | valid | |
| note-string | valid | |
| note-null | invalid | type |
| range-low | invalid | minimum |
| range-high | invalid | maximum |
| enum-other | invalid | enum |
| count-low | invalid | minItems |
| count-high | invalid | maxItems |
| item-type | invalid | type |
| required-query | invalid | required |
| extra-property | invalid | additionalProperties |
| query-type | invalid | type |

The native exported schema preserves description, integer minimum/maximum,
string enum, array item type and minItems/maxItems, optional nonnullable
note, required list, closed object and x-order. The two typed receipts
reproduce the separate loss: the Generable initializer accepts note:null,
while generatedContent omits note. Original is invalid against the
generated schema, returned is valid, canonical values differ. Hence
typed construction is not validation; validate original arguments before
typed conversion and preserve the original schema authority.

## Packaging and next decision

Compared evaluated manifests: 13 -> 14 products, 31 -> 33 targets,
zero dependencies, unchanged macOS 15/iOS 18 floors, all original
products/targets and other semantic fields unchanged. Only the
disposable JSONFoundationModels target and its test target are added;
the test target directly depends on JSON, JSONSchema and
JSONFoundationModels. This reinforces the existing Apple packaging
evidence but does not repeat JF1's ordinary consumer link checks.

Proceed to JF3: native Codable schema import, constrained reverse
projection, exact constraint/annotation diagnostics, original validation
authority, and explicit rejection of unverified declarations. Keep
x-order separate from validation equivalence; do not silently discard
unknown metadata or treat optional as nullable. A Codable roundtrip or
these finite cases alone do not prove arbitrary Draft 2020-12 equivalence.

No production code/manifest or runner changes, merge, tag, CI launch
or publication. JF1 portable and existing full native/platform-floor/
Linux/WASI lanes and eventual product admission remain required. This
review does not establish actual Linux FoundationModels, live model
generation, complete metadata fidelity or an API freeze. Re-run JF2.2
at the original source SHA above, not at this documentation commit.
