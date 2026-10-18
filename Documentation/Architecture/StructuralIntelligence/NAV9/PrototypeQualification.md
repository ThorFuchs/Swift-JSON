# NAV9 private prototypes — qualification contract

This is original Apache-2.0 experimental source in JSONInspection, not a public
product/API addition. The current public Navigation56/Inspection95 and ten-product
inventory are preserved. Set and numeric matrix constructors are package-only,
with fileprivate initializers; an external consumer must fail to name/construct
them. They remain out of released examples and the public DocC symbol surface.

## Final declarations under test

- `package JSONStructuralSetProjection.build(document:at:limits:maximumUniqueItems:)`
  returns a complete source-attached operation report. Immutable metadata stores
  input count, selected path and first physical representative indices. `member`
  performs a new explicit finite full-source-admitted read.
- `package JSONNumericMatrixProjection.build(document:at:limits:maximumRows:maximumColumns:maximumElements:)`
  returns complete rectangular exact-numeric evidence. `transposed()` copies only
  fixed orientation metadata; `element(row:column:limits:)` is a new explicit read.
- `package mutating JSONTraversalContext.equalArrayElements(at:lhs:rhs:)` selects
  two positions in the admitted original array and calls core JSONComparison with
  the original meter. No scope, meter or selected value escapes this helper.

See StructuralSetADR.md and NumericMatrixADR.md for finite defaults, logical
weights, failure/zero-shape semantics and deliberate deferrals. Calling public
comparison/read constructors *inside* an owned reducer is forbidden: that would
create a second operation. Later explicitly requested reads are separate reports.

## Required evidence

`P2Cases.json` pins46 Swift Testing functions: SSET01–18, MAT01–18, CORE01–10.
`P2Fixtures.json` pins18 unchanged packet fixtures and two original graph/store
premise datasets. `verify_p2_fixtures.py` uses independent pair/scalar/Decimal
semantics; it proves expected data only, not Swift conformance or graph/store
engines. Existing Navigation/Inspection/N3/P1 tests, all49 cap witnesses and126
maintenance identities are preserved. CI checks exact identities and counts.

`qualify_p2_borrowing.py` requires full Debug/Release codegen: two positive and ten
ordinary negative outcomes plus seven runtime proofs/configuration. The original
reducer two-positive/twenty-negative gate remains separate. `qualify_p2.py` links
real JSON/Navigation/Inspection objects, requires six private runtime consumer
cases/configuration and twelve access-control/immutability diagnostic outcomes.
Compiler crashes, unrelated diagnostics, missing runtime cases and empty reports
are failures. The Python harness tests the rejecting receipt/discovery policies.

Final receipts must cover Debug/Release, strict memory/concurrency, ASan/TSan,
native and Linux architectures, supported WASI Node/WasmKit scopes, Apple SDK
builds, public consumers, DocC and reproducible Git-free source. An unexecuted lane
is a blocker/limitation, never a pass. All logs must bind to actual source inputs;
earlier NAV8 or dirty-source runs establish provenance only. Failed attempts stay
visible beside retries in the private return. No timing, throughput or RSS result
is implied by deterministic work/retained-byte counters. Branch A owns G4.
