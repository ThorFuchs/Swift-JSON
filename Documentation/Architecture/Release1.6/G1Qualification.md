# S3 G1 implementation and native qualification

G1 is complete on the isolated `codex/1.6-schema-examples` branch. This closes the
public API/preparation increment, not G2–G8 or a 1.6 release gate. The implementation
commit is `6c19580dec99c9363bb4b4d1611af8b8a2bab266`; the following closure adds
maintainer records and strengthens the public consumer, without changing library
or test source. Native receipts record tested source hashes as well as Git identity.

## Accepted implementation

`JSONSchemaExamples` is the eighth public product and seventh library. It depends
only on JSON and JSONSchema; existing product edges and the empty root dependency
graph are unchanged. No sibling DSL, CLI, platform, resolver or regex implementation
was added. Original code is Apache-2.0, with no new upstream code adaptation.

The package-only qualified-node handle exposes immutable declarations, active
vocabulary/format policy and checked compiler-resolved child/static-reference
edges. It exposes no mutable graph arrays, URI resolver or regex engine. Its
targets originate only in the retained plan. External access and external result
construction are rejected by actual compiler probes.

The public generator compiles once from document plus explicit registry, retaining
separate compilation and validation policies. G1 offers const, enum, default,
examples, true/empty roots and static references. Each candidate is checked against
the original root. The successful result contains the native completed valid
verdict. Unsupported construction, bounded exhaustion, two sound trivial proofs
and generator configuration errors are distinct. Core errors/cancellation escape
terminally; no failed operation is retried with a new budget.

Preparation shares one meter across compilation, normalized snapshot serialization
and portable SHA-256. Each generation shares one noncopyable meter across discovery
and every completed validation, including false verdicts. Discarded validation
ownership is released; work and lifetime admissions are not refunded. Counts and
peak logical bytes are neither caller instruction quotas nor process RSS.

See [the exact declarations and resource units](G1API.md) and the
[public consumer](../../../Examples/SchemaExamplesConsumer/README.md).

## Observed qualification

Native environment: macOS 27.0 arm64, Xcode 27.2 build 27B5019j, Apple Swift 6.4
`swiftlang-6.4.0.34.1`, selected SDK 27.2, language mode 6. Test binary inspection
confirms minimum macOS 27.0; the Swift Testing host-framework banner is not the
package deployment target. No compatibility flag or unsafe annotation was added.

| Command/check | Observed result |
| --- | --- |
| `python3 Scripts/ci.py --lane schema-examples` | Exit 0 on implementation commit; all six commands passed |
| New Swift Testing target | 21 functions, zero failures; exact module identity and cardinality enforced |
| Existing JSONSchemaTests | 69 functions, 12 exact parameter invocations, zero failures |
| Pinned schema suite within existing tests | 1,301 core + 125 optional semantic + 874 format cases = 2,300 evaluated, zero failures |
| Schema policy ledger | 2,337 discovered; 37 separate policy cases, unchanged; exclusions are not evaluated successes |
| NFC qualification within existing tests | 18,853 cases / 94,265 comparisons |
| Public consumer | 12 cases; independent native verification and roundtrip of every returned value, including the offline registry case |
| Public compiler boundaries | Two intended typecheck exits 1 for package-only plan access and internal certificate initialization |
| `python3 Scripts/ci.py --lane schema-examples-safety` | Exit 0: 21 Release ASan functions, one shared-generator TSan function, strict memory-safety target/dependency build with warnings as errors |
| `python3 Scripts/ci.py --lane docs` | Exit 0: seven native DocC catalogs; 988 authored declarations documented, including all 42 new declarations and named parameters; README consumer and local static site checks |
| CI event parser checks | 19 existing parser receipts passed |
| CI negative/mutation checks | 12 acceptance/rejection checks; wrong products, back-edges, dependencies, missing functions and a focused-safety substitution rejected |

Suite pin: `json-schema-org/JSON-Schema-Test-Suite`
`5b0ee1613e45fcc2bddac00e07c19cd49b00d8a8`. Meta-schema pin, Unicode 13 data,
upstream licenses, resource selections and policy tables are unchanged. The tests
run the pinned inputs already in this repository; no online resolution is used.
All 49 baseline finite policies and their full-lane cap probes remain required.
The full root requirements are now 440 Mac functions / 325 parameter invocations
and 16 shared-state functions. Focused G1 runs do not claim that full inventory ran.

Private materialized records are retained under ignored `Artifacts/SchemaExamplesS3/G1`.
The return bundle contains command logs, events, source hashes, input pins and a
mapping from qualified source to the final archive. The successful implementation
native receipt is `native-committed/receipt.json`; safety is `safety-first/receipt.json`.
The strengthened consumer also runs in the final docs lane. Unchanged code evidence
is reused with file-hash comparison, not asserted from a summary alone.

## Review findings and retained failures

The initial full-package test compilation failed with disk-full errors before any
tests ran. Native Swift 6.4's actual `--test-product` option selects the generated
test bundle and preserves exact discovery. An invalid build-option combination
and a skip-build attempt on incomplete unrelated bundles are retained as failed
tool probes, not passes.

One format-policy fixture initially omitted the metadata vocabulary needed to
offer its default candidate; adding that vocabulary preserved the intended format
rejection test. A real harness ambiguity after sanitizer builds was fixed by using
SwiftPM's reported consumer binary directory instead of recursively selecting from
all caches. Both failed runs and subsequent passing runs are retained.

Review also corrected discovery accounting to charge schemaNodes, separated live
discarded-result release from cumulative work, and strengthened the offline public
consumer's independent validation/roundtrip and public remaining-work demonstration.
No test count, expected engine verdict, resource baseline or suite policy was lowered.

## Remaining scope

Only minimal is exposed; G1 records seed but draws no random numbers. The algorithm
is `s3-g1-candidates-v1`, with the documented `swift-json-schema-snapshot-g1-v1`
transport. The digest normalizes key order and numeric spelling; it does not recover
original order/lexemes or source text. G2 must freeze emitted-byte/corpus/trace
identity and metered random construction. No cross-platform determinism claim is
made from native-only G1 results.

General constraint-driven synthesis, richer profiles, the 44-case generation
ledger, advanced/dynamic construction, complete G5 adversarial lifecycle proof and
full G7 Native/Linux/WASI/mobile qualification remain open. No controlled performance
or RSS result is claimed. No branch was pushed, PR opened, merge performed, tag
created or release published. Sibling work and the original main checkout were
not changed by this implementation.
