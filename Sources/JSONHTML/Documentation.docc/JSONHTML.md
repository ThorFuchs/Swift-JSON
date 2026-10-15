# ``JSONHTML``

Complete, exact, highlighted JSON in a standalone HTML document.

``JSONHTMLRenderer`` uses the strict JSON writer's token cursor. The expanded
body preserves insertion order, decoded Unicode scalar sequences and original
numeric lexemes. Constructed numbers use exact normalized decimal spelling.
JSON escaping precedes HTML escaping; input never becomes markup or script.

The API released in 1.3.0 provides formatted mode and an explicit interactive mode.
Interactive documents use native disclosures plus fixed offline controls for outline
navigation, literal search, exact JSON/Pointer copy and UTF-8 downloads. A separate
complete formatted block serves printing independently of collapsed state.
Native JSON transfer and immutable prepared JSON/text/Markdown/static HTML are
available since 1.3.0, with opt-in styled RTF for prepared items.
Explicit main-actor PDF preparation uses the item’s own static HTML. Typed caller annotations attach to exact values or explicitly missing targets at their nearest existing parent. Coherent JSONDocument input adds original byte spans. See <doc:PreparedExport> for format
selection, native text fidelity and finite RTF capacities.

Every call owns one cumulative finite core budget through admission, token
formatting, escaping, fixed assets and metadata emission and final Data or String copying. The
HTML-specific capacities are additional inclusive ceilings. They do not promise
browser heap, browser instruction quotas, process RSS or printing behavior.

## Topics

### Guide

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
