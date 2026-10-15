# Experimental composition qualification

This is a distinct SwiftPM package importing only the JSON and JSONSchema public
products. It cannot access the package-native meter or facade implementation.

Run the complete focused gate from the repository root:

```sh
python3 Scripts/ci.py --lane composition
```

The gate executes 12 Swift Testing functions in Debug and Release, this consumer
in both configurations (two positive and four negative outcomes each), and 11
compiler-negative cases. Negative cases use object emission, which catches
ownership diagnostics deferred beyond typechecking. Missing imports never count
as successful rejection. Copy, Sendable sharing, escape, direct construction,
return, scope swap/use/restore for exact work, retention and caught failures,
double refund and cross-scope refund are rejected.
The policy exposes no ownership token or refund, so those operations are invalid
public programs rather than runtime token failures.

```sh
swift run -c release --package-path Tools/CompositionQualification CompositionRegression
```

The regression probe uses only APIs that also exist at the pinned baseline. It
warms three batches and records nine samples for byte parsing, source-document
Data parsing, Pointer construction/append/resolve and schema-only compilation.
Build the identical source against each revision, then measure while builds and
safety runs are idle. Timing samples are observations, separate from native
logical work/retention counters; a noisy shared machine cannot establish a
controlled regression gate. No release or downstream pin change follows from
successful qualification.

The Data-document and Pointer timing workloads have no native public report; their
raw zero counter placeholders mean unmeasured/N/A. Only byte-parser and schema-only
workloads supply measured native logical work and retention counters. Zero
placeholders must never establish measured counter equivalence.

## Reference-heavy public adapter

The separate fixture target and five Swift Testing functions cover exact scalar/number semantics,
shared exact work/retention boundaries, late failure/cancellation and serial descriptor staging.
Run the composition CI lane to execute both configurations, ASan, eight materialized scale cells
and all 11 compiler rejection cases. Five cells complete and three deliberately reach finite quotas;
those refusals remain operational errors. The initial direct 128/128 balanced capacity assumption
failed and is preserved. Staging the reference array on the same scope qualifies that bounded target
without changing core APIs or limits. See ../../Documentation/Architecture/CompositionQualification.md.

## Reconciled independent accounting proof

Run `python3 Scripts/ci.py --lane composition-proof` in addition to the reference-import
lane above. It runs 26 public functions in Debug/Release, two actual omitted-charge
mutants and 14 unrelated SwiftPM diagnostic builds. `Negative/` preserves the 11
original compiler cases; `ProofNegative/` contains the independent 14-case suite.
Compiler crashes are retained separately under `CompilerBugs/` and never satisfy
an intended rejection. The package uses ordinary public JSON/JSONSchema products.
See [the reconciliation record](../../Documentation/Qualification/Composition/Reconciliation.md).
