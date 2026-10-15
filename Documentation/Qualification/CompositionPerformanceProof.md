# PR35 controlled performance proof

This qualification branch does not change the reviewed PR or library source.
It compares baseline `037e735dc6224789e4d04d2c18d15b8d27440198` with PR35 head
`73efb65189f3f7e08e878a3b0fb6030f34524e4b` on the existing native CI image.

Both detached inputs build the byte-identical public regression harness from
PR35, SHA-256 `9ba2b71bea3889deb24b8cf40301406c24ef658bd619ad2b4a41d377fa2d9b3a`.
Equal-length before/after paths avoid introducing unequal bundle-path accounting.
The script builds both Release programs with the same Swift/SDK before measuring.
It preserves commands, exits, source pins, binary hashes, exact harness bytes,
samples, thermal observations and host/process/paging logs.

Three alternating pairs (AB, BA, AB) provide 27 samples per workload/revision,
with three warmup batches per process. Each process requires pre/post intervals
of at least 90% idle and no competing heavy compiler/renderer. The first cumulative
top sample is excluded; three consecutive one-second interval samples are required.
Paging invalidates the controlled comparison. Only the script's own monitors may
be stopped. The unchanged 10% median/retention change is a review trigger, not an
automatic adoption or merge decision; crossing it preserves measured results and
returns a distinct review-required status.

Byte parser, Data document, Pointer and schema-only workloads retain their fixed
inputs/iterations. Only byte-parser and schema-only native work/logical peaks are
measured; other raw zero fields become N/A. Logical retention is not RSS, and these
four ordinary-operation timings do not establish downstream import capacity.

The driver is original Apache-2.0 qualification code. No runtime dependency, public
product, native limit, source fixture or release policy is changed. No merge,
release, publication or Swift-OpenAPI dependency update follows from this proof.
