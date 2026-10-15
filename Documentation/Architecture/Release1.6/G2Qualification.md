# G2 native increment and evidence

G2 adds metered SplitMix64 choices, stable exact construction and versioned
source/corpus/policy/complete-trace digests to the optional JSONSchemaExamples
product. The accepted API and normative transports are in G2Determinism.md.
G0/G1 history remains intact; G3-G8 remain open and release_ready remains false.
No existing JSON/JSONSchema production source or root dependency was changed.

## Actual native outcomes

On macOS 27.0 arm64, Xcode 27.2 (27B5019j), Apple Swift 6.4
(swiftlang-6.4.0.34.1), selected SDK 27.2, language mode 6:

* `python3 -B Scripts/ci.py --lane schema-examples-determinism --output Artifacts/SchemaExamplesS3/G2/determinism-verified`
  exited 0: seven commands, exact eight-product/empty-dependency checks,
  42 Swift Testing functions in Debug and 42 in Release. The public consumer
  passed 15 cases in each of two independent processes; two public access-control
  negatives rejected as expected. Independent stdlib SHA-256/byte-format vectors
  matched both profiles and all 49 policy fields.
* The implementation compiler qualifier accepted moving RNG state once and
  sharing the immutable facade; it rejected double consumption of RNG/trace and
  Sendable requirements for RNG/trace/transport (one positive, five negatives).
  These trusted @testable fixtures are distinct from the public-only consumer.
* `python3 -B Scripts/ci.py --lane schema-examples-safety --output Artifacts/SchemaExamplesS3/G2/safety-verified`
  exited 0: all 42 functions in Release ASan, one TSan function with 32 concurrent
  invocations (plus sequential reference calls), and strict-memory-safety with
  warnings as errors. Every command exited 0; no sanitizer failure was ignored.
* The broader schema-examples run evaluated all 69 existing schema functions,
  12 parameter invocations and 2300 pinned cases (1301 core, 125 optional semantic,
  874 formats), with zero failures. Its 37 policy exclusions are separate.
  That aggregate run failed its stale **12-case consumer marker**, despite the
  actual 15-case consumer/oracle passing. Only its separately passed unchanged-core
  schema command is reused. The final seven-command G2 lane refreshed all affected
  implementation/consumer checks; the failed aggregate is never called passed.
* Harness mutation checks passed 17 cases; Testing event parser checks passed 19.
  Exact module/function/parameter discovery and all 49 baseline metric probes
  remain required in the full lanes; a focused lane cannot substitute for them.

Raw commands, exits, environment, input SHA-256 lists, Swift Testing event streams
and log hashes are materialized under the private G2 evidence directory. Source
receipts record G1 HEAD 8de39d5 plus the actual working-tree hashes at execution;
that Git SHA alone does not contain G2. The return's SourceEvidenceMap verifies
complete path/hash sets against the committed final source and separately verifies
unchanged-core suite reuse. The final clean-head `Scripts/ci.py --lane docs`
receipt records actual DocC/comment/consumer/site outcomes, rather than inferring
success from authored prose. Build outputs/private logs remain outside source Git.

## Meaningful behavior and resolved findings

The 21 added functions exercise the 16 reference draws, 640 bounded selections,
a forced rejected draw (two draws, 61 work units, 34 trace bytes), terminal quota
failure, quantum-one cancellation inside a draw, normalized exact large/fractional
numbers and scalar-distinct keys, 100 nested arrays, numeric/depth admission,
corpus admission/order/immutability, independent transport/trace goldens, all 49
caps and all policy flags, exact trace capacity, circular scans including false
verdicts, stable keyword/reference traversal and constructor cancellation.
The strengthened sharing function covers both minimal and seeded demonstration.
Native certification against the original compiled root remains the sole success
path; no validation report constructor or alternate validator was introduced.

Compiler probes exposed implicit Sendable inference on internal noncopyable value
types. Explicit unavailable conformances now opt mutable helpers out; no unsafe
annotation or compiler compatibility flag was added. A throwing noncopyable member
initializer was replaced with local construction followed by a final move.

Exploratory failures remain retained: an incorrect fixed-decimal expected byte
string was corrected to the existing writer's normalized coefficient/exponent
spelling; mathematical exactness assertions remain. A corpus test initially hit
the packaged meta-schema string cap first. Its positive control exposed that gap;
the corrected test admits a null corpus at 4096 bytes and rejects a 4097-byte
corpus token. Production/default limits were not changed. The consumer marker
was updated to the actual 15 cases and stale/missing markers now fail mutation
checks. An unavailable Python cache and misspelled parser-probe command were
replaced with cache-free syntax checking and the actual 19-case verifier.

## Remaining boundaries

This is a native G2 milestone, not full schema generation, a satisfiability solver
or a release candidate. G3/G4 constructive fixtures, G5 complete lifecycle review,
G6 final documentation and G7 platform qualification remain separate. No new
Linux/WASI/mobile, controlled performance or RSS qualification is asserted.
Trace bytes never silently truncate; failure/cancellation returns no certificate.
Logical retained weights and owned work do not cap allocator RSS or caller code.

Main independently advanced to 037e735 with 1.5.1 repairs while this isolated train
retained its approved G0/G1 base. That includes a schema best-effort diagnostic
repair and restored tests/harness checks. Integrate and reconcile that source and
its new cardinalities before G7/G8; this G2 result does not qualify that merge.
The separate main/sibling checkouts were not edited. No push, PR, merge, tag,
release, deployment or external message was performed.
