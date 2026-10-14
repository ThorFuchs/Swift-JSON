# Explicit PDF prepared-export increment

This increment continues `codex/1.3-jsonhtml-transfer` from
`703b117c34703292dab26a0420da85d259ba22e2`, stacked on renderer
`3c1e8a1a1bc8d03699665b8ab98f5ece7962aff7` / draft PR #21. Draft PR #22 remains
focused on prepared exports. Parallel branches, main, protection and release
ownership are preserved. Previous immutable RTF candidates remain valid parents.

## Decisions and observed compiler shapes

`@MainActor JSONExportDocument.preparingPDF(options:) async throws` returns a new
immutable document; `preparingPDFWithReport(options:)` returns
`JSONPDFPreparationReport`. `JSONPDFOptions`, `JSONPDFLimits`, `JSONPDFPaper`,
`JSONPDFLayout`, `JSONPDFFailure` and `JSONPDFResourceMetric` are portable public
value types. PDF generation is conditional Apple functionality; pure preparation
and direct JSON transfer keep their four defaults. The selected `.pdf` transfer
closure performs only artifact lookup. No root or arbitrary artifact injection
API is introduced. See the [PDF guide](../../../Sources/JSONHTML/Documentation.docc/PDFPreparation.md).

WebPage remains the preferred nonpersistent/offline HTML loader and continuous
region backend. The initial line-region composition passed unwrapped rows but the
broader wrapped-row test exposed duplicated searchable text at page boundaries.
That strategy is rejected for pagination. An AppKit print spike failed its external
45-second watchdog and left incomplete output; no pagination claim is inferred.
Actual `NSPrintInfo` compilation required the documented dictionary attribute
instead of the proposed nonexistent `jobSavingURL` property.

The selected paginated backend reads bounded syntax runs from the item's own static
HTML using fixed client-world code, then uses CoreText visible UTF-16 ranges and
CoreGraphics page composition. The independent CoreText spike produced seven pages,
all 150 wrapped markers exactly once and a final-page sentinel. The production
behavior suite then passed A4/Letter, wide strings and zero/144-point margins.
The full native lanes and supported-SDK/runtime receipts must qualify the final
source separately; these initial observations do not replace them.

The print profile is A4 by default, Letter explicit, 36-point equal margins,
Menlo 11, 16-point line height, character wrapping, white paper and light syntax
colors. Actual prepared tab width is preserved via finite 6.6-point tab intervals.
No title/header/footer/UI is emitted. Continuous output is explicit and bounded to
14,400 total points. Native PDF text extraction can normalize combining sequences
or omit emoji; the exact native JSON artifact remains the interchange authority.

## Accounting and lifecycle

One PDF-phase noncopyable meter cumulatively admits input, original hidden bundle,
fixed-script/adapter work, text reservations, intermediate pages, final PDF and
immutable copies. No meter crosses actors. Original export representation/bundle
caps also apply. Core balanced defaults and all 49 baseline metrics remain intact.
Additional PDF caps: HTML/intermediate-page/final bytes each 8 MiB, final bundle
16 MiB, pages 64, content height 14,400 points. The soft deadline is 30 seconds
(default), at most ten minutes. Zero forbids usage and arithmetic is checked.

Native SDK instructions and allocation are opaque and not covered by owned-work
or hard RSS caps. Native byte buffers are checked after return. Owned logical text
reservations include source and attributed text; they are not allocator measurements.
Cancellation/deadline use a terminal latch, invocation-only stop/detach, immediate
cancellation-state signalling and unstructured workers. No uncooperative loser is
awaited; late completions cannot install output. Native work or main-actor scheduling
can delay observation or outlive return. Concurrent jobs share no page/layout/meter.

## Acceptance and exact discovery

TX38–TX47 map to `PDFExportTests.swift`, the independent public consumer and
materialized native/export/safety/docs/SDK/runtime/PDF-inspection receipts. Fifteen
Mac behavior functions are added (five portable Linux functions); root discovery
is 257 on Mac and 244 on Linux. Export discovery is exactly 37 on Mac. The TSAN
filter includes the concurrent PDF cancellation case (nine Mac shared functions;
eight on Linux). The unchanged 173 parameter cases and 49 cap probes remain required.
Native PDF test functions use a serialized Swift Testing suite to avoid overlapping
MainActor browser fixtures; explicit independent concurrent-job behavior stays tested.

The five-product public consumer preserves its prior 45 outcomes and adds 18 PDF
outcomes (63 total). It emits eight artifacts including A4, Letter and continuous
PDF, independently inspects geometry, all wrapped markers and final sentinels,
and verifies selected transfer/system filename bytes and public cumulative reports.
Native SDK builds and iPhone/iPad simulator outcomes are separate from physical
mobile devices and actual receiving-app share/drag/drop UI. Those gates remain open.

Final exact-source receipts, source archive/digest, clean reconstruction and review
findings are supplied in the private manifest-backed increment return. Failed
experiments and their outputs/logs are retained there, outside public Git/source.
This document is an implementation/acceptance map, not a substitute for receipts.
