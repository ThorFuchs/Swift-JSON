# Composition quiet-host qualification

The Release comparison retains the full baseline
`30631e8fe60201518c00544c172340ec6576e0d5`, identical public benchmark source,
runtime/resource paths, two pinned inputs, five operations, ABBA ordering and
18 observations per revision/row. The review trigger remains a positive elapsed
increase greater than 10%. Every process must have three consecutive one-second
intervals at least 90% idle both before and immediately after execution. There
is no retry or settling period after a failed post window. Failed host admission
produces a blocked receipt, not a performance result or exception.

## Observer investigation

The three attempts of workflow `38810354356`, on composition proof head
`7ac75818f7974ab17d1bc44a39b08214eab15f16`, stopped at immediate post windows:
87.79%, 71.38% and 54.29% minimum idle. Those receipts remain immutable. They
show bursts of system CPU but contain no process attribution, so they cannot
establish which process caused every burst or quantify a regression.

The former observer starts `top -l 4 -n 0 -s 1` for each window. Limiting its
display does not avoid system-wide process inspection. A local ABBA diagnostic
found roughly 1.2 CPU seconds per four-snapshot invocation even with framework
and memory-map display disabled. This is diagnostic evidence on a busy Mac,
not a controlled performance result. It motivates checking observer overhead
on the actual qualification host rather than rerunning the old gate blindly.

`composition_host.py` samples the supported Darwin
`host_statistics(HOST_CPU_LOAD_INFO)` interface directly. SDK
`mach/host_info.h` and `mach/machine.h` define four unsigned 32-bit CPU tick
counters in user/system/idle/nice order. Four snapshots yield three one-second
interval deltas; boot totals are never treated as interval load. Checked shapes,
normal counter wrap, missing samples and nonfinite values have rejection tests.
All global activity, including the sampler's own CPU, remains in the denominator.
This removes process enumeration from admission without changing its threshold,
interval count or immediate-post policy. The owned Mach send right is released.

Each new native receipt includes a pre-measurement ABBA observer experiment:
the exact former `top` command twice and sampler-only windows twice. It records
independent CPU ticks, observer CPU time, elapsed time and raw top logs. Process
and thermal snapshots are outside measurement windows; a failed post window
additionally captures diagnostics without changing the failure. Paging between
the pre/post windows now also blocks a comparison. No workload is stopped.

Executable replacement, binary digest checks and a separately labelled preparation
launch precede pre-run admission for every process, equally for both revisions.
Preparation outputs are retained and checked for discovery/nonfinite values but
are never qualification samples. This lets first-launch cache/resource setup
settle before admission; it does not establish which service caused an old burst.
The measured processes still each perform their original two warmup sets and
nine samples. The first post-run native snapshot precedes JSON decoding, hashing
or receipt serialization. Eight harness tests reject omitted/changed workloads,
nonfinite/incomplete timings, malformed counters and sub-threshold intervals,
and preserve completion's non-additive peak-retention oracle. This Python
harness is distinct from the unchanged Swift Testing behavior suites.

## Interpretation

Unchanged native API counters must match. Composition completion intentionally
adds 50 work units and 424 final logical retained bytes; peak is
`max(previous peak, previous final retained + 424)`. Logical accounting does not
measure RSS. The pinned frozen schema resource is JSON/Pointer input here, not
protocol conformance or schema evaluation. Compiler ownership limitations and
bounded adapter-capacity refusals remain documented separately.

Run `python3 -B Scripts/qualify_composition_performance.py --output <new-directory>`
on the supported native host. Actual final-source outcomes, command exits,
source/fixture/binary hashes and materialized logs belong in the return evidence.
This contract does not claim an unexecuted pass. Marking the PR ready additionally
requires its current required native/safety/docs checks and relevant Linux and
archive/proof jobs; merge, tagging and publication remain separate actions.
