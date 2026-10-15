# Exact numbers and Unicode

JSONNumber represents bounded exact decimals. JSON strings, JSONKey and semantic
annotation sets preserve decoded Unicode scalar identity without normalization.
No arbitrary-precision public arithmetic surface is exposed.

## Values, text and keys

Equivalent decimal spellings compare mathematically: 1, 1.0 and 1e0 share one
identity. Integers beyond binary64 precision remain distinct. Negative zero and
positive zero share mathematical identity. Parsed numbers may retain original
lexemes for preserved writing; normalized writing emits coefficient/exponent form.
Large exponents do not allocate a dense run of zeros.

JSONKey equality and hashing examine exact UTF-8 scalar spelling. Composed é and
e followed by a combining acute accent are distinct keys and string values.
JSONObject preserves insertion order, rejects exact duplicate keys and compares
membership independently of order. Replacing a key preserves position; removal
then re-insertion appends. Swift randomized hashes are not persistent digests.

Ordinary equality, hashing and object subscripts are unmetered protocol conveniences.
Use JSONComparison.equals(_:_:limits:), bounded member access or Pointer for work
that needs an invocation quota. Direct cases and literals are trusted construction;
bounded operations still admit them. Native String-dictionary decoding rejects a
projection that would collapse scalar-distinct keys.

## Numeric conversion

```swift
let number = try JSONNumber(parsing: "9007199254740993")
let integer = try number.integer(as: Int64.self)
let text = try number.numericText(style: .preserved)
```

Integer conversion requires an integral in-range mathematical value and handles
signed boundaries without negation traps. Exact Double conversion proves equality
with a representable finite binary64 value; decimal 0.1 fails this proof. Rounded
conversion permits finite rounding and still rejects overflow. Decimal conversion
has the target's fixed precision/exponent bounds; exact policy verifies equality.

JSONNumber.fromFiniteDouble preserves Swift's round-trip decimal rendering of the
supplied finite binary value. It cannot recover an earlier source token or the full
terminating decimal expansion of its binary rational. NaN and infinities fail. Native Codable integer
projections are exact; Float/Double projections round to their requested finite type.
Foreign coders determine the fidelity of values they supply.

Digit and token-byte caps apply before normalization, and exponent magnitude is
checked during admission and normalization. Exact schema comparison, integrality
and multipleOf use charged decimal work without epsilon judgments. Divisors must
be positive in schemas. Quota exhaustion is operational failure. Each scan and
operand-pair step is charged; large divisibility problems can reach a finite cap.

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
