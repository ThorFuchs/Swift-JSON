# ``JSONPatch``

Staged RFC 6902 and RFC 7396 operations over the exact JSON model.

``JSONPatch`` parses or constructs add, remove, replace, move, copy and test
operations. Navigation uses strict RFC 6901 tokens and runtime array indices.
Moves remove their source before resolving the destination; moving a value
into its descendant fails. Test uses exact scalar/decimal equality and
order-independent object equality. Irrelevant extra operation members are
ignored as RFC 6902 specifies.

All operations run against invocation-owned staged values. A failure returns
no partially changed document and leaves the caller value unchanged.
``JSONPatchResult`` distinguishes a removed root from a document containing
JSON null. A subsequent root add can recreate a removed document.

``JSONMergePatch`` implements RFC 7396: null object members remove properties,
object patches recurse with explicit frames, and other values replace the
selected value. A root null replaces the document with JSON null. Arrays are
replaced whole. Exact scalar key identity is preserved.

Input, payload and intermediate staged-value capacities are checked under
``JSONPatchOptions``. Replaced ownership is retired; input scanning, comparison,
copying and editing work remains cumulative. A later removal cannot rescue an
earlier oversized stage. Reports expose logical accounting, not process RSS.

## Topics

- ``JSONPatch``
- ``JSONPatchOperation``
- ``JSONPatchResult``
- ``JSONPatchOptions``
- ``JSONMergePatch``
