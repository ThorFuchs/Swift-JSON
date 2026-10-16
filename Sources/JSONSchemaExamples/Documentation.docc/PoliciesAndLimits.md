# Policies, limits and lifecycle

Keep preparation separate, bound every generation attempt cumulatively and treat errors as terminal.

## Configure finite budgets and read remaining work

``JSONSchemaExampleOptions/compilationOptions`` governs the whole preparation:
compilation plus source, corpus and policy serialization/hashing. Generation uses
the per-metric intersection of ``JSONSchemaExampleOptions/limits`` and
``JSONSchemaExampleOptions/validationOptions`` limits. Both default to balanced;
maximumAttempts defaults to 16 and counts completed invalid validations too.

```swift
import JSON
import JSONSchema
import JSONSchemaExamples

var limits = JSONLimits.conservative
limits[.workUnits] = 2_000_000
var evaluation = JSONSchemaOptions(limits: limits)
evaluation.collectAnnotations = true
let options = JSONSchemaExampleOptions(
    limits: limits, maximumAttempts: 4, validationOptions: evaluation
)
let prepared = try JSONSchemaExampleGenerator(
    document: JSONSchemaDocument(JSONParser().parse(#"{"enum":[0,"ok"],"type":"string"}"#)),
    options: options
)
let result = try prepared.generate()
let ceiling = min(prepared.options.limits[.workUnits],
                  prepared.options.validationOptions.limits[.workUnits])
let used = result.statistics[.workUnits]
precondition(used <= ceiling)
let remainingWork = ceiling - used
precondition(remainingWork < ceiling && result.attempts == 2)
precondition(result.statistics[.evaluationWorkUnits] > 0)
```

Discovery, construction, normalization, every native validation and final trace
hashing share one invocation meter. False verdicts keep their evaluation/numeric/
regex work and issue/diagnostic charges. Subsystem work is already included in
workUnits: do not subtract it again. Work, numeric work, evaluation work and
aggregateRegexWorkUnits never reset between candidates or branches. A separate
public generate call starts an independent invocation, not a continuation of a
previous report. To bound a larger caller composition, carry checked remaining
work and subsystem ceilings across its successful calls. PreparationStatistics is
separate and must fit its preparation policy; do not add memory peaks together.

## Preserve evaluator policy and raw metadata

Format is annotation by default. The generator forwards explicit validation options
unchanged; a required format-assertion vocabulary remains authoritative. Compilation
assertion policy is separately retained. Defaults and examples only offer candidates.
The generator neither fills defaults nor upgrades raw metadata into constraints.

```swift
let document = try JSONSchemaDocument(JSONParser().parse(
    #"{"const":"not-an-email","format":"email","default":"example@example.com"}"#
))
let annotated = try JSONSchemaExampleGenerator(document: document).generate()
precondition(annotated.value == .string("not-an-email"))
precondition(!annotated.validationOptions.formatAssertion)
let plan = try JSONSchemaCompiler().compile(document)
let asserted = try plan.validate(annotated.value, options: .init(formatAssertion: true))
precondition(!asserted.isValid)
precondition(document.raw.objectValue?["default"] == .string("example@example.com"))
precondition(!annotated.compilationOptions.formatAssertion)
```

Do not combine a result with another plan, registry or policy and imply the original
certificate applies. Independent validation above is application verification work,
separate from the completed generation report.

## Capacity, retention and terminal state

All 49 existing profile entries stay finite. Individual strings, numeric tokens,
containers, depth and active frames have capacity ceilings. Per-materialization
input/output/node/text capacities retire between candidates while report totals and
charged work are preserved. Per-search regex work has its existing search ceiling;
aggregate regex work remains cumulative. Compilation-only, streaming and Patch
metrics do not imply that generation performs those operations. No new unlimited
setting or generated-node metric is introduced.

``JSONSchemaExampleResult/statistics`` snapshots certification, including the returned
value/verdict, metadata and conservative staging reservations. Some scratch reservations
live until the proposal or invocation ends even when Swift can release a temporary
earlier. Rejected ownership is released without refunding work. Remaining invocation
reservations end on result transfer or failure. Prepared source/registry/corpus/plan
ownership lasts as long as the caller retains the immutable generator. A returned
value remains usable after preparation leaves scope; it holds no generator or search stack.

Logical retained bytes and peakLogicalRetainedBytes are accounting weights, not heap
size, allocator reclamation timing or RSS. Owned work quotas do not cap arbitrary
caller callbacks or instructions and are not wall-clock deadlines.

Native operational errors and cancellation immediately end the invocation. Cleanup
preserves the first terminal failure and consumed counters. No partial candidate or
successful report escapes; retrying with a fresh full quota would lose a caller's
cumulative bound. Cancellation is checked at entry, before owned growth and inside
numeric, regex, traversal and hashing work. There is no public callback or detached
background generator. Independent calls can safely reuse immutable preparation.

A successful abstract trace is complete. Its bytes share diagnosticBytes with
native diagnostics; exhaustion throws instead of returning a truncated certificate.
Trace hashing includes its actual 64-byte hex result. The G5 correction removed an
unmatched 32-byte refund without changing the algorithm, transport or default caps.
Platform-wide release qualification and controlled performance remain separate gates.
