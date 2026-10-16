# G3 conservative typed construction

G3 extends the isolated G2 source at 42a523c. Native JSONSchema compilation and
complete root validation remain the only dialect/success authorities. No core
JSON or evaluator semantic changes, online resolution or dependencies are added.

After declared candidates are tried, a finite typed search constructs candidates
from compiler-qualified nodes. Positive allOf and static reference constraints
are gathered as conjunctions, not merged JSON schemas. AnyOf/oneOf child hints are
separate alternatives and every proposal is validated against the original root.
Dynamic construction and same-instance reference cycles remain explicit failures.
Nested instance construction uses an explicit frame stack; no recursive Swift
constructor or nested helper meter is introduced.

Type selection uses a fixed order: null, boolean, number (integer when required),
string, array, object. A declared number accepts integral and fractional values;
an integer restriction retains only mathematically integral candidates. Keyword
and member identity uses exact decoded scalar UTF-8. Required keys are the union
of active conjuncts, sorted exactly. Every applicable property/additional schema
contributes constraints for that member; no last-wins dictionary or inferred
requiredness is used. Optional false properties can be omitted. MinProperties
can add declared or synthetic names under each applicable additional schema.
Arrays honor basic sizes and prefix/items declarations. Unique items vary leaf
choices, with uniqueness certified only by the full validator.

Exact numeric proposals use bounded signed decimal digit arithmetic. A lower
bound is rounded to an exact positive step (one for integers; a decimal step
derived from bound precision for numbers). MultipleOf supplies an exact step;
integer multiples remove only the denominator's factors of two/five. Open bounds
advance by that exact step, never an arbitrary epsilon. Dense alignment beyond
numberDigits fails before allocation. Upper-bound proposals are used for negative
ranges. This is conservative search, not a general numerical constraint solver.

Strings count Unicode scalars. Minimal uses the shortest available filler; seeded
demonstration can use admitted synthetic tokens. Optional asserted email uses a
fixed example.com token. Format metadata never enables assertions. Arbitrary regex
inversion, dynamic scope, difficult conditionals/dependencies and evaluated-location
construction remain G4 or explicitly incomplete. Defaults/examples remain hints
and can be invalid; no value is repaired or schema rewritten.

All staging, key comparisons, decimal digits, queue/stack growth, reference steps,
trace bytes and final native checks use one noncopyable invocation meter. Each
candidate has checked value capacities; work and lifetime totals never reset.
Discarded staging refunds only its live logical ownership, retaining trace bytes
and cumulative work. Frame/value/slot weights use JSONLogicalWeights v1; qualified
constraint views reserve 64 logical bytes per slot. Bytes are not RSS. Caller
fixtures and ordinary Swift Testing oracle calls are separate qualification work.

The candidate algorithm becomes s3-candidates-v3. Snapshot/corpus/policy v1 byte
transports remain unchanged. Trace becomes swift-json-example-trace-v2 with header
SwiftJSON-example-trace-v2 LF, the same envelope/events as G2, plus offer role 5
(typed proposal), and code 6(depth,variation) for a typed value request. G2 vectors
remain preserved in history/archives; G3 vectors bind the new algorithm/version.
No cross-version or unexecuted cross-platform identity is promised.

Qualification must execute all 24 G3 must-generate IDs, both existing profiles and
multiple deterministic seeds; separately check two sound trivial proofs. Every
success must also pass an independent public native validation and strict value
roundtrip. The complete amended 44-case fixture is a pinned input, not a claim
that G4's remaining cases are implemented. A machine-readable capability ledger
keeps implemented hints, conservative search and deferred features distinct.
