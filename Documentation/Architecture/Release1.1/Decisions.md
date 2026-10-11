# R0 architecture decisions

## Reader ownership and declarations

On Apple Swift 6.4 (swiftlang-6.4.0.34.1), ordinary returned `~Escapable` cursors
are rejected. Explicit `@_lifetime` annotations require the experimental Lifetimes
feature. Preserve the current language configuration. Select a guarded synchronous
scope as the reference implementation; no lifetime flag or unsafe annotation is
added to the libraries. See the compiler fixtures in Tools/Release1_1Probes.

The actual compiling reference declarations are `ProbeReadCursor` with throwing
String, JSONKey and Int subscripts, `requiredString()`, generic
`requiredInteger(as:)`, `presence(of: JSONKey)` and `decode(_:)`, plus generic
`probeReadWithReport(_:limits:_:) -> JSONOperationReport<Result>`. These are compiled
into a separate ReaderProbe module and Swift Testing target, not the JSON product.
The consumer imports the public JSON model and ReaderProbe; it imports no meter.
No complete production cursor API is frozen by these subset declarations.

One JSONCodingState owns one noncopyable JSONWorkMeter in domain core. Selection,
path work, integer conversion and JSONNativeDecoder projection borrow that state;
root admission occurs once. A cursor retains only its scope and typed path. Scope
exit invalidates access and clears root/document/source and coding-state references.
Resource and cancellation failures latch, including when the callback catches them.
Ordinary missing-member failures may be caught without refunding charged work.

Swift 6 rejects Sendable closure capture and actual detached-task transfer. The
latter must be tested with object compilation: typecheck alone does not execute
region-based ownership analysis. Escaped synchronous handles are permitted by the
fallback shape but all later operations fail before root/meter access.

R2/R3 must still qualify the full typed presence/conversion surface, mapped-source
diagnostics, live retention/refunds and stricter projection limits against already
consumed counters. The current meter's immutable limits require a reviewed
restriction adapter; copying/replacing the meter is prohibited. No fresh decoder
facade is permitted inside a scoped projection. The prototype intentionally does
not claim these unimplemented behaviors.

## Index candidates and publication

Tests exercise a scalar reference, fingerprint-assisted linear reference,
array-backed AVL tree and controlled open-address hash table. All confirm exact
UTF-8 identity after candidate filtering, including injected same-fingerprint
collisions. Tree rotations, searches, table scans/rebuilds, key bytes and spare
capacity use the actual core meter. New capacities are admitted while old storage
coexists; owned loops check cancellation. These are test-only candidates.

The release-native corpus covers widths 0, 1, 4, 8, 16, 32, 64, 256, 1024 and 10000,
ASCII, 128-byte common prefixes and scalar-distinct Unicode. It records three
warmups, nine samples, one construction per sample and three sets of four lookup
queries. Construction and lookup work/timing are separate. A resource refusal
stops that comparison and is never counted as a successful fast sample.

No adaptive threshold or wide representation is selected yet. Mac measurements
cannot select a mobile crossover. The next small increment may filter a linear
lookup by its existing cached fingerprint, with exact comparison retained. R1
must audit every publication path, incremental duplicate timing, nonthrowing finish,
keyed encoder traversal/allocation, failure cleanup and immutable Sendable metadata.
Existing 32-byte index-slot reservations include grammar-owned duplicate slots,
materialized object/member slots and admitted graph slots; these are distinct
ownerships. They do not automatically cover new simultaneous buffers. Version 1
weights and all 49 metric caps remain unchanged.

## Version 1 persistence and SDK boundary

Freeze the logical envelope: String format exactly `swift-json-value`, integer
version exactly 1, String utf8Base64 strict standard Base64 of one complete strict
UTF-8 JSON document. Inner writing is compact, insertion order, preserved admitted
number lexemes with the existing fallback. The 0.1 fixture is `MC4x`; present JSON
null is `bnVsbA==` and differs from an optional absent payload.

SwiftDataShape explicitly implements these fixed Codable fields and compiles
nonoptional and optional `@Attribute(.codable)` attributes on macOS, iPhoneOS and
iPhoneSimulator SDK 27.2. It is an SDK shape subject, not the exact owned codec:
strict Base64/inner JSON validation, native nested budgets and fidelity remain R4.
The later persistence test must save to a unique disk URL, leave the scope holding
all models/context/container, recreate the container, fetch and check scalar bytes,
member order and original lexemes. Repeat update/reopen and query/sort ordinary
fields. In-memory rereading is not evidence; no cloud-sync claim is intended.

## Mobile platform and CI

Propose `.macOS("27.0")` and `.iOS("27.0")`; iPadOS shares iOS. The root manifest
remains macOS-only pending the focused platform PR. All four products, private
regex and schema resources compile for iPhoneOS with the default build engine.
The simulator default engine fails while signing the schema resource bundle; its
`Resources` directory layout needs qualification. The documented deprecated native
SwiftPM backend compiles the same simulator consumer without that signing step.
This alternate build is compile evidence, not resolution of the default-engine
failure. The saved inventory lists iOS 27.0 (24A5390f) and eight available
simulator devices. Runtime behavior has not been executed in this milestone;
availability is not runtime qualification.

Keep the three protected check names and strict/no-bypass rules unchanged. The
seven authored prototype cases extend JSONTests from 54 to 61 functions: all other
bundle cardinalities, three targeted Thread Sanitizer cases, 49 exact cap probes,
independent corpus counts and exclusions remain intact. R0's filtered run requires
exactly seven cases. New platform declarations must later update the exact
macOS-only manifest expectation in the same focused change.

## First production increment

Select only the narrow cached-fingerprint filter described in
[BenchmarkReview](BenchmarkReview.md). The below-32-member scalar path and first
eight scalar probes remain available. A query hash, each member probe, fingerprint
comparison and exact candidate comparison consume the same noncopyable meter;
there is no new table, cached mutable state or owned index allocation. The two
additional behavior cases exercise public presence/Pointer/equality, insertion
order, forced collision confirmation in the production comparator, inclusive and
cumulative work exhaustion and cancellation during actual lookup work.

The current 10% performance review trigger is unchanged; accept the measured
first-filtered-hit and short-miss cost for this limited draft change. Full adaptive
index publication/construction and keyed-builder/mobile measurement remain R1/R5,
not completed by these tests. CI now expects JSONTests 63 and total 131 functions;
the seven-case R0 subset, baseline parameterized invocations and all other exact
cardinality/49-cap checks remain unchanged.
