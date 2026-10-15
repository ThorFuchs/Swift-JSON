# Borrowed composition proof

This additive slice is confined to one synchronous borrowed native scope and
explicitly instrumented adapter work. It is not a full external importer, schema
compiler/evaluator composition, general callback instruction quota or RSS bound.
No package product or runtime dependency is added.

The exact compiled public declarations live in JSONCompositionScope.swift and
JSONCompositionScope+URI.swift. The native grammar, scalar key identity and exact
number authority are reused. URI work uses core accounting; parsing temporarily
uses the parsing domain and Pointers the pointer domain, then returns to core.
No schema plan ownership is manufactured for URI identity.

Run `python3 Scripts/ci.py --lane composition` and `--lane composition-proof`, followed by affected native,
safety and docs lanes. The ordinary public consumer package is
`Tools/CompositionQualification`; it has no package access, SPI, @testable or
shim. The root supplementary tests use existing package-only observers solely
to locate cancellation and substitution boundaries. They are not the oracle for
undercharging.

The independent authored adapter's golden event trace is queue 65 work/96
logical bytes, scratch 33/64, result 49/80 and final receipt 50/424: totals
197 work and 664 retained bytes. Three buffers remain returned and live. Exact
and one-below caps and an inserted work unit are tested. Omitting one byte's work
or reservation makes the unchanged positive trace assertion fail in a separate
expected-failing test process. This does not prove an arbitrary adapter is honest;
each downstream adapter needs its own ownership ledger and audited charges.

All owned failures latch the first cause. Finalization verifies the original
ledger identity and health and prepays result/report overlap. Scope access is
borrowed and not Sendable; copying, storing, escaping, suspension, construction,
substitution, reset/fork/refund and private ledger access are separately rejected
by the compiler. A new invocation has new allowances and cannot restore the old
invocation's health. There is no public resource-release token in this slice.

The 6.4 compiler crashed when a local nested helper captured the borrowed scope.
Use an explicit `borrowing JSONCompositionScope` helper parameter. Evidence must
retain that failure separately from the intended negative compiler probes.

Qualification receipts belong outside the tracked public source distribution.
They must bind the source manifest, input pins, environment, exact counts, actual
commands/exits, mutant failures and per-platform status. A blocked Linux runtime
or SDK is not a native pass. There is no downstream pin/release authorization
in this proof. The user-facing return supplies materialized receipts and patches.

The direct escaping-closure capture shape also crashes the observed 6.4 compiler
during SIL ownership verification (`Have operand with incompatible ownership?!`,
`copy_addr`). It is preserved under `CompilerBugs` and in failed exploratory
receipts; it is not counted as an intended compiler-negative pass. The negative
escape probe instead attempts to return an escaping closure from an explicit
borrowed-parameter helper and requires a normal ownership diagnostic. These
compiler defects remain usability/qualification limitations, not runtime passes.

Forming a bound method reference also triggers the same observed SIL verifier
crash, both directly and through a borrowed helper. Those two reproducers are
retained separately as compiler limitations. Call an explicit borrowed helper
instead of forming a method value. The return probe uses explicit `return`; an
unused noncopyable expression can infer Void and does not attempt escape.
The storage probe explicitly consumes to test the borrowed-value restriction.

## Compiler investigation follow-up

Reduced no-import reproducers reproduce the same SIL ownership verifier failures
on Apple Swift 6.4.0.34.1 and the installed Swift.org 6.4 release. An explicit
`(scope: borrowing JSONCompositionScope)` closure parameter fixes the nested local
helper and changes escaping capture into the intended diagnostic. The public
consumer now executes that nested form with an independent 55-work/432-byte ledger,
exact and one-below work ceilings. A separate explicit-capture negative build joins
the existing helper-escape probe: 26 public functions, two configurations, two
rejected mutants and 14 intended diagnostic builds.

Bound method references remain compiler defects even with explicit borrowing.
The reduced compiler investigation is separate from intended negative builds;
crashes never count as diagnostic passes. See the CompilerBugs catalog and its
replay command. The final local report retains the prior frozen proof unchanged
and binds successor evidence to this branch's final source identity.

## Controlled native performance replay

`python3 Scripts/qualify_composition_performance.py --output .build/composition-performance`
compares the approved full main base 30631e8fe60201518c00544c172340ec6576e0d5
and the current source. Both use the same Swift 6.4+ compiler, native Release
build engine, benchmark source, runtime path and identical schema resource bytes.
Two warmup sets precede nine samples per process; ABBA ordering yields 18 samples
per source/row. Five operations run for wide512 and the pinned frozen JSON input.
`schema-only` always compiles the same small schema, not the frozen definitions.
Standalone Data/document and Pointer reports are unavailable and remain null.

Every process requires at least 90% idle before and immediately after timing.
A bounded settling period precedes runs; a failed post-run probe invalidates the
controlled result. The 10% review trigger is unchanged. Exit 2 means blocked and
exit 3 requires review; neither is a performance pass or automatic exception.
Logical retention and owned work remain distinct from RSS and caller instructions.
The Composition performance workflow executes this exact harness when its benchmark
files change in a PR, or through optional manual dispatch after default-branch
availability, on an independent native runner, retaining source/fixture/binary/log identities.
It changes no existing required check name, protection or release workflow.
