# Initial exact-key lookup review

This increment filters the tail of a linear lookup using existing immutable key
fingerprints. Objects below 32 members retain the scalar loop. Wide objects compare
the first eight members scalarly, then hash the query once under the active meter.
Every candidate hit still confirms exact UTF-8 identity. No object representation,
publication path, duplicate detector, capacity weight or public API changes here.
The array-backed AVL and controlled hash prototypes remain experiment subjects.

The matched production-stage comparison used MacBookPro18,2, Apple M1 Max, 32 GiB,
macOS 27.0, Xcode 27.2 / SDK 27.2 and Swift 6.4 in language mode 6, release `-O`.
`Tools/Release1_1Probes/LookupBenchmark.swift` covers ten widths, three key shapes,
first/middle/last/missing queries and the first filtered member. Each run has three
warmups and nine measured samples, twenty lookups with result checks per sample:
129 query cells and 1161 recorded samples. The balanced/hash prototype measurements
are a separate corpus; their timing is not presented as production improvement.

Two sequential matched production pairs were retained, together with an earlier
candidate measurement. The table uses the repeated pair. Times are medians in
milliseconds for twenty lookups, including identical result checks; work counts
are owned package units, excluding the benchmark's result-check work.

| Shape / width / query | Scalar ms | Filter ms | Change | Scalar / filter work |
| --- | ---: | ---: | ---: | ---: |
| ASCII / 8 / last | 0.018041 | 0.018083 | +0.23% | 1620 / 1620 |
| ASCII / 16 / middle | 0.020166 | 0.020167 | approximately 0% | 1820 / 1820 |
| ASCII / 32 / first filtered | 0.020209 | 0.023750 | +17.52% | 1820 / 2020 |
| ASCII / 32 / miss | 0.017584 | 0.019375 | +10.19% | 1280 / 1400 |
| Prefix / 32 / first filtered | 0.230042 | 0.252583 | +9.80% | 24320 / 27020 |
| ASCII / 1024 / last | 1.657416 | 0.525750 | -68.28% | 144420 / 42140 |
| Prefix / 1024 / last | 24.807875 | 0.848333 | -96.58% | 2704420 / 67140 |
| ASCII / 10000 / last | 16.837083 | 5.013375 | -70.22% | 1422220 / 401180 |
| Prefix / 10000 / last | 248.313000 | 6.156417 | -97.52% | 26422220 / 426180 |

The unchanged 10% review trigger applies. Accept the observed boundary cost for
this focused draft increment: query hashing adds ten work units to the first
filtered ASCII hit and six to the short missing key, approximately 0.18 and 0.09
microseconds per lookup in the repeated pair. Later wide hits materially reduce
owned comparisons. This is an explicit tradeoff, not an assertion that every
lookup improves. Keep the scalar path and qualify adaptive metadata separately.

Timings are host observations. An initial width-16 ASCII timing outlier disappeared
in the unchanged-code repeat, and wide scalar timings varied between runs; retain
both raw sets and variance instead of attributing those changes to the algorithm.
Empty-loop timings are at timer/call-overhead scale and establish no throughput
claim. This stage retains no owned buffer and reports zero logical retained bytes;
it measures neither process RSS nor allocator counts. Construction, whole-root
admission, native keyed encoding, thermal/energy effects and mobile crossovers
remain unqualified R1/R5 work. Algorithm costs may change resource failure points;
all finite profiles and counter version/weights remain unchanged.

The historical stream median 1.0749626803 seconds versus 0.968493986 seconds
(+10.9932%) retains its existing accepted disposition and 10% trigger. This lookup
stage gives no stream attribution or fresh full-workload release qualification.
Raw samples, source/input hashes, command receipts and medians/variance are retained
in the milestone return bundle, with compiler, SDK, CI and fixture evidence.
