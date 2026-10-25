# Trusted exact value authoring

Keep authored structure separate from bounded finalization.

The following example is compiled and run by `Examples/DualDSL`.

```swift
let tenth = try JSONNumber(parsing: "0.1")
let instance = try JSONValueDSL.object {
    Field("id", UInt64(9_007_199_254_740_993))
    Field("amount", exactNumber: tenth)
    Field("é", 1)
    Field("e\u{301}", 2)
    Field.array("nested") {
        Element.array {
            Element(1)
            Element(2)
        }
    }
}
```

Import JSON for its exact-number API and JSONValueDSL for syntax. These declarations
retain distinct decoded scalar keys, their insertion order and exact numeric values.
Finalization throws existing JSONFailure for exact duplicates and resource/configuration
failures; cancellation propagates as CancellationError. A partial value is not returned.
Errors must not be replaced with null or defaults. Parse explicit decimal text before
entering the nonthrowing authored closure, so conversion errors propagate normally.

`if`/`else` selects content; a missing branch contributes no declaration. `for` preserves
iteration order. `Field("note", .null)` is an explicit null member, distinct from absence.
`Elements(contentsOf:)` expands exactly the supplied values; an array within that list
remains an array value. An empty object remains `{}` and an empty array remains `[]`.

Finalization traverses literal payloads too. All returned values satisfy the supplied
finite profile, with cumulative finalization work and inner cancellation checkpoints.
The existing 49-cap owners and logical weight version are unchanged. The builder
callback and earlier staging allocations are not billed by that finalization ledger.
Caller computation and process RSS are not owned work or logical-retention metrics.
No public whole-DSL report or untrusted staging guarantee is provided in P1.2.

The shared generic builder types live in JSONDSLCore without a standalone product.
Applications select the JSONValueDSL product; core JSON does not import or re-export it.
