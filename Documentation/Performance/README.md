# Performance and selected optimizations

[Tools/Benchmarks](../../Tools/Benchmarks/README.md) measures twelve public workloads
in release mode with nine samples, three warmups and three iterations per sample.
Compare equal inputs, profiles and configuration on an idle supported host.
A 10% median or retention change is a review trigger, not an automatic veto.

The reviewed 100000-record stream median is 1.0749626803 seconds versus
0.968493986 seconds previously: +10.9932%. Three current runs measured
1.118063139, 1.0952811667 and 1.0749626803 seconds. The unchanged 10% trigger
was exceeded and reviewed. The current cost was accepted for the local candidate;
no threshold or default cap was relaxed and no causal performance improvement
was claimed. A controlled A/B attribution was not performed.

These observations used MacBookPro18,2, Apple M1 Max, 32 GiB, macOS 27,
Swift 6.4 (swiftlang-6.4.0.34.1), Xcode 27.2 and SDK 27.2, with configuration SHA-256
114a8f1279da751fcb1b9af9d5e0cda3e27b33757f960f114ea9262b5c70c728.
Library source is unchanged by public repository preparation. Raw historical
receipts remain in the maintainer's preserved local candidate envelopes.

Scalar scanning retains no reusable record scratch. SIMD/SWAR and literal/start
prefilters remain unselected. Immutable plan-local regex sharing reduced logical
compiler retention from 113986 to 103074 bytes (9.57%) in the preserved experiment;
timing remained within observed variance. Searches retain invocation-owned state.
The stream's logical peak remains 52 bytes. Repeated patterns still consume their
pattern and aggregate-byte quotas; sharing does not bypass admission or work.

Logical retained bytes differ from process RSS. Darwin ru_maxrss is cumulative;
allocator end observations are not isolated workload allocations. These results
make no cross-machine throughput or OS-enforced memory guarantee. Source-attached structural views in unreleased Inspection carry no performance
claim (G4 HOLD). P2 matrix/graph/store/set/retrieval and JSON text-sequence framing
remain deferred.
