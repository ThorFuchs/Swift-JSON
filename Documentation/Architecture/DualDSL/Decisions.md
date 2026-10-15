# Dual DSL decisions

## D1 — Trusted authored staging, finite finalization

P1.2 adopts the explicitly permitted authored-configuration boundary. Result-builder
callbacks, wrappers, collection emission, IR assembly and integer literal construction
are trusted, unmetered staging. They can allocate or run caller computation before
finalization. This API is not an untrusted-input entry point, an instruction quota,
a staging-retention guarantee, an RSS bound or a whole-pipeline cumulative report.
Use existing bounded parsers/accumulators for dynamic untrusted input.

Finalization is a separate checked phase. One invocation-owned JSONWorkMeter covers
iterative lowering, exact key/index admission, output slots, literal payload traversal,
work/cancellation and, for schemas, JSONSchemaDocument admission. Existing package
hooks are reused; JSON, JSONSchema and JSONBridges source need no changes. No helper
restarts this finalization ledger. A caught owned failure remains terminal, including
at the package continuation boundary. No partially finalized value is returned.
There is deliberately no public whole-DSL `WithReport` API. Tests distinguish the
finalization counters from unaccounted staging; existing 49 baseline probes remain.

## D2 — Flat staging lifetime and iterative lowering

The prototype's recursive indirect enum and per-container checked materialization
are replaced with a flat private token sequence. The public node's object/array/literal
factory spellings remain, but it is a struct rather than a pattern-matchable enum.
Nested typed declarations assemble these tokens without flattening JSON array values.
Finalization uses explicit frames and the engine's exact-key index and admission helpers.
IR teardown does not recursively own child IR nodes. Literal JSON retains its existing
engine lifetime semantics. Depth failures use JSONFailure/resource/maxDepth, replacing
the prototype-only JSONDSLBuildFailure; no second resource-error model is added.

Qualification must cover default-cap rejection of deeply staged inputs, accepted depth
boundaries, cancellation in owned finalization and terminal errors. Arbitrary caller-
configured depths and callback recursion are not implied by a finite tested depth.

## D3 — Separate products and semantic authorities

JSONValueDSL and JSONSchemaDSL add no dependency to core or each other. Shared typed
builder protocols are public declarations in JSONDSLCore because optional public generic
signatures reference them; the helper module has no independently selectable product.
Objects use ordered exact-key semantics, arrays preserve nesting, omission emits nothing,
and duplicate keywords/properties/definitions fail. There is no String dictionary merge.

The schema DSL emits ordinary JSONSchemaDocument. The existing compiler and validator
alone govern dialect, vocabularies, regex, references, annotations, requiredness and
invalidity versus operational errors. Explicit offline registry resources use existing
JSONSchemaDocument/JSONSchemaRegistry APIs; no ID-to-retrieval inference or network resolver.

## D4 — E2 reconciliation and minimal naming

Merged E2/JSONBridges remains unchanged and opt-in. DSL implicit numeric inputs remain
BinaryInteger only; exact decimals require explicit JSONNumber. No Float/Double overload,
Optional bridge, floating literal, coercion or automatic requiredness is added.
JSONValueDSL and JSONSchemaDSL remain distinct discovery namespaces. An umbrella product,
typed ObjectSchema/StringSchema/ArraySchema synonyms, automatic references/derivation and
new Boolean-schema overload aliases are deferred: existing Rule(Boolean), table Boolean
initializers and rawKeyword preserve the complete declaration without another surface.
The identical prototype rawSchemaKeyword synonym is removed in favor of rawKeyword.

## D5 — Retain measured variadic composition

Native Swift 6.4 compiled both strategies against the real engine. The final
comparison passed 41 commands, including 22 scaling probes: value/schema blocks
of 16/64/128/256 declarations, nested depth 24, choices/loops and mixed inference.
All six domain-negative fixtures rejected in both configurations, and ordinary
and module-qualified consumers compiled with complete strict concurrency.

The final 256-property schema typecheck took 3.765 s with variadic composition
versus 5.304 s with pairwise partial blocks; compiler maximum resident sizes were
122,929,152 and 137,789,440 bytes respectively. An earlier integration run measured
1.097 s versus 5.513 s. All raw fixture hashes and measurements are retained; neither
run was quiet (final load averages approximately 600/587/533). Some small branching
fixtures favored partial composition. These observations justify retaining the
working variadic strategy through the tested scale, not a general speed guarantee.
Compiler RSS does not bound DSL staging, finalization retention or process RSS.
The alternative modules remain experiment outputs and are not shipped code.

## D6 — Empty enum is distinct from malformed schema

The initial integration test incorrectly grouped an empty enum with malformed
length/count declarations. Actual compiler behavior and the pinned validation
meta-schema accept an enum array with no entries. Draft 2020-12 validation
[section 6.1.2](https://json-schema.org/draft/2020-12/draft-bhutton-json-schema-validation-01#name-enum)
requires an array and recommends a nonempty one. The corrected case compiles
both DSL and handwritten declarations and proves ordinary invalidity for all
six JSON kinds. Negative bounds, zero multipleOf, empty oneOf and duplicate
required names remain explicit compilation failures. No engine behavior changed.

## D7 — Real module qualification instead of facade shadowing

A native Swift 6.4 consumer with its own Field, Element, Schema and Property
declarations cannot spell JSONValueDSL.Field or JSONSchemaDSL.Schema when the
prototype facade enums shadow their modules. P1.2 therefore uses module-level
object/array/document/boolean factories. Existing authored calls retain the same
JSONValueDSL.object and JSONSchemaDSL.document spelling, while declaration types
can be qualified with their actual module. No umbrella, alias or synonym is added.
This is an unreleased prototype declaration-shape change, not an engine API change.
The compiler harness retains explicit collision cases in both configurations.
