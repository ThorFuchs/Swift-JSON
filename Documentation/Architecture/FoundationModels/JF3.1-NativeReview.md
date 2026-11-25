# JF3.1 — First native run and narrow fixture repair

Reviewed 2026-11-25. Native schema bridge compilation succeeded, Debug
10/11 methods passed, all three real FoundationModels methods passed.
Qualification is still FAILED_OR_INCOMPLETE, product_admission NOT_ADMITTED.
Release and the JF2.2 regression subprocesses were not reached.

## Source-bound evidence

- Original commit: `cd62dc5d3e872d443412c2a667cf6ba664fcd4f6`
- Archive: jf3-h_0wdewg.tar.gz
- SHA-256: d48b3e1aa9ee7f29e5f726a5f16577e4873ee880ec65e39340b2d2ed71ba0912
- Host: Darwin arm64, macOS 27.3; Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9); Xcode 27.2 (27B52); SDK 27.2.
- Manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`

The two manifest subprocesses exited 0; debug-jf3 exited 1.
Build completed in 16.97 seconds. 13 -> 14 products, 31 -> 33 targets;
only the experimental bridge and its test target are added. The runner
correctly stopped after the nonzero test exit. No full gate pass claimed.

Passing native methods: exact Codable and canonical plan; explicit metadata
consent; constraint mutation rejection; metadata scoping; invalid native
schema distinction; cumulative N/N-1 work/retention; cancellation.
All three Apple tests passed: macro-generated guide import, reverse
annotation delta, and exact prepared schema. Actual log receipts show
the guided closed-object declaration with the expected bounds, enum,
array length, required list, optional nonnullable note and x-order.
Both reverse and exact receipts contain the known title Object and
x-order [query]. They are concrete SDK results, not proof of arbitrary
schema equivalence. The measured cumulative budget test passed in Debug;
optimized behavior remains untested.

## Failure analysis

jf3RejectsUnqualifiedDeclarations recorded JSONFailure(.syntax, .invalidSyntax)
at byte offset 64. The previous test replaced the substring
`"type":"string` without the closing quote. This produced
`"type":["string","null"]"` — an extra closing quote. Independently
reconstructing the old fixture reproduces a JSON parser error at offset 64.
The error arises before profile comparison; it is not an observed defect
in GenerationSchema conversion or native schema semantics.

Repair: replace all nine mutated negative fixtures with complete named
JSON literals. Independently parse the actual fixture declarations; add a
stdlib offline control checking the exact fixture identities, expected
issue category, complete JSON syntax and nullable type array. The native
method must still reject all nine with their intended issue category;
no skipped test, weakened expectation, change to schema bridge, value
bridge, resource limits or release baseline. Update the runner's exact
changed-file list solely to include this review. Original JF3.1 source and
archive remain reproducible at their original commit. New source has
not yet been natively executed; run the whole JF3 + JF2.2 Debug/Release
matrix again, at the corrected commit.

No merge, tag, publication, product admission or CI launch. Continue
JF3.2 only after the corrected candidate has its actual native receipts.
