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
