# Additive ergonomics E2

These development APIs are opt-in additions to the existing semantic authorities.
Existing calls remain supported. No tagged release is changed by this feature branch.

| Task | Before | After | Authority and boundary |
| --- | --- | --- | --- |
| Strict parsing | `JSONParser(options: options).parse(input)` | `JSON.parse(input, options: options)` | Same overload/input/options, including owned-copy accounting |
| Build object | `.object(try JSONObject.build(body))` | `try JSON.buildObject(body)` | Same exclusive accumulator and cumulative meter |
| Exact decimal | `.number(try JSONNumber(parsing: text))` | `try JSON.number(parsing: text)` | Same strict admission and original lexeme |
| Navigate Pointer | `try pointer.resolve(in: root)` | `try root.value(at: pointer)` | Resolution only; no hidden Pointer parsing |
| Exact key membership | `object[key] != nil` | `object.containsKey(key)` | Unmetered exact indexed lookup; null is present |
| Presence transformation | Exhaustive switch | `presence.map(transform)` / `fold(absent:null:value:)` | Exactly one case; callbacks are caller work and rethrow |
| Reuse schema plan | `try JSONSchemaValidator(options: options).validate(instance, against: plan)` | `try plan.validate(instance, options: options)` | Same evaluation; invalidity is false, operational failures throw |
| Trusted integer | `JSONNumber(integer: count)` | `count.jsonNumber()` | JSONBridges only; exact, trusted and unmetered |
| Checked integer | `try number.integer(as: UInt64.self)` | `try UInt64(jsonNumber: number)` | Same finite integral/range/sign projection |
| Adopt Double text | `try JSONNumber.fromFiniteDouble(value)` | `try value.jsonNumberFromRoundTripText()` | Same finite shortest round-trip decimal text, not exact binary rational |
| Project binary64 | `try number.doubleValue(policy: policy)` | `try Double(jsonNumber: number, policy: policy)` | Exact default, finite rounding opt-in |
| Project Foundation Decimal | `try number.decimalValue(policy: policy)` | `try Decimal(jsonNumber: number, policy: policy)` | Same fixed target precision/range and policy |

The three full guides have public-only executable counterparts in
[ErgonomicsExamples.swift](../../Examples/Consumer/Sources/Consumer/ErgonomicsExamples.swift).
The native/Linux CI lanes verify their fences, compile old callsites, test bridge
import isolation in debug/release, and execute the consumer. README fences are
separately synchronized and executed by the documentation lane.

- [Entry points, builders, scoped reads and presence](../../Sources/JSON/Documentation.docc/QuickEntryPoints.md)
- [Numeric fidelity and optional imports](../../Sources/JSONBridges/Documentation.docc/NumericFidelity.md)
- [Compiled-plan validation](../../Sources/JSONSchema/Documentation.docc/CompiledPlanConvenience.md)
- [Core differential cases](../../Tests/JSONTests/ErgonomicsTests.swift)
- [Bridge differential cases](../../Tests/JSONBridgesTests/ConversionTests.swift)
- [Schema differential cases](../../Tests/JSONSchemaTests/ErgonomicsTests.swift)

## Decisions and exclusions

The Swift 6.4 compiler accepts a generic JSON.number integer overload but selects
it for existing `.number(42)` calls, replacing the enum-case declaration. E2's
source-resolution gate therefore defers it. Keep explicit JSONNumber construction
or opt into `.number(count.jsonNumber())`.

Only JSONKey membership is added: string literals already work and dynamic String
conversion remains explicit. No String-key overload proliferation, keys/values
copied arrays, nested aliases, umbrella imports, writer synonyms, static Codable
synonyms or raw-string Pointer composition is needed for this wave.

JSONBridges is a separate sixth product depending on JSON only. Core imports no
leaf product and does not re-export bridges. Numeric source conversion for Float,
Float16, Float80, CGFloat and Foundation Decimal remains deferred. The existing
package-only exactBinary Double routine remains private pending separate finite
admission, retained-digit, nonfinite and extreme-subnormal correctness review.

Any/NSNumber/dictionary/Optional bridges, implicit float/dictionary literals,
null-on-error navigation and public mutation setters are excluded. No parser,
regex, schema dialect, stream completion, Patch transaction, source map, profile,
callback ownership or cursor lifetime implementation changes are made. Existing
reports remain the route for cumulative successful accounting; errors/cancellation
are terminal when no successful report accounts for the work. Logical bytes are
not RSS and owned work units do not meter arbitrary caller computation.

No runtime speed, zero-allocation or measured human-usability improvement is
claimed. Compiler symbol graphs and compiled task examples establish surface
shape and validity; platform execution receipts establish only their stated scope.
