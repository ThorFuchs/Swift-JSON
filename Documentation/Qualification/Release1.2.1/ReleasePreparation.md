# 1.2.1 maintenance release preparation

PR #28 merged into `release/1.2` at
`28e30aabb662071b314c5024fd98228e04af37aa`. Its tree matches the tested candidate;
all three Native and six Linux jobs passed. Main already contains JSONHTML/1.3,
so the maintainer explicitly selected the 1.2.0-based maintenance branch.
This documentation closeout changes no library, test, fixture, resource profile,
product, dependency or supported-platform contract.

## Explicit performance disposition

On 2026-10-14, the maintainer accepted a **1.2.1-specific performance exception**
after inspecting the failed quiet-host gate and both retained comparisons.
This permits tag/draft preparation when all other release gates pass. It does
not certify an idle-host comparison or authorize publication.

The original longer diagnostic median was +11.9833%, exceeding the unchanged
10% review trigger, with pair changes from -0.5332% to +73.2086%. The subsequent
explicitly authorized loaded-host run was -1.6871%, with all samples retained
and identical work/logical-retention counters. Its fifty host observations had
2.61–58.56% idle CPU and load1 21.98–31.69 on ten cores. The additional release
readiness attempt also failed: five samples, 11.92–50.81% idle CPU and load1
48.97–55.36. No competing process was stopped or reprioritized.

Retain the necessary best-effort diagnostic correctness repair. Attribution
remains unresolved; there is no intrinsic improvement, no-regression or controlled
throughput claim. The exception accepts that measurement limitation for this patch;
it changes neither the review threshold nor any of the 49 finite caps. Logical
retained bytes remain distinct from RSS, and owned instruction quotas from caller
callback work. Historical streaming dispositions remain unchanged.

The [original review](ReviewReadiness.md) and dated wave receipts remain historical
records. They are not rewritten as successful quiet-host measurements.

## Final candidate gates

Before creating an immutable annotated tag, require actual Native, safety and
DocC receipts and full ARM64/x86_64 Linux qualification, safety and coverage for
the final maintenance candidate. Verify exact discoveries, independent policies,
all cap probes, public consumers, empty dependencies, retained licenses and
source archive privacy. Perform a manifest-verified clean extracted native build
and full native lane, and bind public assets to that exact source snapshot.

The draft contains source, matching four-catalog DocC, reviewed public evidence,
a qualification receipt and SHA-256 checksums. Verify uploaded bytes and an
independent SwiftPM consumer resolving the version tag. Public assets exclude
private maintainer records, personal paths/device identifiers and compiled test,
profile or WASI binaries. Scoped WASI evidence is reused only for unchanged
implementation/test inputs; physical-iPad and WASI-sanitizer limitations remain.

The version tag and draft remain separate from publication. They must target
the qualified 1.2 maintenance commit, never main's later feature line.
