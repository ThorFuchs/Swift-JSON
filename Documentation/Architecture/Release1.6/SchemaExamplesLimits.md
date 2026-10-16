# Schema example resource scope

The current API uses the existing 49 finite metrics and version 1 logical weights.
Defaults in [ResourceProfiles.json](../ResourceProfiles.json) are unchanged. This
mapping describes when metrics apply, rather than claiming each metric charges
work in every generation. [G5 resources](G5Resources.md) defines ownership and
terminal behavior; [the compiled guide](../../../Sources/JSONSchemaExamples/Documentation.docc/PoliciesAndLimits.md)
demonstrates policy and checked remaining work using public APIs.

| Metrics | Scope in schema examples |
| --- | --- |
| workUnits, numericWorkUnits | Cumulative preparation work, then a separate cumulative generation ledger; generation includes rejected candidates, native validations and final hash |
| evaluationWorkUnits, aggregateRegexWorkUnits | Cumulative over every native evaluation in one generation; included in workUnits |
| compileWorkUnits, compiledPlanBytes | Preparation compiler-domain work and logical reservations, including preparation serialization/hashing scratch |
| schemaDocuments, schemaBytes | Preparation root/registry admission and snapshot capacities |
| schemaNodes, referenceEdges | Preparation compilation plus bounded generation declaration/conjunction/reference discovery |
| retainedBytes | Conservative logical live reservations across all owned phases; release discarded ownership, never work; report certification and peak separately |
| inputBytes, outputBytes, nodes, aggregateTextBytes | Capacity per materialization; retire between values while preserving lifetime report totals and work |
| maxDepth, objectMembers, arrayItems | Before container/frame growth and each value's container cardinality; not lifetime generated-depth totals |
| stringBytes, keyBytes, numberDigits, numberTokenBytes, absoluteExponent | Individual exact token/value capacities and checked synthesis scratch; no implicit dense unlimited exponent expansion |
| evaluationFrames | Bounded pending discovery/construction and native evaluation state |
| issues, diagnosticBytes | Native diagnostic charges remain cumulative after false verdicts; diagnosticBytes also bounds complete abstract trace bytes |
| annotationEntries, annotationBytes | Native evaluated-location/output state; discarded live annotation bytes can be released while work/entry admission stays charged |
| regexPatternBytes | Preparation/native regex pattern admission and generation proposal-scanner source capacity |
| aggregateRegexPatternBytes, regexProgramInstructions, regexCompileWorkUnits, regexCaptureGroups | Native preparation regex compilation; not a new generation matcher or compiler |
| regexSearchWorkUnits, regexRetainedBytes | Native per-search ceiling and logical live state; per-search retirement does not reset aggregateRegexWorkUnits |
| pointerBytes, pointerTokens | Native compiler/evaluator location and diagnostic Pointer helpers |
| cancellationQuantum | Positive and at most 1,024; entry, owned growth and loop checkpoints also apply |
| sourceMapEntries | No new generator source map; caller-admitted document/source-map ownership precedes preparation |
| chunkBytes, pendingEvents, pendingValues, totalInputBytes, totalRecords, totalWorkUnits, totalScannedNodes, maxReusableBufferBytes | Streaming metrics; generation opens no stream or reusable streaming pool; entries remain finite and policy-bound |
| operations, patchWorkUnits | Patch-only metrics; generation performs no Patch operation |

`maximumAttempts` is the additional finite search ceiling (default 16), not a 50th
JSONResourceMetric. Limits are inclusive and quota arithmetic is checked. Capacity-only
checks may report zero. Cancellation propagates as CancellationError, separately
from JSONFailure resources and JSONSchemaExampleFailure incomplete search/proofs.

Preparation and generation are distinct operations. Each owns one ledger and no
nested helper resets cumulative work. A successful result reports certification;
remaining reservations end on transfer or failure. Conservative arena reservations
can exceed actual temporary liveness. Independent peaks must not be added as if they
were a simultaneous live bound. Logical bytes are not RSS, allocator size or retained
caller output; work units are not elapsed time or arbitrary caller instruction quotas.

For a caller composition spanning several public calls, subtract successful aggregate
work once, preserve subsystem ceilings independently, and stop on an error/cancellation.
A failed call has no successful report; a fresh full quota would lose the cumulative
bound. Native boundary evidence and unchanged default policies do not prove hard RSS
or throughput guarantees. Full 49-probe/platform release execution remains G7.
