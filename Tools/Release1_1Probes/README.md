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
