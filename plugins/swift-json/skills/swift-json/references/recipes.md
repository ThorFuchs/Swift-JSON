# Verified public-API recipes

Use the relevant function in the [canonical executable source](../assets/consumer/Sources/Consumer/Consumer.swift).
Every displayed Swift file in this package is compiled as part of that consumer;
there are no separately maintained Markdown Swift fences. The all-twelve
[manifest](../assets/consumer/Package.swift) is for acceptance, not minimal use.
The compatibility map lists declaration/DocC hashes and recipe marker IDs.

| Marker / function | Since | Minimal direct imports | Behavior asserted |
| --- | --- | --- | --- |
| exact-presence / exactPresence | 1.6 | JSON | >2^53 parse, checked UInt64 read/report, strict write/roundtrip, absent/null, exact scalar keys, duplicate rejection |
| native-bridge / nativeBridge | 1.6 | JSON, JSONBridges | Integer projection, exact decimal 0.1 rejection, explicit finite rounding, round-trip text |
| schema / schemaEvaluation | 1.6 | JSON, JSONSchema | Offline compile, valid/invalid, finite exhausted evaluation error, incomplete diagnostics with completed verdict, packaged registry |
| examples / certifiedExamples | 1.6 | JSON, JSONSchema, JSONSchemaExamples | Fixed seed/profile, repeatable trace/value, attached and independent native verdict |
| streaming / chunkedNDJSON | 1.6 | JSON, JSONStreaming | One-byte chunks split UTF-8/tokens, CRLF, final no-newline record, terminal EOF, truncated record, terminal error and lifetime record quota |
| navigation / navigationCoverage | 1.6 | JSON, JSONNavigation | Physical/virtual roots, complete/restricted/stopped coverage, cumulative work refusal |
| patch / stagedPatch | 1.6 | JSON, JSONPatch | Success, failed later test, caller unchanged, removal distinct from null, Merge Patch |
| html / inertHTML | 1.6 | JSON, JSONHTML | Hostile-looking key/value escaped as inert data; no browser execution |
| located-stream / locatedRootArray | 1.8 | JSON, JSONStreaming | Exact UTF-8 byte spans with leading whitespace and multi-byte text, completion event, provisional yields before a truncated-array failure |
| shape-snapshot / shapeAndSnapshot | 1.7 | JSON, JSONNavigation, JSONInspection | Observed column kinds, explicit null versus missing, complete versus prefix coverage, snapshot records and values |
| batch / orderedBatch | 1.9 | JSON, JSONInspection | Ordered repeats, exact >2^53, null as value, `optionalValues` nil only for missing, wrong-kind and missing errors, request cap |
| store / configuredStore | 1.9 | JSON, JSONInspection | Integer IDs by exact value, no kind conversion, scalar-distinct string IDs, complete follow, batch read, follow capacity error, owner-bound positions, dangling link refusal |
| transform / boundedTransform | 1.7, 1.9 | JSON, JSONTransform | Pull-to-EOF exact output with preserved numbers, terminal result limit, `selectIndices`, `incompleteSelection` |
| dsl / authoredDSL | 1.7 | JSON, JSONSchema, JSONValueDSL, JSONSchemaDSL | Authored exact value with distinct scalar keys, authored schema valid/invalid, offline missing-reference compile failure |

Snapshot records report `JSONTraversalKind`, which JSONNavigation declares;
Inspection does not re-export it. Typed paths (`JSONLocationComponent`) are core.

Copy the asset consumer into a fresh directory outside a library checkout before
running it. It resolves public HTTPS exact 1.9.0 and writes Package.resolved,
cache/config/security/scratch outputs chosen by the caller. Compile and run both
configurations to verify its assertions. Failed checks throw and exit nonzero,
including in Release; a printed success string is not the acceptance predicate.
No library sources, schemas or private meters are copied into this package.
