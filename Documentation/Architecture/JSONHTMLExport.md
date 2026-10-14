# JSONHTML native transfer and prepared export

This additive 1.3 development increment provides JSON, UTF-8 text, Markdown and
static HTML, plus explicitly requested styled RTF and separately prepared Apple PDF.
Synchronous preparation rejects PDF; only successful explicit async preparation advertises it. Published 1.2 versions do not
provide this API.

`JSONExportDocument.prepare(_:options:)` and
`prepareWithReport(_:options:)` synchronously prepare immutable artifacts without
executing WebKit. No source root, mutable cache, native view or temporary file is
retained. `data(for:)` looks up the exact identifier. `selecting(_:)` changes only
per-item advertisement; hidden artifacts remain retained and available for exact
lookup. Empty or unavailable selections fail. There is no public artifact injection.

Defaults request all four formats, filename stem `JSON`, title `JSON`, one literal
tab per level, LF, light HTML and tab display width four. Indentation is 0...8;
display width is 1...8. `compactJSON` affects native JSON only. Existing writer and
renderer defaults and typed initializer references are unchanged.

Native JSON uses the strict writer/parser, insertion order and preserved numeric
lexemes. Constructed numbers retain the exact normalized fallback. Whitespace and
original string escape spellings are not source-document reconstruction. Decoded
scalar sequences remain distinct; neither Swift String equality nor floating-point
round trips establish fidelity. Text is the pretty JSON body with quoted string
roots. Markdown adds a `json` code fence longer than any backtick run in the body,
using LF before and after the unchanged body and after the closing fence.

HTML is expanded and script-free, with fixed hash-authorized CSS and escaped data.
It includes a bounded escaped title and has no disclosure controls, outline,
annotations, line numbers or hidden values. Default light styling is deterministic.
System fonts and the renderer's offline CSP remain in effect. Standalone file
opening and rich-editor paste compatibility are separate qualification claims.

## Apple transfer boundary

Importing JSONHTML on supported Apple SDKs introduces the package's sole
`JSON: Transferable` conformance. Its declaration needs no `@retroactive` because
the compiler recognizes the same-package ownership exception. Compilation with
warnings as errors and an independent consumer qualify this placement.

Direct representations are JSON, static HTML, UTF-8 plain text, Markdown in that
order. Only JSON imports. Every direct request gets fixed finite defaults and its
own invocation. The prepared wrapper is export-only in JSON, HTML, RTF, text, Markdown, PDF order, with
conditions for available/selected artifacts and matching filename extensions.
Closures additionally guard selection: the SDK's generic-text helper can try a
hidden statically declared representation before reaching the selected subtype.
Conditions alone are insufficient to protect that path. An explicit hidden JSON
request fails; Markdown-only generic text reaches Markdown after hidden candidates
are refused. Prefer explicit format selection when a receiver's choice matters.

CoreTransferable may wrap a parser failure in its transport error. Applications
requiring native structured diagnostics should call JSONParser directly. Transfer
does not add a permissive parser. JSON text import rejects invalid UTF-8, decoded
duplicate keys, trailing syntax and trailing commas under balanced finite limits.

The initial module links CoreTransferable and UniformTypeIdentifiers conditionally.
Pure preparation is actor-independent and remains available without those modules.
The approved future PDF amendment permits narrow WebKit/platform-print support in
JSONHTML, while core JSON must never import those frameworks. WebKit/CoreText/CoreGraphics and AppKit/UIKit paragraph styles
are confined to explicit PDF generation. PDFKit remains independent qualification only. JH25's old
module-wide UI dependency exclusion is superseded by this explicit boundary.

## Finite accounting

One noncopyable JSONWorkMeter admits the root once, then serves cursor formatting,
Markdown scan/wrapping, static HTML, RTF encoding, bounded metadata, artifact tables and result
copies. The HTML helper accepts an already admitted root under that same meter.
Export and HTML core limits intersect before execution; no nested public facade
starts a fresh budget. Checked output growth, cancellation inside owned loops,
copy admission and terminal latching apply throughout. Failure returns no partial
document/report, releases owned scratch and preserves an enclosing reservation.

Initial export policy:

| Capacity | Default inclusive ceiling |
| --- | ---: |
| Core | JSONLimits.balanced, all 49 existing metrics |
| One representation | 8,388,608 bytes |
| All prepared artifacts | 16,777,216 bytes |
| Plain title | 4,096 UTF-8 bytes |
| Filename component | 128 UTF-8 bytes |
| RTF syntax color runs | 1,000,000 per artifact |
| Decoded RTF body | 8,388,608 UTF-16 units per artifact |
| RTF tab positions | Int32.max twips, a format parameter bound |
| HTML | JSONHTMLLimits defaults, document ceiling intersected with representation ceiling |

Zero forbids usage. Allocation capacities must be below Int.max; UInt64.max is
invalid. Checked arithmetic refuses overflow. Title controls are rejected. Filename
components additionally reject empty/dot components, slash, backslash, colon and
bidi controls. No path is derived from the JSON or title. Extensions are fixed.

Each artifact reserves its logical bytes even if Foundation shares actual storage.
Construction buffers coexist with copies and contribute to peak logical retention;
table/report/selection entries reserve 48 logical bytes per format. The report
contains core statistics, per-format bytes and their aggregate. The title is
released after preparation; the bounded filename remains owned. Hidden artifacts
remain in aggregate counts after selection. Logical retained bytes are not RSS;
owned work units are not caller/transport instructions or an elapsed-time deadline.
Separate public calls require caller composition. There is no failure report that
would justify retrying with a fresh budget.

These are initial finite policy values, exercised with pinned small fixtures,
generated deep/wide values and inclusive boundary tests. Measurements do not
establish maximum workload throughput, hard RSS or receiving-app resource bounds.
There is no unlimited or device-specific widening preset.

## Qualification and remaining scope

`Scripts/ci.py --lane export` runs fixed-count debug/release behavior tests and the
independent five-product consumer, verifies all six fixture hashes, compiles
WebPage declarations on macOS/iPhoneOS/iPhoneSimulator and builds the public mobile
consumers. It records actual commands, exits, source manifest and toolchain.
The consumer records 65 outcomes and eight artifacts, including explicit opt-in RTF
and A4, US Letter and continuous PDFs. It tests native import, exact selected exports,
discovery, suggested filenames, immutable selection and cumulative reports.
SDK builds do not establish simulator/device/share-sheet/drag/drop qualification.

The T0 offscreen WebPage probe uses nonpersistent per-job state, disables content
JavaScript/subresources, denies external navigation, awaits finished navigation,
sets print media and captures an explicit region. Independent PDFKit inspection
finds the final sentinel on one tall page. This is region capture, not paginated
A4/Letter output or a qualified cancellation/timeout backend. The current paginated backend is qualified separately; neither its public API
nor paper policy is inferred from the historical T0 result. An external
probe watchdog is not a production timeout guarantee.

The initial receiving/device milestones above are historical. The
[qualification closure](Release1.3/ReviewAndQualification.md) records their actual
source-bound completion, including corrected PDF filenames, delivered drag events
and the approved physical-iPad deferral. SDK builds, automated device outcomes and
manual receiving observations remain separately attributed. Final PR-head checks
are required before a protected merge; tagging and release publication remain separate.

The synthetic fixture bytes originate in the JSONHTML Transfer/Export briefing
ZIP SHA-256 `5394fccbcd48244004e146189f4c764857cb83c05fd8a2a91380ca4f9d752105`.
Their registry pins all six files; no fixture is executable instruction input.
All export implementation and fixed assets are original Apache-2.0 code; upstream
notices remain intact. No third-party renderer or external package is introduced.

## Styled RTF increment

`JSONRTFWriter` is package-only original code. It consumes the existing strict
writer's classified bytes after the single admission. Scalar state is fixed-width;
there is no token-sized buffer, Foundation serialization or native attributed-string
allocation in generation. UTF-8 validation prevents malformed sequences even at
this internal boundary. Unicode is emitted as signed `\uN?` UTF-16 units with
`\uc1`; braces and backslashes are escaped. Actual indentation uses `\tab`, while
JSON string escapes remain visible text. `\par` preserves LF; `\line` failed the
initial independent probe's exact decoded-text requirement.

The fixed Menlo 11-point font has no external asset. RTF always uses a light palette:
punctuation/whitespace RGB 35/40/48, keys 33/75/110, strings 35/111/59, numbers
143/59/16, booleans 106/58/156, null 100/100/100. Native calibrated-color conversion
is compared in a common color space. HTML theme selection is independent. Each
paragraph gets explicit tab stops for every actual indentation tab, at 132 twips
per display cell times `tabWidth`; native AppKit decoding ignored `deftab` for its
default interval. No arbitrary HTML import, attachment or executable link occurs.
Receiver font/color substitution remains outside byte-export fidelity.

Style runs count the initial color and every emitted color change; decoded UTF-16
units include syntax, whitespace and supplementary pairs. Both counters are checked
before emission. Output buffers, wrapping, tab parameters and final result copies
remain charged to the shared meter. New counters do not replace or widen any of
the 49 core metrics. Failure/cancellation latches and releases scratch while
preserving an outer reservation. RTF is export-only and offered only when present
and selected, with a guarded `.rtf` transfer closure and `.rtf` filename.

The initial finite policies are boundary-tested rather than hard RSS/throughput
claims. Small exact fixtures and generated deep/wide/cancellation inputs support
this increment; maximum-workload calibration and receiving-app qualification
remain distinct release evidence. See [RTF increment](Release1.3/RTFIncrement.md).

## Explicit PDF increment

See the [PDF decisions and acceptance map](Release1.3/PDFIncrement.md) and
[DocC guide](../../Sources/JSONHTML/Documentation.docc/PDFPreparation.md).
The new public async MainActor methods use only the document-owned static HTML.
Paginated CoreText visible ranges avoid duplicated text from clipped WebPage regions;
continuous WebPage capture is explicit. One cumulative PDF-phase core meter and
six finite PDF caps cover owned admission, adapter work, captures and copies.
Opaque platform work/allocation and the soft lifecycle deadline are distinct.
Only completed immutable PDF bytes can be selected for transfer. Missing HTML,
failures and cancellation preserve the original item and install no artifact.
