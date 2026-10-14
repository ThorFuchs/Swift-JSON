# Render caller diagnostics and source spans

Attach explicitly supplied diagnostics without running schema validation inside the renderer.

```swift
import Foundation
import JSON
import JSONHTML

let document = try JSONParser().parseDocument(Data(#"{"count":9007199254740993}"#.utf8))
var options = JSONHTMLRenderingOptions(presentation: .interactive)
options.annotations = [
    .init(path: [.key("count")], severity: .information, message: "Exact count"),
    .init(path: [.key("missing"), .index(0)], severity: .error, message: "Required value is absent")
]
let renderer = JSONHTMLRenderer(options: options)
let report = try renderer.renderStringWithReport(document)
precondition(report.statistics.annotations == 2)
```

All four renderer methods accept either a JSON value or a JSONDocument. Configuration
and successful reports are Sendable. Annotations are caller diagnostics, with textual
information/warning/error severities. Empty lists make no claim about schema validity.
A caller importing JSONSchema can translate its issue paths explicitly; JSONHTML still
depends only on JSON and never catches arbitrary errors to render their descriptions.

Paths retain decoded scalar identity and component types. A numeric object key differs
from an array index; composed and decomposed keys remain distinct. Existing values get
stable generated targets and accessible descriptions. Missing values are explicitly
marked missing, with the full attempted typed path and a link to their nearest existing
parent. Out-of-range indices and wrong container kinds are missing targets. Negative
indices are invalid configuration, even after an earlier missing component.

Formatted rendering remains script-free. Its zero-width target anchors do not add text
to formatted JSON; a static caller-diagnostic section follows the complete body.
Interactive diagnostic links use the existing ancestor-opening/focus navigation.
Annotations never enter search, copied JSON, Pointer data or the complete print JSON
block. The separate diagnostic section remains visible in printed output.

Only parser-owned coherent mappings produce source spans. These are zero-based,
half-open original UTF-8 byte intervals for values. Missing targets show the parent's
span, labeled as such, and never an invented child location. Root-only documents and
`replacingRoot` have no mapping, even when the replacement compares equal. Source
labels and original source bytes are not embedded or archived; line/column coordinates
are not inferred from generated formatting.

`maxAnnotations` is an inclusive finite HTML capacity (default 128). Message and key
admission uses core string/key/aggregate text bounds. Their raw UTF-8 bytes and array
index digits also consume cumulative `diagnosticBytes` (balanced default 262,144).
Every complete attempted path uses `pointerTokens` and escaped RFC 6901 `pointerBytes`
capacities. Generated quoted labels, escaping, binding, exact comparisons, source-map
scans, traversal scratch, DOM growth and result copies share the existing invocation
meter. No source-map public facade creates a fresh allowance. Zero forbids the relevant
usage; UInt64.max capacities fail configuration. Existing 49 core metrics retain their
meanings and defaults.

Messages and keys use visible JSON-style quoting with explicit C1 and bidi-control escapes before HTML escaping, so controls such as
NUL, CR and LF cannot disappear through HTML parsing. Payload never enters selectors,
IDs, executable code or raw markup. Profiles bound native owned work and logical
retention, not browser or caller instructions, process RSS or receiver behavior.
Failure/cancellation returns no successful partial result or report.
