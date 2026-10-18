# Public projection consumer

This independent SwiftPM package depends on public JSON, JSONNavigation and
JSONInspection products. Run `swift run --package-path Tools/ProjectionQualification
ProjectionConsumer` from the repository root. It executes 16 named cases using
public APIs only: exact physical intervals/paths/values, source coherence, complete
table admission, scalar-distinct columns, three-state presence, empty/equal rows,
late refusal, finite bounds, inclusive work/retention and cancellation health.

`Scripts/qualify_public_projections.py` checks those exact identities in Debug,
Release and ASan, compiles/runs all three DocC guide blocks in both configurations,
and requires 18 ordinary full-codegen access/invariant diagnostics. The separate
private-storage qualifier retains the original P1 reducer/storage proofs. No new
product/dependency or platform/runtime/performance claim is introduced.
