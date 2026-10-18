# NAV11 source authority

Base main: 1a0306d076a08c8c43281f91412a11cd744ff3f6. NAV10 PR66/d566f28 is
independent and not a source dependency. Stable 1.6.1/e431f15 remains immutable.

| Graph work | Existing delegate | Invocation boundary |
| --- | --- | --- |
| Complete root/source/map admission and failures | JSONReadScope, JSONAdmission, JSONWorkMeter | Original inspectOwned scope |
| Physical/virtual roots and exact overlap | JSONTraversal.execute, rejectAmbiguous | Same original scope, before callbacks |
| Row locations and bounded paths | JSONTraversalHit, JSONLocationComponent, context.appending | Same scope |
| Direct string member/presence/kind | JSONObject.lookup through mutating context delegate | No reader/new ledger |
| ID equality | JSONComparison.textEquals through context.equalStrings | Scalar-exact charged UTF8 comparison |
| Owned alias accounting, cancellation, terminal health | context.perform + scope.run/check | Original state, no escape |
| Adjacency and BFS | Package-only graph reducers | Checked work/retention in that invocation |
| Completed source handoff | context.transferDocumentOwnership | Once after complete valid construction |
| Later source value/span | JSONReadScope.select and sourceMap.span | Explicit new whole-source operation |
| Returned value alias | JSONAdmission.value(owned:true) | Same later-read ledger, additional output cost |

No JSON, Pointer, value equality, schema, stream, Patch, HTML or CLI semantic change.
The new context methods are package-only and mutating; original ownership codegen
fixtures are byte-identical. ExtractionManifest records original Apache-2.0 code
and independent fixture provenance. Public symbol graphs must remain unchanged.
