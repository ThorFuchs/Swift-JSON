# Finite resource contract

ResourceProfiles.json is the machine-readable policy: 49 finite metrics, logical weights version 1.
E06 additionally requires totalScannedNodes across the enclosing root-array document.
Every composed owned operation uses one cumulative context; helpers never reset it.

These contracts describe the public behavior and its resource boundaries.

## Resource profiles and counter semantics

The three profiles below are finite initial policy values. Balanced is the default. Conservative is suitable for smaller untrusted documents; offline permits larger trusted research jobs while remaining finite. They are generic policies, not MCP wire limits. Native boundary tests and representative calibration observations qualify their current behavior; they do not prove hard RSS or throughput guarantees, and changes to published defaults require changelog documentation.

MiB means 1,048,576 bytes; GiB means 1,073,741,824 bytes. All maxima are inclusive. Admission of N succeeds at a limit of N; the next charged unit fails before growth. Checked UInt64 counters avoid wrapping. Configuration conversion/reservation into Int uses checked arithmetic. A configuration is rejected if inconsistent or beyond representable supported capacity. The twelve UInt64 work/lifetime ledgers listed in [the WASI contract](WebAssembly.md) are not Int capacities; their finite maxima must be below UInt64.max. All other metrics retain their Int capacity guard. Zero is meaningful for quotas that forbid an operation; cancellation quantum must be positive and at most 1,024. There is no Int.max, UInt64.max, or implicit unlimited default.

### Document and core limits

| Metric | Unit | Conservative | Balanced default | Offline |
| --- | --- | ---: | ---: | ---: |
| inputBytes | bytes | 4,194,304 | 33,554,432 | 268,435,456 |
| maxDepth | open containers | 64 | 128 | 256 |
| nodes | values | 100,000 | 1,000,000 | 4,000,000 |
| objectMembers | members per object | 20,000 | 100,000 | 500,000 |
| arrayItems | items per array | 100,000 | 1,000,000 | 4,000,000 |
| stringBytes | decoded UTF-8 bytes per string | 1,048,576 | 8,388,608 | 67,108,864 |
| aggregateTextBytes | decoded UTF-8 bytes | 4,194,304 | 16,777,216 | 134,217,728 |
| keyBytes | decoded UTF-8 bytes per key | 16,384 | 65,536 | 262,144 |
| numberDigits | coefficient digits per token | 1,024 | 4,096 | 16,384 |
| numberTokenBytes | ASCII bytes per number | 2,048 | 8,192 | 32,768 |
| absoluteExponent | absolute mathematical exponent | 100,000 | 1,000,000 | 10,000,000 |
| retainedBytes | logical live bytes | 16,777,216 | 67,108,864 | 536,870,912 |
| workUnits | primitive operations | 8,000,000 | 64,000,000 | 512,000,000 |
| numericWorkUnits | decimal limb operations | 250,000 | 1,000,000 | 8,000,000 |
| outputBytes | emitted UTF-8 bytes | 4,194,304 | 33,554,432 | 268,435,456 |
| sourceMapEntries | entries | 100,000 | 1,000,000 | 4,000,000 |
| issues | records | 32 | 128 | 512 |
| diagnosticBytes | UTF-8 bytes | 65,536 | 262,144 | 1,048,576 |
| cancellationQuantum | charged work units | 1,024 | 1,024 | 1,024 |

Input accounting includes whitespace. Node count includes each root/container/scalar value but excludes object-key tokens. Container depth is the number of currently open containers: a scalar root is 0, root object/array is 1. Aggregate text counts decoded key and string bytes; number lexemes, source copies and index storage charge retainedBytes separately. Individual member/item limits are per container; nodes and work impose aggregate bounds.

Logical retainedBytes is a reproducible package accounting quantity, not heap allocation or process RSS. Counter version 1 reserves 32 logical bytes per node, 24 per member, 16 per array slot and parser/evaluation frame, 32 per source-map entry, index slot and annotation entry, 16 per regex instruction, 32 per regex state record, and actual payload bytes for strings, keys, numbers, lexemes, source storage and owned buffer capacities. Shared payload is counted once within one logical graph, while distinct owned copies and live slots are charged separately. Charge each logically owned live slot even when copy-on-write shares physical memory; releasing a slot refunds retained-state quota only. Regex grammar nesting uses the core maxDepth ceiling, and instruction/state/capture storage uses the regex limits and these weights. The implementation publishes these weights and refines them with native measurement. No caller-facing claim converts this counter into an operating-system hard memory cap.

For preallocated caller Data/String/JSON input, bytes and traversal charge admission/work, but already-owned caller allocations do not become library allocations. An opt-in source copy, decoded model, resized index, stream buffer, output Data and source map do. If an output buffer is handed off, its quota is not refunded until the ownership contract relinquishes it; waiting on a slow sink cannot accumulate another uncharged buffer.

### Schema limits

| Metric | Unit | Conservative | Balanced default | Offline |
| --- | --- | ---: | ---: | ---: |
| schemaDocuments | documents including root | 16 | 128 | 512 |
| schemaBytes | total admitted resource bytes | 4,194,304 | 33,554,432 | 268,435,456 |
| schemaNodes | nodes across resources | 20,000 | 100,000 | 1,000,000 |
| referenceEdges | edges | 20,000 | 200,000 | 2,000,000 |
| compileWorkUnits | primitive operations | 4,000,000 | 32,000,000 | 256,000,000 |
| compiledPlanBytes | logical retained bytes | 8,388,608 | 33,554,432 | 268,435,456 |
| evaluationWorkUnits | primitive operations | 2,000,000 | 16,000,000 | 128,000,000 |
| evaluationFrames | active frames including reference/dynamic scopes | 256 | 1,024 | 4,096 |
| annotationEntries | internal evaluated-location and output entries | 20,000 | 100,000 | 1,000,000 |
| annotationBytes | logical retained bytes | 2,097,152 | 8,388,608 | 67,108,864 |
| regexPatternBytes | UTF-8 bytes per pattern | 4,096 | 16,384 | 65,536 |
| aggregateRegexPatternBytes | UTF-8 bytes | 65,536 | 262,144 | 2,097,152 |
| regexProgramInstructions | instructions across plan | 20,000 | 100,000 | 1,000,000 |
| regexCompileWorkUnits | primitive operations | 250,000 | 2,000,000 | 16,000,000 |
| regexSearchWorkUnits | primitive operations per search | 100,000 | 500,000 | 4,000,000 |
| aggregateRegexWorkUnits | primitive operations per evaluation | 250,000 | 2,000,000 | 16,000,000 |
| regexRetainedBytes | logical live match state bytes | 2,097,152 | 8,388,608 | 67,108,864 |
| regexCaptureGroups | groups per pattern | 128 | 512 | 2,048 |

Compiler resources share one schemaNodes/schemaBytes/referenceEdges/compileWork budget across the root and registry snapshot; nested resource loading cannot restart it. Each independently supplied resource also passes the configured core parse/materialization profile. The compiledPlanBytes ceiling also admits temporary compiler-owned buffers and graph slots before allocation; releasing scratch refunds that live capacity. Program-size and pattern-byte limits apply before regex compilation. Repeated references reuse immutable plan identities instead of duplicating unlimited compiled nodes.

Evaluation first admits the instance against its core limits, charging traversal. Total evaluation work includes comparisons, numeric work, regex work, reference/dynamic-scope traversal, annotations and diagnostics. Subsystem caps are additional ceilings inside the total; a unit charged to a regex bucket is also charged to evaluation total work. The same applies to numeric and compile regex work. Active frames bound dynamic scopes and recursive schemas independently of JSON container depth.

Budgets do not reset at anyOf/allOf/oneOf branches, references, contains children, format checks or regex search start positions. Operational failures propagate through branch logic. An invalid branch can participate in a normal verdict; an exhausted branch cannot be treated as simply invalid to let another branch pass.

### Streaming and Patch limits

| Metric | Unit | Conservative | Balanced default | Offline |
| --- | --- | ---: | ---: | ---: |
| chunkBytes | accepted source bytes per chunk | 65,536 | 262,144 | 1,048,576 |
| pendingEvents | unconsumed complete events | 1 | 1 | 1 |
| pendingValues | unconsumed complete records | 1 | 1 | 1 |
| totalInputBytes | bytes per iterator lifetime | 268,435,456 | 1,073,741,824 | 68,719,476,736 |
| totalRecords | records per iterator lifetime | 100,000 | 1,000,000 | 16,000,000 |
| totalWorkUnits | primitive operations per iterator lifetime | 512,000,000 | 2,147,483,648 | 137,438,953,472 |

Streaming also applies core limits per record; aggregate text/number/depth caps reset only after a complete record and release of its owned state. Iterator-lifetime quotas never reset. A JSONEventSequence reading a single document has one record. A value/NDJSON sequence checks total bytes, work and record count. Accepted chunk size is checked as soon as next() delivers it, before library copying or parsing. The source's prior allocation is owned by the caller and cannot be prevented by the reader.

One pending event/value is an ownership rule, not a claim that a whole token has constant size. An event's complete key/string may occupy the configured key/string limit. The incomplete token, active stack, current admitted source chunk and current event remain charged. A value stream additionally retains one admitted document. The memory claim is bounded state independent of total stream length, with a documented bound related to these configured maxima; it is not constant few-byte memory.

| Metric | Unit | Conservative | Balanced default | Offline |
| --- | --- | ---: | ---: | ---: |
| operations | operations | 128 | 1,024 | 10,000 |
| pointerBytes | UTF-8 bytes per encoded Pointer | 4,096 | 16,384 | 65,536 |
| pointerTokens | tokens per Pointer | 64 | 128 | 256 |
| patchWorkUnits | primitive operations | 2,000,000 | 16,000,000 | 128,000,000 |

Patch applies core value/output/depth/retained limits to its staged result after each change, not just after the final operation. Copies and comparisons consume cumulative patch work; removed data does not refund work. Total inserted payload must be charged even if shared physically. Pointer text and token limits also apply to stand-alone Pointer operations.

### Work and cancellation

One work unit means one admitted byte scan/copy, scalar or decimal-limb examination, frame/node visit, index/member probe, regex VM instruction or comparable primitive operation. A comparison scanning N bytes charges N rather than one comparison. Decimal multiplication charges operand-pair work. Regex backreferences charge compared subject units. A fast system routine is invoked only after a checked charge for its bounded input; algorithms that can do superlinear hidden work must expose their own counter.

Check limits before push, append, reserve, plan insertion, sink handoff and other expensive growth. Check cancellation at entry, before allocation or suspension, on return from caller-owned async I/O, and after at most 1,024 charged units in owned loops. This specifies a work interval, not a millisecond latency promise. Native latency evidence supplies the practical measurements. Long error rendering, cleanup and rejection paths are included.

The same invocation meter reaches all library helpers. No timer around a synchronous opaque engine is an enforcement mechanism. Trusted custom callbacks, upstream byte production, sink code and user Codable implementations have explicitly documented ownership boundaries; a generic library cannot enforce instruction quotas inside arbitrary user code.

## E08 Operation statistics

Expose opt-in reports from owned operations using counters already required for enforcement. A report pairs the ordinary result with versioned statistics: bytes admitted/emitted, values visited, charged work, subsystem work where applicable, and peak logical retained bytes. Count units and accounting-version identity are part of the documentation.

Do not put unconditional statistics payloads into every JSON value or add a global metrics/logger dependency. Report-producing entry points may wrap results; ordinary APIs remain concise. Conditional Sendable follows the result's actual type, particularly for user-decoded non-Sendable models. A structured resource failure already reports its limit/attempted usage; extending its bounded diagnostic context must not retain the full input.

Logical retained accounting is not process RSS or exact allocation count. Clock measurement belongs in benchmarks or an explicitly separate timing option. Payloads, member names and source bytes are absent from statistics by default. Mandatory work counters stay active when reporting is disabled.

This makes resource tuning, reproducible failures and benchmark interpretation easier without adding a telemetry system. Verify counters at exact boundary values, their behavior on growth/refund, aggregate composition, disabled-report overhead and agreement between scalar and optimized paths.

## Selected scalar retention policy

maxReusableBufferBytes is 512 KiB conservative, 2 MiB balanced and 8 MiB offline
at record boundaries. The selected scalar reader has no reusable scratch pool,
so retained reusable scratch is zero. Live owned capacities still charge
retainedBytes. Scalar scanning and immutable plan-local regex sharing remain the
qualified choices; no SIMD or prefilter optimization is claimed. Native performance
observations are separate from the logical policy in [performance notes](../Performance/README.md).

## Optional schema example generation (1.6 development)

JSONSchemaExamples uses the same 49 caps and logical weights, with a separate finite
preparation budget and one cumulative generation/evaluation budget per invocation.
All candidates, including false verdicts, share that generation ledger. Generation
limits intersect validation limits without changing evaluator policy; a positive
finite maximumAttempts (default 16) additionally bounds candidate checks.

The [metric scope](Release1.6/SchemaExamplesLimits.md) distinguishes cumulative work,
per-materialization capacities, logical reservations and metrics for operations the
generator does not perform. The [compiled public guide](../../Sources/JSONSchemaExamples/Documentation.docc/PoliciesAndLimits.md)
demonstrates checked remaining work. Certification statistics include conservative
staging reservations; transfer or failure ends the invocation's ownership. A failed
call returns no successful report. No independent peak sums, RSS/heap hard caps or
caller instruction guarantees are implied. Default profiles are unchanged.

## Experimental synchronous composition

`JSON.withComposition` borrows a noncopyable, non-Sendable facade over one native
invocation. Native methods and instrumented external work consume the same work
ceiling. The borrowing closure prevents temporary scope substitution. All owned
errors latch; catching one cannot create a successful report. Restriction retains
accepted capacities and consumed work. JSONSchema adds offline URI operations
through package access without a dependency from JSON to JSONSchema. URI identity
and adapter reservations use core, never compiledPlanBytes or compileWorkUnits.

The initial ownership policy is conservative: no public refunds or owner tokens.
External reservations and native result ownership survive until scope completion;
re-admitted roots and selected result graphs are reserved again even for aliases.
The full Data-to-array reservation precedes allocation and remains charged
alongside the root, source bytes, spans, resources and final result. Native scratch
uses its existing release rules. The logical peak is a maximum of this single
ledger, not a sum of independent stage peaks. Arbitrary callback instructions,
uninstrumented adapter allocations and process RSS are outside the claim. A public
JSONOperationReport initializer permits pairing statistics with another result;
its type alone does not establish provenance or adapter completeness. See the
[composition guide](../../Sources/JSON/Documentation.docc/Composition.md).

## Composition completion accounting


The additive borrowed scope uses one original core ledger and the existing 49
metrics/default profiles. It does not introduce adjustable counters or widen any
cap. `chargeExternalWork` charges aggregate work before adapter work;
`reserveExternalLogicalBytes(bytes,count:overhead:)` checks multiplication then
addition and live retention before growth. Zero is valid but never establishes
that opaque caller storage is free. All reservations are conservative until scope
exit; repeated admission and physical aliases count again. Caller instructions,
allocator capacity and process RSS remain outside this contract.

`parseDocument` checks the full Data length against input and retained limits
before allocating its copied byte buffer, charges each copied byte, then invokes
the existing strict parser/source mapper. Caller Data is excluded. Input capacity
is per document: the preceding input count is checked and retired into the same
cumulative report before the next document. Work, retention, accepted-capacity
history and first-failure identity never restart. Remaining core counts are
conservative across the invocation; full source bytes/root/map and re-admitted
Pointer inputs/outputs remain charged. URI identity is core work/storage, never
schema compilation or compiledPlanBytes.

Completion admits an additional 424 logical bytes (32 header + 49 eight-byte
counter slots) and 50 work units (49 counter copies and one final work update).
All result reservations overlap this report buffer. Overflow, quota failure and
cancellation prevent a completed result/report even when caught by the adapter.
No report is emitted after an error. Native accounting-version-1 weights and the
ordinary entry points' accounting stay unchanged. This proof slice has no public
release/promote tokens, refunds or partial reports. Independent adapter events
and failing omitted-charge mutants qualify the authored adapter only.
