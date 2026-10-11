# Swift-JSON 1.1 additive release plan

The released 1.0 API and behavior contracts remain authoritative. This plan records
reviewable work toward 1.1; prototype types under Tests and Tools are qualification
subjects, not additions to the four public libraries.

| Branch | Review scope | Acceptance / gate |
| --- | --- | --- |
| chore/1.1-plan-and-qualification | Ownership and SDK probes, index corpus, finite experiment meters, test discovery adaptation | R0 |
| perf/1.1-exact-key-index | Measured exact-key candidate filtering, then adaptive metadata and incremental duplicate detection | I01–I08 / R1 |
| feat/1.1-scoped-read-access | Scoped typed navigation, bounded paths, guarded lifetime, terminal failure and reports | A01–A13 / R2 |
| feat/1.1-codable-value-bridge | Existing native coder conveniences and projection under the active scope meter | C01–C06 / R3 |
| feat/1.1-exact-codable-payload | Strict Version 1 envelope, finite owned codec and fixed compatibility fixtures | P01–P08 / R4 |
| feat/1.1-apple-mobile-qualification | macOS/iOS 27 minima, resources, simulator/device consumers, disk-backed SwiftData | S01–S04, M01–M06 / R5 |
| docs/1.1-release-readiness | Executed examples, migration/DocC, final integrated qualification and candidate | W01–W05 / R7–R8 |

Create successors from reviewed prerequisites; disclose any stacked base. Each
change must preserve checked Sendable, strict UTF-8, exact numbers/scalar identity,
member order, cumulative finite accounting and zero root dependencies. Root
products stay JSON, JSONSchema, JSONStreaming and JSONPatch; regex stays private.
SwiftData belongs to a qualification example, never a core dependency.

SIMD byte kernels and independent-work batches are conditional R6 experiments.
They remain unselected until scalar parity, ownership, aggregate quotas and native
measurements justify inclusion. E11 projection and E12 text sequences stay deferred.
The existing approximately 11% streaming regression retains its accepted disposition
and unchanged 10% review trigger. This milestone supplies no causal attribution.

[Decisions](Decisions.md) records the executable prototype boundaries. Run:

```sh
python3 Scripts/ci.py --lane r0
python3 Scripts/ci.py --lane native
python3 Scripts/ci.py --lane safety
python3 Scripts/ci.py --lane docs
```

Native includes the ownership consumer and compiler-negative cases. R0 adds the
three SwiftData SDK shape probes. Mobile product builds and controlled benchmark
runs are explicit, separately reported operations:

```sh
python3 Scripts/qualify_release_1_1.py --mode mobile --output .build/ci/mobile/receipt.json
python3 Scripts/qualify_release_1_1.py --mode index --output .build/ci/index/receipt.json
```

Keep actual logs/receipts under ignored build/evidence directories. Each records
source inputs, environment, command exits and counts. A failed or absent runtime
cannot advertise support. Inspect simulator resource signing separately from SDK
compilation. Physical iPhone/iPad performance and real disk teardown/reopen remain
mandatory later gates. No merge, tag or publication follows from this plan.
