# Conservative typed construction

Construct a bounded proposal, then certify the complete original schema.

```swift
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

The machine-readable Release1.6/Capabilities ledger distinguishes constructive
hints, conservative search and native-certification-only features. G4's advanced
fixtures and G5-G8 lifecycle/platform/release qualification remain separate.
