# 1.3 implementation review and qualification

The renderer, native preparation, styled RTF, explicit Apple PDF and typed diagnostic
slices are implemented and qualified in the representative scope below. The
reviewed implementation is `2872afee29ba65905a16653eee8ea4f3807e14e5`. Renderer
[PR #21](https://github.com/ThorFuchs/Swift-JSON/pull/21) merged as
`d463d0418e0fc201229ae38af6464e56311f6e11`; the child-only commits in
[PR #22](https://github.com/ThorFuchs/Swift-JSON/pull/22) were transplanted onto
that identical renderer tree without changing any source bytes. Documentation
corrections are a separately checked successor. Required checks and review-thread
resolution must pass on its actual final head before merge. The maintainer's
2026-10-14 authorization permits the protected stack merge; tagging and release
publication remain separate.

## Review findings

A separate source-and-contract review covered the shared writer cursor and original
initializer function type; exact typed/scalar identity; HTML/RTF escaping, fixed CSP
and offline navigation; cumulative admission/output/retention; cancellation and
late PDF results; immutable selection/transfer filenames; conditional framework
placement; consumers, independent fixtures and exact test discovery. No unresolved
code defect was found. This is an agent source review, not a claim of an independent
second reviewer or a GitHub approving review. Effective main rules require zero
approvals, resolved threads and strict Native / native, Native / safety and
Native / docs checks; bypass actors are empty. No protection was changed.

Three documentation findings were corrected: README incorrectly called annotations
deferred; current CI/export inventory retained old counts; and the acceptance/progress
headers retained earlier not_run/partial states after the corresponding source-bound
passes. Historical records and their original limitations are preserved. The 84-row
acceptance ledger records implementation qualification; it does not substitute for
live required checks, certify every receiving app or publish a release.

## Source-bound evidence

The materialized source archive SHA-256 is
`36b21a3805d0b187d77bbe4bd173443e963ced4fd00c700f7c681ee2790cd44a`:
886 source files plus its manifest. Clean extraction/build/test, two byte-identical
normalized archives and exact final-source bindings were verified. The diagnostic
qualification envelope SHA-256 is
`f587fbeab66ef5f43eaa9d20057dc80fcc08bfa1c3dd0266f28345fd610b21fd`.
The receiving/accessibility closure envelope is 57,927,484 bytes, SHA-256
`cc9720209057ed6e8d6aa5cf979f97b5853d541f37f8377f942df6d699b9d586`.
It includes the actual source and parent envelopes, new receipts/logs and artifacts.
A separate recursive audit verified all three envelope manifests, 844 scoped log
references, 1,552 historical aliases and three unique source-archive manifests.
Private device records and build products remain outside public Git/source archives.

| Area | Executed evidence |
| --- | --- |
| Mac behavior | Native debug/release 270 functions and 173 parameter invocations; all 49 cap probes and the explicitly rooted 20-outcome public consumer |
| Safety | ASAN 270/173; ten shared/concurrent functions under TSAN; strict-memory-safety build with warnings as errors |
| Independent inputs | Syntax 318 observed = 287 evaluated successes + 31 policy exclusions; schema 2,337 = 2,300 successes + 37 exclusions; authored semantics 82, budget boundaries 9, malformed replay 4,396 |
| Export | 38 focused debug/release functions; 65 public consumer outcomes and eight artifacts; macOS, iPhoneOS and iPhoneSimulator SDK 27.2 compiler/consumer builds |
| Actual runtimes | The same 65 outcomes/eight artifacts executed on Mac, physical iPhone 14 Pro Max iOS 27.2, iPhone simulator and iPad simulator iOS/iPadOS 27.0; these are not 260 distinct behavior cases |
| Browsers | 46 cases across pinned Chromium/Firefox/WebKit, zero skips; native Safari 27.0 navigation/file/print checks remain separately recorded |
| Portable | Linux ARM64/x86-64 native/safety passed; Node debug/release 256 functions/173 parameters; 71 WASI commands. WasmKit remains limited to its recorded 14-function public consumer/probes/command parity scope |
| Documentation | Five compiled DocC catalogues, 771/771 authored declarations and 13 executable README fences; affected documentation is refreshed for the correction |

Commands, exits, exact input/source/asset hashes and environment are in the receipts,
not inferred from summaries. Native tools were Apple Swift 6.4, language mode 6,
Xcode/SDK 27.2 on macOS 27.0 ARM64. Required Native and supporting Linux checks
passed on the reviewed source; final-head checks must be read again after integration.
Policy exclusions are not evaluated successes; ordinary schema invalidity remains
distinct from operational failure. Historical W/G/RC/F/J and failed probes remain
intact in their original scope.

## Actual receiving and accessibility closure

Three Mac drags delivered callbacks with exact comparisons: native JSON to the typed
JSON reader, Markdown to its subtype reader and Markdown to a generic String reader.
Earlier automation gestures delivered no event and were not counted as successes.
Mac plain TextEdit paste/save retained all 105 UTF-8 bytes. Rich RTF paste/save retained
font/colors, but TextEdit's rich save canonicalized a decomposed key; emitted/native-
decoded RTF is separately exact. Native JSON is the interchange authority. HTML rich
paste and standalone opening were observed independently.

Fresh physical iPhone Share PDF offered `A4.pdf` without editing; the maintainer
confirmed local Files save/reopen, seven pages and the final LAST-CONTENT-SENTINEL.
The iPad simulator's actual Files-saved `A4.pdf` matched prepared bytes exactly and
independently decoded as seven pages with the sentinel. After Device Hub automation
stalled, the maintainer confirmed actual Files reopening. These manual observations
are separate from generated-file decode and automated API outcomes. Physical iPad
retains the approved simulator-only qualification policy.

Native Safari's new annotated fixture opened nested target ancestors and focused the
exact value; missing targets focused the existing parent with the full missing path.
The script-free formatted fixture retained complete data and explicit value/parent
anchors. The maintainer reported all four interactive diagnostic VoiceOver checks
passed: labeled controls/disclosure states, nested value/diagnostic announcement,
missing-parent/path announcement, status/no keyboard trap. VoiceOver's runtime was
absent afterward. Audible speech is human-reported, not inferred from AX or Playwright;
formatted speech and exhaustive accessibility certification are outside this check.
Earlier no-script/print/manual navigation results remain source-bound history.

## Representative calibration and finite policy

Eighteen release-native observations cover six deterministic workloads. Median
rendering was 44.693 ms for 5,000-member formatted output and 71.459 ms for a
1,000-member interactive object with 128 coherent mapped diagnostics. The latter
emitted 980,689 bytes, charged 4,202,193 owned work units and peaked at 1,961,378
logical retained bytes. Default 128 diagnostics passed; 129 refused.

The review added 54 browser observations: the same six frozen HTML workloads,
three fresh contexts each in Chromium 151.0.7922.34, WebKit 26.5 and Firefox 153.0.
The Browser plugin was unavailable; the existing pinned Playwright 1.62.1 runtime
was reused. All loads, actual DOM bounds, expansion/collapse and literal-search
completion/focus checks passed with no unexpected request or script error.
5,000-member formatted output had 50,020 actual DOM nodes against a 120,032 bound;
the 128-mapped-diagnostic object had 29,128 against 64,512. Median load/DOM times
for that annotated object were 114.160, 223.408 and 232.024 ms respectively; median
search completion was 44.130, 110.151 and 66.949 ms. Public consumer receipts separately
record native preparation/RTF/PDF expansion and elapsed platform work, including the
physical representative seven-page export and historical background soft deadlines.

These observations support the retained finite initial profiles in their measured
representative scope. They do not guarantee maximum-workload throughput, idle A/B,
hard RSS, physical responsiveness or browser/SDK/caller instruction quotas. Logical
retention and owned work remain separate. No profile, deadline, 49-metric meaning,
private optimization or 10% review trigger changed. Historical streaming and schema
performance dispositions remain retained, not relabeled as new idle-host passes.
