# JSONHTML browser qualification closure

This increment preserves the formatted and interactive implementation history.
The feature integrates upstream main `25fb04f747e583209b4c4511abf39e11ef5b4f80`
through merge `e6bca54`; the original interactive implementation remains
`d1f63624a92966ee5d1b91182dcbcdd8dacc401a`. Main and the sibling worktree were
not edited. Integration resolves CI conflicts by preserving both WASI and browser
lanes, five products, exact discovery counts and all 49 baseline metric probes.

## Firefox and the automated matrix

Pinned Playwright 1.62.1 uses Chromium 151.0.7922.34, WebKit 26.5 and Firefox
153.0. The 37 required cases passed: 13/12/12, with zero skips. Release-native
fixtures cover eight documents and exact JSON bytes. Final-source lane receipts
record source identities, fixture hashes, versions, assertions and actual exits.

On macOS 27, Firefox receives an invocation-owned temporary `MOZ_APP_DATA`
directory in addition to Playwright's disposable profile. This follows the
[Mozilla app-data isolation workaround](https://bugzilla.mozilla.org/show_bug.cgi?id=2069536).
No browser signing, sandbox preference, personal profile permission or HOME value
is changed. Direct launches previously failed; that failed evidence is preserved.
The owned application-data directory is removed after browser closure.

Firefox can attempt its automatic favicon from its internal
`resource:///modules/FaviconLoader.sys.mjs`. The document's `default-src 'none'`
correctly denies the test server's `/favicon.ico`. These precise console messages
and matching `img-src` violation events are recorded as `browserPolicyEvents`.
They are not silently discarded or reported as zero total CSP events. All other
console/page errors, CSP violations and external requests fail the case. This
classification requires the internal module, exact local favicon URL and denied
directive; it does not relax the generated document's CSP.

Chromium supplies screenshots and print PDF evidence. Playwright WebKit is not
native Safari. Its screenshot synchronization stylesheet is prohibited by CSP;
its DOM/layout/interaction tests run without that screenshot hook. Automated
viewport tests do not qualify physical devices or VoiceOver announcements.

## Native Safari and VoiceOver

Native Safari 27.0 (22625.1.29.11.24), macOS 27 arm64, uses the same exact fixture
bytes. Observed served-page checks include ready controls, exact preserved number
spellings and scalar-distinct keys; collapse reports four containers; selecting
Level 2 opens ancestors and focuses its container; the 15-digit search remains
focused and finds one value; selecting the result focuses that value. Copy JSON
reports awaited browser acceptance. Saved UTF-8 JSON is exactly 181 bytes, SHA-256
`9fc1eeffbcd7adf39e11dae20805b5d79cf17842e786ea12526252490cf2e088`.
The 10-byte Pointer download includes NUL/CR/LF and has SHA-256
`35ebf28bfdfc5b2ca6fa66b68bd285de39ca485bb162e83b1c52e8e6a233a15e`.
Clipboard acceptance is not a guarantee about receiving application transforms.

VoiceOver was enabled only with explicit maintainer authorization. Its first-run
welcome needed completion before the runtime started. Automation could inspect
Safari accessibility and focus, but the VoiceOver caption/rotor interface timed
out. After restoring it off, the maintainer performed the real manual check and
reported all four checks passed: labeled controls and expanded/collapsed summary
states; announced destinations after outline/search selection; search/copy/collapse
status announcements; no keyboard trap. The maintainer confirmed VoiceOver off
afterward. These are maintainer-observed speech/navigation results, not automated
caption assertions, a physical-mobile result or an exhaustive accessibility audit.

## Script-disabled correction and print evidence

Native Safari discovered that Pointer action buttons remained visible when
JavaScript was disabled. The fixed CSS hides them until the original script
installs handlers and marks enhancement active. The automated matrix now asserts
Pointer-action visibility in every applicable case, alongside toolbar visibility;
its 37-case cardinality is unchanged. Updated mirrors preserve exact CSP hashes.
Native Safari directly opened the corrected file: disclosures and explanatory
noscript text remain; unavailable toolbar/Pointer actions are absent. Restoring
JavaScript and reloading restores enhanced controls. The original enabled
JavaScript preference was restored; VoiceOver remains off.

Safari's actual collapsed-tree print PDF was saved and independently inspected:
one A4 page, all values including the last null and exact number spellings,
no toolbar clutter, readable highlighted text without clipping. Its 10,937 bytes
have SHA-256 `b9edd3ae158ee468881f6fcd3cd702d55aa920adf84feac029f27d2d36a59e2a`.
This is Safari print evidence, not implementation of the future PDF preparation
API. PDF text extraction renders the combining-key glyph as its composed form;
it is not evidence of lossless PDF scalar round-trip. Exact JSON/Pointer downloads
are checked separately. These print/manual speech observations preceded the
no-script visibility fix; their normal-script layout/content/labels are unchanged.
The corrected Safari no-script and enhancement-restoration checks follow it.

## Integrated test discovery

The WASI parent adds three JSON functions: `retiredWorkOverflowIsAtomicAndTerminal`,
`capacityAndUInt64QuotaConfigurationBoundariesRemainDistinct` and
`UInt64QuotasCrossIntBoundaryWithoutNarrowingOrReset`. The inherited CI count
expectation remained 104, so the first combined native lane rejected a successful
Swift test exit: actual JSON 107 versus expected 104. Its failed receipt remains.
The feature corrects only this exact expectation: six bundles are 107 JSON,
51 schema, 14 regex, 12 streaming, 11 patch and 25 HTML, total **220**; the existing
173 parameter invocations and all 49 cap probes remain required. No tests are
removed, skipped, weakened or replaced with a nonzero/exit-only discovery check.

## Evidence scope

Native/safety/docs/browser lanes refresh after the source commit. Any failing lane
remains open. Materialized receipts, screenshots, fixtures and reproduction bytes
are outside public Git. Existing sealed increment archives remain immutable.
Annotations, transfer/RTF/PDF product preparation, final mobile/portable five-product
qualification and measured final release profiles remain separate later gates.
No PR merge, release tag or publication is performed by this increment.
