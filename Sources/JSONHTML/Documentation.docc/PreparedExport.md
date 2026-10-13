# Prepared export and Apple transfer

Prepare exact JSON, pretty UTF-8 text, safely fenced Markdown and expanded static
HTML without executing a browser. RTF and PDF are not yet qualified artifacts.

```swift
import JSON
import JSONHTML

let root = try JSONParser().parse(#"{"amount":9007199254740993,"state":null}"#)
let report = try JSONExportDocument.prepareWithReport(root)
let markdown = try report.result.selecting([.markdown])
let bytes = try markdown.data(for: .markdown)
let cumulativeWork = report.operation[.workUnits]
```

The immutable item owns complete bytes and bounded filename metadata. Selection
changes advertisement and shares existing buffers; hidden formats remain available
for exact lookup and remain in aggregate accounting. Empty/unavailable selections
fail. Owned generation and result copies use one cumulative finite meter with one
root admission, checked growth and cancellation. Logical retention is not RSS.

Defaults use one literal tab per level, LF and light static HTML. Native JSON and
text share the pretty body; `compactJSON` changes only JSON. Numeric lexemes,
insertion order and decoded scalar sequences are preserved. Original whitespace
and string escape spellings are not reconstructed. Markdown uses a fence longer
than any backtick run, and its body is unchanged. HTML remains script-free and
expanded, with no interactive controls, external assets or hidden JSON values.

On Apple platforms importing JSONHTML enables the package's single JSON Transferable
conformance. Direct JSON, HTML, plain text and Markdown requests use fixed finite
profiles. Only JSON imports; the immutable wrapper is export-only. Prepared transfer
closures guard both advertisement and exact selection and never render PDF or
mutate a shared cache. Generic text subtype negotiation belongs to the system;
select a format explicitly when recipient choice matters. CoreTransferable wraps
some native parser errors; use JSONParser for structured diagnostics.

The default inclusive limits are 8 MiB per artifact, 16 MiB aggregate, 4 KiB title,
128 bytes filename and balanced core/HTML limits. Zero forbids usage. These initial
policy values are not process or recipient memory/CPU guarantees. Each generated
artifact, overlapping construction buffer and owned copy is charged. Filename
components reject controls, separators, dot components and bidi controls.

The public export consumer and SDK builds qualify API/file transport separately
from real receiving-app, simulator and device behavior. WebPage's T0 region probe
produces one tall page and establishes no A4/Letter pagination, public PDF API or
production timeout claim. Styled RTF and explicit MainActor PDF remain separate
milestones; unsupported requests install no artifact and advertise no capability.
