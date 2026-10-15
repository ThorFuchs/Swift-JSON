# Exact filter arithmetic

C3 builds on query core 6e8f145 / draft PR #24. Original private code implements
base-ten unsigned working magnitudes plus native sign/coefficient/exponent values.
No Double, Float or Foundation Decimal is an arithmetic authority. Numeric binary
operators clear originalLexeme and normalize computed zero. Untouched selected
values preserve their admitted spelling; null's identity overload selects a value.

Addition bounds exponent alignment before dense storage. Schoolbook multiplication
uses UInt16: digit product + stored digit + carry <=99; addition <=19. Subtraction
fits Int16. Long division maintains r<divisor before consuming the next digit, so
a quotient digit is <=9. GCD reduces exact rationals; only 2/5 denominator factors
produce a default finite decimal. Repeating division raises catchable inexactDivision;
zero division and fractional remainder are distinct catchable domain errors.
All loops spend numeric work, including normalization, factor removal and carries.

Normalized coefficient drafts retain their buffer lease through full result admission;
withExtendedLifetime prevents an optimized-away lease from refunding a still-live
number alias. Working storage has invocation leases and a checked 2*numberDigits+2 scratch
bound; that is a derived storage bound, not an iteration guard. Result digits,
exponent and normalized token bytes retain independent native limits. Host-index
narrowing is checked before allocation. A 1e1000000+1 probe fails before dense
storage; multiplication by zero uses exact sparse computation. Numeric work and
retention cap/cap-minus-one checks exercise actual operations. A 300-digit product
is cancelled after 5,000 charged units inside its nested multiply loop and reclaims
all scratch while retaining terminal health. wasm32 execution is still a gate.

`--division-scale N --rounding half-even` is an explicit pair. It quantizes every
numeric division, including finite values; reports count nonzero discarded
remainders. Builtin round instead uses ties away from zero. The cumulative report
uses totalInputBytes/totalOutputBytes/totalWorkUnits and preserves completed versus
terminal failure. Diagnostics carry metric/limit/attemptedUsage/overflow and source
byte offsets when known. Version 1 limits files may omit the version field.

String/array/object operator overloads preserve exact scalar/key identity, bounded
collection ownership and insertion order. Recursive object merge uses an explicit
stack. Range yields one exact step at a time with end-exclusive comparison and a
nonzero step; it does not allocate a complete output array or impose a hidden
10,000-step cap. All arguments/replays and resulting collectors remain finite.

Independent fixture generator: Python integers/fractions.Fraction, seed 0x140C3,
738 cases, SHA-256 57b2affc52c872fdbc9e6cb25168bdd8b5999db6d8e5d8a988ff99cbf2c7accb.
Ten arithmetic tests and 17 authored C3 subprocess vectors pass. Full native,
safety and DocC refresh passed on the corrected handoff source; see Qualification.md.
The authored fixture bytes remain unchanged. Vector invocation adds the documented
`--` terminator so negative-leading filters are operands, keeping unknown flags
strict. The initial two argv failures are retained, not counted as successes.

Review corrected a prototype probe expecting 2*D+2 overflow for D<Int.max:
on 64-bit that expression still fits UInt64. The final test instead proves a small
allocation under a large finite D works, then rejects Int.max at the actual host
allocation boundary; no configuration or test was weakened to hide a real overflow.

Release-mode integration caught an actual domain-handoff issue after coefficient
leases were extended: output's scratch baseline included queued refunds, then an
inner checkpoint drained them. The job domain handoff now drains refunds before
new-stage baselines. A regression verifies the live result remains charged while
dead drafts disappear and work never refunds. The failed native receipt/vectors
remain retained; refreshed lanes are required after this correction.
