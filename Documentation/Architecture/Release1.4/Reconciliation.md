# Main reconciliation of PR23–PR27

The original renderer-pinned stack is preserved in local `codex/1.4-pre-main/*`
branches and the immutable CLI return bundle at head7a133437. Main advanced through
PR21/22 to9517233ef0a3c1b961b738df58fe3ee4081d780c. Only CLI child commits were
transplanted onto that main tree; duplicate renderer ancestry was not merged again.
The previous28-conflict merge probe is history, superseded by this restacked graph.

All current main JSONHTML source/tests, export/browser consumers and Release1.3
records remain byte-identical. CLI engine/filter source and behavior cases are
byte-identical to the prior candidate. Resolutions retain both extraction/license
records, all parent APIs and the newer event error/console diagnostics. No public
query library, dependency, platform or fallback engine is added.

The six-product forward harness retains75 Apple/61 portable HTML functions,
38 focused export functions,14 WASI public-consumer functions and the HTML command
probes. All49 baseline caps, exact corpus counts/exclusions and173 inherited
parameter cases remain guarded. CLI adds26 parameter cases and77 final functions;
the installed-resource regression adds one schema function. Final native totals
are348/199 and Linux334/199. Shared TSan scope is11 native/10 Linux functions.
No blanket exit-zero or nonzero-cardinality replacement is used.

Before this milestone prose, native25 commands, safety3 commands and docs1 command
passed on the same unchanged source manifest
792ade5810b9d8d2a43c3cd66fdebbe2895640fd1cea52ff19fef05cc36b0475.
Native debug/release and ASan each ran348 functions/199 parameter cases. TSan ran11
shared functions; strict-memory/warnings-as-errors compiled cleanly. Five DocC
catalogues and the existing compiled public examples passed. CLI53 foundation/37
integration subprocesses,33 probes across16 CLI metrics and105 C1-C4 vectors passed.
The native public consumer includes interactive/typed diagnostic HTML from main.

These are local source-bound results, not claims of final-head hosted success.
Remote heads use exact leases against the preserved original PR heads. Final PR
heads, native/Linux run identities, actual logs and materialized receipts are
recorded in the separate reconciliation return. Each child PR continues to target
its preceding branch; foundation targets main. Required check names, resolved
threads and no-bypass protection are unchanged. No PR merge/tag/publication occurs.

Provider CL078/CL079 remain blocked by the absent qualified helper declarations;
WASI CLI keeps its explicit limited disposition. Main reconciliation does not
convert these into successes or qualify MCP server/conformance behavior.


The subsequent portable provider increment addresses the previously blocked CL078/79.
Its [separate provider record](Providers.md) and new source-bound receipts supersede
that prerequisite blocker while preserving every reconciliation/archive observation
above. It does not qualify Apple model/schema bridges or unrestricted WASI CLI IO.
