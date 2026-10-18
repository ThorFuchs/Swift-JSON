# Semantics and limits

The tagged public engine is authoritative. The compatibility map binds each
recipe to exact upstream declarations and their byte hashes.

JSONNumber represents bounded exact decimals. Parse decimal text directly;
binary64 cannot preserve all integers above 2^53 or decimal 0.1 exactly.
`Double(jsonNumber:)` defaults to exact conversion and rejects 0.1.
`policy: .rounded` makes finite rounding an explicit caller decision.
`jsonNumberFromRoundTripText()` adopts a finite Double's printed decimal meaning,
not its complete binary rational. Native Codable does not route through a
Foundation JSONSerialization/JSONEncoder bridge.

String/key identity compares decoded Unicode scalars. U+00E9 and U+0065 U+0301
remain distinct. Swift String Dictionary behavior must not replace this identity.
Checked JSONObject admission rejects exact duplicate keys. Source insertion order
is preserved by iteration/writing; exact object equality ignores member order.
JSONPresence distinguishes absent, null and value. Null does not mean removal.

Each owned operation admits inputs and checks finite work and logical capacity.
Nested work within that operation is cumulative, including failed schema branches,
regex work, Patch intermediate values and iterator-lifetime stream quotas.
Independent public calls have independent ledgers. A generator's preparation
and generate invocation are separate documented phases; certification and prior
failed candidate work share the generation ledger.

Do not translate logical retained bytes into RSS promises or interpret a callback
as having a caller instruction quota. Preallocated source chunks and values have
caller-owned allocations; the reader still checks admission and owned work.
All profiles are finite. Choose explicit ceilings, check cancellation, and retain
terminal failure instead of retrying the same input with reset quotas.

Schema `.isValid == false` is a completed ordinary invalid verdict. A work budget
failure throws JSONFailure with category resource and the violated metric.
Best-effort diagnostic limits can yield diagnosticsComplete false with a completed
verdict; evaluation exhaustion never becomes an ordinary false verdict.
Annotation-only format and default metadata do not imply validation or mutation.
An immutable explicit registry is offline; it is not a network resolver.

NDJSON permits a final complete record without LF. Exhaust the iterator to nil;
strict syntax failures and initialized-iterator cancellation are terminal.
Earlier records survive but do not certify the rest. Root-array early yields
require later enclosing completion. Await sinks and respect exclusive iterators.

Navigation complete/restricted/visitorStopped describe exploration, independently
of emission filtering. A finite collection refusal throws rather than silently
truncating. Physical and virtual scopes still admit the whole captured source.

JSONPatch stages edits; a later failure exposes no partial document. Distinguish
`.removed` from `.document(.null)`. JSONMergePatch returns a present JSON value.
JSONHTML's default formatted output escapes keys and values; data resembling an
HTML tag is not executable content. Other presentations have explicit policies.
