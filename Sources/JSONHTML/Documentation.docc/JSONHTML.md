# ``JSONHTML``

Complete, exact, highlighted JSON in a standalone HTML document.

``JSONHTMLRenderer`` uses the strict JSON writer's token cursor. The expanded
body preserves insertion order, decoded Unicode scalar sequences and original
numeric lexemes. Constructed numbers use exact normalized decimal spelling.
JSON escaping precedes HTML escaping; input never becomes markup or script.

The 1.3 development API provides formatted mode and an explicit interactive mode.
Interactive documents use native disclosures plus fixed offline controls for outline
navigation, literal search, exact JSON/Pointer copy and UTF-8 downloads. A separate
complete formatted block serves printing independently of collapsed state.
Annotations, transfer conformance, RTF and PDF preparation remain later increments.

Every call owns one cumulative finite core budget through admission, token
formatting, escaping, fixed assets and metadata emission and final Data or String copying. The
HTML-specific capacities are additional inclusive ceilings. They do not promise
browser heap, browser instruction quotas, process RSS or printing behavior.

## Topics

### Guide

- <doc:FormattedRendering>
- <doc:InteractiveRendering>

### Rendering

- ``JSONHTMLRenderer``
- ``JSONHTMLRenderingOptions``
- ``JSONHTMLTheme``
- ``JSONHTMLPresentation``

### Limits and reports

- ``JSONHTMLLimits``
- ``JSONHTMLRenderReport``
- ``JSONHTMLStatistics``
- ``JSONHTMLResourceMetric``
- ``JSONHTMLFailure``
