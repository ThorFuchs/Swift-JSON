# Navigation over composition-enabled main

The integration base is `30631e8fe60201518c00544c172340ec6576e0d5`, the
protected-main merge of composition PR #35. Original Navigation PR #34 ends at
`4403b9ab3b0a1fadc57c12a283cfabb255f6237a`; its public-product promotion in
stacked PR #37 ends at `5cf78972b279f398894dd4afcbc09dd058889371`.
The integration replays those increments on a new main-based branch. It does
not rewrite either historical head or include unrelated DSL/composition-proof
branches. Original source-bound receipts remain evidence of their own heads.

## Source and conflict decisions

| Original increment | Integration commit | Decision |
| --- | --- | --- |
| 94369e1, exact traversal | f83a638 | Add Navigation target, tests and lanes; keep composition lane, checks, extraction notice and test identities |
| 6e5e5fa, scope-key admission | f168e9d | Preserve exact core admission before path staging |
| 4403b9a, DocC transport | d4730f1 | Preserve verified tar transport without renaming native DocC paths |
| 7ee2712, public product | 8199f3c | Add opt-in JSON-only product and external SwiftPM consumer |
| 5cf7897, promotion boundary | 134a516 | Preserve historical decision and isolate failed compiler spike |

Generated CLI identity is recomputed from final Package.swift and Sources;
neither branch's old stamp is authoritative for the combination. Discovery merges
add Navigation's 39 functions without changing existing module counts. CI retains
composition's public consumers, capacity-characterization policy and normal
negative compiler checks. No test exclusions, quota values or safety flags change.

Navigation source, its 39 tests, fixture bytes, DocC and external consumer are
byte-identical to 5cf7897. Core JSON, JSONSchema and composition tests/tools are
byte-identical to the fresh base. The 56 authored Navigation declarations retain
their exact shape; source admission/error precedence, DFS/overlap/coverage,
typed paths, cancellation and logical retention remain unchanged.

## Review and qualification boundary

The public review accepts explicit opt-in traversal with metadata-only collected
results and synchronous caller work. It adds no cursor, path grammar, mutation,
fresh nested meter or speed claim. All existing products remain available; the
external dependency graph is empty. A0 research and JSONInspection are absent.

Fresh native, safety, docs, archive, both Linux architectures, WASI and mobile SDK
consumer receipts must bind to this combined source before merge. A green check
on an old stacked head is insufficient. Required main checks and resolved review
threads remain mandatory; only a qualified new integration PR may merge under
the owner's bounded authorization. No release tag or publication follows here.

PR #31 (DSL) and #36 (composition qualification) retain their separate ownership.
Their CI/discovery/docs overlaps need additive reconciliation when their owners
update their bases. This integration neither rebases nor merges their work.

## Deferred ownership research

The original noncopyable borrowed-context escape still requires full codegen
qualification. Its failed `SILGenCleanup` probe is not a valid negative result.
Any recovery and conditional inspector live on a separate experimental branch;
they cannot change this Navigation candidate or borrow historical passes.
