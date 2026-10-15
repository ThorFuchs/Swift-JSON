# Reconcile the advanced CLI base

PR #30 retains the structured-preview and physical-qualification history at
`1fd32d19b4e16891073cb9fdba7ecdcc7660bf88` and incorporates the CLI/provider base
`c3760730dc333a84810bba53cde4da339ada90af`. This updates the feature branch only;
PR merging, tagging and publication remain separate maintainer actions.

The four conflict resolutions retain both API sections and both complete extraction
records, including all enrichment/provider fixture pins. All original HTML source,
tests, browser/export consumers and existing preview contracts remain byte-identical
to the feature parent. Provider source, tests and frozen vectors remain byte-identical
to the advanced base. Automatically combined CLI help retains the provider commands
and all structured HTML switches. The package still has five libraries and the
sixth executable, private runtimes and no root external dependencies.

The harness combines the inventories instead of selecting one parent's smaller set:

| Scope | Exact inventory |
| --- | --- |
| Apple root | 393 functions: JSON 107, schema 65, stream 14, patch 11, regex 12, HTML 97, CLI 87 |
| Linux root | 377 functions; HTML has 81 portable functions, all other modules retain the Apple counts |
| Root parameters | 325 exact named case invocations on Apple/Linux |
| Shared-state TSan | 13 Apple / 12 Linux functions, including structured rendering and provider sharing; the Apple PDF concurrency case remains included |
| Focused export | 40 functions across two test modules: 39 HTML and one provider/schema export function |
| WASI root | 290 functions, including schema 65 and HTML 81; 288 named parameter cases |
| Public WASI consumer | 14 functions, including the separate six-case HTML mode |

Swift Testing ABI events determine discovered module/function/parameter inventories.
The focused export probe exposed two separate runner summaries; its exact guard is
`[1, 39]`, not only the last console total. The shared-state guard also checks exact
module identities. Event-reader canaries, all 49 core metric probes, corpus observed/
evaluated/policy counts, malformed replay, all six C5 vectors, the 14-case public
provider consumer and 37 provider process/fixture outcomes remain required. No
passing placeholder or blanket exit-zero/nonzero-cardinality check replaces them.

The existing receipt identities stay bound to their original sources. Combined-source
native, safety, documentation, Linux and affected WASI outcomes need fresh receipts;
parent success alone does not qualify this integration. Actual commands, toolchains,
source/fixture hashes, discovery events, exits, preservation comparisons and hosted
run identities are materialized in the separate reconciliation handoff. The unchanged
HTML implementation retains its prior native browser/device/VoiceOver/calibration
scope, including attributed manual observations and the reviewed performance policy.

## Reconcile the approved JSONBridges baseline

The maintainer explicitly approved retaining current main's JSONBridges while
reconciling the advanced CLI base `aab19ce3414b80e5fef69ffd1d895bd0a2c2cadb`.
This supersedes the earlier forward five-library inventory, preserving its history.
The combined package has six libraries plus the swift-json executable, no external
root dependencies, JSON-only HTML/Bridges dependencies and private regex/filter/CLI
runtimes. Core does not re-export JSONBridges. The feature parent is
`e1b82a583f66afffeec992a95a6e08ad36a1c3f0`; its receipts remain immutable.

The five new resolutions retain the structured HTML and E2 API/release descriptions,
all current README examples and both exact test inventories. JSONHTML test fixtures
remain packaged. Core/Bridges/schema facade additions and the provider implementation
are retained without source changes. No rendering behavior, preview ceiling, platform,
metric meaning or existing fixture is changed by this synchronization.

The required combined inventory is 419 Apple / 403 Linux functions, with 325 named
parameter cases. Modules retain HTML 97/81 and CLI 87 while adding core 119,
schema 69 and Bridges 10. Shared-state TSan requires 15 Apple / 14 Linux functions,
including structured plans, providers, Apple PDF and both E2 sharing functions.
The WASI root requires 316 functions and 288 parameter cases, including Bridges 10,
core 119, schema 69 and HTML 81. All 49 caps, exact corpus policies, 19 event canaries,
public consumers, six DocC catalogues and eight E2 compiler/import checks remain
required. Discovery and execution receipts must confirm these inventories; expected
counts alone are not qualification.

New source-bound native, safety, docs, Linux and affected WASI receipts are recorded
separately from the earlier pinned return. Byte-identical HTML implementation/tests/
assets retain their prior browser, physical-touch, VoiceOver and calibration evidence
within its stated scope. The inherited approximately 11% streaming comparison and
existing disposition remain unchanged. No PR merge, tag or publication is performed.


## Final merge review: preserve the export lane

Review against current main found that the earlier CLI reconciliation had dropped
its existing `export` lane and event-reader I/O diagnostics. Restore the complete
five-command export lane, including the native public consumer and three Apple SDK
probes, while retaining the structured combined focused inventory `[1, 39]`.
Restore missing-event error capture and both console/ABI parameter counts in receipts.
Library, CLI, assets, fixtures, product policy and all counters remain unchanged.
Fresh required hosted checks and actual export-lane execution qualify the harness
correction. Earlier source-bound implementation/WASI evidence is retained through
exact equivalence; no previous receipt is relabelled to the new head.
