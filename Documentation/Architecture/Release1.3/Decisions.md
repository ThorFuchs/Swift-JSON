# 1.3 decisions and open qualification choices

| Decision | Disposition |
| --- | --- |
| Product and version | Maintainer assigns JSONHTML as the fifth product in the existing Swift-JSON package, targeting 1.3.0. |
| 1.2 release ownership | Linux/WASI release work proceeds separately. This branch must integrate the final 1.2 source before its final gates. |
| Specification precedence | Transfer/export explicit amendments override conflicting renderer statements; remaining H/JH requirements remain. |
| Package boundary | JSONHTML depends on JSON only; private regex and empty root external dependencies remain. Apple framework declarations/execution stay conditional and out of core JSON. |
| Framework amendment | JSONHTML may link Apple PDF/printing frameworks. Pure HTML/native export preparation remains actor-independent and does not execute WebKit. |
| Writer compatibility | JSONIndentationUnit defaults to spaces through the retained legacy initializer; a separate overload requires the unit explicitly, preserving typed initializer references. Export tabs/preserved lexemes are explicit. Final declaration requires compiler/behavior evidence. |
| Asset strategy | Prefer versioned original Swift constants for fixed CSS/JS; measure and qualify hashes, CSP and full emitted bytes before selection is frozen. |
| RTF | Prefer owned bounded token-based emission. Strategy remains provisional until independent text/style and platform evidence. |
| PDF | Prefer modern WebPage where executed behavior qualifies it. Region capture is distinct from pagination; A4/Letter/default geometry and backend remain open. |
| Finite presets | No invented values. Freeze additional finite ceilings from native/browser/format measurements; leave core 49 metric values/meanings unchanged. |
| Transfer selection | One Apple JSON conformance, JSON-only strict import, immutable per-item export selection. PDF must already be prepared. |
| Device limitation | Preserve physical-iPad deferral explicitly; record actual iPhone and simulator checks for new capabilities. |

The initial SDK declaration probe typechecked DataRepresentation, exportingCondition, suggestedFileName, exported/importedContentTypes, UTType.markdown, WebPage.load(html:), mediaType and exported(as: .pdf(region:)) on macOS, iPhoneOS and iPhoneSimulator SDK 27.2 with Swift 6.4/language 6 and warnings as errors. This confirms these declaration shapes, not JSON same-package conformance, offscreen rendering, format negotiation, finite policies or pagination. Actual source/log/SDK receipts remain private maintainer evidence.

The first probe was stopped by the default module-cache sandbox path before loading the standard library. The successful run used an invocation-owned explicit module-cache directory. No compatibility or unsafe compiler flag was added.

Review findings resolved in this plan: captured base/release assignment is stale; fifth-product and Apple PDF amendments are explicit; PDF region export cannot establish pagination; default numeric policy requires measurements; all six formats remain in the intended objective; source/receiver/system work and historical qualification remain separate.

## First formatted increment decisions

Ordinary calls accept an appended defaulted `JSONIndentationUnit`, but a further
Swift 6.4 consumer probe proved that this changes the original initializer's
function type. The final declaration therefore retains the four-argument
initializer with its original defaults and adds a five-argument overload whose
`indentationUnit` is required. The legacy initializer delegates with `.spaces`;
callers opt into `.tabs` explicitly. Public consumer and behavior tests exercise
both ordinary calls and the original typed initializer reference.
The original cursor now emits package-only byte classifications and value-start
markers; its byte facade consumes exactly the same steps and accounting. JSONHTML
uses that cursor directly after one admission, with one noncopyable writing meter.
No second parser/formatter or temporary formatted JSON buffer is introduced.

The initial public API is formatted-only: `JSONHTMLRenderer`, immutable facade
options, Data/String and successful report variants. It does not advertise
interactive or transfer behavior before implementation. HTML-specific failures
are latched into the same package meter before scratch cleanup. Final copies
charge overlapping logical ownership; successful core output counts HTML bytes.

The fixed original CSS is a Swift constant. Its emitted bytes and CSP SHA-256 are
checked against an independent Python known answer. Print selectors explicitly
override all three theme classes, a specificity issue found during source review.
The HTML DOM count is an upper bound: 24 fixed nodes plus four per syntax or
whitespace run. Defaults provisionally reuse existing balanced node/output caps;
browser calibration is still required before final preset qualification.

Actual JSON/JSONHTML modules and a public report consumer typecheck on iPhoneOS and
iPhoneSimulator SDK 27.2, Swift 6.4/language 6, with warnings as errors. This does
not qualify simulator/device execution, Linux/WASI runtime or transfer/PDF APIs.
