# Explicit PDF preparation

Prepare complete PDF bytes before offering them to the transfer system.

```swift
import JSON
import JSONHTML

@MainActor func pdfForSharing(_ root: JSON) async throws -> JSONExportDocument {
    let prepared = try JSONExportDocument.prepare(root)
    let report = try await prepared.preparingPDFWithReport(options: .init(
        paper: .usLetter, marginPoints: 36
    ))
    return try report.result.selecting([.pdf])
}
```

This second operation consumes only the item's own prepared, expanded, script-free
HTML. It does not retain or reformat the source JSON, accept arbitrary HTML, or use
an interactive document. Missing HTML fails. Pure synchronous preparation still
rejects `.pdf`; direct JSON transfer retains its four fixed defaults. Transfer
closures look up completed selected bytes and never start WebKit or mutate caches.
Success returns a new immutable item; failure leaves the original unchanged.

The supported Apple backend uses per-job nonpersistent WebPage state with content
JavaScript and subresources disabled, sensors denied and external navigation refused.
Fixed client-world code awaits `document.fonts.ready`, applies the trusted print
profile and reads only bounded syntax runs. Paginated output uses CoreText visible
text ranges and CoreGraphics page composition. It never clips one long inline span
across multiple regions: that prototype duplicated searchable text at page edges.

Defaults are genuine A4 pages, equal 36-point margins, local Menlo 11-point text,
16-point lines, character wrapping, white paper and a fixed light syntax palette.
US Letter and margins from zero through 144 points are supported. Actual tabs use
6.6 points per cell times the prepared HTML tab width. There is no title/header,
footer, page number, outline, control or annotation in the PDF. Native font fallback
renders supplementary and bidirectional text. PDF text extraction may normalize
combining sequences or omit emoji; PDF is a presentation format. Use the unchanged
native JSON artifact for exact scalar identity, number lexemes and interchange.

Continuous output must be selected with `layout: .continuous`. It captures one
measured WebPage region at the selected paper's width and makes one tall PDF page.
It is limited to 14,400 total points including margins; it never substitutes for
pagination. Normal paginated pages have the selected physical paper geometry.

Each explicit PDF call has one cumulative noncopyable core meter. It admits HTML,
all existing artifacts including hidden formats, fixed-script/adapter work, native
text reservations, intermediate/final PDF bytes and immutable result copies. It
never resets a nested helper's work. Original representation and aggregate export
caps also constrain the result; replacing an existing PDF does not double its final
bundle count. A report exposes accepted input/capture/output bytes, page count,
backend, elapsed time and public owned-work/logical-retention statistics. PDF performs
no root admission (`nodes == 0`). Caller composition across separate calls remains
the caller's responsibility; no failure report licenses a budget-reset retry.

Default inclusive policy is balanced core limits, 8 MiB HTML, 8 MiB aggregate
intermediate page PDFs, 8 MiB final PDF, 16 MiB final bundle, 64 pages and 14,400
measured content points. Zero forbids usage. The default responsiveness deadline is
30 seconds, with a maximum of ten minutes. These are finite initial policies,
qualified with small and generated wrapped inputs, not hard RSS/throughput limits.
Opaque WebKit/CoreText/CoreGraphics instructions and allocations are outside owned
instruction accounting. Native buffers are size-checked after SDK return; the SDK
can allocate more memory before that check. Logical retention is not process RSS.

Cancellation is checked in owned loops and between native stages/pages. A terminal
latch stops/detaches the invocation, cancels its worker/timer and ignores late native
results. The timeout does not await an uncooperative task-group loser. It is a soft
responsiveness policy: main-actor scheduling or synchronous native SDK work can
delay observation, and platform work can outlive the caller's return. Such work
cannot install a PDF. Concurrent jobs have separate WebPage, layout and meter state.

macOS, iPhoneOS and iPhoneSimulator SDK evidence, simulator runtime outcomes,
independent PDF text/geometry checks and rendered-page inspection are recorded
separately in the materialized increment report. Share-sheet/drag/drop receiving-app
UI and physical-device PDF behavior are distinct, unqualified gates. Linux/WASI
retain pure exports and return `backendUnavailable` for explicit PDF preparation;
no platform fallback renderer or new dependency is introduced.
