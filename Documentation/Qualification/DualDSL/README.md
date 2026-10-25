# Dual DSL P1.2 qualification

This development wave qualifies actual engine behavior; the input's Linux 6.2.1 shims
are neither production source nor conformance evidence. See the
[plan](../../Architecture/DualDSL/Plan.md), [decisions](../../Architecture/DualDSL/Decisions.md)
and [progress](../../Architecture/DualDSL/Progress.json).

| Contract | Regression evidence |
| --- | --- |
| Exact number/scalar authority and no silent merge | JSONDSLTests dslV01/V02/V04/V05; actual core constructors/comparisons |
| Omission, null, empty and Boolean schemas | dslV06/V07/V08And09; public compiler/evaluator |
| No inferred schema semantics | dslV10–V17, manual raw/annotation/verdict parity |
| Whole-root finalization ceilings and terminal failure | ResourceLifecycleTests; schema admission shares the same finalizer |
| Entry/inner cancellation and no successful publication | deterministic dslV19 tests with no sleeps |
| Iterative staging lifetime and depth boundary | 5000 staged levels rejected at finite depth; accepted depth 128 |
| Immutable independent finalization/plan invocations | dslSharedFinalizationAndPlansAreInvocationOwned |
| Compile-time domain exclusions and scaling | six original negative fixtures plus the G4 native harness |
| Public module direction, docs and consumer | production manifest checks, native DocC and Examples/DualDSL |

V-03 is a compiler-negative assertion, not a runtime test. V-18/V-19 are actual
resource/cancellation tests. V-20 is repeated exact raw, verdict and annotation parity
across manual and DSL paths. Official JSON/schema suites and their policy exclusions
remain unchanged. Test counts, toolchains, source pins and receipts are reported after
execution, not inferred from this mapping. No gate is closed by this document alone.
