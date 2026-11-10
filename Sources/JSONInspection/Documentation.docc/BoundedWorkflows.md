# Read batches and configured stores

Read ordered exact values, or follow explicitly declared links in an immutable source.

## Choose the smallest operation

Use ``JSONInspectionBatch`` for typed path requests, or
``JSONStructuralSnapshot/values(for:maximumRequests:limits:)`` when you already
have snapshot-local ordinals. Repeated requests remain repeated outputs. Missing
selections throw; explicit JSON null is a value. Empty batches still admit the
whole captured source, including its source map. Each batch has one cumulative
native admission/work/retention ledger, rather than one independent read per item.

The default request ceiling is 1,024. Limits are inclusive. Invalid configurations,
resource exhaustion and cancellation throw without publishing a partial array.
Returned JSON values retain ordinary native value semantics. Logical alias bytes
are finite accounting policy, not a process RSS or caller-instruction guarantee.

## Declare a read-only store

``JSONStoreBuilder`` promotes a source to ``JSONConfiguredStore`` only after the
existing complete eight-phase checked construction. Names, ID fields, paths and
reference fields are explicit. There is no id/_id inference, Unicode normalization,
database, file loader or network resolution. This API is a candidate for 1.8;
released 1.7 does not contain it.

```swift
import Foundation
import JSON
import JSONInspection

func boundedStoreExample() throws -> [JSON] {
    let document = try JSONParser().parseDocument(Data(#"{"users":[{"id":"a","friend":{"collection":"users","id":"b"}},{"id":"b","friend":null}]}"#.utf8))
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [], collections: [
        .init(name: "users", recordsAt: [.key("users")], idKey: "id", referenceFields: [
            .init(key: "friend", presence: .required, nullable: true)])
    ], references: .strict(marker: .v1, validateTargets: true))
    let store = try JSONStoreBuilder(document: document, profile: profile).build().result
    guard let first = try store.lookup(collection: "users", id: "a").result else { return [] }
    let closure = try store.follow(from: first)
    // Construction, lookup, follow and value reads are separate reported operations.
    // Every selection within this one batch shares its original native ledger.
    let values = try store.values(at: closure.result)
    return values.result
}
```

The runnable [public consumer](https://github.com/ThorFuchs/Swift-JSON/tree/main/Examples/BoundedWorkflows)
exercises exact scalar IDs, missing versus null, repeated selections, cycles,
owner refusals and cumulative reports. Use this feature branch for the 1.8 API;
a compatible dependency on 1.7 cannot supply it.

## Understand ownership and errors

Positions are store-instance-local tokens. They cannot be constructed publicly
or reused against another build, even if that build has byte-identical input.
Fixed collection/record/reference metadata access is ordinary trusted caller work;
scanning lookup and value/follow operations have explicit reports and finite quotas.
A missing ID in a known collection returns nil. An unknown collection throws
``JSONStoreFailure`` with ``JSONStoreFailureCode/unknownCollection``. Declared
reference slots distinguish absent, null and validated links. Marker-shaped values
outside declared fields remain ordinary JSON.

``JSONStoreFollowLimits`` defaults to depth64 and frontier/visited/results10,000.
Follow includes the start exactly once and visits new positions breadth-first in
configured field order. A self-cycle does not consume another depth. Any reachable
new node beyond a bound throws: depth is a complete-search capacity, not permission
to return a truncated closure. Cancellation invalidates the invocation; another
operation on the same immutable store starts with independent health.

The original twelve store construction ceilings and 49 core metrics are unchanged.
They are finite policies, not a demonstrated joint capacity or heap bound. No
persistence, mutable store, parallel batches or new performance claim is supplied.
