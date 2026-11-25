# JF3.3 — Bounded structural equivalence for GenerationSchema

**Status:** candidate implemented; native Swift 6.4.2 / Apple SDK
qualification pending. Parent review: `e9f401e5f428740346ddf6d0c44d69a61aa50073`.
The JF3.2 native qualification at 318b8b2cc6cfdc04dd7cf17257b00c665bda051f
and its 58 method executions remain immutable source-bound evidence.

## Decision

Add explicit opt-in JSONGenerationSchemaMetadataPolicy.allowStructuralEquivalence.
The default .exact and .allowGeneratedAnnotations paths retain their earlier
compiler, profile, comparison and failure order. The new policy includes
the existing generated title/x-order opt-in, plus only the following
proved transformations of the returned representation:

- Replace an inline concrete object schema with a pure reference to a
  concrete object schema in a root-local $defs table.
- Permute a required array if, and only if, its distinct exact names
  comprise the same set as the canonical required declaration.

The source profile is unchanged: reference-free closed object root,
qualified types/constraints, maximum 16 schema levels and 128 properties
per object. Unknown declarations, explicit dialects, nullable unions and
all other previous exclusions remain excluded. No new canonical $ref
support, external registry, network resolution or model execution.
Do not infer a general schema equivalence theorem or identical generation
behavior.

## Proof and canonical authority

Use a paired traversal of the canonical schema tree and the actual Apple
Codable representation, with the existing exact, bounded native equality
for nonstructural declarations. No expanded schema tree is constructed.
At a reference use, require exactly one $ref member, not at root, and
use the native metered JSONPointer.uriFragment parser. Accept only two
decoded tokens, $defs and the exact definition name. Percent decoding
and RFC 6901 tilde decoding occur once. Resolve against the actual root
definition table (nonempty, at most 128 entries), compare a concrete
object target at the same effective position, and track active and used
indices. Reject unresolved, cyclic, root, sibling-bearing, nonlocal,
non-direct, alias-chain or nonobject references. All definitions must be
used by the proof. No nested definition tables or URI-scope-changing
declarations can pass. Shared definitions must be compared at EVERY use;
a matching title or an earlier successful use is not a cache certificate.

Required permutations are proved with bounded exact scalar matching and
one-to-one marking. Duplicate names, missing names and added names reject.
Enum arrays and existing x-order remain ordered. Exact mathematical
numeric constraints and all existing annotations must remain unchanged.
Only new string title and valid full property-permutation x-order
annotations are permitted at actual schema nodes. Unknown additions
reject. Property names such as title, $defs and x-order remain ordinary
property names inside the properties map.

Canonical compilation and preflight occur first. After native Codable
conversion, the new structural proof preflights the actual returned
representation before the second native compilation. This order gives
typed proof failures for unsafe references before compiling such graphs.
Successful projection still requires the actual untouched returned
schema to compile offline. Preserve canonical CompiledJSONSchema and
actual roundtripped JSONSchemaDocument. No rewritten schema is handed to
the framework and no new plan replaces the canonical validation authority.

Use the single invocation-owned JSONCodingState/JSONWorkMeter through
compilation, Codable, proof, returned compilation and report. Explicit
work, logical reservations, diagnostic issue/byte charges and cancellation
checkpoints cover native-owned operations. Framework callbacks and hidden
allocations are outside the native accounting contract. Recursive proof
is bounded by canonical depth with at most one dereference per effective
node; no graph expansion is materialized. Resource/cancellation/native
compilation errors remain distinct from compatibility rejections.

The projection adds structural rewrite diagnostics (kind, effective typed
path and exact decoded definition key for local references); existing
additions remain separate. New issue codes: invalidLocalReference,
cyclicLocalReference, unusedDefinition. A failure has no successful
projection or successful report.

## Qualification

Eight new portable methods exercise the full controlled Codable projection
and canonical plan, escaped fragments, single decoding, external/dangling/
malformed references, siblings, scope changes, alias chains, root refs,
unused definitions, cycles, each shared use including conflicting same-title
schemas, required membership vs enum/x-order ordering, exact referenced
numeric constraints, annotation scoping, N/N-1 cumulative work/retention,
and deterministic cancellation during proof. These are synthetic test
fixtures, not a fake Apple framework.

Two new Apple methods reuse the exact unchanged ReverseMatrix.json:
19 actual reverse schemas (expected 18 successes and the same precise
decimal rejection), and all 12 existing canonical preflight exclusions.
Every successful projection must retain the exact original schema, actual
Apple schema, expected instance verdicts and the correct rewrite/addition
receipts. The three local reference cases and the required permutation
are anchored to JF3.2's observations, not assumed universal Apple behavior.

The independent Python verifier uses a bounded expansion ONLY for the
fixed small qualification corpus, unlike the paired native proof. It
parses exact Decimal/scalar/type-aware JSON using the existing JF3.2
helpers, verifies rewrites and annotation additions, reconciles actual
returned schemas with the unchanged old-policy regression, and insists
that the precise decimal-bound mutation is still rejected. It requires
the prior counts 13 exact and 14 annotation-opt-in successes per mode,
18 structural successes, and 12 canonical preflight rejections. Any
anchor drift requires review. Instance verdicts are supplemental,
not the structural proof.

Per Debug and Release: 10 new JF3.3 methods, 4 JF3.2 methods, 11 JF3.1
methods, 14 JF2.2 methods. Total 78 intended native method executions.
The dedicated runner grafts only the existing experimental product/test
target into a disposable copy and reuses the historical receipt validators.
No root manifest, original test fixture, historic runner or ValueBridge
change. The new SchemaBridge candidate is the only modified prior source;
original exact/annotation behavior must pass all unchanged regressions.

Actual editing-host verification: 14/14 Python offline controls passed
under isolated Python execution, with synthetic receipts. Independent
delta replay against all 38 actual historical JF3.2 Debug/Release raw
schemas agrees with the expected four structural rewrites, six permitted
annotation paths per mode and both altered decimal endpoints. This replay
is not a new Swift or Apple execution. The new Swift code is not yet
compiled or run on the supported toolchain. Native N/N-1, URI/compiler
agreement and actual Apple conversion remain explicit gates.

## Native run

From a clean exact JF3.3 commit:

    python3 -I -B Scripts/test_foundation_models_structural.py
    python3 -I -B Scripts/qualify_foundation_models_structural.py "$(git rev-parse HEAD)" /path/outside/checkout/JF33-Evidence

Native ARM64 macOS 27+, Swift 6.4.2, SDK 27.2, 20 GiB minimum free
workspace (not a bound). Preserve evidence archives on failure as well
as success. Expected outcome APPLE_STRUCTURAL_SCHEMA_PASS; product
admission remains NOT_ADMITTED. No merge, tag, publication or hosted CI.
Full existing native/platform-floor/docs/Linux/WASI gates, real model
behavior and final API/inventory admission remain separate. Proceed to
JF4 after reviewing actual JF3.3 evidence.
