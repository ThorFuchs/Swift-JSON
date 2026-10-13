# ``JSONHTML``

Complete, exact, highlighted JSON in a standalone HTML document.

``JSONHTMLRenderer`` uses the strict JSON writer's token cursor. The expanded
body preserves insertion order, decoded Unicode scalar sequences and original
numeric lexemes. Constructed numbers use exact normalized decimal spelling.
JSON escaping precedes HTML escaping; input never becomes markup or script.

This first 1.3 development increment implements formatted rendering. It contains
no interactive controls, outline, search, annotations, transfer conformance,
RTF or PDF preparation. Those remain planned increments, not available API.

Every call owns one cumulative finite core budget through admission, token
formatting, escaping, fixed CSS emission and final Data or String copying. The
HTML-specific capacities are additional inclusive ceilings. They do not promise
browser heap, browser instruction quotas, process RSS or printing behavior.

## Topics

### Guide

- <doc:FormattedRendering>

### Rendering

- ``JSONHTMLRenderer``
- ``JSONHTMLRenderingOptions``
- ``JSONHTMLTheme``

### Limits and reports

- ``JSONHTMLLimits``
- ``JSONHTMLRenderReport``
- ``JSONHTMLStatistics``
- ``JSONHTMLResourceMetric``
- ``JSONHTMLFailure``
