# G8 combined-source qualification and review

Reviewed source `130823a5c8af47e21251f271df50a948c73cb9a1` integrates main
`7d72c8825982550f0ee87218136fda12d8bae13b` with repaired S3 parent
`8d0e83037cb1e82b33e1dec862123c890b9b9bc7`. The actual PR merge-ref source is
`34efc30e56da30a1e907a8f7d8b6614fd97b2951`; every public source-input hash matches.
This record is a documentation-only successor. Final PR checks and materialized
receipts bind its final archive separately; executable inputs and declarations stay
identical. Earlier G0–G7 and lifetime-repair records are retained as history.

[Native run 38829233646](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38829233646)
and [Linux run 38829233447](https://github.com/ThorFuchs/Swift-JSON/actions/runs/38829233447)
passed all eight qualification jobs. Branch Pages deployment is skipped. Commands
run through `Scripts/ci.py`; full native/Linux jobs additionally run `--lane composition`.
All actual commands, exits, event streams, source-input hashes and environments are
materialized in the maintainer review bundle; expected compiler failures remain
explicit nonzero outcomes, not silently ignored failures.

| Actual scope | Outcomes |
| --- | --- |
| Native lane | 38 commands; 695 functions and 325 parameter invocations in each of Debug/Release |
| Native safety | Four commands; ASan 695/325, TSan 47, strict-memory warnings-as-errors, 128-scope corpus lifetime probe |
| Linux, each architecture | 34 commands; 679/325 Debug/Release; pinned Swift6.4 Ubuntu24.04 image |
| Linux safety, each architecture | Five commands; ASan 679/325, TSan46, strict-memory, explicit ASan/LSan lifetime probe without suppressions |
| Composition, each full job | Nine commands; 12 core functions, five external functions Debug/Release/ASan, eight cells (five completed, three operational refusals), 11 compiler negatives |
| Native documentation | Eight catalogs, 1,077 authored declarations documented, 14 README fences; S3 ten guide snippets in two processes |
| Native archive | Byte-equal archive/rebuild/extracted rebuild; full 38-command native from a real Git-free extraction |
| Linux extraction, each architecture | Release build, six focused integrity/resource functions and real public consumer; full 679-function root runs are separate |
| WASI | Matching Swift6.4 SDK; 79 commands; Node Debug/Release591 functions and288 parameters; strict memory, 49 caps, public vectors and independent suites; WasmKit public scope remains distinct |
| Apple mobile | S3 and Navigation compiled for both mobile SDKs; iPhone/iPad simulators each ran15 public cases, ten guides and512 matrix certifications with64 negatives |

Native hosted execution used macOS27.0.1 arm64, Xcode27.2/SDK27.2 and
Apple Swift6.4 (`swiftlang-6.4.0.34.1`); local checks used macOS27.0 with the
same compiler/SDK baseline. Linux ARM64/x86_64 used official Swift6.4 on
Ubuntu24.04.5/glibc. WASI used the installed matching Swift.org6.4 SDK and both
recorded Node/WasmKit runtimes. No baseline, timeout, exclusion, cap or review
trigger was weakened.

The pinned schema suite still distinguishes 2,300 evaluated successes from37
policy cases (2,337 observed); JSONTestSuite287 from31 (318 observed). All126
restored maintenance identities and49 cap probes remain required. Policy cases
are not successes. The amended44-schema/155-witness fixture remains unchanged.
Native fixed replay has816 certifications and32 explicit incompletes, plus two
separate trivial proofs; the additional seeded grammar has512 certifications,
64 negative cases and zero exact external-oracle disagreements. Five current
platform/engine matrix outputs match preserved values, traces, attempts, digests
and charged work byte-for-byte. Incompletes do not prove unsatisfiability.

## Review decisions and boundaries

The [12 conflict decisions](G8Integration.md) preserve composition, Navigation,
S3, every parent provenance notice, finite policy and required check name. Source
blob checks prove the S3 implementation/tests/fixtures/consumer match its repaired
parent, and core JSON/composition/Navigation match main. Compiler graphs preserve
all60 S3 declarations and all existing repaired-parent declarations. Navigation's
56 declarations remain unchanged. Nine products and23 targets retain an empty
root dependency graph; runtime targets remain private. CLI identity is regenerated
from the actual combined Package.swift/Sources manifest.

The source/API/resource/lifecycle review found no further runtime repair needed.
Certification still requires a complete original-root native verdict. False
checks retain work; operational failures and cancellation remain terminal. Exact
numbers/scalars, immutable offline plans, iterative construction and finite
shared ledgers remain authoritative. No new public composition adapter is implied.

This is agent review, not independent human approval. The physical iPhone was
disconnected, so no new device pass is claimed; its historical G7 receipt retains
its own source boundary. Physical iPad retains the previously accepted simulator
policy. Logical retention is not RSS, functional timing is not controlled
throughput, and arbitrary-schema solving remains incomplete. Source archive
`ab4cc31d95d3409d7947aafa057954089961fd6ff65e573e43ce92dd03f2a29c`
contains1,177 public source files plus its manifest and was independently reproduced.
The final documentation-only successor receives its own archive and receipts.

G8 is ready for owner review with those explicit limits. PR #39 remains draft;
merging, tagging, release publication and Pages deployment remain separate.
