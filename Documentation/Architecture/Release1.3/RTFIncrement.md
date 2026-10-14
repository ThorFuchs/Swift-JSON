# Styled RTF prepared-export increment

This work continues `codex/1.3-jsonhtml-transfer` from `6f1c6ebe442bd51119ca0486b78bf9d90da561ba`,
stacked on renderer `3c1e8a1a1bc8d03699665b8ab98f5ece7962aff7` / draft PR #21.
Draft PR #22 retains its base and existing history. Parallel work and release
ownership remain unchanged. No merge, tag, publication or protection change occurs.

The [export contract](../JSONHTMLExport.md) and [DocC guide](../../../Sources/JSONHTML/Documentation.docc/PreparedExport.md)
describe explicit `.rtf` preparation. Public methods are unchanged; finite
`maxRTFStyleRuns` and `maxRTFUTF16Units` are appended defaulted initializer arguments.
Direct JSON transfer and prepared defaults remain the four baseline formats.
Prepared RTF is export-only and guarded by immutable selection.

Five portable Swift Testing functions exercise escaping, inclusive caps, composed
budgets, terminal failure and cancellation during encoding. One Apple native
function independently verifies exact decoded bytes/scalars/lexemes/order, all six
root kinds, font/colors, UTF-16 ranges and actual tab positions. The existing
16-task shared export test now also includes RTF and remains in the TSAN filter.
Exact export discovery is 22 functions on Mac, root discovery 242 with the unchanged
173 parameter cases; Linux root discovery is 239. The original 49 metric probes,
independent suites and policy exclusions remain required.

The independent public consumer preserves the original 35 outcomes and adds ten
RTF outcomes (45 total), emits five artifacts, and checks one admission, cumulative
work/retention, native text/styles, selected transfer and system filename bytes.
Three supported SDKs compile all five products. Optional isolated iPhone/iPad
simulator runs qualify UIKit decoding separately; physical devices and rich-editor
UI remain explicitly unqualified for this increment.

Required source-bound receipts: native, safety, docs and export CI lanes, optional
RTF simulator receipt, clean archive reconstruction and separate source review.
Materialized logs and artifacts stay outside Git. Any failed/pending receipt keeps
its gate open; this plan is not a substitute for actual outcomes. Previous
immutable source and delivery archives remain preserved. PDF remains a distinct
backend/pagination/lifecycle milestone, with no public preparation API added here.
