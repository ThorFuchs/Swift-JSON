# Compose native operations

Run synchronous native operations and explicitly instrumented adapter work with
one finite ledger. The experimental composition facade does not meter arbitrary
callback instructions, allocator sizes, physical RSS, or Foundation instructions.

```swift
import Foundation
import JSON
import JSONSchema

let report = try JSON.withComposition { scope in
    let document = try scope.parseDocument(Data(#"{"count":9007199254740993}"#.utf8))
    try scope.reserveExternalLogicalBytes(64) // Adapter-declared output frame weight.
    try scope.chargeExternalWork(1)           // Before the adapter's corresponding work.
    let pointer = try scope.pointer(tokens: ["count"])
    _ = try scope.uri("https://example.invalid/schema.json")
    return try scope.resolve(pointer, in: document.root)
}
```

The scope is borrowed, noncopyable, synchronous and not Sendable. Its methods
mutate invocation-owned private state. The closure cannot replace or swap the
borrowed facade. It has no public
initializer, continuation, refund or ownership token. Every reservation lasts
until completion. Re-admitting a value reserves its graph again; resolving
reserves its input graph and selected graph again. This intentionally overcounts
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
