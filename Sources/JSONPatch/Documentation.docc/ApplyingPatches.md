# Choosing and applying patches

Choose operation-based editing or object-shaped updates while preserving exact values.

## RFC 6902 JSON Patch

``JSONPatch`` admits an ordered operation list or JSON operation array. Each
operation uses strict `JSONPointer` navigation. Extra operation members
follow RFC treatment and are ignored; required fields and operation shapes fail
when malformed.

```swift
let original = try JSONParser().parse(#"{"count":1}"#)
let patch = try JSONPatch(operations: [
    .replace(path: JSONPointer(parsing: "/count"), value: 2)
])
let result = try patch.applying(to: original)
```

Add can replace an object member or append at an array dash token. Replace/remove
require an existing target. Move removes its source before resolving the destination
and cannot move into its descendant. Copy has value semantics and charged payload
work. Test uses exact decimals/scalars and order-independent object equality.

Operations run against invocation-owned staging. A later failure exposes no partial
result and leaves the caller value unchanged. Every intermediate stage must fit
configured capacities; a later removal cannot rescue an earlier oversized stage.
Work remains cumulative even when retired ownership refunds logical retention.

## Root removal and null

``JSONPatchResult`` distinguishes a document containing JSON null from a removed
root. A later root add can recreate a removed document. The six-kind JSON model
itself contains no missing-document case, so inspect the Patch result explicitly.

## RFC 7396 Merge Patch

``JSONMergePatch`` applies object-shaped updates. Object null members remove
properties; nested objects merge through explicit frames. Arrays and non-object
values replace the selected target whole. A root null produces JSON null and
does not remove the document.

Merge Patch cannot use a null-valued object member to assign literal null to that
member. Use RFC 6902 add/replace for that distinction. Exact scalar keys remain
independent throughout both standards.

Both APIs offer successful reports and enforce finite input, staged-value,
retention and work limits. Errors and cancellation produce no completed result.

## Topics

- ``JSONPatchOperation``
- ``JSONPatchResult``
- ``JSONMergePatch``
- ``JSONPatchOptions``
