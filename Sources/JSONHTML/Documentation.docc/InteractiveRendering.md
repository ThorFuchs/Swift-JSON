# Interactive rendering

Explore complete exact JSON without a browser-side JSON model.

```swift
import JSON
import JSONHTML

let root = try JSONParser().parse(#"{"amount":9007199254740993,"items":[null,-0.00e+2]}"#)
let renderer = JSONHTMLRenderer(options: .init(
    title: "Exact values", presentation: .interactive,
    initiallyExpandedDepth: 2, outlineDepth: 3))
let report = try renderer.renderWithReport(root)
```

Formatted remains the default. Containers use native `details`/`summary` elements
without exclusive accordion grouping. Root is level zero; levels below the initial
depth start open. Outline depth includes containers through that level; nil omits
it. Generated ordinal identifiers are independent of keys and Pointer spelling.
Native disclosure works without scripting; enhanced controls appear only after the
fixed script runs. No external resources, online resolver or UI framework is used.

Search is case-sensitive literal matching over rendered JSON key/value text, including
JSON quotes and escapes. It does not match source locations, Pointer labels or
container kind labels. There is no normalization, regex or browser number conversion.
The UTF-8 query ceiling is explicit. Scans and expand/collapse actions process at most
128 nodes per scheduled chunk. All matching nodes are counted and highlighted; up to
100 result links are listed with that limit disclosed. Typing preserves query focus; selecting a result focuses and scrolls its target.
A newer query/action invalidates an older queued scan. This does not provide browser CPU, instruction or heap quotas.

Copy JSON and Download JSON use inert Base64 of the exact shared writer bytes with
preserved numeric lexemes, insertion order and selected indentation. Raw RFC 6901
Pointers and their JSON-string-escaped forms are generated in Swift from typed key
and array-index paths. Keys containing slash, tilde, NUL or line breaks remain exact.
Escaped labels and raw copies are explicitly distinguished. Clipboard success is
reported only after the browser accepts `writeText`; rejection or absence shows a
manual text area. Browsers and platform clipboards may transform text, and textareas
normalize line endings. UTF-8 downloads preserve the independently tested bytes;
“download requested” does not claim that a receiving application has saved them.

Printing uses a second complete formatted block, hidden on screen and shown in print
media. Collapse/search state does not truncate it. Both copies, the original native
JSON buffer, Pointer forms, Base64 metadata, outline records and final result copy
share one cumulative meter. Root admission occurs once. Additional ceilings bound
outline entries and emitted metadata; exceeding them fails before growth and returns
no partial result. Reports distinguish raw copy bytes, Base64 bytes, complete document
bytes and logical retained-byte accounting. Logical retention is not process RSS.

Defaults are initial finite policy. Browser query bytes must be zero through 65,536;
zero rejects nonempty queries. Native DOM accounting reserves 96 fixed nodes, 32 per
JSON tree node (including its possible dynamic search result), eight per outline entry
and four per print/scalar syntax run. It conservatively covers generated document
nodes and bounded enhancement nodes, not browser internal allocations.

`Scripts/ci.py --lane browser` checks eight native fixtures and 37 pinned Chromium,
Firefox and WebKit cases using file/local HTTP, scripting on/off, keyboard, search,
exact downloads, clipboard outcomes, mobile viewports and complete print content.
Playwright WebKit is not native Safari; viewports are not physical device tests.
Native Safari, VoiceOver and the final 1.3 platform matrix remain separate release
qualification. Annotation/source mapping and transfer/RTF/PDF APIs are not included.
