# Dual DSL P1.2 integration

This is an unreleased integration on `codex/dual-dsl-p1.2`, based on current main
`e8c3e4bd9ae40d797f07a527ea98879acee3c057`. The supplied packet inspected
`9517233ef0a3c1b961b738df58fe3ee4081d780c`; the intervening E2 merge adds entry points
and JSONBridges. Existing six products and core implementation remain authoritative.
The requested JSONValueDSL and JSONSchemaDSL are additive opt-in products. JSONDSLCore
has no standalone product. Root dependencies, platforms and all 49 profiles remain unchanged.

The maintainer-supplied packet SHA-256 is
`a69432b69f59d3d587502c2453fed3d00259845b9335a551b962965be10f9588`.
Its 32-file manifest verified. Its three DSL source roots and six negative fixtures are adapted. Neither
signature shim is an engine input. Its sixteen positive cases are ported from XCTest to Swift Testing and real JSONLimits.
Original and adaptation contributions retain Apache-2.0.

## Gates and reviewable increments

1. **G0 baseline:** pin source/SDK/compiler; record manifest and file collisions;
   run production native baseline in an untouched detached worktree.
2. **G1/G3 integration:** add opt-in targets, iterative flat staging/lowering,
   exact admission and shared finalization/document ledger. Compile the real consumer.
3. **G2 semantics:** port all sixteen cases, implement V-01–V-20 parity against
   exact manual JSON and hand-written schemas; retain unchanged official suite policies.
4. **G4 compiler qualification:** exact-domain negative fixtures and measured
   16/64/128/256 blocks, nesting, choices, loops and mixed schema contexts; compare
   pairwise composition when the observed scaling warrants it.
5. **G5 API/docs:** public comments and DocC, compiled README and guides; record
   accepted/rejected namespace and sugar decisions against merged E2.
6. **G6 final qualification:** exact-count native/safety/docs and real Linux lanes;
   public consumer, strict concurrency, source/diff/receipts and remaining limitations.

Each coherent increment is committed on the isolated feature branch. The maintainer
authorized a branch push and existing ARM64/x86_64 Linux CI after native checks.
PR creation, merging, tagging and release publication remain separate. Existing release and sibling worktrees
are preserved. A passing shim or typecheck is never a semantic qualification claim.

Private input and raw receipts live in ignored `Artifacts/DualDSLP1.2`; source identity,
commands, exits, toolchains, suite counts and source hashes accompany actual outcomes.
[Progress](Progress.json) records incomplete gates without rewriting older release history.
