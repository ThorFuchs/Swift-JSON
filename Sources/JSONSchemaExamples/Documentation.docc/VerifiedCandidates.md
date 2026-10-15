# Verified candidates

Prepare an offline schema once and return exact JSON only after native validation succeeds.

## Prepare and generate

Add the optional JSONSchemaExamples product to your application target, then import
JSON, JSONSchema and JSONSchemaExamples explicitly. This product is in 1.6 development;
use the inspected feature checkout until a qualified release includes it.

```swift
import JSON
import JSONSchema
import JSONSchemaExamples

let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"const":9007199254740993}"#
))
let prepared = try JSONSchemaExampleGenerator(document: document)
let result = try prepared.generate(seed: 42, profile: .minimal)
let text = try JSONWriter().writeString(result.value)
precondition(result.validation.isValid && text == "9007199254740993")
precondition(result.attempts == 1 && result.statistics[.evaluationWorkUnits] > 0)
```

``JSONSchemaExampleGenerator`` retains the admitted document, explicit registry,
compiled plan and policies. Each call owns independent mutable state. A successful
``JSONSchemaExampleResult`` contains its exact value, actual native verdict,
cumulative statistics and versioned provenance. Callers cannot initialize a
certificate through a public initializer. The existing JSON model and
JSONSchemaCompiler/JSONSchemaValidator remain the semantic authorities.

## Select a definition and supply offline resources

A document containing only `$defs` does not select an instance schema. Root the
requested definition explicitly. Retrieval URIs identify resources; they never
cause network access. Compilation uses only packaged meta-schemas and your registry.

```swift
let parser = JSONParser()
let resource = try JSONSchemaDocument(parser.parse(
    #"{"$defs":{"count":{"type":"integer","minimum":9007199254740993}}}"#
), retrievalURI: JSONSchemaURI("https://example.com/schemas/counts"))
let registry = try JSONSchemaRegistry(documents: [resource])
let root = try JSONSchemaDocument(parser.parse(
    ##"{"$ref":"https://example.com/schemas/counts#/$defs/count"}"##
))
let prepared = try JSONSchemaExampleGenerator(document: root, registry: registry)
let result = try prepared.generate()
let plan = try JSONSchemaCompiler().compile(root, registry: registry)
let independentlyValid = try plan.validate(result.value).isValid
let exact = try JSONNumber(parsing: "9007199254740993")
let roundtrip = try JSONParser().parse(JSONWriter().write(result.value))
precondition(independentlyValid && result.value.numberValue == exact)
precondition(roundtrip == result.value)
```

The final verdict always evaluates the original prepared root, including reference
siblings. Raw `$defs`, defaults, examples and unknown metadata are retained without
inserting fields, repairing candidates or inferring requiredness. Static targets
come from the compiler-qualified plan; construction does not implement another URI
resolver. Reached dynamic scope and active same-instance cycles can fail explicitly.

## Handle incomplete search separately from errors

A rejected candidate is an ordinary completed false verdict and consumes budget.
An exhausted search can still have a valid witness outside the offered candidates.
Only root false and an active root `not` of true/empty schema have trivial proofs.
No search exhaustion, reference cycle or operational error establishes unsatisfiability.

```swift
let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"const":1,"type":"string"}"#
))
let prepared = try JSONSchemaExampleGenerator(document: document)
var exhausted = false
do {
    _ = try prepared.generate()
} catch JSONSchemaExampleFailure.searchExhausted(let attempts) {
    precondition(attempts == 1)
    exhausted = true
}
precondition(exhausted)
```

Other construction outcomes use ``JSONSchemaExampleFailure/unsupportedFeature(_:)``,
``JSONSchemaExampleFailure/provenUnsatisfiable(_:)`` or
``JSONSchemaExampleFailure/invalidConfiguration(_:)``. Native compilation/evaluation
errors, resource errors and CancellationError propagate separately; catch them only
when the application can handle them. A failure has no value or successful work report.

See <doc:TypedConstruction>, <doc:AdvancedConstruction>, <doc:DeterministicConstruction>
and <doc:PoliciesAndLimits> for the bounded construction and accounting contracts.
Every Swift block in these guides is synchronized with and executed by the standalone
Examples/SchemaExamplesConsumer package using public imports only.
