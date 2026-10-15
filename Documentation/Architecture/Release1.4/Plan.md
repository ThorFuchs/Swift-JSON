# CLI release plan

The maintainer-approved 1.4.0 train adds `swift-json` as an executable beside the
six libraries, including the independently merged opt-in JSONBridges. JSONFilterRuntime and JSONCLIEngine are package-private targets;
JSONRegexRuntime remains private. Root external dependencies remain empty.
Historical four/five-product releases and their evidence are unchanged.

The CLI stack starts at the qualified JSONHTML renderer commit
`3c1e8a1a1bc8d03699665b8ab98f5ece7962aff7`, PR #21. Its native, safety, docs and
Linux x86_64/arm64 lanes passed. Main at orientation was
`25fb04f747e583209b4c4511abf39e11ef5b4f80`. This train uses dependent feature
branches and draft PRs; it does not change the parallel transfer/PDF or 1.2 work.

| Gate | Cohesive implementation and acceptance |
| --- | --- |
| C0 | Source/protection/prerequisite audit, executable/private target shapes, one noncopyable job ledger |
| C1 | Bounded argv/stdio/files, diagnostics/exits, atomic output, format/validate/Pointer/Patch, seven-product inventory |
| C2 | Original flat filter IR and pull VM, input framing, generators/paths/control/bindings/common builtins |
| C3 | Private exact decimal arithmetic; explicit scale plus half-even division policy |
| C4 | Qualified richer filters, lexical functions/reductions/path updates; explicit unsupported features |
| C5 | Qualified renderer/schema/provider adapters, consumers, independent corpus/oracle, platform/distribution and final candidate |

The planned stack is foundation, query-core, arithmetic, richer filters and
integration. Each has a compiling boundary, exact acceptance receipts and a draft
PR against its actual dependency. No public query library, eager legacy evaluator,
remote resolver, shell executor, daemon or release action is introduced.

The input briefing SHA-256 is
`43f8819c57e3d93bc6f7cf561d2d111442e089f2973cb7c62e16e3bd3fd73d0d`.
Its structural verifier counted 94 requirements, 111 new cases and 168 inherited
cases; those are inventory counts, not execution successes. The jq 1.7 observations
are historical references; differential claims require an actual pinned jq 1.8.2
runner. Missing provider APIs/platform runners remain explicit blockers.

Swift 6.4, language 6 and macOS/SDK 27 remain the native baseline. Mobile libraries
must continue to compile independently of the executable. Linux is a process
host; WASI executable feasibility is separate from the already qualified libraries.
Native and sanitizer receipts, subprocess outcomes, commands, toolchain, source and
binary identities accompany every qualified milestone. All 49 baseline probes and
independent-suite exclusions remain required and separate from CLI additions.

The stack has since been reconciled onto main9517233, retaining the complete1.3 renderer/export implementation. See [reconciliation](Reconciliation.md). Original renderer-pinned evidence remains historical; fresh current-source checks qualify the restacked heads.
Main reconciliation for merging PR23–PR27 preserves E2 main e8c3e4b and its public bridges, ergonomics behavior, six DocC catalogs and compiler consumers. Only the CLI executable is added to those six libraries. Exact combined module inventories and all 49 baseline probes remain mandatory.
