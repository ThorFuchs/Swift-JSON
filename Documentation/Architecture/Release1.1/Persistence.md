# Exact Version 1 persistence

The implemented public wrapper is immutable `JSONCodablePayload: Sendable, Codable`.
`init(preserving:limits:)`, `preservingWithReport(_:limits:)`, `value(limits:)`
and `valueWithReport(limits:)` use the existing owned codec. Private storage is
validated UTF-8 Data only, without a DOM cache, public byte mutation or equality.

Version 1 requires format `swift-json-value`, integer version 1 and strict standard
Base64 `utf8Base64`. Compact insertion-order writing preserves admitted number
lexemes, with normalized fallback. Scalar sequences, exact decimals and array/member
order survive fixed-primitive foreign transport. Whitespace/escape/source-document
fidelity is outside this contract. Eight committed golden fixtures pin the envelope
and inner hashes; empty arrays/objects are additional behavior cases.

Construction preflights prospective Base64, fixed envelope output and text sizes.
Explicit limits intersect balanced, never widen it. Decode admits text before
decoding, checks decoded size, certifies complete inner grammar/EOF and releases the
temporary DOM. Opening is a fresh bounded parse. Copies, simultaneous byte/text/DOM
ownership, work and cancellation share the enclosing native meter when nested.
Foreign callbacks/allocations remain caller work. No meter is borrowed across an
Encoder/Decoder callback. Logical retention is not an allocator or RSS promise.

Required field types use ordinary Codable errors. Unknown marker/version and
malformed inner syntax/Base64 map to bounded corruption with a static description;
resource/configuration failures and cancellation retain their types. A caller that
catches an owned operational failure cannot certify successful native completion.
The shared Base64 decoder now rejects nonzero unused padding bits, closing a real
strict-codec gap. No legacy heuristic or corrupt-data-to-null fallback is added.

`Tools/MobileQualification` imports the four public products and SwiftData outside
the core package. Three Swift Testing cases qualify public behavior, stream/sink
completion/cancellation and disk persistence. The disk case saves eight exact
fixtures, executes each save/reopen/update phase in a separate process, reopens at the
same URL, checks scalar bytes/order/lexemes, queries/sorts ordinary fields, updates,
releases again and verifies a third reopen. Optional nil and present JSON null are
distinct. SwiftData owns its database representation; embedded JSON predicates and
cloud synchronization are not claimed. Mac, simulator and physical-device outcomes
are separate receipts. Under the [amended 1.1 policy](QualificationPolicy.json),
macOS, both simulator families and physical iPhone disk phases remain required;
physical iPad disk execution is deferred and nonblocking.

The first simulator release run failed the additional weak-container assertion:
SwiftData retained a container beyond lexical scope. The debug Mac run passed it.
Retain both outcomes; do not claim that SDK lifetime is controlled by this package.
The final disk harness uses three independently exited processes on Mac/simulators,
so reopening cannot read prior model/context/container memory or SDK caches.
