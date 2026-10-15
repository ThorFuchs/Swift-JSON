# Conservative typed construction

Construct a bounded proposal, then certify the complete original schema.

```swift
import JSON
import JSONSchema
import JSONSchemaExamples

let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"type":"integer","minimum":9007199254740993}"#
))
let generator = try JSONSchemaExampleGenerator(document: document)
let result = try generator.generate(seed: 42)
precondition(result.validation.isValid)
```

The standalone public consumer's G3 mode runs this shape and all 24 foundational
must-generate fixtures with both profiles and four seeds. It independently
validates and roundtrips all 192 values, checks 90 witness expectations and keeps
two trivial unsatisfiability proofs separate. Its caller I/O/assertions are
qualification work, separate from each generator invocation's cumulative meter.

## Exact scalars and containers

Basic numeric lower/upper/open bounds and multipleOf use exact bounded decimal
steps and signed rounding. Integers larger than UInt64 remain exact. There is no
Double, Foundation Decimal or epsilon intermediary. Dense digit alignment can
exhaust a finite quota; this is not a general constraint solver.

Strings count Unicode scalars. Demonstration can use immutable synthetic tokens;
known asserted email uses a fixed example.com address. Format metadata never
implicitly asserts a format or changes the declared type. Required keys are
preserved as exact scalar sequences, including simultaneous NFC/NFD spellings.
MinProperties can fill declared or synthetic keys. Each conjunction contributes
its own property/additional constraints, with no dictionary override or inferred
requiredness. Arrays preserve nesting, use positional prefix/items declarations
and bounded size. Uniqueness uses finite leaf variations and native certification.

## References, composition and incomplete search

Static reference targets come from the prepared compiler plan. Positive allOf
constraints remain separate conjunctions. AnyOf/oneOf declarations provide finite
alternative proposals, never branch-local certificates. Repeated DAG targets are
shared constraints; a same-instance ancestor reference cycle is unsupported.
Recursive containers can use an admitted empty base case. No independent URI
resolver, schema algebra, default repair or alternate validator is introduced.

Construction uses an explicit frame stack and the same invocation meter through
staging, comparisons, exact arithmetic, false verdicts and final trace hashing.
Operational error/cancellation terminates the call. Returned logical accounting
is not process RSS or caller instruction accounting. Required defaults/examples
can be invalid; an independently constructed proposal may later pass while the
original metadata remains unchanged.

## Supported construction subset

| Declarations | Current proposal behavior | Boundary |
| --- | --- | --- |
| const, enum, default, examples | Exact declared candidates, arrays in declaration order | Defaults/examples can be invalid; no repair |
| type and unions | Fixed kind order and qualified intersections | No universal witness promise |
| minimum/maximum, exclusive bounds, multipleOf | Bounded exact decimal stepping/rounding | Several divisors or dense alignment can fail or exhaust limits |
| minLength/maxLength | Scalar-counted corpus or filler strings | Byte caps also apply; no implicit Unicode normalization |
| required/properties/minProperties/maxProperties | Exact required keys, declared or synthetic names | No general pattern/name/dependency key synthesis |
| prefixItems/items/minItems/maxItems/uniqueItems | Positional typed proposals and finite variations | Uniqueness can exhaust search |
| contains/minContains/maxContains | Minimum matching-position hints | Full native evaluation counts all matches and maxima |
| Anchored literal/range/exact-repeat patterns | Bounded ASCII proposals | No general regex inversion; native regex certifies |
| Static refs, allOf, anyOf, oneOf | Qualified targets, separate conjunctions and finite hints | No schema merging or branch-local certification |
| if/then/else, dependencies, not, unevaluated locations | Native certification of offered candidates | No general constructive solver |
| Dynamic references and cycles | Optional omission or finite base case can succeed | Reached dynamic scope/active same-instance cycles fail explicitly |

The machine-readable Release1.6/Capabilities ledger classifies all 59 compiled
keywords; it describes construction hints, not changes to Draft 2020-12 evaluation.
A validator-supported keyword is not necessarily constructively supported. G3/G4
fixture success applies to the pinned cases, not every schema using those keywords.

## Preserve exact keys and requiredness

```swift
let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"type":"object","required":["é","e\u0301"],"properties":{"é":{"const":9007199254740993},"e\u0301":{"const":null},"optional":{"default":42}}}"#
))
let result = try JSONSchemaExampleGenerator(document: document).generate()
let object = result.value.objectValue
let exact = try JSONNumber(parsing: "9007199254740993")
precondition(object?.count == 2 && object?["é"]?.numberValue == exact)
precondition(object?["e\u{301}"] == .null && object?["optional"] == nil)
```

Both scalar-distinct keys survive. Null is present; the optional default is not
inserted. See <doc:PoliciesAndLimits> for cumulative work and retention semantics.
G5 native lifecycle qualification is complete; final platform/integration/release
qualification remains G7/G8.
