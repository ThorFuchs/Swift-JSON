# Structured layout and native preview contract

This additive work implements the maintainer's consolidated briefing revision 0.2.
The revision is a design input, not a package release number. Release placement is
unassigned. Earlier Release1.3 and Release1.4 records retain their historical gates.

The root package exposes five libraries (JSON, JSONSchema, JSONStreaming, JSONPatch,
JSONHTML) and the sixth `swift-json` executable. External package dependencies remain
empty. JSONHTML imports JSON; it does not require schema, an image codec, a Markdown
engine, a TeX engine or a browser at generation time. Original code is Apache-2.0.

| Entry point | Layout | Presentation | Values | Print/PDF |
| --- | --- | --- | --- | --- |
| Direct renderer | structured | interactive | inspection | complete |
| Prepared export / direct transfer | structured | formatted (static) | complete | complete |
| CLI HTML | structured | static | inspection | complete |
| Explicit syntax | syntax | caller choice | exact full JSON | exact full JSON |

Layout and presentation are independent. The existing six- and nine-argument
`JSONHTMLRenderingOptions.init` function shapes remain available. New callers can
use the required `layout:` overload or mutate the copied options. Default HTML bytes,
DOM size, appearance and print geometry intentionally change. Select `.syntax` and
`.formatted` to retain the former code-only rendering contract. Core JSON writer
formatting defaults and non-HTML export bytes are unchanged.

`JSONHTMLLayout`, `JSONHTMLValueProfile`, `JSONHTMLInlineFormatting`,
`JSONHTMLLinkActivation`, `JSONHTMLPreviewPolicy` and `JSONHTMLPreviewHint` are checked
Sendable values. Hint paths use `[JSONLocationComponent]`; key `"0"` and index `0`
are distinct. Explicit declarations precede caller-translated effective annotations,
complete color/data-URI recognition, automatic inline formatting and literal output.
Duplicate declarations in a tier are configuration errors. Missing/wrong-kind or
unavailable declarations generate bounded issues and retain source. Literal hints
suppress inference. Syntax does not run the preview pipeline. Schema validity is
independent of preview admission.

Nonempty ordered objects use `dl/dt/dd` forms. Complex or mixed arrays use ordered
indexed cards. Scalar flow eligibility is inclusive at 10 items and 60 display-token
Unicode scalars, including quotation/control escapes before HTML entity encoding.
The original full token determines eligibility. Other arrays use indexed lists.
Every root, empty container, scalar and empty key has an explicit kind/value cue.
Static containers are ordinary expanded markup. Interactive containers have native
summaries; original-value disclosures and both source views work without scripting.
Visual depth stops adding rails/padding at level 3; JSON structure is never truncated.

Inspection prefixes independently cap decoded scalars at 512, UTF-8 prefix bytes at
2048 and escaped display scalars at 512. Prefixes never split a scalar or a reversible
control escape. Full original strings remain in native Original value disclosures
and complete JSON source. Complete values/print expand original strings. Keys,
numbers and JSON nodes are never shortened. C0/C1, the documented format/bidi ranges
in `JSONHTMLDisplay.protected`, quotes and backslashes have reversible structured
display. Full JSON/source/copy/download retain native writer bytes and numeric
lexemes; source text is bidi-isolated. Display escaping does not normalize scalars.

The closed inline dialect supports star bold/italic, plain/emphasized link labels,
declared embedded images and inline math. Backtick runs, fences and block-looking
lines remain literal. Parsing occurs only in the admitted prefix. Links remain inert
by default; explicit activation permits validated credential-free absolute HTTP/HTTPS
user navigation. Remote images, SVG input, raw markup, document Markdown, arbitrary
CSS/MathML, generated-HTML replacements and external parser dependencies are excluded.

Mini math supports the fixed Latin/Greek/operator mapping, groups, decimal tokens,
exact fraction/radical arities and at most one subscript/superscript per atom.
Unbraced multi-character arguments, unknown commands, malformed, ambiguous or cutoff
spans remain wholly literal. Single-child groups are unwrapped as the fixture's
permitted canonicalization. Math is presentation only; fractions are not evaluated.
Output uses the fixed MathML Core allowlist. No partial parse is committed.

Color strings use complete #RGB/#RGBA/#RRGGBB/#RRGGBBAA and comma rgb/rgba grammar.
Numeric hinted channels require explicit integer8 or normalized units and rgb/rgba
order. Exact native range checks precede appearance conversion; alpha slightly above
one is rejected even when Double would round it to one. Controlled SVG swatches
include checkerboard alpha backgrounds and separate channel text. Only geometry and
validated channels enter their generated attributes.

Declared PNG/JPEG uses canonical standard Base64 with exact padding and zero pad
bits. Native admission checks signature, bounded headers/structure/dimensions/pixels,
IHDR CRC and framing. It is not a full raster codec or browser RSS guarantee. Image
count and aggregate decoded bytes are counted once per unique staged preview, even
when screen/print representations emit it again. `img-src data:` is authorized only
when admitted media is emitted; external resources remain denied.

`PreviewPolicy.json` freezes all 22 proposed eligibility ceilings. These supplement
unchanged core/HTML/export/PDF ceilings. All 49 core metric meanings and presets are
preserved. Decoded binary media contributes to logical retained bytes and the separate
`decodedImageBytes` statistic, not the emitted UTF-8 metric. No nested facade resets
work. Admission, staging, all duplicate bodies, assets, escaping, Base64 and final
copies share one invocation meter. Local syntax/eligibility rejection refunds only
live scratch; real resource/configuration/cancellation failures remain terminal.

Prepared HTML retains immutable layout/value/print and font/media readiness policy.
Explicit asynchronous Apple PDF consumes that artifact, awaits fonts/image decoding,
forces its print representation, and never regenerates JSONHTML. Syntax pagination
retains CoreText visible ranges. Structured pagination collects native line/media
bounds one DOM step at a time, chooses integer whitespace cuts and composites native
regions. An unbreakable fragment larger than a page fails explicitly; no syntax
fallback is selected. SDK decoding/layout/capture work and allocations are outside
owned instruction/RSS claims. Actual readiness/output/font evidence is reported
separately from the native generation policy.

The CLI adds HTML-only `--layout structured|syntax`, `--string-preview N` versus
`--full-values`, `--inline-formatting off|declared|automatic`, and `--value-previews
 off|standard`. N is checked/nonnegative, zero is meaningful, and its UTF-8 allowance
is min(core stringBytes, checked 4*N). Invalid/non-HTML/conflicting choices remain
usage exit 2. Atomic output and the `--html PATH` conflict rules are unchanged.

Browser search retains the existing 1024-byte query ceiling and 100 listed/highlighted
node limit. It reports total matching nodes separately from the listed subset and
wraps only within that disclosed set. It excludes Original value and print/source
duplicates from structured search. Syntax search is a separate exact-source scope.
Optional browser Download HTML is omitted: callers save immutable renderer/export
bytes; no mutated DOM serialization or recursive HTML payload is shipped.

Preview logical weights are versioned in this revision: 64 bytes per staged node or
inline token, 32 per inline delimiter frame, four per scalar, 64 per math node/frame
plus eight per child slot and admitted token UTF-8, actual encoded/decoded/prefix
bytes, and 256 for active structured emission scratch. PDF fragment bounds reserve
32 bytes each and its fixed native cursor 128. Borrowed immutable fixed asset/mapping
tables are shared; no invocation stores a global mutable cache. These are logical
accounting weights, not Swift allocator measurements or process RSS promises.

Math's token ceiling counts consumed identifiers/numbers/commands/operators/braces/
script markers, rather than interpreter decisions. Interpreter loops remain covered
by cumulative work/cancellation. Number/command staging reserves source UTF-8 plus
128 fixed scratch bytes; MathML emission reserves 32 and swatch emission 64. The
structured source-download anchor reuses exact native UTF-8 and works without JS;
its Base64 duplication is metered. `copyJSONBytes` describes the one raw payload,
while emitted metadata/output counts each copy. Legacy static syntax retains its
original code-only counters.
