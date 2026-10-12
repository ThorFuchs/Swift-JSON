# Integrated 1.1 performance disposition

The unchanged twelve-workload public harness compares the released 1.0 core at
`a2733dd` (identical Sources/benchmark harness to tag 1.0.0) with the 1.1 core plus
capacity-history correction. M1 Max/32 GiB, macOS27.0, Swift6.4, Xcode27.2/SDK27.2,
release optimization, finite balanced profile, three warmups, nine samples and
three invocations/sample apply to both. Inputs/configuration hashes match exactly.
Measurements are serial, with compilation/safety workloads idle.

An initial implementation recorded maximum admission history on every meter check
and regressed most workloads substantially. Retain those results. The correction
records history only in native coding/read scopes that can tighten limits; work is
already cumulative and live retention uses current ownership. Fixed-policy codecs
skip unused history writes. Refusal/cancellation/overflow remains terminal. The
capacity-history refusal test protects against silently weakening later ceilings.

| Workload | Before / after ms | Change | Before / after logical peak bytes |
| --- | ---: | ---: | ---: |
| parse_small_exact | 0.018653 / 0.020917 | +12.14% | 649 / 721 |
| parse_owned_data | 0.023042 / 0.025722 | +11.63% | 0 / 0 |
| parse_large_exact_array | 21.826889 / 22.917903 | +5.00% | 320064 / 320064 |
| write_large_unicode_string | 100.354583 / 101.423028 | +1.06% | 1040004 / 1040004 |
| native_value_codable | 16.128958 / 16.260583 | +0.82% | 166332 / 166468 |
| exact_number_parse_compare | 1.459167 / 1.448500 | -0.73% | 0 / 0 |
| schema_compile_repeated_patterns | 36.223806 / 35.530042 | -1.92% | 103074 / 104642 |
| shared_plan_regex_evaluation | 0.352625 / 0.358167 | +1.57% | 1412 / 1412 |
| schema_exact_evaluation | 0.022833 / 0.023208 | +1.64% | 647 / 647 |
| staged_rfc6902 | 1.522097 / 1.531833 | +0.64% | 97100 / 97100 |
| rfc7396 | 0.052417 / 0.054500 | +3.97% | 1191 / 1255 |
| generated_root_array_stream | 1179.382305 / 1365.204694 | +15.76% | 52 / 52 |

The unchanged 10% review trigger applies. Accept the observed small exact parse
(+12.14%, about 2.26 microseconds) and owned-Data parse (+11.63%, about 2.68
microseconds) costs, including controlled duplicate/index bookkeeping and terminal
accounting. Small-parse logical peak rises 649 to721 (+11.09%): explicit additional
index capacity is covered by unchanged weights/limits. Accept the stream observation
(+15.76%, about1.86 microseconds/record) for this correctness/ownership increment,
with no throughput improvement claim or isolated causal attribution. Raw samples
and variance remain material evidence. No profile/10% threshold is raised.

The historical stream 1.0749626803 versus0.968493986 seconds (+10.9932%) retains
its earlier disposition independently. The new matched stream pair is1.3652046943
versus1.1793823053 seconds; do not compare either new run with a historical median
as if inputs/environment were a fresh matched pair.

The separate wide-index construction/lookup corpus retains its full trigger review
and spare-capacity tradeoff in IndexMeasurements.md. This integrated corpus supplies
no new index crossover, SIMD/parallel speed claim or SwiftyJSON comparison.

Physical iPhone14ProMax/iOS27.2 current-candidate public-product/payload work has
nine release samples after three warmups: median54.406542 ms and process peak RSS
24395776 bytes. This is a whole app/SDK peak, including UIKit, without isolated
allocation or hard-RSS claims, and no matched mobile optimization comparison.
Physical iPad measurements remain blocked. Logical bytes, allocator observations,
process RSS and caller computation remain distinct.

The additional QA wave changes only Base64 failure cleanup in the runtime. Affected
public Data/payload paths have three matched, alternating release-native process
pairs (27 samples per source/workload, 100 invocations/sample). Valid Data medians
range from −1.28% to +4.98%; payload decoding is +1.16%, corruption recovery −0.09%.
Input hashes/work counters match; no new 10% timing trigger is crossed. The corrected
recovery ledger reports final live zero instead of 300 and peak 16 instead of 300.
This is truthful accounting of freed scratch, without an RSS/allocator improvement
claim. The unchanged index and twelve-workload dispositions above are retained.
The expanded physical QA harness has different work and cannot be compared with
the earlier phone median as a matched speed result. See [QA](QA.md).
