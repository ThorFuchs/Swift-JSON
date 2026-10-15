# Experimental composition qualification

The synchronous borrowed composition API is described in
[Compose native operations](../../Sources/JSON/Documentation.docc/Composition.md).
Its public surface and default profiles are unchanged by this qualification work.
The root dependency graph remains empty and the package retains seven products.

The separate [qualification package](../../Tools/CompositionQualification) exercises
source-backed parsing, exact Pointer targets, URI identity and explicitly charged
adapter storage/work through one scope. Its generated inputs contain a definition
object and reference array. Every definition includes 9007199254740993, the
preserved decimal spelling 0.0100, and scalar-distinct precomposed/decomposed keys.
These are synthetic JSON graphs, not protocol or schema-validation conformance
fixtures. Source bytes are materialized and hashed in each receipt.

## Capacity and adapter strategy

The direct adapter resolves each descriptor against the complete document, then
resolves its target against that same root. Both calls conservatively re-admit
their input graph. The initial assumption that balanced could complete a
128-definition/128-reference import failed: 98 references completed before
numericWorkUnits attempted 1,000,001. That failed assumption remains in the
evidence and a dedicated quota-behavior test. Refusal is an operational error;
there is no successful report for the incomplete import.

A second serial adapter resolves the reference array once through the same
scope and uses that admitted array as the descriptor root. Target resolution
continues to use the original document. Every helper still borrows the same
ledger; no new context, budget, root token, refund, manual key lookup or core API
is introduced. Both graphs and all aliases remain conservatively charged.
This avoids repeatedly admitting definition numbers merely to read a descriptor.
The overall algorithm still has reference-count times root-size admission cost.

The finite characterization matrix is:

| Definitions / references | Profile | Descriptor root | Required outcome |
| --- | --- | --- | --- |
| 16 / 32 | balanced | complete document per reference | Complete |
| 128 / 64 | balanced | complete document per reference | Complete |
| 128 / 128 | balanced | complete document per reference | Numeric-work refusal after 98 completed references |
| 256 / 256 | offline | complete document per reference | Complete |
| 1,024 / 1,024 | balanced | complete document per reference | Operational quota refusal |
| 1,024 / 1,024 | offline | complete document per reference | Operational quota refusal |
| 128 / 128 | balanced | staged reference array | Complete |
| 512 / 256 | offline | staged reference array | Complete |

Five completed cells and three quota refusals are reported separately. A green
characterization check verifies those outcomes; it does not turn the three
incomplete imports into successes or establish arbitrary production capacity.
The direct adapter's failed capacity target remains explicit.

The adapter declares 64 logical bytes for its frame, 16 per output slot and a
conservative 68 per descriptor (20 index-text bytes and three 16-byte input token
slots). Staging adds one admitted input token slot. Reservations and work charges
precede growth. These are declared logical weights, not Swift layout or RSS.
Caller-generated input and independent expected-value oracles are outside the
owned operation. Functional elapsed times do not establish throughput guarantees.

## Execution and evidence

Run python3 Scripts/ci.py --lane composition on the supported native or Linux
runner. The lane requires 12 core functions in each build mode, separate public
consumers, five external Swift Testing functions in Debug/Release/ASan, all eight
scale cells and 11 compiler rejection cases. Exact module/cardinality checks
reject missing tests and misclassified resource failures. The 560 native / 544
Linux root functions, 325 parameter invocations, restored identities and 49 public
metric probes retain their existing contracts.

The tests replay exact and one-below work/retention thresholds, compare both
strategies on identical input, preserve exact values and scalar keys, and catch
late missing-target/cancellation failures before attempting normal completion.
Finalization must still throw the original native failure. Each report retains
its actual source, environment, command exits, counts and input hashes.

Completion additionally owns a 424-byte counter report and charges 50 work units.
The retained threshold assertions include that independent buffer, and source input
capacity is per document while reported bytes accumulate across all documents.
The original two-argument reservation method is retained; a checked `overhead:`
overload is additive. See [reconciliation](../Qualification/Composition/Reconciliation.md)
for the independent ledger/mutant and compiler proof carried from PR #36.

CI runs the focused lane alongside the existing Native / native and both Linux
architecture jobs. Their names and protection rules remain unchanged. Sanitizer
and full-root lanes continue independently. Linux uses the existing Swift
Testing-only runner policy; no baseline is suppressed.

Controlled idle-host performance remains a separate gate using the unchanged
10% review trigger. Shared or busy-host timing cannot close it. Representative
application scale beyond these synthetic cells needs separate evaluation; no
downstream dependency adoption, merge or release follows automatically.
