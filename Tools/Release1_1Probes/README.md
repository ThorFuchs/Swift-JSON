# First milestone qualification subjects

These files support the [1.1 plan](../../Documentation/Architecture/Release1.1/Plan.md).
They are not runtime products or a second JSON engine. Reader/index implementations
live under Tests/JSONTests/Release1_1 and use the actual native core meter via testable
imports. Consumer.swift exercises exported prototype shapes without private meters.
TaskEscape and TaskTransfer are intentional compiler-negative fixtures; they are
not targets in the mobile consumer package.

SwiftDataShape is an explicit Version 1 Codable *shape* used only for SDK compilation;
it does not implement or qualify the strict persistence codec. The mobile consumer
imports all four products and compiles schema-resource/regex call sites. SDK builds,
simulator runtime correctness and device measurements are separate claims.

Use Scripts/qualify_release_1_1.py through Scripts/ci.py where applicable. Index
measurements must run on an otherwise idle release-native host. Samples identify
input hashes, finite policy, work, logical peak and refusals. They do not measure
isolated allocator allocations, process RSS or physical mobile throughput.

The small production increment is reviewed in
[BenchmarkReview](../../Documentation/Architecture/Release1.1/BenchmarkReview.md).
Its deterministic lookup-stage corpus can be repeated after building the real
release testable module on the supported toolchain:

```sh
swift test -c release --filter wideLookup
xcrun swiftc -swift-version 6 -O -parse-as-library \
  -I .build/out/Products/Release -L .build/out/Products/Release -lJSON \
  Tools/Release1_1Probes/LookupBenchmark.swift -o .build/lookup-benchmark
.build/lookup-benchmark .build/lookup-samples.json
```

For A/B, build the baseline libraries in a separate worktree and compile the same
benchmark source against those libraries. Record both core source identities and
the benchmark/input hashes. Run measurements while local verification builds are
idle; preserve all samples, refusal outcomes and repeated-run variance.
