# Combine checked structural workflows

Compose existing authorities while preserving exact values and each operation's limits.

## Validate, then interpret records

JSONSchema owns schema semantics. A valid verdict does not construct a store;
JSONInspection separately checks the explicit collection, ID and link profile.
An ordinary false verdict is a completed evaluation. A thrown operational error
must not be converted to false or an empty store.

```swift
import JSON
import JSONSchema
import JSONInspection

func validatedStore(document: JSONDocument, schema: CompiledJSONSchema,
                    profile: JSONStoreProfile) throws -> JSONConfiguredStore? {
    let validation = try JSONSchemaValidator().validateWithReport(document.root, against: schema)
    guard validation.result.isValid else { return nil } // Application's explicit invalid-input result.
    return try JSONStoreBuilder(document: document, profile: profile).build().result
}
```

Compile the schema against an explicit immutable offline registry. If a schema
contains only definitions, select the intended definition before validation;
the store does not invent a schema root or infer required properties.

## Read, transform and write

The executable `Examples/BoundedWorkflows` validates an exact source, constructs
a store, follows declared references, batch-reads the closure, runs the existing
JSONTransform compiler/VM and writes an independent byte-level golden result.
`9007199254740993` and `0.10000000000000001` never pass through Double.
Caller collection assembly between stages is ordinary caller work. Each public
stage has its own bounded report; this recipe does not create one pipeline-wide
ledger or a caller-instruction/RSS bound. Within a batch/follow/transform invocation,
all nested owned work still uses the original cumulative ledger.

A caught transform resource failure remains terminal for that execution. It is
not EOF, JSON null or schema invalidity. A later operation on the immutable source
has independent health. With an awaited streaming sink, already accepted bytes
remain accepted after cancellation; stage output in the caller if publication
must be atomic.

## Patch and rebuild deliberately

Apply JSONPatch to the original canonical value, then use
`JSONDocument.replacingRoot(_:)` to capture the result. The replacement has no
invented original source bytes/spans. Rebuild its store and obtain new positions;
old owner-bound tokens are refused even when most records are unchanged. A patch
which creates a dangling declared link cannot publish a successful checked store.
Root removal is `JSONPatchResult.removed`, distinct from a present JSON null.

## Interpret capacity evidence

The public consumer's `--capacity OUTPUT_DIRECTORY` mode uses fixed 1/8/64/512
request cells and small growing chains, unchanged balanced native limits and
explicit finite follow bounds. It checks exact work/retention and request boundaries,
compares independently admitted reads and writes fixture bytes for independent
hash verification. Logical counters are not heap allocations, RSS or elapsed time.
A diagnostic resource refusal remains an incomplete capacity observation. These
fixtures do not prove the default maxima jointly achievable or a speed improvement.

The existing developer kit stays pinned to its published library version. This
1.8 candidate recipe is compiled separately; it does not silently change that kit's
compatibility or distribution claims.
