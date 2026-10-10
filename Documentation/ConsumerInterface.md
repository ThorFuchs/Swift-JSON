# Public interface for the downstream server

This note is an observed JSON/JSONSchema integration contract. The separate
[consumer package](../Tools/MCPReadiness/README.md) imports only the public
JSON and JSONSchema products. It has no MCP server, transport or private-meter
dependency. Native CI records its outcomes and source identity with the other public consumers.

The frozen input is MCP schema commit c518f7a927cff918bce35d3522fcdb046d264d7c,
blob 213c58f6d9a1c2ce6ad055afe90bbdb095a29ee8, SHA-256
`ef70b61f99b6d2e5e3b46863822eab08dff6a45bedc7a08914e0e5b133f40203`.
It contains $schema and 155 $defs, with no instance-root assertion. Every vector
uses an explicit $ref wrapper retaining the unchanged definitions. The selected
roots are DiscoverRequest, Tool, SubscriptionsListenResult and CompleteResult.
Twenty frozen cases contain eight positive and twelve negative expectations;
policy exclusions are not used. Generic schema validation does not establish
server authorization, session/version/transport policy or all MCP semantics.

The following actual methods compile in the consumer:

```swift
JSONParser(options: JSONParsingOptions(limits: limits))
    .parseWithReport(bytes) // bytes: [UInt8], report result: JSON
JSONSchemaCompiler(options: JSONSchemaOptions(limits: limits))
    .compileWithReport(raw, retrievalURI: nil, registry: .empty)
    // raw: JSON, report result: CompiledJSONSchema
JSONSchemaValidator(options: JSONSchemaOptions(limits: limits, output: .flag))
    .validateWithReport(instance, against: plan)
JSONWriter(options: JSONWritingOptions(limits: limits))
    .writeWithReport(instance) // result: Foundation.Data
```

The compiler raw overload includes document admission in its meter. The
JSONSchemaDocument overload starts after construction. Do not hide a separate
unreported document construction in a purported fully accounted chain. Schema
wrappers and configuration loaded ahead of the operation are caller preparation;
if constructed with bounded JSON APIs inside a chain, their owned work also needs
accounting. The demonstration parses raw schema text inside its chain and uses
the raw compiler overload. A precompiled shared plan is immutable/Sendable; every
validation has separate mutable evaluation/dynamic-scope/annotation/regex state.

JSONOperationReport<Result>.statistics has accountingVersion 1, domain,
`statistics[.workUnits]`, subsystem counts and peakLogicalRetainedBytes. Limits
are mutable through `limits[JSONResourceMetric]`. The consumer-owned RemainingWork
account supplies remaining finite limits to each stage and subtracts successful
reports with checked subtraction. It subtracts workUnits once: subsystem counts
are additional independent ceilings, already included in the total. Per-search
regex and live/shape capacities retain per-stage semantics. Neither capacities
nor peak retained bytes can be summed into a physical RSS promise.

Successful reports cannot account for an interrupted stage. On any operational
error or cancellation, the account becomes terminal; there is no downstream retry
with a fresh full allowance. The tests prove aggregate exhaustion even when every
stage fits individually, exact-total success, and rejection of a retry after failure.
Caller allocations, arbitrary Codable code, I/O and account/bookkeeping code are
outside the library's owned instruction quota.

A validation result with isValid false is an ordinary schema verdict. JSONFailure
with category resource and its resource.metric/limit/attemptedUsage identify a
budget error. JSONSchemaCompilationFailure identifies an unavailable offline
reference or other compile error; JSONSchemaEvaluationFailure identifies an
operational evaluation error. Cancellation propagates as CancellationError.
Do not convert these thrown failures into isValid false.

For exact IDs keep JSONNumber; integer exponent notation is mathematical integer
notation. `originalLexeme` and JSONWritingOptions(numberStyle: .preserved) preserve
source spelling; default normalized writing may change equivalent spelling.
JSON/JSONObject preserve scalar-distinct keys. Native String dictionaries throw
if their canonical equality collapses keys. Native Float/Double projections
round to the finite target type; use doubleValue(policy: .exact) when required.
External coders cannot restore numbers/keys they already collapsed.

`value.presence(of:)` distinguishes absent, null and value. The synthetic tool
schema is retained raw. `JSONSchemaDocument(raw).nodeWithReport(at: pointer)`
inspects `/properties/value`; declaredAnnotations.presence(of: "x-mcp-header")
is .value("Value"). This is an immediate declaration, with no effective-shape
inference or automatic HTTP header mapping. Unknown metadata stays unknown;
fields unconstrained by the frozen schema are not assigned stricter JSON policies.
