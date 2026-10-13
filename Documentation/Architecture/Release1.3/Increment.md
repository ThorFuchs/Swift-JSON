# First JSONHTML increment

Branch: `codex/1.3-jsonhtml`, isolated from the 1.2 Linux/WASI release work.
Base: `532f725740a4d61c32bc9870986d050b71f9db78`.

This increment adds the working fifth product, JSONHTML, depending on JSON only.
Its formatted renderer produces complete expanded HTML for all six JSON roots.
It shares the strict writer cursor, preserves source numeric lexemes, insertion
order and scalar identity, escapes keys/values/titles, uses fixed original hashed
CSS and emits no scripts or external assets. Data/String/report APIs are checked
Sendable. The additive writer indentation option defaults to legacy spaces;
tabs are literal bytes, with separate HTML visual tab width.

One invocation meter covers admission, title checks, cursor traversal, escaping,
assets and the final result copy. Additional HTML capacities bound complete bytes,
rendered values and a conservative DOM node upper bound. Failures return no partial
document/report and latch the meter before releasing owned scratch. Core failure
types and cancellation propagate. Logical retention remains distinct from RSS.

## Verification

Native environment: macOS 27.0 arm64, Xcode 27.2 (27B5019j), SDK 27.2,
Apple Swift 6.4 (swiftlang-6.4.0.34.1), language mode 6. Explicitly select this
Xcode with `DEVELOPER_DIR` and its macOS SDK with `SDKROOT`.

The full initial native, safety and docs lanes passed with unchanged inputs.
After source review corrections, the committed source is refreshed through:

```
python3 -B Scripts/ci.py --lane native --output .build/ci/jsonhtml-native-compatible
python3 -B Scripts/ci.py --lane safety --output .build/ci/jsonhtml-safety-compatible
python3 -B Scripts/ci.py --lane docs --output .build/ci/jsonhtml-docs-compatible
```

Expected discovery is exact: 205 root functions, 173 parameterized invocations,
49 original cap probes, seven targeted shared-state functions, three tests each
in mobile and downstream consumers, and one qualification function. Independent
syntax: 318 observed, 287 evaluated successes, 31 strict/finite-policy dispositions.
Independent schema: 2337 observed, 2300 evaluated successes, 37 policy dispositions.
The rooted downstream consumer retains 20 cases (8 positive, 12 negative) and two
operational errors. Five DocC catalogues cover all 628 authored public declarations;
README examples compile and run. Actual command exits, per-case records, hashes
and source identities belong to the materialized lane receipts, not these counts.

Six additional compiler commands pass for JSON, JSONHTML and a public report consumer
on iPhoneOS and iPhoneSimulator SDK 27.2 with warnings as errors. These are module
and interface typechecks, not device or simulator runtime passes. A supplemental
Python HTML parser checks exact body bytes, conservative DOM accounting and the CSS
CSP hash. It is not a browser runtime or accessibility/printing qualification.

Release-native public-consumer measurements cover scalar, exact hostile input,
400-member and 80-level values, five timed samples after warmup. Reported logical
retention includes buffer/result overlap. Timings are observational under concurrent
host work, not idle-host comparisons or throughput guarantees. HTML defaults are
provisional finite policy; browser calibration remains pending. Existing performance
dispositions and the 10% review trigger remain unchanged.

## Initializer compatibility correction

A public Swift 6.4 compiler probe failed when the original four-argument initializer
was stored as a function value after appending a defaulted fifth parameter. The
final source retains that original initializer and adds an explicit-unit overload.
The compiled public consumer and existing formatting test now cover that source
form. All affected lanes are refreshed after this correction; predecessor receipts
remain separate. The release checklist also now selects five products for 1.3.

## Review and remaining gates

Source review fixed print-rule specificity so light, dark and automatic themes all
use the intended print palette. It strengthened exact public-product target mapping
in CI, added independent CSS hash evidence and explicit hostile control-bearing key
bytes, and checked indentation's supported upper boundary. The failed exploratory
symbol-extraction command used an assumed module search path; actual SwiftPM graph
extraction succeeded through the docs lane. No unsupported compiler flag was added. The post-review CSS test caught a stale CSP
hash after the print rule changed; the exact emitted bytes were rehashed with
Python and the digest/length/CSP known answers corrected before committing.

This is an intermediate implementation, not a 1.3 release candidate. Interactive
disclosure/search/outline/copy/download, source annotations, Transferable/selection,
Markdown/RTF/PDF preparation, browser matrix/accessibility/printing, final renderer
preset calibration, mobile runtime and integrated Linux/WASI qualification remain
open. The final qualified 1.2 source must be integrated before final 1.3 gates.
Physical-iPad deferral remains as approved. No release, tag, merge, protection change,
publication or sibling-source modification belongs to this increment.
