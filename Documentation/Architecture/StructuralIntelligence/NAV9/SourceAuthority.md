# Branch B source and operation authority

NAV9 starts from current main0cb8ca40eb3c3bcf479006c2dcd88672f0a9b83b,
tree9b9e775e5d90bbcefb9f4bca35f01b207a3fffa6. Protected PR59 already integrated
Navigation V1; do not replay old stacks. Stable1.6.1 remains e431f157, without
Inspection. Main has ten products/nine libraries, empty external dependencies,
Navigation56/Inspection95 public declarations. No P2 names collide in this source.

| Concern | Existing owner | Branch B boundary |
| --- | --- | --- |
| JSON/number/key equality | Sources/JSON/Value/JSONComparison.swift and JSONNumber/JSONObject | Call package comparator with original meter; no second relation/hash authority |
| Full admission/root/map | JSONReadScope.init and JSONAdmission | Exactly once per constructor; no fresh nested quota |
| Typed physical selection | JSONReadScope.select/append | Preserve key/index and missing/null/wrong-kind distinctions |
| Owned traversal | JSONTraversal.inspectOwned/exclusive JSONTraversalContext | New comparator stays package-only/mutating; no meter/cursor escape |
| Error/cancellation health | JSONCodingState, JSONWorkMeter, context.perform | Catching owned failures cannot produce success |
| Captured source | context.transferDocumentOwnership | One-shot complete finalization, default N1/N2/P1 unchanged |
| Later reads | Existing core read scope | New explicit admission/report, no claimed constant-time lookup |
| Counters and limits | All49 ResourceProfiles metrics; checked work/retention | Additional explicit finite prototype counts, no baseline changes |
| CI/discovery | Scripts/ci.py and TestDiscovery.json | Add exact stable identities, retain old49/126 and original proof matrices |

ADRs precede implementation; D0 compiler proof must precede D1/D2. Performance
belongs to separate Branch A codex/nav9-g4-performance. Branch B neither runs
controlled timings nor claims a G4 PASS. Every modified-source lane requires fresh
receipts. Current-main NAV8 receipts may establish only the unchanged baseline.
Draft PR only; no ready transition, merge, release/tag, protection or sibling edits.
