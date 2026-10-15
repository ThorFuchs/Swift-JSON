# ``JSONHTML``

Exact JSON as structured forms/cards or highlighted syntax in a standalone HTML document.

``JSONHTMLRenderer`` defaults to interactive structured inspection since 1.6.0.
Object fields, indexed arrays, scalar previews and native disclosures retain
insertion order, decoded Unicode scalar identity and exact numeric lexemes. An
explicit syntax layout uses the shared strict writer's token cursor. Generated
markup is owned and allowlisted; arbitrary input is escaped, never trusted as HTML.

Inspection prefixes are labelled, and full originals/source remain accessible
without JavaScript. Finite color, declared raster, inline formatting and atomic
mini-math previews preserve unsupported spans literally. Exact JSON/Pointer copy,
downloads and complete printing use native prepared bytes. See <doc:StructuredPreviews>.
These structured previews extend the renderer released in 1.3.0.

Native JSON transfer and immutable prepared JSON/text/Markdown/static HTML,
opt-in styled RTF and explicit main-actor PDF preparation are available since
1.3.0. PDF consumes prepared static HTML; typed caller annotations attach to exact
values or explicitly missing targets at their nearest existing parent. Coherent
JSONDocument input adds original byte spans. See <doc:PreparedExport> for format
selection, native text fidelity and finite capacities.

Every call owns one cumulative finite core budget through admission, token
formatting, escaping, fixed assets and metadata emission and final Data or String copying. The
HTML-specific capacities are additional inclusive ceilings. They do not promise
browser heap, browser instruction quotas, process RSS or printing behavior.

## Topics

### Guide

- <doc:StructuredPreviews>
- <doc:FormattedRendering>
- <doc:InteractiveRendering>
- <doc:DiagnosticAnnotations>
- <doc:PreparedExport>
- <doc:PDFPreparation>

### Rendering

- ``JSONHTMLRenderer``
- ``JSONHTMLRenderingOptions``
- ``JSONHTMLTheme``
- ``JSONHTMLPresentation``
- ``JSONHTMLAnnotation``

### Limits and reports

- ``JSONHTMLLimits``
- ``JSONHTMLRenderReport``
- ``JSONHTMLStatistics``
- ``JSONHTMLResourceMetric``
- ``JSONHTMLFailure``

### Prepared native export

- ``JSONExportDocument``
- ``JSONExportOptions``
- ``JSONExportFormat``
- ``JSONExportLimits``
- ``JSONExportReport``
- ``JSONExportResourceMetric``
- ``JSONExportFailure``

### Explicit Apple PDF preparation

- ``JSONPDFOptions``
- ``JSONPDFLimits``
- ``JSONPDFPaper``
- ``JSONPDFLayout``
- ``JSONPDFPreparationReport``
- ``JSONPDFResourceMetric``
- ``JSONPDFFailure``
