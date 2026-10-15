# Experimental composition qualification

This is a distinct SwiftPM package importing only the JSON and JSONSchema public
products. It cannot access the package-native meter or facade implementation.

Run the complete focused gate from the repository root:

```sh
python3 Scripts/ci.py --lane composition
```

The gate executes 12 Swift Testing functions in Debug and Release, this consumer
in both configurations (two positive and four negative outcomes each), and eight
compiler-negative cases. Negative cases use object emission, which catches
ownership diagnostics deferred beyond typechecking. Missing imports never count
as successful rejection. Copy, Sendable sharing, escape, direct construction,
return, scope swap/use/restore, double refund and cross-scope refund are rejected.
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
