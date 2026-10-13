# Browser qualification

The public fixture generator imports JSON and JSONHTML only and writes eight
complete HTML documents, exact native JSON bytes and cumulative resource counts.
The root package still has no external dependencies. Playwright 1.62.1 is a pinned
qualification tool; install it in this directory and install its Chromium,
Firefox and WebKit browsers. Alternatively set `JSONHTML_NODE` to an available
Node executable and `PLAYWRIGHT_MODULE` to the installed pinned package.

Run `Scripts/ci.py --lane browser` with the supported native toolchain selected.
The lane verifies fixed asset hashes, generates release-native fixtures and runs
37 explicitly discovered browser cases. Missing browsers fail rather than becoming
skipped passes. Receipts include engine versions, fixture hashes, DOM observations,
console/CSP/network errors, screenshots and a Chromium print PDF.

The cases exercise file and local HTTP documents, native keyboard disclosures with
and without scripting, outline navigation, literal search and capped results,
exact downloads, clipboard acceptance/rejection, Pointer controls and scalar
identity, hostile input, mobile viewports and complete print content. Clipboard
seams qualify UI outcome handling separately from the Chromium clipboard test.
Textareas can normalize line endings; exact UTF-8 Pointer downloads remain the
byte-preserving path. WebKit is not a native Safari result, mobile viewports are
not device qualification, and VoiceOver remains a separate manual release gate.

Chromium supplies desktop/mobile screenshots. Playwright WebKit screenshot
synchronization injects a `body {}` stylesheet, which the document correctly blocks;
WebKit therefore uses DOM/layout/interaction checks without that screenshot hook.
CSP and console assertions remain enforced, and no unsafe-inline bypass is added.

On macOS, the harness gives Firefox a disposable `MOZ_APP_DATA` directory to avoid personal app-data access (Mozilla bug 2069536). Sandbox defaults remain intact. Internal automatic-favicon denials and their exact matching CSP events are retained separately in `browserPolicyEvents`; other errors/violations still fail. See [browser qualification closure](../../Documentation/Architecture/Release1.3/BrowserQualification.md).
