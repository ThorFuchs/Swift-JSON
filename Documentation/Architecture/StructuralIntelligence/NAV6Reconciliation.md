# NAV6 source reconciliation

The isolated candidate combines original N2 8313e06 with protected main c79d48c
(schema examples, PR #39). Original #41 and #42 commits remain preserved. No
Inspection or Navigation semantic source changes occur in this reconciliation.
The manifest contains ten candidate products: nine libraries and the CLI. Root
dependencies remain empty. JSONSchemaExamples and its 98 functions remain intact;
Navigation has 47 functions and Inspection retains all seventeen I01–I17 cases.
The combined root inventory is 720 native, 704 Linux and 616 WASI, with 325/288
parameter invocations unchanged. Shared-state counts are 48 native and 47 Linux.

Conflicts in manifest consumers, docs catalogue/site lists, CI and discovery are
resolved by retaining both increments. The harness regression fixture expecting
39 Navigation functions is raised to 47 and adds exact Inspection identities;
missing/wrong-module/changed-parameter counterexamples remain required. The CLI
source digest is regenerated from the finalized manifest and Sources. All 49
metric probes, 126 maintenance identities, composition qualification and schema
example ownership/matrix/lifetime checks remain mandatory.

These are requirements, not execution claims. Source-bound receipts determine
qualification. This candidate grants no merge, tag or release authority. N2's
public API and prefix/complete row coverage are unchanged; N3 promotion remains
an independent child experiment.
