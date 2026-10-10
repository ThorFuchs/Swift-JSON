# Public API contract

This document describes the implemented public interface. Native compiler symbol
graphs supply the complete declarations in the four DocC catalogs. Examples
in the [README](../../README.md) are compiled and executed by the public consumer.

## Products and ownership

| Product | Main entry points | Owned implementation boundary |
| --- | --- | --- |
| JSON | JSON, JSONNumber, JSONObject, JSONParser, JSONWriter, JSONValueEncoder, JSONValueDecoder, JSONPointer, JSONDocument | Shared strict codec, exact decimal model, bounded traversal and native coding |
| JSONSchema | JSONSchemaDocument, JSONSchemaRegistry, JSONSchemaCompiler, CompiledJSONSchema, JSONSchemaValidator | Offline immutable plan, invocation-owned evaluation and private native regex |
| JSONStreaming | JSONEventSequence, JSONValueSequence, NDJSONValueSequence, JSONTopLevelArraySequence, JSONAsyncWriter | Exclusive pull state, shared codec, strict framing and awaited handoffs |
| JSONPatch | JSONPatch, JSONPatchOperation, JSONPatchResult, JSONMergePatch | Transaction staging, exact comparison and iterative editing |

JSON imports no siblings. JSONSchema depends on JSON and package-private
JSONRegexRuntime. Streaming and Patch depend on JSON. There are four public
products and no external root-package dependencies. Runtime code uses no HTTP,
UI, MCP or documentation-tool dependencies.

Immutable facades store value configuration. Every operation owns its mutable
context; every stream iterator requires exclusive access. Sendable follows the
actual stored state and result types. See [concurrency](Concurrency.md).

## Exact values and construction

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
| Object subscripts by String/JSONKey | Unmetered linear exact-key lookup; nil means absence |
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

JSONWritingOptions selects compact output or indentation of 0...8 spaces, insertion
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
