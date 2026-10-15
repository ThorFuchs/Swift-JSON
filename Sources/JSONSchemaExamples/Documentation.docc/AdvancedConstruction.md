# Conservative advanced proposals

Use bounded hints while keeping the complete native schema as the authority.

```swift
import JSON
import JSONSchema
import JSONSchemaExamples

let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"type":"array","minItems":2,"uniqueItems":true,"items":{"type":"string"},"contains":{"pattern":"^SKU-[0-9]{4}$"},"minContains":2,"maxContains":2}"#
))
let result = try JSONSchemaExampleGenerator(document: document).generate(seed: 42)
precondition(result.validation.isValid)
```

The native tests execute this composed shape. Contains hints request enough items
and add the qualified contains child beside each applicable prefix/items child.
Several conjunctions remain separate. Full native validation counts actual matches,
checks maxima and propagates evaluated-item annotations. The constructor does not
solve arbitrary matching partitions or prevent every possible surplus match.

The pattern helper only proposes fully anchored ASCII sequences of printable
literals, escaped regex punctuation, single ASCII ranges and exact `{n}` repeats.
It neither matches strings nor replaces the native regex engine. Unsupported
patterns can use finite admitted corpus/filler candidates. No Foundation regex,
external parser, unbounded fallback or new runtime dependency is introduced.

## Honest incomplete search

AllOf, oneOf, conditionals, dependencies, property-name/pattern rules and
unevaluated-location behavior are checked against the original root. Empty optional
objects or a later finite variation can satisfy some schemas; that does not
establish general constructive support for those keywords. A oneOf branch candidate
matching two branches is rejected and its evaluation work remains charged.

Static external references require explicit immutable registry resources. Compiler
identities preserve base URI and anchor transitions. Reaching a scope-dependent
dynamic reference fails explicitly; omitting an optional dynamic child may yield a
valid finite witness without implementing constructive dynamic navigation.

The G4 public consumer executes ten additional must-generate cases and eight
may-fail cases across two profiles/four seeds, recording every outcome. A may-fail
case may return a fully verified witness or explicit unsupported/exhausted result.
It cannot turn search failure into an unsatisfiability proof. Native resource
errors, compilation errors and cancellation remain operational failures.

All scans, repeat digits, staging and completed false verdicts use the same finite
generation ledger. Returned statistics describe successful calls only; no value
or successful report is invented after a failure. Logical retained bytes are not
RSS and caller qualification work is separate. Algorithm is s3-candidates-v4;
the trace v2 grammar and source/corpus/policy v1 transports remain unchanged.
G5-G8 lifecycle/platform/integration/release qualification remains separate.
