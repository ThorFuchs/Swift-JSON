# Actual-engine Dual DSL consumer

Run `swift run --package-path Examples/DualDSL DualDSLConsumer` on the supported
Swift 6.4 toolchain. This separate package imports only public products, not
JSONDSLCore, private meters or either signature shim. It checks exact integers,
explicit decimals, scalar-distinct keys, nested arrays, an explicitly selected
local definition, positive/negative verdicts and missing-resource operational failure.

The builder is for trusted authored configuration. Staging and caller computation
are not budgeted; finalization and schema-document admission use finite limits.
This consumer is not a whole-pipeline resource or downstream protocol claim.
