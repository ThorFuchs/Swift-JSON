# Pointer, Patch and Merge Patch

These contracts describe the public behavior and its resource boundaries.

## Pointer and Patch behavior

JSONPointer.init(parsing:limits:) is throwing. Accept an empty root Pointer or slash-prefixed tokens; accept only ~0 and ~1 escapes. Decode URI fragment form through a separately named operation so percent-decoding and tilde-decoding order are unambiguous. String tokens retain exact scalar spelling. Evaluation distinguishes object keys from array indices using the actual encountered value.

Array indices use RFC 6901/RFC 6902 grammar and checked numeric conversion; leading zeroes and out-of-range indices fail as appropriate. The dash append token is permitted only where the Patch operation allows it. A root Pointer can select a whole value. Represent root removal with JSONPatchResult.removed, outside the six-kind JSON model. JSONPatchResult.document(JSON) represents an existing document. The staged Patch state can therefore remove the root and later recreate it with add, without manufacturing null or reintroducing a missing JSON case.

JSONPatchOperation represents add, remove, replace, move, copy and test. Patch JSON decoding checks required fields and preserves ordinary RFC treatment of irrelevant extra members rather than imposing an undocumented unknown-field rejection. JSONPatch.applying(to:options:) returns a JSONPatchResult only after all operations succeed. Input remains unchanged if a later operation fails.

Move resolves/removes before interpreting the target in the modified document, with correct same-array indexing. A destination inside the moved source subtree fails. Copy has independent value semantics even with physical copy-on-write sharing. Test uses exact budgeted equality, including order-independent objects and scalar-distinct strings. No case uses serialization text as mathematical equality.

The general Patch API preserves document absence explicitly; consumers choose how to handle removal. Test empty-root add/remove/replace/test and remove-then-add sequences, including the preconditions when no document exists.

## Pointer construction and composition

JSONPointer is reusable and immutable; parse it once when resolving repeatedly. In addition to strict textual construction, the API provides construction from literal key tokens and checked array-index convenience, plus appending operations. These methods escape tilde and slash correctly without callers performing string concatenation.

A Pointer token is text. Appending key “0” and appending index 0 may generate the same Pointer spelling; resolution interprets it using the actual object or array encountered. Typed runtime diagnostic locations preserve that distinction. Do not pretend that Pointer syntax alone identifies an array.

Reject negative index construction, invalid escape syntax and configured token/byte overflow. A bounded pointer from decoded tokens is distinct from parsing an already escaped string or a URI fragment. URI fragments must not be double decoded.

Pointer construction is a convenience over strict tokens. It adds no wildcards, JSONPath, jq expressions, automatic parent creation or ambiguous autovivification. Test empty keys, slash/tilde, Unicode scalar identity, numeric object keys, percent fragments and repeated resolution with one immutable Pointer.

## JSON Merge Patch

JSONMergePatch implements RFC 7396 in the JSONPatch product. This offers an object-shaped partial-update use case beside RFC 6902 operations. The new type uses the exact JSON model and an explicitly bounded staged application.

An object patch recursively updates members; a null-valued member removes that member. Arrays and other non-object patches replace the target wholesale. A null patch at the root produces the JSON value null, not document removal. Arrays are replaced rather than concatenated.

JSONMergePatch.applying(to:options:) accepts JSON and returns JSON. Resource checks reuse core depth/nodes/text/growth limits and cumulative patch work. RFC 6902's operation-array count applies to that array format; Merge Patch member traversal is bounded by value/member/work ceilings rather than pretending every member is an RFC 6902 operation.

The implementation uses explicit frames and exact JSONKey identity. A null-valued
object patch member cannot assign literal null to that member; use RFC 6902 for
that distinction. Qualification covers standard vectors, nested admission limits,
array replacement, root null, absent targets and scalar-distinct names.
