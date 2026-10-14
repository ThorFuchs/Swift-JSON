# Receiving-app and physical export qualification

This pass continues export implementation 1e0b86d2580bb9678039597523aa3b99d2905abf
on codex/1.3-jsonhtml-transfer, stacked on renderer PR #21. It changes qualification
tools and documentation, not the JSONHTML public API or library implementation.
Actual source hashes, app binaries, commands, failed attempts and observations are
materialized in the local handoff; this document is a scope map, not a receipt.

## Observed receiver behavior

The five-product native consumer passed 63 outcomes and produced eight artifacts
on macOS 27.0 and a development-signed physical iPhone 14 Pro Max running iOS 27.2.
The device uses the existing Swift 6.4 / SDK 27.2 baseline and packaged schema
resources. Its representative UI checks were maintainer-observed: seven-page PDF
and final sentinel; Share PDF to local Files and reopen; explicit Copy JSON and
Share JSON/Copy into the strict reader; explicit Copy Markdown into its reader.
The maintainer reported all four checks passed. These are manual UI observations,
separate from the automated consumer and from unexecuted recipients.

On macOS, the actual ShareLink PDF/Copy action produced com.adobe.pdf bytes equal
to the prepared A4 artifact. Explicit Copy JSON and Copy Markdown reached their
typed readers unchanged. TextEdit 1.21 plain paste/save preserved all 105 UTF-8 bytes,
including scalar-distinct keys, exact integer and number spelling.

TextEdit rich RTF paste and its saved file retain Menlo-Regular 11 and distinct
token colors. The saved RTF canonicalizes the decomposed key to composed U+00E9:
exact scalar text fidelity at this recipient save layer fails. The emitted RTF
independently decodes exactly in the native consumer. No emitter normalization,
format relabeling or hidden fallback is introduced. Use the native JSON artifact
for interchange. HTML paste is separately observed: TextEdit receives the complete
visible data, document heading and highlighted tokens; its own paragraph/font
choices remain recipient behavior.

The private SwiftUI qualification app uses the actual compiled ShareLink shape:
a non-String/non-URL item needs an explicit SharePreview. Its wrapper adapts only
the existing consumer entry/output URL, resource-bundle access and an observation
type name that otherwise shadows Apple's Observation module. It introduces no
second JSON conformance or production renderer.

Background startup of that private GUI app hit the unchanged 30-second soft PDF
deadline. Explicit foreground preparation passed. The failed observation is retained;
this does not establish a hard background responsiveness guarantee or justify
widening a default. Native platform work and main-actor scheduling remain separate
from owned quotas and logical retention.

## Integrated portable harness

The inherited WASI harness still asserted four products and 104 JSON functions.
Actual final-source discovery includes 107 JSON functions, including the three
quota/cumulative-overflow regressions, plus 49 portable JSONHTML functions.
Both inner and outer exact expectations now require those bundles. The 173
parameter cases and all 49 baseline cap probes remain unchanged.

The existing 13-function WASI public consumer gains one meaningful Swift Testing
function covering six portable checks: exact static HTML, complete interactive
CSP bytes, native/text/Markdown/HTML/styled RTF preparation, finite HTML exhaustion,
deterministically canceled preparation and the explicit unavailable PDF boundary.
Both Node and WasmKit execute these checks; Apple transfer/PDF functionality is
never inferred from portable rendering. The complete debug/release root suites,
independent corpus policy accounting and frozen rooted consumer remain required.

## Open integrated gates

The final receiving/platform ledger records which Mac and simulator drag/share/
reader interactions actually executed. Undelivered automation gestures do not
count as passes; manual observations are identified as such. Physical iPad
qualification retains the maintainer's existing deferral.

JH20/JH21 diagnostic annotations and coherent JSONDocument source-location input
remain unimplemented in the renderer. Their associated annotation accounting and
full renderer/release gates remain open. This qualification pass does not turn
those absent APIs into evaluated successes or make the complete 1.3 release ready.
Affected native/safety/docs/browser and portable checks must be bound to the
final feature source. No merge, tag, publication, protection change or parallel
checkout modification is performed.
