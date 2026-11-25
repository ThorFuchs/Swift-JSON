# JF3.3a — First native run and raw-literal repair

Reviewed 2026-11-25. JF3.3 remains FAILED_OR_INCOMPLETE / NOT_ADMITTED.
The test package failed to compile before any Swift Testing method ran.
This repair preserves the structural proof, schema bridge, value bridge,
all test expectations and all 78 intended native method executions.

## Source-bound evidence

- Archive: jf33-akshep6k.tar.gz
- SHA-256: 78b79744767d6ce432ff07076107b64d3d53f040086b8cee3cadb6e548d5e9fb
- Failed source: `d4e10e88289eb95e501e174636bf3fa79f077c64`
- Parent review: `e9f401e5f428740346ddf6d0c44d69a61aa50073`
- Manifest blob: `088e256101f1f5f330e20ba5c915cd5e188ba11f`
- Reverse fixture SHA-256: 9e8d6b50ae8c407f8d4d42632cbd66c5f381f3bf7bef53fd36b6659e8134bb47
- Native Darwin arm64, macOS 27.3, Apple Swift 6.4.2
  (swiftlang-6.4.2.1.9), Xcode 27.2 (27B52), SDK 27.2.

Read regular archive members directly, without executing or extracting
content. Baseline and candidate manifest subprocesses exited zero.
debug-jf32-regression exited 1 during compilation of the test target;
there are no test pass receipts, JF3.3 runtime observations, Release
runs or completed regression runs in this archive.

## Cause and correction

The first compiler diagnostic is StructuralProofTests.swift:9:91,
consecutive statements on a line must be separated by ';'. The 335
source-specific error lines are concentrated on 13 fixture declarations
and are consequences of prematurely terminated Swift raw string literals.
A JSON string value starting with # creates the sequence quote/hash,
which closes a Swift single-hash raw string. These fixtures include
local $ref and $dynamicRef fragments. This is a Swift lexical issue,
not evidence of failed schema proof, pointer semantics or JSON parsing.

Use double-hash raw string delimiters on all 13 affected declarations:
hoistedChild, escaped, once, siblings, unused, scoped, alias, dynamic,
rootRef, cyclic, mutual, aliasBoth, added. Preserve every fixture payload
byte and every assertion. No changes to the actual two bridges or
StructuralProof.swift. Add this review to the existing exact-delta
allowlist; no weakening of the native qualification.

## Actual editing-host verification

Reconstructed the original test file from the corrected source by
reversing just the 13 delimiter changes, verified its exact Git blob
3da8775ca5180364a0287b7be7fd47310ccb35d3, and reproduced the original
first diagnostic at 9:91 with Linux Swift 6.2.1. The corrected file's
Git blob e93cd15052afc66391ff2d645cec3298bf34628a passed full frontend
syntax parsing, including an additional syntax-only copy with the Apple
conditional guard removed. All 13 original JSON literal contents
were unchanged and independently parsed as JSON.

Added two permanent offline controls: inspect the actual Swift fixture
delimiters and strict JSON payloads for all 13 named declarations;
invoke swiftc -frontend -parse on the complete actual test file.
All 16/16 offline controls passed under isolated Python execution on
the editing host, including the existing 14 receipt controls. This
syntax preflight now requires a Swift compiler in PATH. It is not
native typechecking or execution on the target toolchain.

## Next gate

Run the full corrected candidate from its exact commit using the JF3.3
runner. Expect 39 Swift test methods per mode, 78 cumulative, including
all historic regressions and the 18/19 structural acceptance anchor
with the precise decimal constraint rejection. No qualification success
is claimed until the actual native evidence arrives. No merge, tag,
release, public product admission or hosted CI invocation.
