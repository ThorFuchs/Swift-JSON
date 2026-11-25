# JF3.1a — Successful native qualification

**Decision: APPLE_SCHEMA_CANDIDATE_PASS.** The repaired JF3.1 candidate
passes its complete focused native Apple qualification, including the
unchanged JF2.2 regression suite. Product admission remains NOT_ADMITTED.

## Source-bound receipt

- Archive: jf3-nqa9vlk4.tar.gz
- SHA-256: 59e78813c78c8d8f73ad3c505551ce9e68be65ed0bc9fbabf5ef67278a72aee5
- Exact source: `addb0045911e4082d8f8678c6ad822a8be82284c`
- Runner base: `dda2274598d823d311c587d280f00444b3c1fc68`
- JF2.2 source: `f081536bfb63b7f35e327812882ffa2cd298b631`
- Root manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- Schema bridge blob: `8ccc47ed3eb96ca099f5bb706945005d2af5be8b`
- Repaired test blob: `07c9d8ec3badd411b55b080463d3acab3b21e261`
- Runner blob: `77a87fd5c01670ddd93b711419a16284f536355b`
- Native Darwin arm64; macOS 27.3; Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9); Xcode 27.2 (27B52); SDK 27.2.

Reviewed 2026-11-25. Read the archive's regular members directly, without
extracting or executing its contents. All six recorded subprocess exits
are zero; no failure.txt is present. The earlier failed native run and
its fixture repair remain documented in JF3.1-NativeReview.md.
Separate offline Python-control stdout is not included in this archive;
no new 9/9 offline execution result is inferred.

## Complete focused native gate

| Step | Exit | Test methods passed |
| --- | ---: | ---: |
| Baseline manifest | 0 | n/a |
| Candidate manifest | 0 | n/a |
| Debug JF3 | 0 | 11/11 |
| Debug JF2.2 regression | 0 | 14/14 |
| Release JF3 | 0 | 11/11 |
| Release JF2.2 regression | 0 | 14/14 |

Total: 50/50 method executions (25 distinct methods in each mode).
All started method names reconcile to unique passing names and the
recorded receipts. No skip, known issue, failure, or compiler warning
observed in the four test logs. JF3 debug build 17.79 s; release build
26.37 s. JF3 test runs 4.383 s and 0.436 s respectively; JF2.2 regressions
0.451 s and 0.052 s. These are incidental recorded timings, not controlled
performance measurements or performance qualification.

All eleven JF3 methods pass in both modes:
exact Codable and canonical plan; metadata consent; changed-constraint
rejection; metadata scoping; unqualified declaration rejection; native
invalidity distinction; cumulative work/retention N and N-1 boundaries;
cancellation; real Apple guided import; real Apple reverse annotation
delta; real Apple exact prepared schema. The corrected test now exercises
all nine complete negative fixtures without the old syntax failure.
No production implementation was changed by the fixture repair.

## Schema evidence

The six JF3 schema log lines match schema-receipts.json verbatim and the
three expected schema objects per mode by independent type-aware exact
JSON comparison (Decimal, distinct scalar keys, Boolean/number identity).
Debug and Release schema values match; property serialization order may
differ. Guided import preserves the actual title JF3GuidedArguments,
description, integer bounds 1 and 20 (emitted 2e1), string enum date/title,
array item type and minItems/maxItems=2, required list, optional
nonnullable note, closed object and x-order.

Both reverse and exact prepared receipts equal the expected closed object
schema with query:string, required [query], title Object and x-order
[query]. The real strict reverse test denies the new annotations by
default. Explicit opt-in permits precisely their two recorded paths.
The exact prepared schema succeeds without additions. Canonical plan
preservation and positive/negative native instance validation passed.
Both modes pass the cumulative native ledger boundary and cancellation
controls. Opaque framework work is outside the native accounting claim.

## Regression reconciliation

Independently parse all 104 value rows, 104 corresponding raw rows,
28 guide rows and two typed rows from the actual test logs. Reconcile
them with value-regressions.json. Confirm the 52 source fixtures in each
mode, exact Decimal/scalar/type comparison of source vs raw, completeness
and actual bridge dispositions. All pass the independent comparisons.
All raw JSON values and dispositions agree across Debug and Release.
Each mode retains JF2.2's distribution:

| Export outcome | Per mode | Both modes |
| --- | ---: | ---: |
| accepted | 23 | 46 |
| changedValue | 15 | 30 |
| incompleteContent | 14 | 28 |
| frameworkRejected | 0 | 0 |

Raw import accepts 38 complete representations and rejects 14 incomplete
ones per mode; it does not recover previously lost source semantics.
All 14 isolated guide cases per mode match the expected verdicts, four
valid and ten invalid. The typed optionality receipt still shows
note:null becoming absent, invalid original and valid returned value,
with unequal canonical JSON. No new conversion regression observed.

Supplementary independent evaluation using Python jsonschema 4.26.0
Draft202012Validator checks all 14 guide inputs against both actual
exported guided schemas (JF2.2 and JF3) in each mode: 56 matching
verdicts, and each negative has exactly its intended error keyword.
Convert exact integral Decimal numbers to Python int for that validator's
integer type checks, with no binary floating conversion. This is an
independent replay of observed schemas, not 56 additional native tests.

## Packaging and admission

Compared evaluated manifests: 13 -> 14 products, 31 -> 33 targets.
Existing products and targets and all other semantic manifest fields
except packageKind's root path are unchanged; zero external package
dependencies, macOS 15/iOS 18 package floors. Only the disposable
JSONFoundationModels target (JSON, JSONSchema dependencies) and the test
target (JSON, JSONSchema, JSONFoundationModels dependencies) were added.
This is consistent with the JF1 Apple packaging result, not a fresh
ordinary-consumer link or portable platform qualification.

JF3.1a is admitted as a passed focused native candidate only. No public
product admission, model execution, final API freeze, Linux/WASI pass,
or arbitrary reverse-schema support claim. JF3.2 should expand the
actual reverse SDK matrix over nested closed objects, arrays, primitive
types, optionality, numeric bounds, enums, metadata scope and exact
rejection diagnostics. Widen the profile only after measured evidence;
do not silently strip or loosen unqualified constraints. Continue to
JF4 typed conveniences afterward. The original canonical validation
plan remains authoritative.

The root package's full native, deployment-floor, docs, Linux and WASI
qualification and explicit product/API inventory admission remain open.
This review adds documentation only. Re-run the successful candidate
at the exact source SHA above; the historic runner intentionally checks
its exact source delta. No merge, tag, release or hosted CI invocation.
