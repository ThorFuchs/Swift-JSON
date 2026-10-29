# Execution update — 28 October 2026

1.7.0 is published at `8557badef562cf2f059e964c113d4a7f60ecbe6c`.
The maintainer has now commissioned the 1.8 bounded structural wave, including
the public read-only store, on isolated `codex/1.8-batches-and-store`.
[The implementation contract](Architecture/StructuralIntelligence/BoundedWorkflows1.8.md)
freezes this wave; [qualification](Qualification/Release1.8.md) records actual results.
The proposal and historical inventories below remain source-bound. Persistence,
platform-floor reduction and new query grammars are not included.

# Release roadmap: 1.7 through 2.0

Maintainer working proposal, audited 27 October 2026. The next step is a release
freeze review, not a tag or publication. This roadmap authorizes no new public API
and does not supersede existing semantic, resource, ownership or platform gates.

## One repository, one package version

Swift-JSON is one SwiftPM package with separately selectable products. A repository
tag versions all products in that tag. JSONNavigation is already released in
1.6; Inspection is a different optional product. Do not give Navigation a separate
version or repository merely to describe the Structural Intelligence programme.
A split would need an independent dependency/versioning design.

The audited development baseline is main
`15aa7e432cbb7173aa94b91e32badd1ab2695068` (PR #69). It contains twelve library
products and the CLI, thirteen reference catalogs including the non-product
JSONDSLCore module, and 1,500 compiler-derived authored declarations. The latest
published stable version is 1.6.1. The frozen historical Transform RC at 6fe8067
is a different source and must not replace current main during release preparation.
See [source lines](Qualification/ReleaseLines.md) and
[combined qualification](Qualification/Consolidation2026.md).

## Product and capability inventory

| Selectable product | Current capability | Publication boundary |
| --- | --- | --- |
| JSON | Exact decimals/scalar keys, strict codec, Codable, Pointer, presence, source documents, finite operation reports | Existing stable product |
| JSONSchema | Offline Draft 2020-12 plans, native bounded regex, annotations and declaration inspection | Existing stable product |
| JSONSchemaExamples | Exact deterministic candidates with native validation/certification | Existing stable product |
| JSONStreaming | Pull events/values, strict NDJSON, root-array completion and awaited sinks | Existing stable product |
| JSONPatch | Staged RFC 6902 and RFC 7396; root removal distinct from null | Existing stable product |
| JSONHTML | Formatted/interactive inspection, annotations and qualified Apple transfer/export backends | Existing stable product; platform scopes stay explicit |
| JSONBridges | Opt-in checked native/Foundation conversions | Existing stable product; core does not re-export |
| JSONNavigation | Exact typed DFS traversal, physical/virtual scopes and coverage | Existing stable product; 56 authored declarations unchanged |
| JSONInspection | Array evidence, source-attached snapshots, trees, sparse tables, structural sets, exact numeric matrices and source-bound directed graphs | Public development source; not supplied by 1.6.1 |
| JSONTransform | Exact query compiler/VM facade, bounded execution and accounted CLI adapter | Public development source; 42 accepted declarations |
| JSONValueDSL | Trusted authored value construction with checked finalization | Public development source |
| JSONSchemaDSL | Trusted authored schema documents using the native compiler/validator | Public development source |
| swift-json | Existing CLI workflows, sharing the Transform implementation | Existing stable executable; new development engine must be qualified |

JSONDSLCore has 82 authored public generic declarations needed by the DSLs, but
no standalone product. Regex/filter/CLI runtime targets remain package-private.
Store preparation and construction are also package-only inside JSONInspection;
there is no public store/follow API or store product. Root dependencies stay empty.

## Proposed release sequence

| Release | Proposed outcome | Gate before choosing a release date |
| --- | --- | --- |
| **1.7.0 — integrated foundations** | Release the complete current public consolidation together: Navigation/Inspection snapshots, projections and graph, Transform and both DSL products, alongside all stable products. Keep store implementation private. | Freeze current-main successor; qualify exact source, public consumers/API/DocC, archives/assets and supported platforms; resolve the new candidate's performance dispositions explicitly. |
| **1.8.0 — bounded structural workflows** | Add independently reviewed, additive Inspection conveniences: aggregate batch reads and, if separately admitted and qualified, the minimal immutable public configured-store/follow interface. Improve Navigation/Inspection guides and error/resource ergonomics. | One-ledger aggregate proof, finite request/result/frontier profiles, ordinary compiler refusals, adversarial failure/cancellation and complete supported-platform evidence. Store can remain private if its gate is not complete. |
| **1.9.0 — durable workflows and operational maturity** | Candidate wave for versioned exact snapshot/store persistence and source-bound restoration, after a dedicated design admission. Complete capacity/scaling characterization and consumer migration guidance. | Freeze the logical envelope, corruption/version/source-identity semantics, bounded decode/rebuild and disk teardown/reopen tests. No persistence or source-span claim from a bare JSON dump. |
| **2.0.0 — supported family and compatibility contract** | Ship all accepted products/capabilities under one coherent, documented compatibility, resource and platform contract. Complete end-to-end applications, migration tooling and the release qualification matrix. | Scope freeze, complete public API review and cross-product qualification, explicit treatment of every remaining hold, reproducible clean candidate and a separate owner tag/publication instruction. |

Release numbers are shared across all products. Do not remove already-integrated
public APIs merely to postpone a product to 1.8. Minor releases remain additive.
A major version is a deliberate compatibility commitment: record and justify any
actual break and provide migration guidance; do not manufacture a break to reach
2.0. Dates follow exit gates, not a promised calendar.

The 1.8/1.9 entries are **proposed scope**, not API approval or permission to start
implementation. All planned packages at 2.0 means the explicitly accepted release
portfolio. Lexical/semantic retrieval, embeddings, persistent indexes, weighted
graph algorithms, set algebra, matrix arithmetic, JSONPath/another query grammar,
new backends and text-sequence framing have no automatic place in this promise.
If a later scope review admits one, give it its own product-boundary decision,
finite profiles, fixtures and release gate. Do not rename speculative designs
into committed packages.

## Navigation and Inspection ownership

The maintainer can operate this train directly through the repository's normal
PR/review workflow; an external coordination layer is not a release dependency.
Use current main as the sole integration authority. Keep JSONNavigation focused
on traversal and JSONInspection on checked observations/views. Prefer public
consumers over private-meter test shortcuts. New APIs require an exact compiled
surface review before promotion, with ordinary full-codegen negatives and no
escaping cursor/context, replacement ledger or second root admission.

The first bounded work queue after the 1.7 freeze is:

1. Record the Navigation56/Inspection162 public boundary and compiled examples on
   the frozen source. Preserve factual prefix evidence versus complete admission.
2. Admit NAV13's batch design: caller order/repeats, complete results or throw,
   one source admission/ledger and explicit request/output alias retention. Do not
   implement batches as loops over independently admitted single reads.
3. Review the private store profile and ownership/error precedence before proposing
   public construction/follow. Source-local handles are not persistent IDs; cycles
   and missing/null/reference states need explicit, bounded semantics.
4. Consider durable snapshots/store restoration only after that contract settles.
   A rewritten root does not acquire invented original source spans.

## Consolidation and branch discipline

PR #66 admitted set/matrix; PR #69 reconciled graph, Transform, DSL and private
store source with current main. Historical donor drafts are provenance, not a
second integration backlog. Replaying them wholesale could restore old manifests,
remove later functionality or duplicate semantics. Squash ancestry alone cannot
prove whether a feature was incorporated: inspect donor source and the recorded
component mapping. Close a proven superseded draft as superseded, not merged.

Use one short-lived feature branch per independently reviewable increment, based
on fresh main. Keep protected main/tag rules and the `Native / native`, `Native / safety`,
`Native / docs` contexts unchanged. A clean worktree whose exact head is a merged PR
can be archived recoverably after confirming no new work or needed ignored files.
The app's active/shared ownership guard must be honored; retire such a checkout
from its owning task instead of deleting directories manually. Preserve held
composition/root and lower-platform proposals until independently dispositioned.
Maintenance releases use the 1.6 line; do not merge old release branches into main
just to make ancestry look simpler.

## Required release evidence and remaining holds

Current-main hosted Native and both Linux architectures are green, with the
original x86 Swift Build planning crash and its unchanged-source retry retained.
Actual roots are 975 native / 959 Linux functions with 390 parameters, targeted
sharing 60/59; all 49 core caps, 16 CLI metrics, 126 maintenance identities and
independent fixture policies remain required. The current WASI contract expects
871 functions/353 parameters, with separately stated Node/WasmKit scopes. SDK
compilation is not a new mobile-device runtime qualification.

Existing unchanged-source evidence can be reused only with explicit source/flag
equality and scope. A successor freeze must bind every claim to its final source
SHA/tree/archive. Required checks include public consumers, original ownership
codegen, Debug/Release/ASan/TSan/strict checking, supported Linux/WASI/Apple lanes,
13 DocC catalogs, link/privacy/license/dependency review, clean Git-free rebuilding
and exact artifact checksums. Policy exclusions are not evaluated suite successes.

Controlled Navigation G4 remains HOLD. Transform's historical one-time P4 waiver
for the frozen RC and later partial 44/150 and 119/150 populations do not qualify
a new consolidated candidate or constitute measured allocation totals/overhead.
A new release must either satisfy the applicable measurement gate or receive an
explicit source-bound maintainer disposition. Keep the unchanged 10% review
trigger, historical streaming disposition and zero unproven performance claims.
Logical retained bytes are not RSS/heap measurements; caller work is not owned
instruction work. Do not run a controlled characterization on a busy host.

Tagging, draft release creation and publication remain separately deliberate
maintainer actions under [RELEASING.md](../RELEASING.md). This roadmap creates none.
