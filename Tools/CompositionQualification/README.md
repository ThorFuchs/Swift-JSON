# Experimental composition qualification

This is a distinct SwiftPM package importing only the JSON and JSONSchema public
products. It cannot access the package-native meter or facade implementation.

Run the complete focused gate from the repository root:

```sh
python3 Scripts/ci.py --lane composition
```

The gate executes 20 Swift Testing functions in Debug, Release and ASan, two
concurrent-invocation functions with TSan, strict memory-safety JSON compilation,
and this consumer in both configurations (four positive and six negative outcomes
each). `CompositionRootScale` resolves 1,000 references over 50,000-value trusted
and source-backed roots with balanced limits. The root is admitted once; selected
outputs remain charged individually. The arbitrary-JSON overload retains its
conservative repeated-root admission behavior.

Eighteen compiler-negative cases use object emission, which catches
ownership diagnostics deferred beyond typechecking. Missing imports never count
as successful rejection. Compiler signals, fatal diagnostics and emitted objects
also cannot satisfy a negative case. Copy, Sendable sharing, escape, direct construction,
return, scope swap/use/restore for exact work, retention and caught failures,
double refund and cross-scope refund are rejected.
The policy exposes no transferable owner token or refund. Borrowed root handles
have no public constructor, value accessor or mutation; their private owner
identity rejects use by another scope before navigation.

Fourteen actual-callsite probes retain the original nine programs and add five
explicit-ownership counterparts. Explicit borrowing instance methods prevent the
two bound-method aborts: the escape is rejected, while the nonescaping bound-method
positive remains blocked as unsupported. Four original inferred-capture forms still
abort Swift 6.4. Explicit callback parameter spelling makes invalid captures receive
ordinary diagnostics and makes local-function and closure-literal helper uses compile.
See [the compiler diagnosis](../../Documentation/Architecture/CompositionCompiler.md).

These outcomes remain separate from the 18 semantic rejections. Fourteen Python
harness cases reject setup-log keyword false positives and require an exact
borrowed-self error plus a source-local note for bound-method diagnostics.
The lane completes its checks, then exits 2 with overall `blocked` if known aborts
or unsupported positives remain. A workaround or an ordinary rejection does not
satisfy the original positive requirement.

```sh
swift run -c release --package-path Tools/CompositionQualification CompositionRegression
```

The regression probe uses only APIs that also exist at the pinned baseline. It
warms three batches and records nine samples for byte parsing, source-document
Data parsing, Pointer construction/append/resolve and schema-only compilation.
Build the identical source against each revision, then measure while builds and
safety runs are idle. Timing samples are observations, separate from native
logical work/retention counters; a noisy shared machine cannot establish a
controlled regression gate. They do not substitute for functional or ownership
qualification.

The Data-document and Pointer timing workloads have no native public report; their
raw zero counter placeholders mean unmeasured/N/A. Only byte-parser and schema-only
workloads supply measured native logical work and retention counters. Zero
placeholders must never establish measured counter equivalence.

## Reference-heavy public adapter

The separate fixture target and five Swift Testing functions cover exact scalar/number semantics,
shared exact work/retention boundaries, late failure/cancellation and serial descriptor staging.
Run the composition CI lane to execute both configurations, ASan, eight materialized scale cells
and all 18 source-anchored compiler ownership rejections. Five cells complete and three deliberately reach finite quotas;
those refusals remain operational errors. The initial direct 128/128 balanced capacity assumption
failed and is preserved. Staging the reference array on the same scope qualifies that bounded target
without changing core APIs or limits. See ../../Documentation/Architecture/CompositionQualification.md.
