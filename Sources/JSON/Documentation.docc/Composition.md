# Compose native operations

Run synchronous native operations and explicitly instrumented adapter work with
one finite ledger. The experimental composition facade does not meter arbitrary
callback instructions, allocator sizes, physical RSS, or Foundation instructions.

```swift
import Foundation
import JSON
import JSONSchema

let report = try JSON.withComposition { scope in
    try scope.withParsedDocument(Data(#"{"count":9007199254740993}"#.utf8)) { document, root in
        try scope.reserveExternalLogicalBytes(64) // Adapter-declared output frame weight.
        try scope.chargeExternalWork(1)           // Before the adapter's corresponding work.
        let pointer = try scope.pointer(tokens: ["count"])
        _ = try scope.uri("https://example.invalid/schema.json")
        _ = document.sourceMap
        return try scope.resolve(pointer, in: root)
    }
}
```

The scope is borrowed, noncopyable, synchronous and not Sendable. Its methods
mutate invocation-owned private state. The closure cannot replace or swap the
borrowed facade. It has no public
initializer, continuation or refund. Every reservation lasts
until completion. Re-admitting a value reserves its graph again; resolving an
arbitrary JSON input reserves its input graph and selected graph again. This intentionally overcounts
aliases and dead temporaries rather than assuming copy-on-write releases memory.
Reserve each external result, queue, diagnostic and copied slot before growth;
choose and audit its logical weights in the adapter. A zero reservation makes no
claim about opaque storage. External loops must charge/checkpoint regularly.

`parseDocument` pre-admits the complete Data-to-array buffer before allocation,
charges each copied byte and runs the native source-map parser on the same meter.
The original caller Data is excluded; the array copy remains conservatively
reserved alongside decoded values, source bytes, spans and final output.
Version 1 native weights and internal scratch releases follow the resource
contract. Reported peak is this ledger's conservative logical peak, not a sum of
independent operation peaks. Final retained bytes include all unreleased
reservations, even when the callback returns a smaller result.

All owned helper errors are terminal, including syntax and missing-target errors.
Catching one cannot produce a successful report. Scope exit rethrows the original
owned failure ahead of any later callback error. Restriction intersects limits
and preserves admitted capacities, cumulative work, live bytes and health.
A fresh invocation has a fresh budget; nesting does not certify inner work as
part of an outer report. Use a single borrowed scope throughout the adapter.

URI operations in JSONSchema use the core domain: URI identity and adapter models
are not compiled schema plans. They do not charge compiledPlanBytes or
compileWorkUnits. This facade does not compose schema compilation or evaluation.
No circular JSON-to-JSONSchema dependency is introduced.

`JSONOperationReport` has a public initializer. Its type is not a cryptographic or
unforgeable receipt, and it cannot establish that an arbitrary callback charged
all its work. An adopting adapter must own its final accounting boundary and audit
all external work and reservations. Independent reports cannot retroactively
certify one enforced invocation.

For repeated lookups, `withAdmittedRoot` admits a trusted immutable graph once.
`withParsedDocument` supplies the source-backed document and a handle to its
already-admitted root, without a second root traversal. Both borrow a noncopyable,
non-Sendable `JSONCompositionRoot` in a synchronous nonescaping callback. The handle
has no public constructor, value accessor, mutation or refund. It keeps the exact
immutable snapshot even if the caller later replaces its original JSON value.

Only the creating composition can resolve against a handle. A wrong-owner attempt
fails before navigation and permanently fails the receiving invocation. The owner
identity is a private reference retained by the handle, so identity cannot be
recycled while a handle exists. Native health and cumulative limits still apply.
No mutable meter borrow spans callback execution.

Root ownership and one 16-byte logical handle slot remain charged after the root
callback ends, until composition completion. Each selected output graph is still
admitted and reserved separately, including an empty Pointer selecting the whole
root. Pointer admission and navigation remain metered. For R small selections over
an N-node root, admission becomes O(N) plus navigation and selected-output work;
large selected graphs still cost their full size. Calling `withAdmittedRoot` again
reserves another graph even for aliases. This API never caches arbitrary JSON
identity or presumes a copy-on-write refund.

The pinned Swift 6.4 compiler can abort when implicitly named borrowed callback
parameters are captured by local functions or escaping containers. Spell callback
parameter ownership explicitly when factoring synchronous work into helpers:

```swift
try JSON.withComposition { (scope: borrowing JSONCompositionScope) in
    try scope.withAdmittedRoot(value) { (root: borrowing JSONCompositionRoot) in
        let pointer = try scope.pointer(tokens: ["name"])
        return try scope.resolve(pointer, in: root)
    }
}
```

Use a closure literal, for example `try perform { try scope.checkpoint() }`,
instead of a bound method reference. Instance methods explicitly borrow `self`;
Swift 6.4 diagnoses bound method capture, including a reference passed to a
nonescaping helper. Qualification preserves the original inferred-capture crash
cases and unsupported positive as blockers. Explicit spelling is a verified source
workaround; it does not establish general compiler robustness.
