# Exact numbers and Unicode

Scalar identity is required for values, keys, annotation sets, caches and all semantic comparisons.
No public arbitrary-precision arithmetic is introduced.

These contracts describe the public behavior and its resource boundaries.

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

## Native conversion bridge qualification

Binary32/binary64 conversion uses at most 800 coefficient digits plus a nonzero
sticky digit for a discarded normalized tail. A binary64 halfway boundary has
at most 769 finite decimal coefficient digits (a 54-bit integer times 5^1075), so
this reduction preserves the side of every rounding boundary and exact halfway
equality. The system converter receives at most 822 UTF-8 bytes, with checkpoints
before/after; original coefficient scans, short text construction and exactness
proofs share the operation meter. Exact conversion still compares the full exact
decimal against the reconstructed binary value. Numeric text reserves both its
result and construction buffer during their overlapping lifetimes.
