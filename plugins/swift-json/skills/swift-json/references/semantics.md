# Semantics and limits

The tagged public engine is authoritative. The compatibility map binds each
recipe to exact upstream declarations and their byte hashes.

JSONNumber represents bounded exact decimals. Parse decimal text directly;
binary64 cannot preserve all integers above 2^53 or decimal 0.1 exactly.
`Double(jsonNumber:)` defaults to exact conversion and rejects 0.1.
`policy: .rounded` makes finite rounding an explicit caller decision.
`jsonNumberFromRoundTripText()` adopts a finite Double's printed decimal meaning,
not its complete binary rational. JSONWriter's default normalized number text is
exact; `numberStyle: .preserved` keeps an admitted original lexeme. Native Codable does not route through a
Foundation JSONSerialization/JSONEncoder bridge.

String/key identity compares decoded Unicode scalars. U+00E9 and U+0065 U+0301
remain distinct. Swift String Dictionary behavior must not replace this identity.
Checked JSONObject admission rejects exact duplicate keys. Source insertion order
is preserved by iteration/writing; exact object equality ignores member order.
JSONPresence distinguishes absent, null and value. Null does not mean removal.
`JSONInspectionBatch.optionalValues` maps only an absent member or an index past
the end to nil; explicit null is `.some(.null)`. Because JSON accepts the nil
literal as null, test missing with `if let`, `switch` or `== .none`.

Store IDs are declared per collection. String IDs compare by decoded scalars;
integer IDs compare by exact mathematical value, so 7, 7.0 and 7e0 are one ID
and values beyond 2^53 stay exact. A string never matches an integer ID.

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

Located root-array spans are zero-based half-open UTF-8 byte offsets in the whole
stream, independent of chunking and excluding separators. They stay provisional
until `documentCompleted`, exactly like the elements.

Navigation complete/restricted/visitorStopped describe exploration, independently
of emission filtering. Shape evidence reports observed columns only; prefix
coverage states the examined and total rows and asserts nothing about the rest.
Batches admit the whole source once, keep caller order and repeats and publish
all results or throw. Store construction checks every declared link before a
store exists; follow returns the complete closure or a typed capacity failure.
Positions are bound to their store; a rebuilt store refuses old positions.
Transform executions and selections end at explicit EOF; a caught resource
failure is terminal and an early return from a selection is incompleteSelection. A finite collection refusal throws rather than silently
truncating. Physical and virtual scopes still admit the whole captured source.

JSONPatch stages edits; a later failure exposes no partial document. Distinguish
`.removed` from `.document(.null)`. JSONMergePatch returns a present JSON value.
JSONHTML's default formatted output escapes keys and values; data resembling an
HTML tag is not executable content. Other presentations have explicit policies.
