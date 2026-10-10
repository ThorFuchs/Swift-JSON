# Native public-product benchmarks

From the repository root:

```sh
swift run -c release --package-path Tools/Benchmarks Benchmarks --output .build/handoff/benchmarks.json --repetitions 9 --warmup 3 --iterations 3
```

Twelve workloads exercise exact parsing, owned Data, large arrays/Unicode text,
native value Codable, long decimals, schema compilation/exact assertions/
repeated regex searches, both Patch standards and a generated root-array
stream. Each operation checks its result. The 100000-record source allocates
only its current tiny chunk; it does not preload the document.

Reports contain input/configuration hashes, all samples, medians, population
variance and units/second. Public operation reports supply logical retained
peaks; zero marks a facade without that report. Darwin `ru_maxrss` is the
cumulative process peak in bytes, and libmalloc statistics are allocator-wide
end observations. Neither is an isolated workload allocation count or a hard
memory guarantee. Native receipts add compiler/SDK/model and source hashes.

Run measurements while other build/safety workloads are idle. Compare equal
inputs/profiles/configurations; preserve the scalar baseline before changing
an optimization. A 10% median/retention change is a review trigger after
variance calibration, not a cross-machine performance guarantee. The balanced
numeric ceiling rejects the original 16000-element exact-number array;
the admitted benchmark uses 4000 elements without changing profile limits.
