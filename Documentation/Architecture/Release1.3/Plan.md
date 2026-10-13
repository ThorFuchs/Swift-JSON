# Swift-JSON 1.3.0 — JSONHTML and exact export

Status: maintainer-approved release direction; implementation and qualification pending.

1.3.0 introduces **JSONHTML**, a fifth library product in the existing Swift-JSON package. It depends on JSON; JSON does not acquire a reverse dependency. The five-product policy becomes effective with the working target, consumers and matching CI checks. Historical four-product releases remain unchanged. JSONRegexRuntime remains private and root external dependencies remain empty.

The portable product renders complete self-contained HTML from exact values/documents. Its export preparation supplies JSON, plain text, Markdown, static HTML and qualified styled RTF. On supported Apple platforms, JSONHTML also provides CoreTransferable integration and explicit asynchronous PDF preparation. This is one product, not a new repository or a sixth adapter product.

## Release coordination

The 1.2.0 release train owns Linux and WASI work. This feature begins from merged Linux source `532f725740a4d61c32bc9870986d050b71f9db78`, rather than the briefs' captured `e9c6693c7cb29df5125e1699fef70f98229ccfdf`. Before integration, bring the final qualified 1.2.0 source into the feature and rerun affected checks against that exact combined tree. Do not modify the parallel worktree, change release assets or route this feature into 1.2.0.

No 1.3.0 tag, merge or publication is authorized by this plan. A complete release candidate must pass the implementation/qualification gates first.

## Reconciled contracts

The renderer specification supplies H0–H4 and JH01–JH28. The transfer/export specification adds T0–T6 and TX01–TX56. The transfer pack's explicit amendments take precedence where these documents differ; the maintainer assigns the combined scope to 1.3.0.

- Pure renderer/export preparation is synchronous, invocation-owned and callable away from MainActor. Apple transfer/framework declarations are conditional; only PDF/printing platform lifetime is MainActor isolated. Core JSON imports no WebKit, AppKit, UIKit or CoreTransferable.
- JSONHTML may link the required Apple frameworks for its PDF backend. Pure HTML generation never starts WebKit. This explicitly amends the earlier module-wide framework exclusion and JH25.
- Define one JSON: Transferable conformance in JSONHTML on Apple. Strict bounded native JSON is the only import representation. HTML, text, Markdown, RTF and PDF are export-only.
- Preserve existing JSONWriter defaults and calls: compact nil indentation, spaces, insertion order and normalized number style. Add a defaulted indentation-unit parameter at a source-compatible position. Exports deliberately select preserved number spelling and one tab per level; direct renderer defaults remain two spaces.
- Use exact typed paths, generated ordinal IDs and inert ASCII Base64 metadata. Preserve scalar-distinct keys, numeric lexemes, insertion order and the distinction between absence/null. Never reconstruct JSON through browser Number/JSON.parse/JSON.stringify or Foundation serialization.
- Full output is all-or-nothing. No hidden truncation, partial preview, new online resolver, arbitrary script/theme injection or asynchronous sink API enters this scope.

## Delivery sequence

| Slice | Gates and acceptance | Reviewable result |
| --- | --- | --- |
| A — Contracts and native probes | H0/T0; JH01–03; TX01–06 | Compiler-driven public shapes, actual content types/conformance behavior, conditional Apple boundary, asset/version strategy and measured finite-preset proposal. Add the fifth target only alongside working code. |
| B — Shared exact formatting | T1; JH07–11; TX07–09 | Additive indentation units and admitted token helpers. Preserve all legacy writer/stream output; prove one noncopyable writing meter and unchanged original default semantics. |
| C — Formatted renderer and baseline exports | H1/T2/T3; JH04–11, JH17–21; TX10–33 | Complete static highlighted HTML, native JSON/text/Markdown, immutable prepared artifacts, strict JSON import, exact format lookup/selection, bounded metadata and one cumulative native preparation operation. |
| D — Interactive inspection | H2; JH12–24 | Multiple native disclosure nodes, bounded outline/literal search, themes/focus, exact copy/download fallbacks, annotations/coherent source locations, CSP and full-content printing. |
| E — Styled RTF | T4; TX34–37 | Owned bounded RTF emitter preferred, independently decoded text/styles, Unicode/surrogate/tab-stop fidelity and real receiver evidence. |
| F — Apple PDF | T5; TX38–47 | Explicit async preparation from the document's own static HTML; qualified WebPage or justified fallback, actual continuous/paginated policies, isolated state, cancellation/timeout/late-result handling, page completeness and immutable success. |
| G — Integrated qualification and docs | H3/H4/T6; JH22–28; TX48–56 | All final platform/consumer/browser/receiver checks, comparative measurements, reviewed finite profiles, DocC/examples, separate source review and reproducible local candidate. |

Keep coherent commits on the 1.3 feature branch initially. Split B, E and F into dependent branches/PRs when useful for review; base them on actual feature commits. Each PR describes its dependency and exact base/head. Intermediate four-format output is an intermediate result, not completion of the six-format release.

## Accounting and fidelity design

Admit the JSON root once and pass the active noncopyable writing meter through token generation, escaping, Base64, paths, assets, annotation binding and final Data/String materialization. Extract package-scoped admitted helpers narrowly; invoking independent public writers/renderers inside one preparation operation must not restart quotas.

The 49 core metrics retain their meanings/default values/weights. JSONHTMLLimits and JSONExportLimits add distinct finite product capacities for emitted/DOM nodes, HTML bytes, outline/annotations, aggregate/per-format prepared bytes and bounded metadata/style runs. Finite numeric presets require representative measurements before freezing; the briefing supplies no qualified numbers.

Reports distinguish final HTML bytes, cumulative helper output, per-format/aggregate artifacts and logical peak retention. Hidden prepared artifacts and overlapping token/copy/print/markup buffers count. Zero/restrictive quotas remain meaningful; checked growth/overflow and in-loop cancellation remain required. A failed operation returns no successful document/report.

PDF preparation is a second explicit operation with a separate finite PDF allowance. It admits the existing bundle and static HTML, bounds owned work/input/output/page count and ensures final aggregate artifact limits. Web engine allocations, transport copying and receiver work are platform/caller work; none imply a hard RSS or instruction cap. No composite convenience may hide another reset.

## Asset, transfer and PDF decisions

Prefer original fixed CSS/vanilla JS as generated Swift constants with explicit versions and byte hashes, avoiding another resource-bundle dependency. Qualify actual emitted block hashes/CSP, UTF-8 copy/Pointer reconstruction, payload inertness and absence of external requests. Original assets retain Apache-2.0; record any adaptation and its notices before inclusion.

Direct transfer order is JSON, static HTML, UTF-8 plain text, Markdown. Prepared order is JSON, static HTML, RTF, UTF-8 plain text, Markdown, PDF, omitting unselected/unavailable representations through immutable conditions. Plain-text requests can match conforming subtypes; test real negotiation and explicit format-only selections. OS requests are independent bounded operations. Transfer closures return prepared PDF bytes and never start WebKit.

Prefer a bounded owned RTF emitter to preserve actor-independent preparation. Verify its decoded body/styles through independent platform decoders and recipients. A necessary actor-bound native RTF adapter would require a separate explicit asynchronous operation and a recorded API decision.

The SDK exposes WebPage loading, print media and region-based PDF export. Declaration availability does not prove offscreen behavior or pagination. Probe full-content capture separately from genuine A4/US Letter pagination and page limits; do not label a tall capture as paginated output. Freeze PDF geometry/media/wrapping/defaults only after an executed backend result. Preserve nonpersistent per-job state, deny external navigation/subresources and scripting, await actual readiness, dispose state on every terminal path and reject late callbacks.

## Acceptance and release evidence

Acceptance.json retains all **84** requirement IDs. Status changes require evidence; package integrity and SDK typechecking do not qualify renderer, transfer receiver or PDF behavior. Treat missing environments as blocked/not_run and preserve actual failed probes.

- Native Swift Testing: all six roots, exact large/exponent/negative-zero numbers, scalar/order/lexeme checks, controls/prototype-like keys, deep/wide inputs, all new quota boundaries/overflow, mid-loop cancellation, terminal failures and concurrent independent calls.
- Existing baseline: retain exact test discovery, all 49 cap probes, both pinned independent suites and policy exclusions, malformed replay, ordinary-invalid versus operational-error outcomes and required Native / native, Native / safety and Native / docs names/settings.
- Five-product consumers: macOS, mobile SDK/simulator/device matrix and the qualified 1.2 Linux/WASI matrix for portable renderer/export capabilities. Apple-only transfer/PDF rows must remain distinct. Preserve the approved physical-iPad deferral explicitly; no simulator result is a physical-device pass.
- Browser: Safari/Firefox/Chromium, local file/served, scripting on/off, CSP/network, search/outline, keyboard/focus/themes, relevant VoiceOver, clipboard fallback/actual UTF-8 downloads and complete print output.
- Apple export: explicit type negotiation, share/drag/paste/open receivers, independently decoded RTF, PDF pages/bounds/last-content sentinel and long/Unicode/bidi content. Record app/font/recipient limitations and actual platform versions.
- Measurements: generation/preparation costs, output expansion, logical retention, browser DOM/interactivity and PDF responsiveness. Preserve the 10% review trigger and prior dispositions; do not infer hard RSS or browser CPU guarantees.
- Final integration: fresh exact-source affected lanes, current-base reviews, five DocC catalogues/compiled examples, updated product/support/dependency contracts, deterministic source/evidence archives and matching qualified assets.

## First implementation increment

Finish same-package JSON conformance and renderer/report compiler probes, then implement the additive indentation unit and a tested exact formatted-output path. Add meaningful fixtures and public consumers with that code. Introduce JSONHTML, forward five-product policy, exact manifest/test assertions and its DocC catalogue coherently, without an empty placeholder target. Record finite-profile measurements and backend gaps as open until their evidence exists.
