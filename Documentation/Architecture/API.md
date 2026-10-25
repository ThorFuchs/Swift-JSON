# Current API inventory

Unreleased 1.7.0-dev consolidation has twelve library products plus swift-json and
thirteen DocC catalogs including the non-product JSONDSLCore reference. The native
compiler graphs define the complete authored inventory. JSONTransform and the
trusted-authored DSLs are opt-in; the core products retain their semantic authority.
The stable 1.6 inventory and chronological component records below retain their
original scope, not the current combined product count. See
[combined qualification](../Qualification/Consolidation2026.md).

# Public API contract

The current product table below describes this development source. Stable 1.6.1
retains eight libraries plus CLI and eight catalogs. Development adds Inspection,
Transform and both optional authored DSL products, with a shared JSONDSLCore
reference catalog. Existing released contracts remain unchanged. Compiler symbol
graphs supply the complete authored declarations; the README examples are compiled
and executed by public consumers.

## Products and ownership

| Product | Main entry points | Owned implementation boundary |
| --- | --- | --- |
| JSON | JSON, JSONNumber, JSONObject, JSONParser, JSONWriter, JSONValueEncoder, JSONValueDecoder, JSONPointer, JSONDocument | Shared strict codec, exact decimal model, bounded traversal and native coding |
| JSONNavigation | JSONTraversal, JSONTraversalScope, JSONTraversalOptions | Exact many-node DFS, strict physical/virtual scopes, bounded metadata and explicit coverage; one core read-scope meter |
| JSONInspection | JSONShapeInspector, JSONStructuralSnapshot, JSONGraphProjection | Source-attached observed evidence, immutable exact projections, set/matrix and directed graph views; finite invocation-owned reads |
| JSONTransform | JSONTransformProgram, JSONTransformOutput, JSONTransformExecution | Shared query compiler/pull VM, exact native values, finite guarded execution and typed terminal errors |
| JSONValueDSL | JSONValueDSL.object/array, Field, Element, Elements | Trusted authored staging; finite iterative exact finalization |
| JSONSchemaDSL | JSONSchemaDSL.document/boolean, Schema, Property, Definition, PatternProperty, DependentSchema, RequiredDependency, Rule | Trusted authored schema declarations; existing document/compiler/validator authority |
| JSONBridges | BinaryInteger.jsonNumber, FixedWidthInteger/Double/Decimal.init(jsonNumber:), Double.jsonNumberFromRoundTripText | Optional one-delegate numeric conversions; explicit fidelity, no new authority |
| JSONSchema | JSONSchemaDocument, JSONSchemaRegistry, JSONSchemaCompiler, CompiledJSONSchema, JSONSchemaValidator | Offline immutable plan, invocation-owned evaluation and private native regex |
| JSONSchemaExamples | JSONSchemaExampleGenerator, JSONSchemaExampleResult | Conservative deterministic witnesses certified by the existing native validator; separate finite preparation and cumulative generation |
| JSONStreaming | JSONEventSequence, JSONValueSequence, NDJSONValueSequence, JSONTopLevelArraySequence, JSONAsyncWriter | Exclusive pull state, shared codec, strict framing and awaited handoffs |
| JSONPatch | JSONPatch, JSONPatchOperation, JSONPatchResult, JSONMergePatch | Transaction staging, exact comparison and iterative editing |
| swift-json | format, validate, pointer, patch, query, stream, schema, render | Bounded process/file adapters; the public Transform facade and CLI use the same private query compiler/VM |
| JSONHTML | JSONHTMLRenderer, JSONHTMLRenderingOptions, JSONHTMLLimits, JSONHTMLRenderReport, JSONHTMLAnnotation, JSONExportDocument, JSONExportOptions, JSONExportReport | Structured forms/cards and bounded native previews, exact HTML, native Apple transfer, immutable prepared JSON/text/Markdown/static HTML/opt-in styled RTF and cumulative budgets |

JSON imports no siblings. JSONSchema depends on JSON and package-private
JSONRegexRuntime. Streaming, Patch, HTML, Bridges and Navigation depend on JSON.
JSONSchemaExamples depends only on JSON and JSONSchema. JSONInspection depends on
JSON and JSONNavigation. JSONTransform depends on JSON and the package-private
JSONFilterRuntime; JSONCLIEngine uses the same engine. Optional DSL products depend
on JSON/JSONSchema and JSONDSLCore as declared in Package.swift. There are twelve
library products plus swift-json and no external root-package dependencies. The
shared helper has no standalone library product. JSONHTML conditionally uses Apple
SDK frameworks for explicit native transfer/PDF preparation; core value, schema,
Patch and streaming semantics remain portable. Package-only store preparation is
not a public API or a second ledger. No online resolver or runtime dependency is added.

Immutable facades store value configuration. Every operation owns its mutable
context; every stream iterator requires exclusive access. Sendable follows the
actual stored state and result types. See [concurrency](Concurrency.md).

## Exact values and construction

The ergonomic surface released through the 1.4.0 tag and 1.5.0 release is documented in the
[ergonomics crosswalk](../Ergonomics/README.md). JSON.parse forwards String, Data
and byte arrays to their respective parser overloads; buildObject, number(parsing:)
and value(at:) wrap one existing authority each. JSONObject.containsKey is an
unmetered exact-key lookup; JSONPresence.map/fold preserve all three cases and
rethrow caller errors. CompiledJSONSchema.validate evaluates its existing offline
plan. No raw-string Pointer composition or generic number factory is added.

JSON has six cases: object, array, string, number, boolean and null. Numbers compare
mathematically, text/keys compare decoded Unicode scalars, and object equality
ignores insertion order. JSONObject iteration and writing preserve insertion
order by default. Exact duplicates fail checked construction and parsing.

| Interface | Observable behavior |
| --- | --- |
| `JSONObject(members:limits:)` | Throwing ordered construction; duplicate detection and payload admission |
| `JSONObject.build(limits:_:)` | Exclusive noncopyable member accumulator; checks before append |
| `JSON.buildArray(limits:_:)` | Exclusive array accumulator; nested arrays remain one element |
| `append(contentsOf:)` on array accumulator | Explicit flattening with charged work |
| Object subscripts by String/JSONKey | Unmetered exact-key lookup using immutable metadata; nil means absence |
| `JSON.requiredMember(_:limits:)` | Bounded lookup; throws on wrong kind or missing member |
| `JSON.presence(of:limits:)` | Bounded lookup separating absent, null and non-null value |
| `JSONObject.presence(of:)` | Unmetered convenience with the same three states |
| Optional kind accessors | Inspect without coercion or manufactured defaults |
| `JSONComparison.equals(_:_:limits:)` | Throwing bounded semantic equality |
| `JSONObject.setting(_:for:limits:)` | Replacement keeps position; new key appends |
| `JSONObject.removing(_:limits:)` | New object without the key; absence leaves it unchanged |

Direct enum cases and literals construct trusted caller values without admission.
Every bounded operation charges their traversal and checks applicable capacities.
Ordinary Equatable and Hashable operations cannot throw or enforce a work budget;
randomized hashes are not persistent digests. There are no floating-point literals
or shape-inferencing result builders. See [numbers and Unicode](NumbersAndUnicode.md).

## Strict codec and source documents

| Entry point | Result and boundary |
| --- | --- |
| `JSONParser.parse(_:)` | JSON; overloads accept String, Data and [UInt8] |
| `JSONParser.parseWithReport(_:)` | JSONOperationReport&lt;JSON&gt;; accepts [UInt8] |
| `JSONParser.parseDocument(_:source:)` | JSONDocument; accepts Data and an optional source label |
| `JSONWriter.write(_:)` | Owned Data containing complete strict UTF-8 JSON |
| `JSONWriter.writeString(_:)` | Owned String with its additional retention charged |
| `JSONWriter.writeWithReport(_:)` | JSONOperationReport&lt;Data&gt; |

Parsing accepts exactly one root followed by JSON whitespace and EOF. It rejects
BOM, malformed UTF-8, unpaired surrogate escapes, raw controls, malformed numbers,
duplicate decoded keys and trailing data. BOM rejection is the package's strict
policy. Parsing and streaming use one grammar.

JSONWritingOptions selects compact output or indentation of 0...8 units (spaces by default or literal tabs), insertion
or scalar key order, and normalized or preserved number text. Preserved lexemes
were admitted with their grammar and identity. Sorting makes no cryptographic
canonicalization claim.

JSONDocument owns optional original bytes and bounded value/member-key spans.
Spans are half-open zero-based byte ranges; diagnostic line/UTF-8 byte column and
physical record coordinates are one-based when present. Typed source paths keep
numeric object keys distinct from array indices. `replacingRoot` returns a root-only
document and discards the source label, bytes and mapping.

## Native Codable and field presence

`JSONValueEncoder.encode(_:)` and `JSONValueDecoder.decode(_:from:)` operate directly
on the JSON model. Their `encodeWithReport`/`decodeWithReport` counterparts expose
successful counts. Standard keyed, unkeyed, single-value and superclass containers
use invocation-owned state.

`JSONParser.decode(_:from:coding:)` accepts Data. `JSONWriter.encode(_:coding:)`
returns Data. These conveniences share one cumulative context and intersect the
facade and coding limits; they currently materialize the JSON value.

JSON, JSONObject and JSONNumber use exact native passthrough. String dictionaries
throw if Swift equality would collapse scalar-distinct keys. CodingKey enumeration
rejects changed scalar spellings; unrecognized keys remain ordinary unknown fields.
Caller models can intentionally discard fields, so model decoding does not itself
promise raw fidelity. Caller Codable/CodingKey computation and errors remain caller
work.

Integer projection is exact; Float/Double projection rounds to a finite target.
JSONNumber conversion has explicit exact/rounded policies. Data defaults to strict
metered Base64; Date defaults to its Codable representation. Explicit ISO-8601 uses
UTC fractional seconds, finite years 0000...9999 and at most 128 input UTF-8 bytes.
`JSONCodingOptions.userInfo` stores checked Sendable values.

Foreign Codable bridges inherit the foreign coder's source fidelity. External
numeric decoding tries Int64, UInt64 and Decimal, with no Double fallback. External
encoding requires an exact Int64, UInt64 or Decimal representation. Neither bridge
can recover keys or numbers already changed by another coder.

`KeyedEncodingContainer.encodePresence(_:forKey:)` omits absent fields, encodes null
explicitly and encodes present payloads. `decodePresence(_:forKey:)` classifies
missing/null/non-null wire state and throws for an incompatible non-null model.
Normal Optional/encodeIfPresent semantics remain unchanged. A generic payload that
itself encodes null cannot preserve an arbitrary extra in-memory distinction.

## Pointer, Patch and streams

JSONPointer accepts strict RFC 6901 text or decoded tokens. `uriFragment` separately
percent-decodes UTF-8 then tilde escapes. Appending keys, nonnegative indices and
other Pointers preserves exact token identity. Resolution uses the encountered
object/array kind; leading-zero array indices and a resolvable dash index fail.

[Patch](Patch.md) documents staged RFC 6902 and RFC 7396. Root removal is represented
outside the six-kind value model. [Streaming](Streaming.md) documents provisional
events/elements, certified completion, lifetime quotas and awaited output acceptance.

## Schemas, verdicts and inspection

JSONSchemaDocument admits raw object/Boolean declarations; compilation remains the
schema authority. JSONSchemaRegistry supplies immutable offline resources with
unambiguous retrieval identities. JSONSchemaCompiler creates a checked Sendable
CompiledJSONSchema; each JSONSchemaValidator call owns evaluation state.

Completed validation returns JSONValidationResult.isValid true or false. Schema
compilation errors, nonproductive references, output-unavailable errors, resource
failure and cancellation throw. They are not ordinary invalidity and propagate
through applicators. Format is annotation by default; content remains metadata.
See the exact [dialect and regex contract](SchemaAndRegex.md).

Flag/basic output uses collected issues and optional annotations. Complete output
throws on diagnostic exhaustion. Best-effort output marks diagnosticsComplete false
while semantic work continues; required evaluated-location state remains enforced.
A flag result cannot be upgraded to invent basic issues. `output` and
`outputWithReport` construct bounded JSON output without re-evaluating the instance.

Document and compiled `node`/`nodeWithReport` inspect immediate raw declarations at
an optional document Pointer. Compiled views may add resource identity and initial
reference targets. Unknown metadata, exact numeric constraints and defaults remain
raw declarations; inspection infers no effective schema, inserts no defaults and
cannot determine final dynamic targets without evaluation scope.

## Failures, diagnostics and cumulative accounting

JSONFailure carries a stable category/code, optional source location and optional
JSONResourceViolation. Counter overflow has attemptedUsage nil and overflow true.
CancellationError propagates separately. JSONDiagnostic classifies these errors
without rendering arbitrary caller descriptions or traversing rejected payloads.
JSONPreview is a redacted bounded snippet with explicit completeness, not a serializer.

JSONOperationReport pairs a successful result with JSONOperationStatistics:
accountingVersion, domain, metric counts and peakLogicalRetainedBytes. Capacity-only
predicates may report zero. Logical retention is not heap size, allocation count or
RSS; work is not elapsed time or a quota inside caller callbacks.

Owned composed helpers share one meter. Raw schema `compileWithReport` includes
schema document admission; its document overload starts after construction. Across
separate public calls, carry checked remaining work from successful reports and keep
subsystem ceilings independently. WorkUnits includes subsystem work, so subtract it
once. Failure/cancellation terminates the composition because no successful report
accounts for failed work. The [actual consumer interface](../ConsumerInterface.md)
and runnable consumer demonstrate this contract.

## Additive 1.1 candidate

JSON and JSONDocument provide `read(limits:_:)` and `readWithReport(limits:_:)`
with synchronous non-Sendable JSONReadCursor. Throwing String/JSONKey/Int brackets,
required kind/integer access, explicit Double/Decimal policies, raw/scalar/model
presence and native projection share one active meter. Paths are typed and bounded;
JSONAccessFailure carries the complete path and structured cause. Scope exit
invalidates handles and releases root/source ownership. Resource/cancellation
failures remain terminal when caught by a caller. See [reading](Release1.1/Reading.md).

JSON `init(encoding:coding:)`, `decode(_:coding:)` and `decodeWithReport(_:coding:)`
delegate to existing native facades. JSONCodablePayload provides
`init(preserving:limits:)`, `preservingWithReport(_:limits:)`, `value(limits:)`
and `valueWithReport(limits:)`. Its explicit Codable Version 1 stores validated
UTF-8 only and shares native parent budgets. See [persistence](Release1.1/Persistence.md).

The native ISO-8601 Date strategy now includes calendar fields as well as fractional
UTC time. Prior time-only stored values cannot recover their original calendar
date; application migration needs an independent source of that information.
Noncanonical Base64 with nonzero unused padding bits now rejects. These corrections
restore the documented strict/native contracts; they do not add a permissive mode.

## Additive 1.3 prepared export

See the [export contract](JSONHTMLExport.md) for compiler-proven declarations,
finite limits, selected-format transfer guards and the remaining RTF/PDF and
receiving-app qualification boundaries.

JSONHTMLRenderer also accepts JSONDocument in its four rendering/report methods.
Caller annotations use exact typed paths, explicit missing-parent attachment and
coherent value byte spans without schema execution or source-byte archival.
See [diagnostic rendering](Release1.3/DiagnosticAnnotations.md).

## Structured HTML and previews

Layout and presentation are orthogonal. Direct defaults are structured interactive
inspection; prepared/transfer defaults are structured static complete values. Typed
preview hints, the closed inline/MathML dialect and finite eligibility counters are
defined in [the additive contract](Release1.3/StructuredPreviews/APIAndPolicy.md).
Core exact values, native writer defaults and all 49 metrics retain their meanings.

## Provider-specific schema fragments (1.4 development)

`OpenAIJSONSchemaBridge(profile:limits:)` in JSONSchema provides `check`/`checkWithReport`,
`responseFormat`/`functionTool`, and their complete Data/String and WithReport forms.
Profiles are `.openAIResponsesFormatV1` and `.openAIResponsesFunctionV1`; native JSON schemas,
offline registries and exact typed issue paths stay authoritative. A compatible local check
is neither native validation of an instance nor a service-acceptance guarantee. Finite limits
and all phase accounting are specified in [Providers](Release1.4/Providers.md) and the frozen
[profile table](Release1.4/ProviderProfiles.json). No new product, SDK client or Apple type is added.

## Schema examples (1.6 G4 development)

The optional JSONSchemaExamples product prepares an immutable document/explicit
registry/compiled-plan snapshot. `JSONSchemaExampleGenerator(document:registry:options:)`
and `generate(seed:profile:)` offer exact declared candidates and compiler-qualified
static reference targets. Every success contains the actual native valid verdict
for the original root. Minimal scans stable exact declarations; demonstration
uses metered SplitMix64 rejection sampling and circular scans. An immutable exact
`JSONSchemaExampleCorpus` supplies candidates for true/empty schemas. Returned
objects/numbers use scalar order and normalized exact spelling. Conservative
typed construction covers the qualified foundational subset. G4 adds conservative
contains minima and a small anchored ASCII pattern-proposal grammar. Native
validation retains conditional, dependency, regex and evaluated-location semantics.
General constraint
solving, arbitrary regex inversion and dynamic construction remain incomplete.

`JSONSchemaExampleFailure` distinguishes unsupported construction, searchExhausted,
reviewed trivial provenUnsatisfiable and invalidConfiguration. Core operational
failures and cancellation propagate without retries. Preparation accounting is
separate from the shared per-generation ledger, which includes all completed
invalid checks. Discarded validation ownership is released without refunding work. Logical
retention is not process RSS.
The result binds the versioned snapshot, ordered corpus, all generation/compiler/
evaluator caps and flags, and complete abstract trace with SHA-256 digests. Trace
bytes share diagnosticBytes with native diagnostics; exhaustion never truncates a
success. See [the G3 constructive subset](Release1.6/G3Construction.md),
[the G4 advanced boundary](Release1.6/G4Construction.md),
[the capability ledger](Release1.6/Capabilities.json), [the G2 byte transports](Release1.6/G2Determinism.md), the historical
[G1 API decision](Release1.6/G1API.md), and the
[compiled public consumer](../../Examples/SchemaExamplesConsumer/README.md).

## Optional verified schema examples (1.6 development)

JSONSchemaExamples adds an immutable prepared generator over admitted documents and
explicit offline registries. Every returned value has a completed native root verdict,
with exact JSON semantics, cumulative generation statistics and versioned provenance.
It does not alter JSON/JSONSchema APIs, policies, products or dependencies.

See the [current public declarations and failures](Release1.6/API.md),
[supported construction subset](../../Sources/JSONSchemaExamples/Documentation.docc/TypedConstruction.md),
[resource scope](Release1.6/SchemaExamplesLimits.md) and
[compiled public consumer](../../Examples/SchemaExamplesConsumer/README.md).
Preparation and generation use separate finite ledgers. All attempts within a generation
share one ledger; false verdicts consume work, operational errors/cancellation terminate
without a candidate or successful report, and search exhaustion is not a proof.
The [combined-source G8 record](Release1.6/G8Qualification.md) describes qualification,
review and platform limits. Merge and release approval remain separate.
The CLI's human version reports the candidate/release source version. JSON metadata
includes `revisionKind: "source-sha256"` and `revision: "sha256:<hex>"`. This is the
SHA-256 of the ordered Package.swift plus Sources content manifest, excluding only
the generated identity file itself. It is not a Git commit, binary digest or claim
of publication. Generation/checking needs no Git, time, environment or network.

JSONNavigation product promotion preserves all 56 N1 public declarations and resource semantics. Full-source admission precedes invalid depth/record-option validation, including oversized sources; N1Promotion.md records this preserved precedence. JSON imports no Navigation symbols implicitly.

## Provisional JSONTransform extraction (1.7 feature branch)

JSONTransform is an opt-in public product depending on JSON and the private
JSONFilterRuntime kernel. JSON and JSONSchema do not import or re-export it.
JSONCLIEngine uses its package-only accounted adapters; both callers execute the
same FilterCompiler/FilterVM. The public interface contains no CLI context, file,
process, exit-code or private-runtime signature.

- `JSONTransformProgram.compile(_:variables:limits:)` creates an immutable Sendable
  plan under finite compilation limits. Variable names are ASCII identifiers,
  without `$`; JSON values retain exact native number and scalar-key semantics.
- `withExecution(input:bindings:limits:source:_:)` creates a synchronous guarded
  invocation and returns `JSONOperationReport<Result>`. Root admission, bindings,
  all pulls/provider values and output results share one cumulative ledger.
- `JSONTransformExecution.next()` returns `JSONTransformOutput?`. Nil means EOF;
  a present handle may contain JSON null. Handles share one owner and are not
  Sendable. Scope exit invalidates data access and releases provider/frame/root
  ownership; output aliases retain their source reservation until last release.
- `statistics`, `used(_:)` and `remainingWorkUnits` expose finite accounting without
  exporting a mutable meter. During provider callbacks they report the bounded
  callback-entry snapshot. `cancel()` latches terminal cancellation.
- `JSONTransformLimits` combines the existing native policy with eleven mapped
  transform ceilings. `JSONTransformFailure` distinguishes compilation, language,
  resource, cancelled, provider and configuration failures. Owned operational
  failures bypass query catches and remain terminal after caller catches.

Provider work/allocations and extracted JSON copies belong to the caller; logical
retention does not cap process RSS. Re-entering next() from the same provider
throws `configuration/reentrantExecution` before accessing its borrowed context.
The CLI retains one ledger across parsing, transformation, writing and diagnostics,
its sixteen existing metric names and its own completion/EOF duties. Public
compilation and execution are separate finite scopes, not one combined claim.

See the [actual API/ownership decision](Release1.7/JSONTransform.md),
[DocC guide](../../Sources/JSONTransform/Documentation.docc/ScopedTransforms.md)
and [standalone public SwiftPM consumer](../../Tools/TransformQualification).
This is an unreleased candidate, absent from published 1.6.1. No merge, tag,
publication, new dialect, implicit floating bridge or feature from another draft
follows from this contract.

## 1.7.0 release-candidate authority

This unpublished candidate retains the accepted Transform API (42 authored
declarations) and Inspection API (95), with all 56 Navigation declarations
unchanged. Historical provisional headings above remain stable link targets and
checkpoint descriptions; the [candidate contract](../Qualification/Release1.7.0.md)
and final compiler graphs determine current scope. API shape acceptance does not
imply publication, measured allocations or unobserved platform execution.

## Optional Dual DSL P1.2

The two DSL products do not change or re-export the existing core entry points.
JSONDSLCore has no standalone product; its public structural builder types occur
in the optional generic signatures. See the [decisions](DualDSL/Decisions.md).
Callbacks, content emission and staging are trusted and unmetered. Finalization
uses one finite invocation ledger through iterative construction and, for schemas,
document admission. This does not imply whole-pipeline cumulative billing, staging
retention, caller instruction or RSS bounds. No whole-DSL report is supplied.

Exact duplicate names throw JSONFailure/duplicateKey. Decoded scalar identity and
order are preserved. Missing declarations emit nothing; null, empty containers and
Boolean schemas differ. Array flattening requires Elements(contentsOf:). Implicit
numbers accept BinaryInteger only, with explicit JSONNumber for decimals. E2 and
JSONBridges remain unchanged; DSL targets import neither bridge nor framework DSL.

Schema rawKeyword preserves declarations for existing compiler classification.
No requiredness/default/format/reference/annotation policy is inferred. Invalid
instances return false; malformed schemas, offline missing resources, nonproductive
cycles, resource failures and cancellation remain operational errors. Factories
never validate or publish a candidate schema as already compiled.
