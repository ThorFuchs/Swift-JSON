# Prepared export and Apple transfer

Prepare exact JSON, pretty UTF-8 text, safely fenced Markdown and expanded static
HTML without executing a browser. Add `.rtf` explicitly for styled monospaced
rich text. Prepare PDF separately with the explicit main-actor operation in <doc:PDFPreparation>.

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

RTF uses the same strict syntax tokens and cumulative meter as other formats.
Its independently decoded body equals pretty JSON, including quoted string roots,
LF, literal indentation tabs, insertion order, exact number lexemes and decoded
scalar sequences. Braces/backslashes are escaped, and supplementary scalars use
signed UTF-16 surrogate pairs. Fixed local Menlo 11-point styling distinguishes
keys, strings, numbers, booleans and null. Explicit paragraph tab stops use 6.6
points per cell times `tabWidth`. RTF always uses a deterministic light palette;
`theme` affects HTML only. A receiver may substitute fonts or convert colors.
No attachment, executable link, external asset or native text renderer is used
in generation. Native decoding is qualification work outside owned quotas.

```swift
let rich = try JSONExportDocument.prepare(root, options: .init(
    formats: [.json, .plainText, .rtf], tabWidth: 4
))
let richTextItem = try rich.selecting([.rtf])
let richTextBytes = try richTextItem.data(for: .rtf)
```

The default inclusive limits are 8 MiB per artifact, 16 MiB aggregate, 4 KiB title,
128 bytes filename, 1,000,000 RTF color runs, 8,388,608 decoded RTF UTF-16 units
and balanced core/HTML limits. Each RTF artifact has its own run/unit ceilings;
all formats share core work/output/retention and aggregate prepared bytes. Tab
positions must fit the RTF signed 32-bit parameter, measured in twips. Zero forbids usage. These initial
policy values are not process or recipient memory/CPU guarantees. Each generated
artifact, overlapping construction buffer and owned copy is charged. Filename
components reject controls, separators, dot components and bidi controls.

The public export consumer exercises API/file transport, native decoding and PDF
geometry/text independently of receiving-app and physical-device behavior. Failed
explicit PDF requests install no artifact and advertise no capability. The original
T0 tall-region probe is historical evidence; it never established pagination.

## Receiving applications

Offer an explicitly selected immutable item to SwiftUI with an explicit preview:

```swift
import SwiftUI
import JSONHTML

@MainActor func sharePrepared(_ item: JSONExportDocument) throws -> some View {
    let selected = try item.selecting([.json])
    return ShareLink("Share JSON", item: selected,
                     preview: SharePreview("Exact offline JSON"))
}
```

Actual Mac ShareLink PDF/Copy bytes matched the prepared PDF. Physical iPhone
share/open checks passed for the representative generated JSON/Markdown/PDF input.
These observations do not promise every receiving app chooses the same format.
Explicit Copy JSON and Copy Markdown routes should select their exact artifacts.

TextEdit plain paste/save preserved the native pretty-body UTF-8 bytes. Its saved
rich RTF retained Menlo 11 and token colors but normalized a decomposed key to
composed Unicode. HTML rich paste also carries the standalone document heading
and follows the receiver's formatting choices. Presentation exports are export-only;
retain native JSON for exact scalar identity and interchange. Native emitted RTF
text/attributes are tested separately from these receiving-editor transformations.
See the [receiving qualification scope](../../../Documentation/Architecture/Release1.3/ReceivingQualification.md).
