# Numeric fidelity

Import JSON and JSONBridges explicitly; import Foundation when using Decimal.
These opt-in development extensions do not appear with a core-only import.

```swift
let count: UInt64 = 9_007_199_254_740_993
let before = JSONNumber(integer: count)
let after = count.jsonNumber() // Trusted construction, without an operation meter.
precondition(before == after)
let recovered = try UInt64(jsonNumber: after)
precondition(recovered == count)
let tenth = try JSONNumber(parsing: "0.1")
let rounded = try Double(jsonNumber: tenth, policy: .rounded)
let adoptedText = try rounded.jsonNumberFromRoundTripText()
precondition(adoptedText == tenth)
let decimal = try Decimal(jsonNumber: tenth)
precondition(decimal == Decimal(string: "0.1"))
```

Trusted BinaryInteger construction is exact and unmetered, with work and storage
growing with digit count. It is not an untrusted arbitrary-precision admission API.
FixedWidthInteger projection is integral, sign- and range-checked and bounded by
the same finite limits as JSONNumber.integer(as:limits:).

Decimal JSON 0.1 is mathematical one tenth. Binary64 0.1 is a different rational;
Double's shortest round-trip text is `0.1`. Adopting that text does not preserve
the exact binary rational. The default exact Double initializer rejects this
JSON decimal; `.rounded` explicitly permits finite rounding. NaN, infinities,
overflow, resource exhaustion and cancellation throw; none becomes JSON null.
Negative zero uses JSON's single mathematical zero identity.

Do not widen Float to Double to simulate a Float bridge. On the qualified toolchain
Float(0.1) renders `0.1`, while its widened Double renders `0.10000000149011612`.
Float, Float16, Float80 and CGFloat source bridges are deferred. The package-only
exactBinary helper stays private: promoting exact-binary source conversion needs
a separate bounded-work, admission and retained-digit correctness review.

Foundation Decimal has fixed precision and exponent bounds. Its initializer uses
the existing exact/rounded projection, including its limits. Decimal-to-JSON is
deferred pending a formatting, locale and admission contract. Arbitrary Any,
NSNumber, Optional and dictionary conversions are deliberately absent.

Each throwing bridge forwards one existing delegate and limits unchanged. It
creates no cache or hidden multi-stage quota. Use the owning APIs for reports;
logical retained bytes are distinct from RSS and caller work from owned work.
