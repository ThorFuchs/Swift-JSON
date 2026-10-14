# Formatted rendering

Generate a complete HTML document without executing a browser or UI framework.

```swift
import JSON
import JSONHTML

let value = try JSONParser().parse(#"{"amount":9007199254740993,"note":null}"#)
let renderer = JSONHTMLRenderer(options: .init(layout: .syntax, presentation: .formatted, title: "Exact values"))
let report = try renderer.renderWithReport(value)
let bytes = report.result
let work = report.statistics.operation[.workUnits]
```

The result is a UTF-8 document with inline fixed CSS, syntax highlighting and a
complete expanded body. A hash authorizes the exact CSS block under Content
Security Policy. Scripts, external resources, forms and base URLs are denied.
The renderer accepts plain titles, escapes them and rejects ASCII controls.
It uses system fonts and makes no network request or browser number conversion.

Space indentation defaults to two units. Set `indentationUnit: .tabs` to emit
actual horizontal tabs; `tabWidth` controls visual display independently. Zero
units still produces expanded lines. All roots are supported, including a quoted
string, JSON null and empty containers. The syntax layout is complete and returns no partial success. Structured inspection has labelled prefixes; see <doc:StructuredPreviews>.

Numeric output uses preserved source lexemes where available. Neither browser
floating-point conversion nor semantic equality substitutes for exact output
bytes. Key order and composed/decomposed Unicode scalar sequences remain distinct.

`JSONHTMLLimits.core` controls the one meter used by admission, title checks,
formatting, escaping, assets and final result copying. `outputBytes` counts emitted
HTML bytes; the cursor's intermediate JSON bytes are consumed directly without a
separate JSON buffer. `documentBytes` is the complete HTML size. Copying charges
additional work and overlapping logical retained bytes, but does not double output
bytes. `renderWithReport` and `renderStringWithReport` expose equivalent accounting.

Additional capacities bound rendered JSON values, document bytes and a conservative
DOM node upper bound. The latter reserves 24 nodes for fixed structure and four
per contiguous syntax/whitespace run. It includes parser-created structure but
does not model browser heap. Defaults reuse existing balanced core ceilings as
provisional finite policy. Representative browser calibration remains pending.

Core failures remain `JSONFailure`; additional HTML failures use
``JSONHTMLFailure``. Cancellation remains `CancellationError`. No successful
report or partial document escapes a failure. Mutable state belongs to each
invocation, so an immutable renderer may be shared across tasks.

This API formats values only. A source document can be rendered through its
`root`; it does not imply preservation of source whitespace or source locations.
Browser accessibility, printing and the complete supported-platform matrix need
their separate later qualification. Native transfer and prepared exports, including opt-in styled RTF, are documented
in <doc:PreparedExport>. Explicit asynchronous PDF consumes the prepared artifact; see <doc:PDFPreparation>. See <doc:InteractiveRendering>
for the separately selected interactive presentation.
