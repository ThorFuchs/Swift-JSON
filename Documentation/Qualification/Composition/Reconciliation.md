# Composition reconciliation: PR35 and PR36

## Reconciliation with schema examples

The successor incorporates main
`c79d48c15f83ef88bed9459d9abcf05e54bd0bea` (PR39) without changing its
JSONSchemaExamples implementation, schema compiler support, consumers, fixtures
or documentation. The existing composition runtime, proof package and performance
harness remain byte-identical to `47ea4ef71dd7286ef0ec81342a8bb527438ce4b5`.
Main's nine-product graph and empty root dependency graph are retained.

The combined inventory requires 697 Mac / 681 Linux / 593 WASI root functions,
325 Mac/Linux / 288 WASI parameter invocations and 47 Mac / 46 Linux shared-state
functions. All 98 schema-example functions, 39 Navigation functions, 34 integration
functions, 126 restored identities and 49 baseline cap probes remain required.
The two composition lanes and every S3 consumer, ownership, construction, matrix
and lifetime gate are retained. Eight public library DocC catalogs are required.
The harness rejects omission of either proof dispatch or S3 qualification;
cardinality checks still require the complete module and parameter inventories.

The four conflicts are resolved by combining CI dispatch/cardinality guards,
combining provenance notes and regenerating the CLI stamp from combined source.
No implementation, quota, safety policy, baseline or review trigger is replaced.
Actual source-bound receipts establish execution results, rather than these counts.
Quiet-host performance remains pending by maintainer instruction. No timing retry,
PR readiness change, merge into main, tag or publication is part of reconciliation.

The following sections retain their original increment and source context.

PR35 landed as main 30631e8fe60201518c00544c172340ec6576e0d5. This follow-up
reconciles that implementation with proof head
bab6316d31e9c1aca30ba3f9040b20edf1e6ae85 from PR36. The independent original
proofs and source archives remain historical evidence, not receipts for this tree.
No downstream importer, release or dependency adoption is included.

## Selected implementation

There is one noncopyable borrowed `JSONCompositionScope`, one private state and
one native ledger. PR35's native parse, Pointer, trusted admission, URI and
terminal-failure routes are retained. JSON remains independent of JSONSchema.
The original `reserveExternalLogicalBytes(_:count:)` declaration is retained;
the explicit `overhead:` overload checks multiplication and addition before growth.

PR36 adds per-document input capacity retirement with cumulative reported counts
and persistent accepted-capacity history. It also prepays completion's independent
49-slot report: 424 logical bytes and 50 work units. These are intentional
composition accounting corrections. Existing standalone API counters, all 49
metric meanings, finite profiles and native accounting weights are unchanged.
Original continuation health/identity is checked before and after completion.
A caught owned quota, arithmetic, syntax or cancellation failure cannot finalize.

The 12 original root behavior functions and five external reference-import
functions remain, including the failed direct 128/128 capacity hypothesis and
eight characterized cells. Their assertions now include report/result overlap;
the same native work still refuses the direct adapter after 98 references.
The two supplementary native functions and 26 independent public functions from
PR36 add cancellation boundaries, original-ledger identity, per-source capacity,
exact values, event-ledger thresholds and deliberate omitted-charge mutants.
There are 599 native / 583 Linux root functions and 325 parameter invocations.
The 126 restored identities and 49 exact public cap probes remain required.

## Reproducible checks

Run Scripts/ci.py lanes `composition`, `composition-proof`, `native`, `safety`,
`docs` and `archive` on the supported native toolchain. Linux architecture jobs
retain `linux` and `linux-safety` plus both focused composition lanes. Existing
protected check names/settings are preserved. The focused proof is a separate
job so root discovery guards and reference-import cardinalities stay explicit.
The original lane requires 12 root / five external functions, eight scale cells,
11 intended compiler diagnostics and distinct consumers. The proof lane requires
two root / 26 public functions, two rejected mutants and 14 intended diagnostics.
Crashes never count as normal diagnostic rejection. Exact discovery guards retain
15 Python harness functions; additional rejection assertions live in that harness.

Compiler reductions and qualified explicit-borrow helper forms are preserved in
`Tools/CompositionQualification/CompilerBugs`. Known Swift 6.4 inferred-capture and
bound-method-value crashes remain usability limits. No unsafe annotation or
experimental ownership flag is added. Current main’s eight public products are retained and root
external dependencies remain empty. Physical devices are not requalified here;
portable compilation/runtime evidence must identify its actual host and SDK.

## Performance and evidence policy

The controlled Release comparison uses main 30631e8 as its full pinned baseline.
Both existing PRs' comparisons against 037e735 remain historical. Identical public
harnesses, runtime/resource paths and fixtures compare unchanged APIs and the
composition document route. Existing API counters must match; composition's
expected completion delta is exactly 50 work / 424 final logical bytes. Peak is
max(previous peak, final retained plus report), rather than a sum of stage peaks. Five operations
on two inputs, nine samples per process and ABBA ordering yield 18 samples per
revision/row. Each pre/post admission requires three interval samples >=90% idle.
The review trigger stays 10%; operational refusals and blocked/noisy timing are
never evaluated successes. No RSS, throughput or arbitrary adapter honesty claim.

Final commands, exits, source hashes, manifest-backed archives, materialized hosted
receipts, performance disposition and review findings belong in the maintainer's
return evidence. Source documents here specify replay and acceptance, not a
fabricated pass. Private evidence and build caches are excluded from source archives.

## Current-main reconciliation

Main `7d72c8825982550f0ee87218136fda12d8bae13b` independently added JSONNavigation.
This branch retains that source, all 39 Navigation functions, the normal public
consumer, exact product/dependency checks and seven DocC catalogues. Composition
proofs remain additive; no Navigation or historical behavior is removed.
