# Schema and regex implementation



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

## Backend comparison and regex experiment

The pinned native candidate is ajevans99/swift-json-schema v0.14.1 at 1514dd27fd55dbd36eec40c60e40ac8bfe0a22f4. Its source has reusable keyword, resource, reference and annotation algorithms. Its JSONValue implements scalar equality for string values, but object storage remains OrderedDictionary<String, JSONValue>. Keyword property sets also use String. A String-key adapter would therefore collapse distinct scalar spellings. The inspected evaluator uses shared context/cache facilities and synchronous Swift Regex matching without our complete invocation meter [R01–R03].

| Approach | Benefit | Architecture consequence | Recommendation |
| --- | --- | --- | --- |
| Direct package dependency with facade | Least initial copying | Key/annotation identity, actual budgets, immutable plan and module-name boundary still require invasive changes; full manifest resolves development dependencies | Do not choose as the release path |
| Selective native adaptation | Reuses established algorithms and fixtures, with one exact JSON model and controlled graph | Requires semantic review, explicit frames/meters, regression tests and MIT notices for copied portions | Preferred implementation path, subject to W05–W07 qualification |
| New evaluator written solely from specifications | Full control | Recreates all vocabulary/reference/annotation behavior and needs the same independent qualification | Use for components where adaptation is less clear |
| Corvus C/Rust backend | Useful comparison behavior | Additional binary/ABI/provenance/precision/bounded-execution decision | Comparison only; not the default |

The source review establishes architectural incompatibilities, not a measured Swift port effort or executed conformance result. An adapter spike must exercise failing key, annotation and work-gate vectors. W05 records that experiment and a small selective adaptation prototype before expanding the port; ordinary ASCII samples are insufficient qualification.

The new regex candidate is ridiculousfish/regress at **771e6c8fa1e472ef86c45b5206b37fa4e4494e25**. Its manifest offers MIT OR Apache-2.0; an approved selective port may choose Apache-2.0 while retaining upstream copyright and attribution. Its source exposes BudgetedMatch with match, no-match and exhausted outcomes, and find_from_budgeted. The inspected engine charges backtracks, with ordinary find/iterators remaining unbudgeted. It does not provide our total compilation/search/state/cancellation contract [R04–R06].

Use this as reference material for a private Swift JSONRegexRuntime, not as a new production Rust binary dependency. A full source copy includes a large generated Unicode table and multiple execution backends; a selective port must identify what is necessary rather than mechanically importing all of it. Check generated-table provenance and licensing separately before copying.

The regex semantic target is the ECMA-262 **11th edition (2020)** referenced by Draft 2020-12, with Unicode u-equivalent processing and unanchored search. JSON Schema recommends ECMA syntax and Unicode support and explicitly forbids implicit anchoring; it does not itself require every newer ECMAScript extension [R07]. Do not accidentally turn this into a requirement for a JavaScript runtime or all future regex standards. Publish a precise feature/version ledger and test differences from the referenced edition.

The native spike must demonstrate parser-to-program-to-search behavior for Unicode literals/classes, quantifiers, grouping, alternation, anchors, empty matches, astral scalars, escaped surrogates, backreferences and lookarounds required by the claimed engine dialect. Cases such as dot, dollar before a final line terminator, character classes and Unicode property data need explicit vectors. Invalid and unsupported patterns are distinct from a non-matching instance. No Foundation or Swift Regex fallback is allowed for a feature the bounded VM cannot execute.

Charge VM dispatch, input candidate scans, retries, captured/backreferenced comparisons and table/state operations. Bound compilation grammar depth, token scans, instructions, capture groups, backtracking frames, program/table memory and search state. Expansion of large repetitions should use bounded program structure rather than allocating one instruction per repetition without a cap. The same meter persists across all start positions and all patternProperties searches in one evaluation.

**Experiment completion gate:** a native report with exact source/file pins, semantics vectors, catastrophic-backtracking and long-forward-scan inputs, finite counter boundary failures, cancellation work interval and retained-state measurements. Porting only the backtrack counter does not pass. Timebox the initial prototype to three to five focused engineering days, then report observed code size, gaps and an evidence-based estimate; that timebox is a discovery allocation, not an estimate for a complete engine.

If the spike cannot qualify the required engine, W07 remains open and full schema release remains blocked. A restricted preview must state its regex limitations explicitly. Changing to a foreign engine, subprocess isolation or a broader dependency requires a concrete architecture revision with its semantic and operational tradeoffs; this plan does not pre-approve one.

## E07 Schema declaration inspection

Expose a bounded read-only view of a schema node, its raw JSON, declared keywords and declared annotations. It may expose static reference target information from a qualified compiled resource snapshot. The public facade should keep resource identity and Pointer location, with no upstream engine types.

This preserves the useful idea in RhoeJSON's schema handles without importing their limited enum, silent raw fallback, Double constraint fields or “effective view” inference. Exact numerical bounds remain JSONNumber or raw JSON. Declared type may be a set of types; an allOf node does not magically become one inferred object shape. Boolean schemas are first-class.

Use names such as declaredKeywords and declaredAnnotations. Defaults/examples remain declarations; inspection does not insert values into the instance. Annotations from schema declarations and annotations from an evaluation result are separate APIs. Dynamic reference resolution requires evaluation scope; a document-only inspector cannot promise its final target.

Inspection consumes limits for navigation, copies and optional reference traversal. Its owned Sendable result may retain an immutable qualified snapshot; no borrowed node crosses await or outlives storage. Merely reporting a raw declaration must not claim the instance will satisfy it.

This supports documentation, debugging and downstream schema-driven applications without building forms, code generation, inference, repair or schema algebra here. Tests cover raw metadata, exact constraints, boolean resources, multi-type declarations, static resource locations, dynamic-ref ambiguity, unknown annotations and bounded navigation.

## E10 Private regex reuse and optimization

Within a bounded compiled schema plan, deduplicate identical immutable regex programs by exact pattern scalar spelling, semantic flags, claimed dialect and Unicode data version. Do not use Swift String canonical equality for that cache key. Each distinct entry and retained program is charged to compilation and plan capacity. Per-evaluation matching/capture/backtracking state remains exclusive.

Literal patterns and sound start predicates may avoid running the full VM at every candidate position. Regress supplies concrete IR and predicate examples. The optimizer must conservatively choose no prefilter when it cannot prove safety; a mistaken necessary-prefix assumption can silently invalidate correct instances. Never use canonically normalizing String matching for exact literal semantics.

Count input scans, retries and comparisons, including the prefilter itself. Keep cancellation and aggregate meters through every fallback. “Fast path” cannot mean calling an unbudgeted Foundation matcher. Differential vectors include alternation, empty matches, anchors, Unicode classes, backreferences, lookarounds and capture semantics.

Do not port every optimizer or a second PikeVM backend as a first-release requirement. One qualified engine plus small proved optimizations is a manageable scope. Additional engines require independent semantics/budget evidence and workload measurements; the existence of another execution source file is not an obligation to adopt it.

The Unicode generator belongs in development tooling if used. Pin actual source versions, bytes/hashes, generator revision and selected license/provenance. Check generated tables into reviewed runtime source or resources with a regeneration comparison; no runtime fetch from “latest.” The regex feature ledger identifies the ECMAScript and Unicode behaviors actually qualified. Benchmarks compare the same semantic profile and limits, without importing upstream speed claims.
