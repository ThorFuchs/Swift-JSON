# Structured layout and value previews

Inspect exact JSON as ordered forms, indexed record cards or wrapping scalar lists.
Layout is independent of static or interactive presentation.

```swift
import JSON
import JSONHTML

let value = try JSONParser().parse(#"{"message":"**Hello** $x_i^2$","amount":9007199254740993}"#)
let options = JSONHTMLRenderingOptions(layout: .structured, presentation: .formatted)
let report = try JSONHTMLRenderer(options: options).renderWithReport(value)
```

Direct rendering defaults to structured, interactive inspection. Formatted presentation
is script-free. Prepared exports and direct transfer use structured, static complete
values and light colors. Explicit `.syntax` emits full highlighted native JSON and
runs no preview pipeline. The original initializer function shapes remain available.

Inspection prefixes are labelled and bounded independently by 512 decoded Unicode
scalars, 2048 UTF-8 bytes and 512 escaped-display scalars. A scalar or control escape
is never split. Keys, exact numbers and node structure remain complete. Native
Original value disclosures and the complete JSON pane/source work without JavaScript.
Complete values and the print representation expand full original strings. Derived
inline previews still obey their source-prefix and destination eligibility limits. Copy and
download use native exact writer bytes, not a JavaScript JSON model.

Declare typed paths through ``JSONHTMLPreviewHint``. Literal declarations suppress
inference; explicit hints precede caller-translated effective schema content
annotations. Rendering does not validate schema or treat preview failures as schema
invalidity. Missing/wrong-kind declarations create bounded preview issues without
creating values. Duplicate paths in one tier are invalid configuration.

Native previews support complete sRGB hex/rgb/rgba strings, explicitly unit-labelled
numeric channels and declared canonical PNG/JPEG. Geometry/header/pixel and aggregate
checks precede emission; admission is not a full raster codec or a browser RSS cap.
Remote images, SVG input and arbitrary markup remain unavailable. Channel text makes
swatches understandable independently of color.

The small inline dialect supports star bold/italic, inline links/images and atomic
mini-math. Links are inert unless ``JSONHTMLLinkActivation/httpAndHTTPS`` is explicitly
selected and the absolute destination passes validation. Backticks, fences and
block-looking text remain protected. Mini math emits allowlisted native MathML Core;
unknown, malformed, ambiguous or cutoff expressions remain entirely literal. There
is no document Markdown engine, full TeX engine, browser conversion or external parser.

``JSONHTMLPreviewPolicy`` adds finite eligibility ceilings to unchanged core/HTML
limits. Staging, all duplicate source/print bodies, decoding, assets and result copies
share one invocation meter. Local rejection releases live scratch without refunding
work. Global exhaustion, cancellation and invalid configuration are terminal and
return no partial artifact. ``JSONHTMLStatistics`` separates unique JSON values,
conservative DOM bounds, preview issues and logical raster bytes.

Use <doc:PreparedExport> for immutable transport artifacts and <doc:PDFPreparation>
for the explicit asynchronous Apple backend. It consumes already-prepared bytes,
awaits fonts/images and retains the selected layout. Structured pagination uses
measured line/media whitespace; an unbreakable oversized fragment fails rather than
switching to syntax. Native/browser/font/assistive technology observations are
qualified separately; package budgets do not meter browser or receiver instructions.
