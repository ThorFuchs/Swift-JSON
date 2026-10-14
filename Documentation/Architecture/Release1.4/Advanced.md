# Advanced filter execution

C4 builds on exact arithmetic 10e585d / draft PR #25. The flat immutable plan now
contains lexical function metadata and destructuring patterns. Definitions see
earlier definitions and themselves; forward definitions and same-scope duplicate
signatures fail compilation. Invocation-owned closures capture declaration-time
environments. Filter arguments are code thunks evaluated on the callee input;
value parameters use explicit binding desugaring. Recursion uses arena frames,
not Swift call-stack recursion. Mutable closures/thunks are never shared as Sendable.

Reduce consumes every update result and carries the last; an empty update becomes
null. Foreach extracts each update and carries its last. Independent initialization
results remain ordered. While/until/recurse/walk use explicit continuations, with
finite frames, work and cancellation. Walk reconstructs children before transforming
the parent, preserving exact object keys; array child generators retain all values,
object updates select first/delete empty according to update semantics.

Collections use stable bounded merge sorting and full lexicographic key-result lists.
First stops its generator, last consumes it, and nth scans once, retaining only requested
results in argument order. Any/all short circuit and use empty false/true identities.
Flatten and recursive containment use explicit bounded stacks. Literal strings compare,
count, slice and match by decoded Unicode scalars. No regex engine is a fallback.

Interpolation uses explicit lexer jobs, strict native literal decoding and bounded
Cartesian construction. Formatted interpolation encodes holes while preserving literal
text. Text/JSON/HTML/URI/CSV/TSV/POSIX shell quoting/base64 encoders are owned bounded
code; shell output is inert text. Base64 enforces canonical padding bits and strict
UTF-8, rejecting replacement decoding. Tonumber accepts one exact strict number token.

Assignable values carry invocation-root path provenance. Computed values cannot become
addresses. Path arrays use exact string/integral-number segments, separately from Pointer
text escaping. Setpath preflights array gaps before allocating; null can create a container
but wrong non-null kinds remain errors. Assignment stages targets before RHS effects,
deduplicates exact normalized paths, rejects parent/child overlaps, and emits complete
candidates only. Update takes first RHS/delete empty. Deletions order original array
indices descending at their first diverging segment, including nested targets.

All 38 authored C4 vectors pass. The 119+49 inherited files remain byte-identical:
154 evaluated successes and 14 explicit policy rejections; no policy row is an evaluated
success. The pinned jq 1.8.2 arm64 oracle SHA-256 is
2d75340ba57a4b4b4c8708a21c2dc8e958a48aaa8bba13b27f77f6e4c0eca07e.
Golden SHA-256 c8d1df9cd20754eec4fdb7605cdfafa636eafade19067463809f3e7627ab93ee;
subset e6839542d49ccb3f9119cde5ccd0035036fd1ccb54a1d4da2a2cee21aa0201ab.
Planning labels remain context, not qualification. Exact expected tokens are loaded with
an integer/decimal-token-preserving fixture codec, never a floating arithmetic oracle.

Review tests verify zero live storage/counters after scopes and terminal failures,
configured frame recursion, cancellation after actual loop work and malformed source
replay. They exposed and corrected: walk's transform continuation; interpolation's
closing-string transition; assignment scratch double ownership; and a charge calculated
before queued collection refunds drained. The last now checkpoints before calculating
next usage, preventing refunded capacity from being restored. Failed receipts/logs remain
retained. Full native/safety/docs and clean-source integration remain required.

The full native pre-review lane passed 23 commands at source manifest
`aa742411f3d22bc82c681b03944c12772ad52e41b3773269b0d84b9d4e3a2cbc`: debug/release and ASan 291 functions/199 parameter cases, TSan eight shared-state functions, strict-memory warnings zero, five DocC catalogues, existing 49 public probes and pinned suites. A separate source review then reproduced a reduction followed by a parenthesized outer pipe being misclassified. Whole-span recognition and reduce/foreach regressions correct that case; subsequent targeted and hosted checks bind the revised source.

Matched Swift6.4 wasm32 private arithmetic consumer runs passed 738 exact integer/rational cases in WasmKit0.3.1 and Node26.5.0. This is kernel evidence only: the CLI build fails at the unavailable Glibc adapter and has no WASI executable qualification. Five selected library consumers compiled for iPhoneOS and iPhoneSimulator SDK27.2 without the CLI target. The offline slow-sink 2,000/20,000-record observations retain roughly66.5KB logically; process RSS was not measured in that probe.
