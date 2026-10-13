# Interactive JSONHTML increment

Branch `codex/1.3-jsonhtml`; parent implementation head
`41fdf1c5045ef171059981ffcbc59a5aef8f998a`. The original base and first increment
remain recorded in Plan.md and Increment.md. Parallel 1.2 work is untouched.

## Decisions and implemented scope

Interactive rendering is additive and opt-in; formatted remains the default.
The original six-argument options and four-argument limits initializer function
shapes remain callable. All new public declarations and parameters have authored
DocC comments. JSONHTML depends on JSON only; root dependencies remain empty.

Native details/summary supports multiple open branches and works without script.
Root is level zero. Expansion depth is exclusive; outline depth is inclusive;
nil omits the outline. Generated ordinal IDs do not incorporate keys or Pointers.
A typed active path generates RFC 6901 raw and JSON-string-escaped metadata in
Swift. Inert Base64 carries exact copy/download bytes from the same strict cursor,
without JavaScript JSON parsing, serialization, numeric conversion or normalization.

Search is case-sensitive literal matching over rendered JSON key/value text.
It scans in 128-node chunks, counts all matches and lists up to 100 result links
with that display cap disclosed. New queries/actions invalidate queued old scans. Typing preserves query focus;
selecting a result opens, focuses and scrolls to its target.
Invalid queries clear earlier highlights. The UTF-8 query limit is explicit;
zero rejects nonempty queries and configuration is limited to 65,536 bytes.

Clipboard success follows awaited API acceptance. Rejection/absence shows a
manual text area. Clipboard receivers and textareas may transform line endings;
UTF-8 downloads preserve raw Pointer bytes. Download status means requested,
not confirmed saved by a receiving application. A print-only formatted block
includes every value independently of disclosure/search/script state.

One invocation-owned meter covers admission once, all traversals, generated
number scratch, Pointer forms, Base64, outline records, HTML and result copies.
Additional inclusive limits bound outline entries and emitted Base64 bytes.
DOM reservations include possible dynamic search nodes. Limits remain finite
initial policy; logical retained bytes are not RSS and chunking is not a browser
instruction, heap or CPU quota. Original 49 metric meanings/probes are preserved.
Fixed original JS/CSS sources are excluded from target compilation and mirrored
into Swift; Scripts/verify_html_assets.py verifies exact bytes and CSP hashes.

## Verification and remaining qualification

Native: macOS 27 arm64, Xcode/SDK 27.2, Swift 6.4, language 6. Expected discovery is
217 root Swift Testing functions across six bundles, 173 parameter cases, 49 cap
probes and seven shared-state functions (including both HTML presentations).
The external public consumer demonstrates interactive accounting and exhaustion.
README examples compile; five DocC catalogues cover all authored declarations.

Run Scripts/ci.py with lanes native, safety, docs and browser. Final-source receipts
and the reproduction archive are materialized separately from public Git records.
The optional browser lane verifies two assets and eight native fixtures, then
requires 37 cases across pinned Chromium, Firefox and WebKit. Missing engines
remain blocked and unexecuted cases are reported separately, never passed/skipped.
Playwright 1.62.1 is qualification-only; notices are retained without introducing a
root dependency. Source, engine versions, hashes, commands and exits belong to
actual receipts. The first browser run corrected a test expectation from short
CR/LF escapes to the strict writer's established Unicode escape spelling.

Screenshot review corrected the desktop columns so the JSON tree receives the
main width and the outline is a sidebar. Supported viewports are desktop 1440×1000
and mobile 390×844. Native Safari, VoiceOver, physical browser/device tests and the
final Linux/WASI 1.2 base/platform integration remain open. The local pinned Firefox
startup probe failed with sandbox-extension/graphics errors and timed out in both
headless and windowed modes; do not claim its unexecuted matrix passed.

Annotations/source locations, transfer/RTF/PDF preparation and measured final
presets remain future increments. Existing release/performance history and the
10% review trigger are unchanged. No PR merge, tag or publication is performed.

Chromium supplies desktop/mobile screenshots. Playwright WebKit screenshot
synchronization injects a `body {}` stylesheet, which the document correctly blocks;
WebKit therefore uses DOM/layout/interaction checks without that screenshot hook.
CSP and console assertions remain enforced, and no unsafe-inline bypass is added.

## Subsequent browser closure

See [BrowserQualification.md](BrowserQualification.md) for the isolated Firefox solution, all 37 executed browser cases, native Safari and maintainer-observed VoiceOver results. The original failed/unexecuted evidence above remains historical. WASI main is integrated on the feature branch only; final-source native/safety/docs/browser receipts refresh for the combined source.
