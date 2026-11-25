# JF4.1a — Native Debug evidence and precise diagnostic repair

Reviewed 2026-11-25. The first JF4.1 native build succeeded, but the
focused gate remains FAILED_OR_INCOMPLETE / NOT_ADMITTED. This repair
does not change either bridge, the prepared-generation implementation,
the native evaluator, the product manifest, or the acceptance contract.

## Source-bound evidence

- Archive: jf4-gikrs1tu.tar.gz
- SHA-256: 98f101d3778099c6f5aea10391a2c42bb4d3820995e6c03b7bd8be5516313b28
- Source: `69ca100bf693a7ec65cbf74e28d436dc5d763f59`
- Parent review: `7f63b2c38a578b1fd8c49bb64c95a4d7c98bb3f0`
- Manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- Reverse fixture SHA-256: 9e8d6b50ae8c407f8d4d42632cbd66c5f381f3bf7bef53fd36b6659e8134bb47
- Darwin arm64, macOS 27.3, Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9), Xcode 27.2 (27B52), SDK 27.2.

Read regular archive members directly; no extraction or execution.
Both manifest subprocesses exit 0; debug-jf32-regression and
debug-jf33 exit 0; debug-jf4 exits 1. No Release, JF3.1 or JF2.2
regression subprocess has yet run. The first build log records 19.39 s.
25/26 started native test methods passed: JF3.2 4/4, JF3.3 10/10,
JF4.1 11/12. The last suite's failure contains four assertion issues
in one method, jf4AppleValidationPrecedesTypedConversion.
No complete native qualification is claimed.

Replay the actual JF3.2 and JF3.3 logs through the byte-verified historical
Python verifiers; both agree with the stored debug JSON receipts.
All 19 reverse/structural rows reconcile. The previous policy acceptance
counts are unchanged (13 exact, 14 annotation, 18 structural). Evaluated
manifests retain all original product/target declarations: 13 -> 14
products, 31 -> 33 targets, zero external dependencies.

## Actual new native observations

All eight portable-policy methods passed, including cumulative N/N-1
work/retention and cancellation after the typed callback. Three of four
actual Apple tests pass: typed public roundtrip, nested DSL preparation,
and schema-valid but unrepresentable value. The 26 invalid-route receipts
were emitted despite the single method's diagnostic assertions failing.
All six invalid fixtures were rejected on all four input routes; mutated
typed range and nested DSL required cases were rejected too. No unsafe
acceptance was observed. The existing test verified invalidity and
diagnostic completeness before comparing the keyword.

Independently parse the two typed roundtrip receipts using the historical
exact JSON comparator; both source and returned values match. The native
guided schema is emitted; optional note absence and presence survive
the roundtrip. DSL canonical and projected schema values match the
prior nested fixture and actual JF3.2 raw schema; the valid instance
roundtrips. Numeric receipt confirms that 9007199254740992 succeeds
and 9007199254740993 is rejected as changedValue, despite both being
valid against the exact canonical integer schema.

## Cause: keyword-less Boolean subschema

The four mismatches all occur for unknown property extra, under
decodeJSON, decodeContent, export and import. Expected keyword
additionalProperties; recorded keyword string "" in all four.
This is the native engine's representation of a failing false subschema,
not an observed loss of argument validation.

Inspected unchanged JSONSchemaEvaluation.swift (blob
31a3f2759e091486926a9b0073ac5bc1171700e5): initialize at lines 249-254
calls issue(nil) for a false Boolean schema; issue at lines 127-144
records the empty keyword for nil, and locations at lines 95-125 uses
the frame trace with no appended keyword. Additional property evaluation
at lines 463-472 enters that subschema with the extra member's instance
path; trace construction at lines 295-301 retains the applicator.
The expected native tuple for this fixture is consequently empty
keyword, keywordLocation /additionalProperties, instanceLocation /extra.
The failed log did not serialize those paths, so these locations are a
source-derived expectation, not an already observed native receipt.

JF4.1a requires one complete exact diagnostic tuple (keyword,
keywordLocation, instanceLocation) for each of the same 26 invalid
routes, in both configurations. This is stricter than checking whether
an expected keyword occurs somewhere in the result. It deliberately
does not treat an empty keyword as a wildcard, rewrite native
diagnostics, alter the engine's false-schema semantics, or skip any
negative test. The exact paths are specified for all other fixtures too.
Runner receipt validation and mode comparison check all three fields.
Add only this review to the new candidate's exact-delta allowlist.

## Editing-host verification and next gate

Verified original and corrected Swift test/runner/control Git blobs.
Python isolated unittest: 16/16 pass, including four new controls for
keyword location, instance location, false-subschema diagnostic
not being a wildcard, and duplicate diagnostics. Swift 6.2.1 Linux
frontend parses all four JF4.1 sources through the syntax control and
the corrected Apple test source in a separate syntax-only unguarded
copy. No new Apple SDK typecheck or native runtime execution here.
Offline test receipts are synthetic; no corrected native path result
is claimed until the Studio rerun.

Run the full corrected candidate at its exact commit. Intended counts
remain 51 Swift methods per mode / 102 cumulative. Expected outcome
APPLE_ERGONOMICS_CANDIDATE_PASS; product admission NOT_ADMITTED.
Keep old source and archive immutable. No merge, tag, release or
hosted CI invocation. Full portable, platform-floor and product
admission gates remain open.
