# Additional 1.1 acceptance and conformance wave

The Turn003 wave adds 19 Swift Testing behavior functions to the 156-function
Turn002 candidate. Exact discovery is JSON97, Streaming14, Schema41, Regex12 and
Patch11: 175 functions, with all 173 prior parameterized invocations and all 48
earlier Swift test files retained. No independent policy exclusion is reclassified.

| Subject | Additional evidence |
| --- | --- |
| Exact transport | Fixed seed `0x534A1100A11CE001`, 192 documents across six root kinds; compact token bytes independently check native projection, Version 1 opening and native/Foundation JSON/property-list transport |
| Numeric projections | 772 integral spellings, independently checked signed/unsigned 8-bit ranges, including equivalent fractional/exponent spellings |
| Keys/index publication | Checked construction, accumulator, parser, edits and reusable scopes; actual member boundaries 7/8/9, 31/32/33, 63/64/65 and 127/128/129; ordered scalar-key oracle |
| Base64 | 259 canonical byte fixtures; 1,152 mutated unused-padding-bit cases; repeated caught corruption, prefix ownership, quota failure and in-loop cancellation |
| Scoped coding | Permanent ceilings after ordinary failure, prior unselected-text admission, caller-error scratch release and mapped Unicode UTF-8 byte coordinates |
| Payload budgets | Six roots, creation/opening work and live-retention inclusive/minus-one matrix; identical preserved bytes |
| Shared state | 16 workers ×20 openings/read scopes over shared immutable inputs; checked Sendable and five-case TSAN selection |
| Schema | Explicitly rooted definitions and negative cases; wide persisted instances/evaluated scalar locations, plan reuse after invalidity, cumulative regex search boundary |
| Patch | Ordered scalar-key edits and real 32→31→32 stages; cumulative quota refusal publishes no partial result |
| Streaming | Every byte split of a wide scalar-key/lexeme document and malformed duplicate; stable second-key location, terminal pulls, cancellation after three accepted sink bytes |

The first executed wave reproduced a logical-retention accounting defect: shared
Base64 decoding left partial scratch charged after ordinary corruption. A caller
catching that error could accumulate freed-byte reservations and later get a false
resource refusal. Decode now releases only its invocation's failed reservation.
Consumed work and terminal resource/cancellation state remain charged/latched;
successful Data ownership retains its prior accounting. This corrects Version 1
accounting without changing weights, caps, grammar or the public API. It is not an
allocator-memory leak or an RSS improvement claim. Original failure receipts remain.

A new projection test initially calibrated its limit using native rounded decoding
then added a larger exactness-proof operation. Its correction measures the same
complete operation on both sides. Compiler harness corrections use an explicit
JSONKey initializer and an actor-owned Sendable sink; no unsafe annotation or
compiler bypass is introduced. A separate review expanded generated field widths
to include actual member boundaries after adding the special keys.

Use `Scripts/ci.py --lane native`, `--lane safety`, `--lane docs` and the supplemental
`--lane qa` on the supported host. Full native execution retains JSONTestSuite
318 discovered/287 evaluated/31 policy and Schema2337/2300/37, 82 authored vectors,
nine budget vectors, 4,396 malformed replays, 31,824 regex cases/442 patterns and
18,853 Unicode cases/94,265 comparisons. All49 public cap outcomes remain required.
The rooted public consumer retains20 cases and distinct operational errors.

The public mobile harness additionally checks100 caught malformed Data projections
under32 logical bytes and wide indexed payload/Schema/Patch behavior. Both SDKs,
isolated iPhone/iPad simulators and the physical iPhone execute the updated harness;
disk save/reopen/update uses three independently exited processes and eight frozen
fixtures. This QA wave originally left physical iPad qualification blocked. The
subsequent [maintainer policy](QualificationPolicy.json) accepts iPad simulator
evidence for 1.1.0 and defers physical iPad execution without blocking the release.
Simulator execution does not establish physical-device performance.

The affected Base64 paths have three serial alternating release-native pairs,
each with3 warmups,9 samples and100 public invocations/sample, finite balanced caps,
matched input hashes and identical work. Across27 samples/side, valid decode
medians range from−1.28% to+4.98%; native payload decode is+1.16% and corruption
recovery−0.09%. No new10% timing trigger is crossed. Recovery's corrected logical
peak is16 rather than300, with final live0 rather than300; work remains506. Keep
raw variance/ranges and process-wide RSS separate from these logical counters.
The earlier wide-index and integrated streaming dispositions remain unchanged.

Physical iPhone14ProMax/iOS27.2 updated public QA measures9 release samples after3
warmups: median50.457167ms, process-wide peak25,133,056 bytes, thermal state0 at
both observations. This harness adds work relative to Turn002; the two medians
are not a matched speed comparison. SDK/UIKit/process costs are included.

Actual receipts, failed-source reproduction, raw samples, source bindings, clean
archive rebuilding and compiled catalogues are materialized in the local Turn003
return. Hosted Native job artifacts supply remote source/command receipts. This
wave does not merge the protected PR stack, qualify an MCP server, publish1.1,
select SIMD/parallel batches, or claim physical iPad qualification. The later
release-scope decision supersedes the physical iPad blocker while preserving these
historical receipts and outcomes.
