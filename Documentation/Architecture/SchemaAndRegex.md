# Schema and regex contract

These contracts describe the public behavior and its resource boundaries.

## Schema compiler references and evaluation

JSONSchemaDocument accepts only JSON.boolean or JSON.object as the schema root. It preserves the complete raw document, optional retrieval URI and source map. A builder produces ordinary JSONSchemaDocument input. It does not bypass validation or discard unknown annotation keywords.

JSONSchemaRegistry is an immutable bounded snapshot of explicitly supplied resource documents. Updating it produces a new snapshot. There is no automatic URLSession resolver or mutable global registry. A caller fetches resources through its own authorized application I/O before constructing the snapshot. Each compile consumes the selected snapshot within the compiler's own cumulative limits.

Use JSONSchemaCompiler(options:).compile(document, registry:) throws -> CompiledJSONSchema and JSONSchemaValidator(options:).validate(instance, against:) throws -> JSONValidationResult. Compiled plans are checked Sendable and immutable; validators store configuration only. Plan IDs, resource IDs, keyword IDs and reference targets use bounded private indices. Avoid exposing upstream Schema, Context, OrderedDictionary or Regex types in signatures.

Compilation validates dialect declaration, required vocabularies, meta-schema constraints, identifiers, anchors and resolvable resources. Support Draft 2020-12 as the only standard dialect. Custom meta-schema declarations using supported vocabularies can be resolved from the snapshot; unsupported required vocabularies fail. Unknown annotations follow dialect rules. Keep format annotation distinct from assertion; do not turn content metadata into unconditional decoding of instance text.

Official meta-schemas are packaged with their provenance and applicable license. Bootstrap uses a small trusted immutable representation of the official dialect and validates the runtime-loaded documents through a staged path; it must avoid infinitely compiling a meta-schema against itself. Bootstrap integrity, loaded meta-schema validation and the independent suite are separate gates.

Reference resolution uses RFC 3986 rules, base URI transitions, percent-decoded fragments exactly once, strict Pointer fragments, resource boundaries and anchor rules. URI identity is not String canonical normalization or ad hoc path replacement. Collision policies reject ambiguous duplicate resource identifiers/anchors instead of first-wins caching. Reconstructing Foundation URL repeatedly in deep evaluation is not the evaluation authority; the compiler resolves indexed targets and stores bounded original locations.

Evaluation uses invocation-owned explicit frames and dynamic scopes. Preserve annotations only from successful branches where the vocabulary requires them. anyOf may need additional successful branches for evaluated locations; oneOf must establish exactly one successful branch; if/then/else and contains/minContains/maxContains have their own annotation behavior. Returning early on a boolean answer is valid only when no required downstream evaluated-location/output behavior is lost.

Reference recursion can be legitimate as instance traversal progresses. A global seen-reference String set is incorrect. Use a qualified active-state guard including compiled node identity, instance location and relevant dynamic scope; allow return to a reference at another instance location. Detect nonproductive cycles as an operational schema evaluation failure or exhausted budget rather than falsely invalidating recursive data. Active-state tables and comparisons are themselves charged and bounded.

Exact integer count/length assertions compare mathematical bounds without narrowing them just to render an error. Strings count Unicode scalars, not Swift grapheme clusters or UTF-8 bytes. const, enum and uniqueItems use budgeted exact equality. Evaluated property sets use JSONKey rather than String identity. All of these requirements must survive dependency adaptation.

## Native backend and regex dialect

The shipped evaluator uses the exact JSON model, private indexed plans and
invocation-owned frames. Its reference/adaptation inputs and licenses are recorded
in [ExtractionManifest.json](ExtractionManifest.json) and [UpstreamPins.json](UpstreamPins.json).
There is no production upstream schema package, Rust binary or external engine
dependency. Independent suites and policy exceptions are documented in
[qualification](../Qualification/README.md).

The package-private regex VM targets ECMA-262 11th edition (2020), fixed Unicode
13.0.0, case-sensitive u-equivalent processing and unanchored scalar searches.
Supported behavior includes Unicode literals and classes/properties, grouping,
alternation, anchors, empty matches, counted/greedy/lazy repetition, captures,
backreferences and directional lookarounds. Malformed or unsupported patterns fail
compilation; a valid pattern's no-match outcome is ordinary assertion invalidity.
There is no Foundation or Swift Regex fallback.

Compilation charges grammar/token work, instructions and storage. Evaluation
charges candidate scans, dispatch, retries, captures/backreference comparisons,
state and table work. Grammar depth, groups, program size and live match state
have finite ceilings. Counters persist across candidate positions and repeated
patternProperties searches. Exhaustion/cancellation propagates as an operational
error and cannot become a false assertion or a passing alternative branch.

Identical exact-spelling programs share immutable storage within one plan. Match
state belongs to each search. Literal/predicate prefilters and alternate backends
were not selected. The public contract does not claim all newer ECMAScript
extensions, configurable flags or a standalone regex product.

## Schema declaration inspection

Expose a bounded read-only view of a schema node, its raw JSON, declared keywords and declared annotations. It may expose static reference target information from a qualified compiled resource snapshot. The public facade should keep resource identity and Pointer location, with no upstream engine types.

This preserves the useful idea in RhoeJSON's schema handles without importing their limited enum, silent raw fallback, Double constraint fields or “effective view” inference. Exact numerical bounds remain JSONNumber or raw JSON. Declared type may be a set of types; an allOf node does not magically become one inferred object shape. Boolean schemas are first-class.

Use names such as declaredKeywords and declaredAnnotations. Defaults/examples remain declarations; inspection does not insert values into the instance. Annotations from schema declarations and annotations from an evaluation result are separate APIs. Dynamic reference resolution requires evaluation scope; a document-only inspector cannot promise its final target.

Inspection consumes limits for navigation, copies and optional reference traversal. Its owned Sendable result may retain an immutable qualified snapshot; no borrowed node crosses await or outlives storage. Merely reporting a raw declaration must not claim the instance will satisfy it.

This supports documentation, debugging and downstream schema-driven applications without building forms, code generation, inference, repair or schema algebra here. Tests cover raw metadata, exact constraints, boolean resources, multi-type declarations, static resource locations, dynamic-ref ambiguity, unknown annotations and bounded navigation.

## Qualified regex sharing

Compilation shares identical admitted patterns by exact spelling within one
immutable plan. Each match owns capture, retry and search state; work remains
cumulative. No process-global regex cache, start-predicate prefilter or hidden
fallback engine is selected. Performance observations and their limitations are
in [the performance notes](../Performance/README.md).
