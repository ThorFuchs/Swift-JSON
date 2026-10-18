# Verified public-API recipes

Use the relevant function in the [canonical executable source](../assets/consumer/Sources/Consumer/Consumer.swift).
Every displayed Swift file in this package is compiled as part of that consumer;
there are no separately maintained Markdown Swift fences. The all-eight
[manifest](../assets/consumer/Package.swift) is for acceptance, not minimal use.
The compatibility map lists declaration/DocC hashes and recipe marker IDs.

| Marker / function | Minimal direct imports | Behavior asserted |
| --- | --- | --- |
| exact-presence / exactPresence | JSON | >2^53 parse, checked UInt64 read/report, strict write/roundtrip, absent/null, exact scalar keys, duplicate rejection |
| native-bridge / nativeBridge | JSON, JSONBridges | Integer projection, exact decimal 0.1 rejection, explicit finite rounding, round-trip text |
| schema / schemaEvaluation | JSON, JSONSchema | Offline compile, valid/invalid, finite exhausted evaluation error, incomplete diagnostics with completed verdict, packaged registry integrity loading |
| examples / certifiedExamples | JSON, JSONSchema, JSONSchemaExamples | Fixed seed/profile, repeatable trace/value, attached and independent native verdict |
| streaming / chunkedNDJSON | JSON, JSONStreaming | One-byte chunks split UTF-8/tokens, CRLF, final no-newline record, terminal EOF, truncated record, terminal error and lifetime record quota |
| navigation / navigationCoverage | JSON, JSONNavigation | Physical/virtual roots, complete/restricted/stopped coverage, cumulative work refusal |
| patch / stagedPatch | JSON, JSONPatch | Success, failed later test, caller unchanged, removal distinct from null, Merge Patch |
| html / inertHTML | JSON, JSONHTML | Hostile-looking key/value escaped as inert data; no browser execution |

Copy the asset consumer into a fresh directory outside a library checkout before
running it. It resolves public HTTPS exact 1.6.1 and writes Package.resolved,
cache/config/security/scratch outputs chosen by the caller. Compile and run both
configurations to verify its assertions. Failed checks throw and exit nonzero,
including in Release; a printed success string is not the acceptance predicate.
No library sources, schemas or private meters are copied into this package.
