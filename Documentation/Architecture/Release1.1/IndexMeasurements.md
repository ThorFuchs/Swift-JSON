# Production index stage measurements

The matched predecessor core is `5d01f88` (mobile branch `bf0ff41` changes only
resource packaging/platform documentation). The metadata/keyed-storage core is
`bf37941`. Swift 6.4, SDK 27.2, macOS 27.0, M1 Max/32 GiB, release optimization,
finite offline profile, three warmups and nine measured samples apply to both.
Exact benchmark source and static-library digests accompany the private native
receipts. Documentation/test-only successors reuse these bytes explicitly.

Construction measures 120 cells: four paths, ten widths 0–10000, three key shapes.
The predecessor has 1044 successful samples and four explicit long-prefix
width-10000 work refusals. The candidate has 1080 successful samples. Never use a
refusal's elapsed time as successful throughput. Accumulator timing is available;
its public facade has no accounting report, so its work/retention is unavailable.

| Stage / ASCII width | Before median ms | After median ms | Change | Before / after logical peak bytes |
| --- | ---: | ---: | ---: | ---: |
| Checked 8 | 0.0060 | 0.0039 | -35.9% | 808 / 808 |
| Checked 32 | 0.0510 | 0.0155 | -69.5% | 3136 / 5096 |
| Checked 1024 | 39.5464 | 0.4029 | -99.0% | 99360 / 132128 |
| Parse 1024 | 39.8769 | 1.1994 | -97.0% | 132160 / 197696 |
| Native keyed 1024 | 79.3653 | 1.4056 | -98.2% | 238624 / 336928 |
| Native keyed 10000 | 6930.3080 | 15.7802 | -99.8% | 2330032 / 4464688 |

Lookup measures 129 query cells with 1161 samples per side, 20 lookups/sample.
The final serialized pair, after the overlapping compiler job completed, gives:

| Query | Before / after median ms per 20 lookups | Change | Before / after work |
| --- | ---: | ---: | ---: |
| ASCII 8 last | 0.018042 / 0.018791 | +4.15% | 1620 / 1620 |
| ASCII 32 first filtered | 0.023833 / 0.022792 | -4.37% | 2020 / 2020 |
| ASCII 32 miss | 0.019375 / 0.007542 | -61.07% | 1400 / 580 |
| ASCII 1024 last | 0.526334 / 0.018541 | -96.48% | 42140 / 1540 |
| Prefix 10000 last | 6.195458 / 0.247250 | -96.01% | 426180 / 26580 |

Retain and review every cell above the unchanged 10% trigger, including tiny
measurements near clock/call overhead. The disposition selects this candidate for
wide construction/lookup benefit with explicit additional spare-capacity retention.
It does not claim an improvement for every tiny case or a mobile crossover.
Construction/root admission/ordered rebuilding remain separate from lookup.

Nine separately instrumented native-keyed cells record libmalloc live blocks/bytes
at selected field boundaries. Per-sample allocator observations and cumulative
`ru_maxrss` are process-wide; they are not one allocation per field or isolated
workload allocation counts. Logical weights remain Version 1 and are not RSS.

First lookup samples were lost to a local receipt/output filename collision and
were rerun with distinct sample paths. An earlier retained pair overlapped compiler
work; the final serialized pair is used above. All actual failure/command records
remain evidence. These stage results precede the reader's shared-meter and ISO
correction; affected integrated performance must be refreshed on the final source.
The historical approximately 11% streaming disposition remains separate.

## Complete trigger review

All 11 construction and 16 lookup cells above 10% are retained below.
Construction absolute increases are at most 1.541 microseconds per operation;
lookup increases are at most 1.625 microseconds per twenty queries. These are
observed regressions, without a statistical noise or causal attribution claim.
Accept the small-object metadata/ownership cost for the measured wide-object
benefit, retaining the scalar lookup path below 32. Empty measurements establish
no throughput claim. Four predecessor refusals remain excluded from timing ratios.
The threshold stays 10%; mobile crossovers remain unqualified.

| Operation / shape / width / query | Before / after microseconds | Change | Disposition |
| --- | ---: | ---: | --- |
| accumulator / prefix / 0 / — | 0.584 / 0.666 | +14.04% | No throughput claim; retain observation |
| checked / prefix / 0 / — | 0.792 / 0.875 | +10.48% | No throughput claim; retain observation |
| checked / unicode / 0 / — | 0.709 / 0.833 | +17.49% | No throughput claim; retain observation |
| checked / ascii / 1 / — | 1.125 / 1.417 | +25.96% | Accept measured small-case tradeoff |
| native-keyed / unicode / 0 / — | 2.125 / 2.416 | +13.69% | No throughput claim; retain observation |
| native-keyed / ascii / 1 / — | 4.041 / 4.542 | +12.40% | Accept measured small-case tradeoff |
| native-keyed / unicode / 1 / — | 3.667 / 4.042 | +10.23% | Accept measured small-case tradeoff |
| parse / ascii / 1 / — | 2.625 / 2.958 | +12.69% | Accept measured small-case tradeoff |
| parse / prefix / 1 / — | 11.792 / 13.333 | +13.07% | Accept measured small-case tradeoff |
| parse / unicode / 1 / — | 2.542 / 2.834 | +11.49% | Accept measured small-case tradeoff |
| parse / unicode / 4 / — | 6.500 / 7.500 | +15.38% | Accept measured small-case tradeoff |
| lookup / ascii / 0 / miss | 0.083 / 0.167 | +101.20% | No throughput claim; retain observation |
| lookup / prefix / 0 / miss | 0.042 / 0.167 | +297.62% | No throughput claim; retain observation |
| lookup / unicode / 0 / miss | 0.042 / 0.166 | +295.24% | No throughput claim; retain observation |
| lookup / ascii / 1 / miss | 0.625 / 0.875 | +40.00% | Accept measured small-case tradeoff |
| lookup / unicode / 1 / first | 3.542 / 3.916 | +10.56% | Accept measured small-case tradeoff |
| lookup / unicode / 1 / last | 3.542 / 3.916 | +10.56% | Accept measured small-case tradeoff |
| lookup / unicode / 1 / middle | 3.542 / 3.916 | +10.56% | Accept measured small-case tradeoff |
| lookup / unicode / 1 / miss | 0.583 / 0.875 | +50.09% | Accept measured small-case tradeoff |
| lookup / ascii / 4 / first | 2.875 / 3.208 | +11.58% | Accept measured small-case tradeoff |
| lookup / ascii / 4 / miss | 2.334 / 2.834 | +21.42% | Accept measured small-case tradeoff |
| lookup / unicode / 4 / miss | 2.333 / 2.833 | +21.43% | Accept measured small-case tradeoff |
| lookup / ascii / 8 / miss | 4.542 / 5.292 | +16.51% | Accept measured small-case tradeoff |
| lookup / unicode / 8 / miss | 4.542 / 5.292 | +16.51% | Accept measured small-case tradeoff |
| lookup / ascii / 16 / first | 2.916 / 3.208 | +10.01% | Accept measured small-case tradeoff |
| lookup / ascii / 16 / miss | 8.625 / 10.250 | +18.84% | Accept measured small-case tradeoff |
| lookup / unicode / 16 / miss | 8.916 / 9.959 | +11.70% | Accept measured small-case tradeoff |
