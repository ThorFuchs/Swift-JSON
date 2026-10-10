# Public API contract



These contracts describe the public behavior and its resource boundaries.

## Public products and implementation boundaries

| Public product | Public surface | Private implementation |
| --- | --- | --- |
| JSON | JSON, JSONKey, JSONObject, JSONNumber, JSONParser, JSONWriter, JSONValueEncoder, JSONValueDecoder, JSONDocument, JSONPointer, configuration and diagnostics | Shared lexer/token machine, work meters, decimal components, source maps, budgeted traversal |
| JSONSchema | JSONSchemaDocument, JSONSchemaRegistry, JSONSchemaCompiler, CompiledJSONSchema, JSONSchemaValidator, verdicts, output and options | Immutable indexed plan, invocation evaluation stack, URI resolution, numeric and annotation helpers |
| JSONStreaming | JSONByteChunk, JSONEvent, JSONEventSequence, JSONValueSequence, NDJSONValueSequence, JSONAsyncWriter, stream options | Pull iterator state, token machine composition and framing |
| JSONPatch | JSONPatch, JSONPatchOperation, JSONPatchResult, Patch options and errors | Transaction staging, budgeted comparison and iterative editing |

JSON imports none of its siblings. JSONSchema may depend on a private JSONRegexRuntime target; that target has no public product, imports no schema or MCP types, and exposes only package access. JSONStreaming and JSONPatch depend on JSON. Internal JSON helpers that other targets need use checked package access rather than public SPI, underscored imports, or a second parser. Helpers remain generic: JSON must not contain schema vocabulary or transport concepts.

JSONSchema keeps its evaluator inside its own target initially. Another private engine target is justified only by an actual implementation boundary; it is not a fifth public module. Runtime code does not pull in SwiftSyntax, CLI, HTTP, UI, AI, benchmark or DocC packages. A qualified Swift Collections dependency could be added when measurement justifies it, with JSONKey as the key; ordinary String keys cannot be substituted for convenience.

The root manifest declares four buildable public products. Qualification requires exercised public consumers, populated suites and supported native execution.

## Values and construction

Use an indirect enum JSON with object(JSONObject), array([JSON]), string(String), number(JSONNumber), boolean(Bool), and null cases. Prefer the complete name boolean to parallel the documented data model. JSON is Equatable, Hashable and checked Sendable. Equality and hashing are custom where needed: String cases compare scalar sequences; objects compare membership independently of insertion order; numbers compare mathematical values.

JSONKey owns a decoded String but implements equality and hashing over its exact UTF-8 scalar spelling. JSONObject owns ordered JSONMember records with exact JSONKey lookup. The current scalar implementation uses bounded linear lookup. It provides String and JSONKey lookup. Iteration is deterministic insertion order; replacing a member preserves its position, removal deletes it, and re-insertion appends it. Hash input must be independent of object order. Randomized Swift hash seeds are not a persistent digest.

| Construction or lookup | Contract |
| --- | --- |
| JSONObject(members:limits:) throws | Accept an ordered list of JSONMember; reject exact duplicate keys; check text, member, node and retained-state limits |
| JSONObject subscript(String or JSONKey) -> JSON? | Absence is nil; a present JSON.null is a value |
| JSON.objectValue, arrayValue, stringValue, numberValue, booleanValue | Optional type inspection with no coercion |
| JSON.requiredMember(_:limits:) throws -> JSON | Structured missing-value or type error; bounded key/path work |
| JSONPointer.resolve(in:limits:) throws -> JSON | Strict Pointer evaluation with typed runtime path components |
| JSONComparison.equals(_:_:limits:) throws -> Bool | Explicitly budgeted deep equality for validation/Patch and user operations |
| JSONObject.setting(_:for:limits:) throws -> JSONObject | A new value with checked replacement/growth; the original stays unchanged |

Direct enum cases and Swift arrays are useful for trusted in-memory construction. They cannot prevent a caller from allocating an arbitrarily large value before entering the library. Every bounded operation therefore validates/charges caller-constructed values too. Existing caller memory is outside the allocation ownership claim, while traversal and copies performed by the operation are inside it.

Ordinary Equatable and Hashable methods cannot throw a resource error or return cancellation. They have semantic guarantees, not an invocation budget guarantee. Untrusted bounded operations must use the package's charged traversal, comparison and fingerprint implementation; they must not hide an uncharged Set<JSON> or equality call inside uniqueItems, const, enum or Patch test. Cached metadata may accelerate work but does not excuse charging the admitted value size. Sorting keys similarly charges comparisons and examined bytes.

Initially offer string, boolean, null, array and integer construction convenience where it has deterministic semantics. Throwing JSONObject construction is the authority for duplicate detection. Do not ship dictionary-literal behavior that traps on duplicates or silently selects a winner. Do not enable floating-point literals for JSONNumber or JSON; their rounded Swift Double value would obscure exact input. JSONBuilder is an optional thin construction layer over the same checked APIs, not an alternative value model.

## Exact numbers and conversions

JSONNumber stores normalized sign, decimal coefficient and exponent, with optimized common-integer storage and optional original lexeme. Its private representation may use decimal limbs. Normalization removes redundant leading/trailing zeros with checked exponent adjustment. Zero has one mathematical identity. It does not allocate zeros proportional to a large exponent.

Recommended public contracts are:

```swift
// API design sketch. Native declaration and consumer compilation are W01 gates.
JSONNumber(parsing: "9007199254740993", limits: .balanced) throws
JSONNumber(integer: someInt64)
JSONNumber.fromFiniteDouble(someDouble, limits: .balanced) throws
number.integer(as: Int64.self) throws
number.doubleValue(policy: .exact) throws
number.doubleValue(policy: .rounded) throws
number.decimalValue(policy: .exact) throws
number.numericText(style: .normalized, limits: .balanced) throws
```

The finite-Double constructor uses a documented round-trip decimal rendering of the supplied binary value. It preserves that rendering's decimal meaning, not a vanished original input or the exact infinite binary-to-decimal expansion. NaN and infinities fail construction. Exact Double conversion succeeds only when the mathematical decimal equals a representable finite Double; shortest-text round-tripping alone is not that proof. For example, decimal 0.1 is not exactly representable as Double. An explicitly rounded conversion reports overflow instead of producing infinity. Exact Decimal conversion checks the supported decimal representation and reports range/precision failure.

Raw coefficient digits and token bytes have separate limits, so leading zeros or long exponent spelling cannot evade admission accounting. Exponent magnitude is checked while parsing before narrowing to Int64 and again after normalization. Int64.min/max conversion and sign handling avoid negation and boundary traps. Mathematical integer detection, order and multipleOf use exact components. Divisors must be positive schemas, and numeric work exhaustion is an operational error, never a floating epsilon judgment.

No general public big-number arithmetic API enters this release. The private numeric subsystem implements only comparison, integrality, conversion and divisibility needed by the public contracts. Each limb scan and each operand-pair operation in multiplication/division is charged. Large divisibility problems may correctly return a numeric resource error within an explicit profile.

## Parser writer and document API

Select top-level names JSONParser, JSONWriter, JSONValueEncoder and JSONValueDecoder. This avoids building the primary API around JSON.Encoder beside Foundation.JSONEncoder. The JSON module and JSON value type intentionally share a name; the native external consumer must test ordinary imports and any documented qualified spelling, including with Foundation and all sibling imports.

JSONParser and JSONWriter are immutable checked Sendable facades containing value configuration. Each call creates an exclusively owned mutable context. The primary byte entry points use Foundation Data, with String UTF-8 convenience and an owned [UInt8] overload if it prevents copies. Generic collections are an optimization experiment, not an excuse to expose escaping borrowed storage.

```swift
// Intended consumer spelling; compile and test this exact example in W01–W04.
import Foundation
import JSON

let parser = JSONParser(options: .init(limits: .balanced))
let value = try parser.parse(Data(#"{"count":9007199254740993,"note":null}"#.utf8))
let count = try value.requiredMember("count").numberValue
let output = try JSONWriter().write(value)
```

The example's optional number inspection is deliberate: requiredMember guarantees presence, while numberValue still checks the kind. Typed convenience may combine both only by throwing a type mismatch; it must never manufacture a default value.

| Entry point | Return and behavior |
| --- | --- |
| JSONParser.parse(Data/String) throws -> JSON | Exactly one root followed by whitespace; strict UTF-8; reject duplicates, BOM, malformed escapes, raw controls, malformed numbers and trailing data |
| JSONParser.parseDocument(Data, source:) throws -> JSONDocument | Opt-in owned source and bounded value/member source spans |
| JSONWriter.write(JSON) throws -> Data | Compact UTF-8 default; validate caller-built values; complete escaping and exact normalized numbers |
| JSONWriter.writeString(JSON) throws -> String | UTF-8 output with the same limits; charge the additional owned result |
| JSONWriter options | Compact/pretty layout, insertion/scalar-key order and normalized/preserved numeric lexemes; no canonical-signature claim |
| JSONDocument.root and source lookup | Immutable coherent value/source snapshot; replacement produces a document with source mapping discarded unless regenerated |

Rejecting BOM is a documented strict package policy rather than an assertion that every JSON implementation must reject it. Unpaired surrogate escapes are rejected instead of converted to replacement characters. Source locations store zero-based byte offsets; human line/column rendering is explicitly one-based, with a defined LF/CRLF policy and UTF-8 byte columns. Arrays use index components, objects use key components, even when a key consists of digits.

The package-visible JSONTokenMachine accepts owned byte chunks, keeps only admitted incomplete state and exposes owned tokens/events. Its explicit state transitions are ready, reading, complete, failed and finished. Each execution step advances input, emits progress, requests more bytes or fails. End-of-input converts incomplete state into an error. An explicit container stack enforces depth before push.

All traversal that can follow attacker-controlled depth, including parsing, writing, previewing, schema evaluation and Patch editing, uses explicit bounded frames. A recursive convenience traversal is acceptable only when bounded and separately proved stack-safe at the maximum supported profile. JSON enum deinitialization and synthesized helpers also need deep-value stress; explicit-stack parsing alone does not prove all lifecycle operations safe.

String/key sorting is by Unicode scalar order using UTF-8 scalar spelling, independent of locale and Swift canonical comparison. Pretty indentation is a finite checked configuration, not arbitrary caller text that could inject non-whitespace. Preserved numeric lexemes are emitted only after their grammar and numeric identity were established; legacy unchecked lexemes cannot bypass the writer.

## Native Codable conversion

JSONValueEncoder.encode<T: Encodable>(T) throws -> JSON and JSONValueDecoder.decode<T: Decodable>(T.Type, from: JSON) throws -> T operate directly on the owned model. They do not route through Foundation bytes or share pooled encoder state. All containers, coding paths, userInfo and strategy state are invocation-owned.

Support standard nested/unkeyed/single-value containers, superEncoder/superDecoder, checked integer types, explicit null and absent-key behavior. JSON and JSONNumber have Codable bridges, with exact native passthrough inside these coders. External arbitrary Encoder/Decoder bridges cannot offer the same assurance: an external decoder may already have rounded a number or collapsed object keys, and the bridge cannot reliably detect or undo that loss.

For an external decoder, attempt numeric admission as Int64, UInt64, then Foundation Decimal and preserve the mathematical value actually supplied by that decoder. Do not add a Double fallback. The external bridge throws when none is available; successfully decoding Decimal is not evidence that the original source was exact. External numeric encoding uses an exact Int64, UInt64 or Decimal conversion and throws if none can represent the value. Complete fidelity requires the package's native parser and value coders. Document and test this boundary beside the conformance rather than claiming universally lossless Codable.

Expose explicit date and data strategies. Date defaults to the Codable representation supplied by Foundation Date; the named ISO-8601 strategy renders UTC with fractional seconds and admits only finite dates in years 0000–9999 (Gregorian interval [-62167219200, 253402300800) since the Unix epoch). Parsing rejects text above 128 UTF-8 bytes before invoking the fixed Foundation ISO8601FormatStyle. Its synchronous bounded bridge checks cancellation before and after the call. Data defaults to base64, documented and tested. Nonconforming floats throw. Default key strategy preserves coding-key spelling. Any snake-case or custom key strategy must detect exact output collisions. A custom strategy is trusted caller code and is outside the library's enforceable instruction budget; all library work around it remains bounded.

Prefer a bounded, checked Sendable userInfo representation to a public [CodingUserInfoKey: Any] property. A typed Sendable box or immutable map of allowed user values must compile under Swift 6.4. Do not mark an arbitrary Any dictionary unchecked Sendable to preserve a legacy signature. Non-Sendable user models may be encoded synchronously without pretending they can cross an async boundary.

Library-owned conversion failures use standard DecodingError/EncodingError where Codable consumers expect them, with a bounded underlying JSON failure/location. Errors thrown by user Encodable/Decodable implementations propagate according to the documented API. Strongly typed throws is reserved for operations whose complete error set the package owns; upstream stream/sink and user coding errors make an unconditional narrow typed-throws declaration inappropriate.

## Errors validation verdicts and output

Use a checked Sendable JSONFailure with a stable category/code, optional bounded structured location and optional JSONResourceViolation record. The violation has operation domain, metric identifier, configured limit and attempted usage. It does not embed a full input, arbitrary underlying error or unbounded descriptive String.

| Situation | Observable outcome |
| --- | --- |
| Malformed bytes or framing | Syntax failure with byte/record position |
| Wrong kind or absent value | Type mismatch or missing-value failure |
| Invalid Pointer/index/Patch precondition | Pointer or Patch failure |
| Numeric conversion cannot preserve requested value | Conversion failure |
| Invalid limit/strategy configuration | Configuration failure |
| Limit exceeded or checked counter overflow | Resource failure with metric |
| Cancelled owned work | CancellationError; diagnostic serialization uses a stable cancellation code |
| Upstream source/sink/user coding throws | Propagated documented caller error; bounded library-owned context only |
| Invalid schema document/dialect/vocabulary/reference | JSONSchemaCompilationFailure with the specific category |
| Well-formed qualified schema and completed evaluation | JSONValidationResult with valid or invalid verdict |
| Evaluation budget, backend or cancellation failure | Operational throw; no validation verdict |

Use native CancellationError for owned APIs and test it in W01; the structured cancellation category is for diagnostic serialization only. Do not require callers to match two interchangeable cancellation error types for the same entry point.

JSONValidationResult separates the verdict from issues and annotations. Flag output returns the verdict. Basic output includes bounded structured issues; detailed/verbose output may be added only with qualified output schemas and limits. Internal evaluated-property/item state required for unevaluated semantics exists even when user annotations are disabled. Exhausting that state quota is always operational failure.

Complete requested diagnostic/annotation output throws if its capacity is exceeded. An explicit best-effort output policy may return truncated diagnostics only after the verdict is established independently, marking completeness false; it must not stop semantic evaluation or omit required evaluated-location work. The default is complete output, preventing silent truncation. The output API exposes instance Pointer, keyword-relative Pointer and absolute keyword resource location as applicable; message text is supplemental.

Redacted previews have their own finite work/output limits and redact an exact-scalar key policy. Conservative preview defaults are depth 4, 32 total visited nodes and 4 KiB output, with a clear truncation marker that itself fits the limit. Error construction must not traverse a whole rejected document just to explain a resource failure.

## Pointer and Patch behavior

JSONPointer.init(parsing:limits:) is throwing. Accept an empty root Pointer or slash-prefixed tokens; accept only ~0 and ~1 escapes. Decode URI fragment form through a separately named operation so percent-decoding and tilde-decoding order are unambiguous. String tokens retain exact scalar spelling. Evaluation distinguishes object keys from array indices using the actual encountered value.

Array indices use RFC 6901/RFC 6902 grammar and checked numeric conversion; leading zeroes and out-of-range indices fail as appropriate. The dash append token is permitted only where the Patch operation allows it. A root Pointer can select a whole value. Represent root removal with JSONPatchResult.removed, outside the six-kind JSON model. JSONPatchResult.document(JSON) represents an existing document. The staged Patch state can therefore remove the root and later recreate it with add, without manufacturing null or reintroducing a missing JSON case.

JSONPatchOperation represents add, remove, replace, move, copy and test. Patch JSON decoding checks required fields and preserves ordinary RFC treatment of irrelevant extra members rather than imposing an undocumented unknown-field rejection. JSONPatch.applying(to:options:) returns a JSONPatchResult only after all operations succeed. Input remains unchanged if a later operation fails.

Move resolves/removes before interpreting the target in the modified document, with correct same-array indexing. A destination inside the moved source subtree fails. Copy has independent value semantics even with physical copy-on-write sharing. Test uses exact budgeted equality, including order-independent objects and scalar-distinct strings. No case uses serialization text as mathematical equality.

A separately named convenience requiring a surviving document may return JSON or throw a specific no-document result error. The general Patch API preserves document absence explicitly; consumers choose how to handle removal. Test empty-root add/remove/replace/test and remove-then-add sequences, including the preconditions when no document exists.

## E01 Explicit field presence

Add an owned JSONPresence<Value> representation with absent, null and value states. Lookup on JSONObject or JSON reports these states explicitly, while the underlying JSON value still has exactly six kinds. A present null must never become absence, and missing data must never become zero, false or null silently.

Recommended spelling is presence(of:) for generic JSON lookup, with explicitly named native coding helpers for typed fields. A typed helper throws when a present non-null value cannot be decoded as the requested type; it does not coerce it to absence. Array positions do not omit absent values by convenience.

| Input object state | Presence result | Keyed native encoding |
| --- | --- | --- |
| Member absent | absent | Omit this member through the explicit helper |
| Member present as null | null | Encode the key with null |
| Member present with a non-null value | value(decoded value) | Encode the supplied value |

The encoding rules belong to an explicit keyed helper. Do not adopt a global “always encode nil” or “never encode nil” policy that changes existing Codable semantics. Do not promise that an arbitrary property wrapper automatically observes an omitted key; synthesized Codable has container behavior that needs separate qualification. Normal Optional/encodeIfPresent behavior remains documented.

For generic Value types capable of themselves encoding null, a caller can construct value(nil) or value(JSON.null). The helper can emit the corresponding wire null, but cannot promise to recover that arbitrary in-memory distinction on decoding. Native lookup classifies the actual JSON wire/model state into the three documented cases.

This refinement makes configuration overlays, partial requests and patch inputs easier to use. It remains a generic representation, with no MCP or Archive semantics. Tests cover omitted versus null, wrong kind, exact numeric conversion, scalar-distinct member names, explicit keyed coding, nested fields and Sendable conditional on Value.

## E02 Explicit construction modes

Use separate object-member and array-element construction. The existing generic JSONBuilder must not guess a container shape from whichever components happen to appear, flatten arrays implicitly, or use an empty object as a stand-in for an omitted branch.

Prefer a small metered closure builder first:

```swift
// Design sketch; native spelling and declarations are consumer-build gates.
let object = try JSONObject.build(limits: .balanced) { members in
    try members.append("title", value: .string("Research"))
    if includeDetails {
        try members.append("details", value: details)
    }
}
```

The exclusive member accumulator owns the invocation budget. It checks before append, rejects duplicate exact-scalar names and preserves insertion order. An array accumulator appends a nested array as one value; explicit append(contentsOf:) expresses flattening and charges every inserted value. Caller closure computation is trusted caller work; collection growth performed by the library is metered.

Result-builder syntax can follow if a real consumer proves that it preserves these semantics and enforces admission without hidden unbounded intermediate arrays or global task-local construction state. It is a syntax refinement, not a release requirement for a second construction engine. Avoid an existential JSONComponent layer solely to infer shapes.

Tests include empty containers, conditional omission, nested arrays, explicit flattening, duplicate names, scalar-distinct names, throw-before-growth limits and non-Sendable caller models used synchronously.

## E03 Pointer construction and composition

JSONPointer should be reusable, immutable and parsed once. In addition to strict textual construction, provide construction from literal key tokens and checked array-index convenience, plus appending operations. These methods escape tilde and slash correctly without callers performing string concatenation.

A Pointer token is text. Appending key “0” and appending index 0 may generate the same Pointer spelling; resolution interprets it using the actual object or array encountered. Typed runtime diagnostic locations preserve that distinction. Do not pretend that Pointer syntax alone identifies an array.

Reject negative index construction, invalid escape syntax and configured token/byte overflow. A bounded pointer from decoded tokens is distinct from parsing an already escaped string or a URI fragment. URI fragments must not be double decoded.

This is an ergonomic extension to the Pointer facility already planned. It adds no wildcards, JSONPath, jq expressions, automatic parent creation or ambiguous autovivification. Test empty keys, slash/tilde, Unicode scalar identity, numeric object keys, percent fragments and repeated resolution with one immutable Pointer.

## E04 Composed typed byte coding

Offer one-call conveniences for strict bytes-to-model decoding and model-to-bytes encoding through the existing components:

- JSONParser.decode(Type.self, from: bytes, coding: options) composes strict parse with JSONValueDecoder.
- JSONWriter.encode(value, coding: options) composes JSONValueEncoder with strict write.

Use one operation context for cumulative work, copies and peak retained state. Each stage applies its own applicable ceilings, and a helper must not restart the total meter. Reusing an immutable value does not count as a fresh allocation; traversing or copying it still consumes work. User Codable code remains outside an enforceable instruction guarantee.

These are convenience APIs, not evidence of faster decoding. They may initially materialize JSON. A direct Codable-to-bytes engine or decoder that skips constructing the model would be another implementation path needing full semantic equivalence tests; do not introduce it merely to reduce an allocation count before measuring the baseline.

Verify dates/data, coding paths, userInfo, inherited classes, custom coding failures, missing/null, integer boundaries, non-finite floats and native exact JSON/number passthrough. Documentation must retain the external-decoder fidelity boundary.

## E08 Operation statistics

Expose opt-in reports from owned operations using counters already required for enforcement. A report pairs the ordinary result with versioned statistics: bytes admitted/emitted, values visited, charged work, subsystem work where applicable, and peak logical retained bytes. Count units and accounting-version identity are part of the documentation.

Do not put unconditional statistics payloads into every JSON value or add a global metrics/logger dependency. Report-producing entry points may wrap results; ordinary APIs remain concise. Conditional Sendable follows the result's actual type, particularly for user-decoded non-Sendable models. A structured resource failure already reports its limit/attempted usage; extending its bounded diagnostic context must not retain the full input.

Logical retained accounting is not process RSS or exact allocation count. Clock measurement belongs in benchmarks or an explicitly separate timing option. Payloads, member names and source bytes are absent from statistics by default. Mandatory work counters stay active when reporting is disabled.

This makes resource tuning, reproducible failures and benchmark interpretation easier without adding a telemetry system. Verify counters at exact boundary values, their behavior on growth/refund, aggregate composition, disabled-report overhead and agreement between scalar and optimized paths.

## Verified native projections and cumulative public reports

Native `JSON` and `JSONObject` Codable round-trips retain every decoded scalar
key and exact number. A `Dictionary<String, Value>` projection throws
`DecodingError.dataCorrupted` if Swift's canonical String equality collapses
members. Key enumeration also rejects a `CodingKey` initializer that changes
an accepted member's scalar spelling; keys the initializer does not recognize
remain ordinary unknown fields. Custom model decoding and CodingKey work are
caller code. They can intentionally discard fields, so their result is not a
raw-fidelity guarantee. External coders may have lost information before this
package receives it.

Native integer projections are exact and fail on range/fractional loss.
Native Float/Double projections round into the requested finite binary type;
use `JSONNumber.doubleValue(policy: .exact)` for a mathematical equality proof.
JSONNumber itself preserves the original decimal value and optional lexeme.

The raw overload `JSONSchemaCompiler.compileWithReport(_:retrievalURI:registry:)`
accepts JSON and includes document admission and compilation in one meter.
The document overload reports compilation after document construction. Report
version 1 exposes counts through `statistics[JSONResourceMetric]`, plus peak
logical retained bytes. Capacity predicates may report zero; they are not
cumulative work. Reports exist only on successful operations.

A caller can carry a checked remaining-work allowance across independent public
calls by passing its remaining `JSONLimits` and subtracting successful reports.
WorkUnits already contains subsystem work, so do not add the subsystem counts
again to that total. Keep subsystem allowances as additional independent ceilings.
A failed/cancelled stage terminates the composed operation: it has no successful
report and cannot retry downstream with a fresh allowance. The compiled
`Tools/MCPReadiness` example and `RC/ConsumerInterface.md` show the actual interface.
