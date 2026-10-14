// SPDX-License-Identifier: Apache-2.0
import JSON

private enum StructuredStep {
    case node(JSON, JSONLocationComponent?, Int)
    case end(String, Bool)
    case objectMember(JSON, JSONKey, Int)
    case arrayMember(JSON, Int, Int, Bool, Bool)
}
private struct StructuredOutline {
    let ordinal: UInt64
    let component: JSONLocationComponent?
    let depth: Int
}

extension JSONHTMLRenderer {
    package func renderRichDocument(
        _ value: JSON, annotations: [JSONHTMLBoundAnnotation], meter: inout JSONWorkMeter
    ) throws -> JSONHTMLDocumentBuffer {
        var planning = options
        if options.layout == .syntax {
            // An explicit syntax invocation never invokes the inline/media pipeline.
            planning.inlineFormatting = .off
            planning.colorPreviews = false
            planning.embeddedImagePreviews = false
            planning.previewHints = []
            planning.effectivePreviewHints = []
        }
        let plan = try JSONHTMLPreviewPlan.make(value, options: planning, meter: &meter)
        var output = JSONHTMLDocumentBuffer(limits: options.limits)
        output.setAnnotations(UInt64(annotations.count))
        output.setPreviews(
            shortened: plan.shortened && options.valueProfile == .inspection
                && options.layout == .structured, issues: UInt64(plan.issues.count),
            images: plan.media.images, imageBytes: plan.media.bytes)
        let interactive = options.presentation == .interactive
        try output.addDOM(110, meter: &meter)
        try output.append(
            "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src ",
            meter: &meter)
        if interactive {
            try output.append(
                "'sha256-" + JSONHTMLInteractiveAssets.scriptHash + "'", meter: &meter)
        } else {
            try output.append("'none'", meter: &meter)
        }
        try output.append(
            "; style-src 'sha256-" + JSONHTMLInteractiveAssets.styleHash + "'; ", meter: &meter)
        if plan.media.images > 0 { try output.append("img-src data:; ", meter: &meter) }
        try output.append(
            "base-uri 'none'; form-action 'none'; object-src 'none'\"><title>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</title><style>", meter: &meter)
        try output.append(JSONHTMLAssets.css, meter: &meter)
        try output.append("\n", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.css, meter: &meter)
        try output.append("</style></head><body class=\"rich ", meter: &meter)
        if interactive { try output.append("interactive ", meter: &meter) }
        try output.append(options.theme.rawValue, meter: &meter)
        try output.append(" tabs-", meter: &meter)
        try output.decimal(UInt64(options.tabWidth), meter: &meter)
        try output.append("\"><main><header class=\"document-header\"><h1>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</h1><p>", meter: &meter)
        try output.append(
            options.valueProfile == .inspection && options.layout == .structured
                ? "Inspection view · bounded string previews; exact values remain available."
                : "Complete values · exact JSON source remains available.", meter: &meter)
        try output.append("</p></header>", meter: &meter)
        let copy = try nativeBytes(value, options: writingOptions, meter: &meter)
        output.setCopyBytes(UInt64(copy.count))
        try output.append(
            "<p class=\"source-download\"><a download=\"document.json\" href=\"data:application/json;charset=utf-8;base64,",
            meter: &meter)
        try output.base64(copy, meter: &meter)
        try output.append(
            "\">Download exact JSON (UTF-8; works without JavaScript)</a></p>", meter: &meter)
        if interactive {
            try output.append(
                "<div class=\"view-tabs\" id=\"jh-tabs\"><a id=\"jh-tab-structured\" href=\"#jh-structured\" data-view=\"structured\">Structured</a><a id=\"jh-tab-syntax\" href=\"#jh-syntax\" data-view=\"syntax\">JSON source</a></div><div id=\"jh-toolbar\" class=\"toolbar\" hidden><button type=\"button\" data-action=\"copy-json\">Copy JSON</button><button type=\"button\" data-action=\"download-json\">Download JSON (UTF-8)</button><button type=\"button\" data-action=\"expand\">Expand all</button><button type=\"button\" data-action=\"collapse\">Collapse all</button><label for=\"jh-query\">Search previews</label><input id=\"jh-query\" type=\"search\" data-byte-limit=\"",
                meter: &meter)
            try output.decimal(UInt64(options.limits.maxSearchQueryBytes), meter: &meter)
            try output.append(
                "\"><button type=\"button\" data-action=\"previous\">Previous match</button><button type=\"button\" data-action=\"next\">Next match</button><button type=\"button\" data-action=\"clear\">Clear search</button><label>Theme <select id=\"jh-theme\"><option value=\"automatic\">System</option><option value=\"light\">Light</option><option value=\"dark\">Dark</option></select></label></div><p id=\"jh-status\" role=\"status\" aria-live=\"polite\"></p><ul id=\"jh-results\" class=\"search-results\" aria-label=\"Search results\"></ul><dialog id=\"jh-manual\" class=\"manual-copy\" aria-labelledby=\"jh-copy-label\"><label id=\"jh-copy-label\" for=\"jh-manual-text\">Manual copy text (raw controls may be invisible)</label><textarea id=\"jh-manual-text\" readonly></textarea><button type=\"button\" data-action=\"select\">Select text</button><button type=\"button\" data-action=\"close-copy\">Close</button></dialog><noscript><p>Both views, native disclosures and original values work without JavaScript. Exact JSON source is below. Enhanced search, copy and download require scripting.</p></noscript><div id=\"jh-copy-json\" hidden data-bytes=\"",
                meter: &meter)
            try output.base64(copy, meter: &meter)
            try output.append("\"></div>", meter: &meter)
        }
        try meter.release(UInt64(copy.count))
        var outline: [StructuredOutline] = []
        if options.layout == .structured || interactive {
            try output.append(
                "<section id=\"jh-structured\" class=\"screen-view\" data-initial-view=\"",
                meter: &meter)
            try output.append(options.layout.rawValue, meter: &meter)
            try output.append(
                "\" aria-label=\"Structured JSON\"><div class=\"layout\"><section id=\"jh-tree\" class=\"tree\" aria-label=\"Ordered JSON values\">",
                meter: &meter)
            try structuredBody(
                value, plan: plan, profile: options.valueProfile, namespace: "jh-n-",
                interactive: interactive, countNodes: true, annotations: annotations,
                outline: &outline,
                output: &output, meter: &meter)
            try output.append("</section>", meter: &meter)
            if interactive, options.outlineDepth != nil {
                try output.append(
                    "<nav class=\"outline\" aria-label=\"Container outline\"><h2>Outline</h2><ul>",
                    meter: &meter)
                for entry in outline {
                    try meter.work()
                    try output.addDOM(8, meter: &meter)
                    try output.append("<li><a href=\"#jh-n-", meter: &meter)
                    try output.decimal(entry.ordinal, meter: &meter)
                    try output.append("\" data-target=\"jh-n-", meter: &meter)
                    try output.decimal(entry.ordinal, meter: &meter)
                    try output.append("\">Level ", meter: &meter)
                    try output.decimal(UInt64(entry.depth), meter: &meter)
                    try output.append(": ", meter: &meter)
                    try label(entry.component, output: &output, meter: &meter, searchable: false)
                    try output.append("</a></li>", meter: &meter)
                    try meter.release(40)
                }
                outline = []
                try output.append("</ul></nav>", meter: &meter)
            }
            try output.append("</div></section>", meter: &meter)
        }
        if interactive || options.layout == .syntax {
            try output.append(
                "<section id=\"jh-syntax\" tabindex=\"-1\" class=\"screen-view\" aria-label=\"Complete exact JSON source\"><h2>Exact JSON source</h2><pre><code data-source-search>",
                meter: &meter)
            try highlighted(value, options: writingOptions, output: &output, meter: &meter)
            try output.append("</code></pre></section>", meter: &meter)
        } else {
            try output.append(
                "<details class=\"exact-source\"><summary>Exact JSON source (complete)</summary><pre><code>",
                meter: &meter)
            try highlighted(value, options: writingOptions, output: &output, meter: &meter)
            try output.append("</code></pre></details>", meter: &meter)
        }
        if !plan.issues.isEmpty {
            try output.addDOM(UInt64(plan.issues.count) * 4 + 4, meter: &meter)
            try output.append(
                "<section class=\"preview-issues\" aria-label=\"Preview issues\"><h2>Preview issues</h2><ul>",
                meter: &meter)
            for issue in plan.issues {
                try meter.work()
                try output.append("<li><code>", meter: &meter)
                let pointer = try pointerBytes(issue.path, meter: &meter)
                try output.escaped(String(decoding: pointer, as: UTF8.self), meter: &meter)
                try meter.release(UInt64(pointer.count))
                try output.append("</code>: ", meter: &meter)
                try output.escaped(issue.message, meter: &meter)
                try output.append("</li>", meter: &meter)
            }
            try output.append("</ul></section>", meter: &meter)
        }
        try annotationSection(annotations, output: &output, meter: &meter)
        // Printing is a separately charged representation of the same immutable plan/root.
        try output.append(
            "<section class=\"print-json\" aria-label=\"Complete values for printing\">",
            meter: &meter)
        if options.layout == .structured {
            var ignored: [StructuredOutline] = []
            try structuredBody(
                value, plan: plan, profile: options.printValueProfile, namespace: "jh-p-",
                interactive: false, countNodes: false, annotations: [], outline: &ignored,
                output: &output,
                meter: &meter)
        } else {
            try output.append("<pre><code>", meter: &meter)
            try highlighted(value, options: writingOptions, output: &output, meter: &meter)
            try output.append("</code></pre>", meter: &meter)
        }
        try meter.release(plan.reservation)
        try output.append("</section></main>", meter: &meter)
        if interactive {
            try output.append("<script>", meter: &meter)
            try output.append(JSONHTMLInteractiveAssets.script, meter: &meter)
            try output.append("</script>", meter: &meter)
        }
        try output.append("</body></html>\n", meter: &meter)
        try meter.checkpoint()
        return output
    }
    private var writingOptions: JSONWritingOptions {
        .init(
            limits: options.limits.core, indentation: options.indentation, numberStyle: .preserved,
            indentationUnit: options.indentationUnit)
    }
    private func scalarFlow(_ values: [JSON], meter: inout JSONWorkMeter) throws -> Bool {
        guard values.count <= 10 else { return false }
        for value in values {
            try meter.work()
            var length: UInt64 = 0
            switch value {
            case .array, .object: return false
            case .string(let s):
                length = 2
                for scalar in s.unicodeScalars {
                    try meter.work()
                    length += JSONHTMLDisplay.units(scalar)
                    if length > 60 { return false }
                }
            default:
                var cursor = JSONWritingCursor(value: value, options: writingOptions)
                while (try cursor.next(meter: &meter)) != nil {
                    length += 1
                    if length > 60 { return false }
                }
            }
            if length > 60 { return false }
        }
        return true
    }
    private func structuredBody(
        _ value: JSON, plan: JSONHTMLPreviewPlan, profile: JSONHTMLValueProfile, namespace: String,
        interactive: Bool, countNodes: Bool, annotations: [JSONHTMLBoundAnnotation],
        outline: inout [StructuredOutline], output: inout JSONHTMLDocumentBuffer,
        meter: inout JSONWorkMeter
    ) throws {
        var stack: [StructuredStep] = []
        var path: [JSONLocationComponent] = []
        var ordinal: UInt64 = 0
        func push(_ step: StructuredStep, _ m: inout JSONWorkMeter) throws {
            try m.retain(JSONLogicalWeights.frame)
            stack.append(step)
        }
        try push(.node(value, nil, 0), &meter)
        while let step = stack.popLast() {
            try meter.release(JSONLogicalWeights.frame)
            try meter.work()
            try meter.retain(256)
            switch step {
            case .end(let markup, let pop):
                try output.append(markup, meter: &meter)
                if pop {
                    path.removeLast()
                    try meter.release(JSONLogicalWeights.frame)
                }
            case .objectMember(let child, let key, let depth):
                try output.addDOM(6, meter: &meter)
                try output.append(
                    "<div class=\"field-row\"><dt><code class=\"key\" data-search-key>",
                    meter: &meter)
                try JSONHTMLDisplay.text(key.string, quoted: true, output: &output, meter: &meter)
                if key.string.isEmpty {
                    try output.append(
                        " <span class=\"preview-kind\">Empty key</span>", meter: &meter)
                }
                try output.append("</code></dt><dd>", meter: &meter)
                try push(.end("</dd></div>", false), &meter)
                try push(.node(child, .key(key), depth), &meter)
            case .arrayMember(let child, let index, let depth, let flow, let records):
                try output.addDOM(6, meter: &meter)
                try output.append(
                    flow
                        ? "<li class=\"flow-item\"><span class=\"visually-hidden\">Index "
                        : records
                            ? "<li class=\"record-card\"><span class=\"index-label\">#"
                            : "<li class=\"scalar-item\"><span class=\"index-label\">#",
                    meter: &meter)
                try output.decimal(UInt64(index), meter: &meter)
                try output.append("</span>", meter: &meter)
                try push(.end("</li>", false), &meter)
                try push(.node(child, .index(index), depth), &meter)
            case .node(let node, let component, let depth):
                if let component {
                    try meter.retain(JSONLogicalWeights.frame)
                    path.append(component)
                }
                let id = ordinal
                ordinal = try JSONHTMLDocumentBuffer.adding(
                    .renderedJSONNodes, ordinal, 1, options.limits.maxRenderedJSONNodes)
                if countNodes { try output.addNode(meter: &meter) }
                let container: Bool
                let empty: Bool
                let kind: String
                switch node {
                case .object(let o):
                    container = true
                    empty = o.isEmpty
                    kind = "object"
                case .array(let a):
                    container = true
                    empty = a.isEmpty
                    kind = "array"
                case .string:
                    container = false
                    empty = false
                    kind = "string"
                case .number:
                    container = false
                    empty = false
                    kind = "number"
                case .boolean:
                    container = false
                    empty = false
                    kind = "bool"
                case .null:
                    container = false
                    empty = false
                    kind = "null"
                }
                if interactive, container, let maxDepth = options.outlineDepth, depth <= maxDepth {
                    try output.addOutline(meter: &meter)
                    try meter.retain(40)
                    outline.append(.init(ordinal: id, component: component, depth: depth))
                }
                try output.addDOM(24, meter: &meter)
                try output.append(
                    container && !empty
                        ? (interactive
                            ? "<details class=\"node container "
                            : "<section class=\"node container ")
                        : "<div class=\"node scalar ", meter: &meter)
                try output.append(kind, meter: &meter)
                try output.append(" depth-", meter: &meter)
                try output.decimal(UInt64(min(depth, 3)), meter: &meter)
                try output.append("\" tabindex=\"-1\" id=\"" + namespace, meter: &meter)
                try output.decimal(id, meter: &meter)
                try output.append("\"", meter: &meter)
                if interactive {
                    let pointer = try pointerBytes(path, meter: &meter)
                    try output.append(" data-pointer=\"", meter: &meter)
                    try output.base64(pointer, meter: &meter)
                    for _ in pointer {
                        try meter.work()
                        try meter.retain(1)
                    }
                    let text = String(decoding: pointer, as: UTF8.self)
                    let quoted = try nativeBytes(
                        .string(text), options: writingOptions, meter: &meter)
                    try meter.release(UInt64(pointer.count))
                    try output.append("\" data-pointer-escaped=\"", meter: &meter)
                    try output.base64(quoted, meter: &meter)
                    try meter.release(UInt64(quoted.count))
                    try meter.release(UInt64(pointer.count))
                    try output.append("\"", meter: &meter)
                }
                if interactive && container && !empty && depth < options.initiallyExpandedDepth {
                    try output.append(" open", meter: &meter)
                }
                try annotationDescription(at: id, in: annotations, output: &output, meter: &meter)
                try output.append(
                    container && !empty
                        ? (interactive ? "><summary>" : "><header class=\"container-heading\">")
                        : ">",
                    meter: &meter)
                if !container {
                    try output.append("<span class=\"scalar-kind\">", meter: &meter)
                    try output.append(
                        kind == "bool"
                            ? "Boolean"
                            : kind == "null" ? "Null" : kind == "string" ? "String" : "Number",
                        meter: &meter)
                    try output.append("</span>", meter: &meter)
                }
                if container {
                    try output.append("<span class=\"kind\">", meter: &meter)
                    try output.append(empty ? "Empty " + kind : kind, meter: &meter)
                    switch node {
                    case .object(let o):
                        try output.append(" · ", meter: &meter)
                        try output.decimal(UInt64(o.count), meter: &meter)
                        try output.append(" members", meter: &meter)
                    case .array(let a):
                        try output.append(" · ", meter: &meter)
                        try output.decimal(UInt64(a.count), meter: &meter)
                        try output.append(" items", meter: &meter)
                    default: break
                    }
                    try output.append("</span>", meter: &meter)
                }
                if interactive {
                    try output.append(
                        "<span class=\"pointer-actions\"><button type=\"button\" data-action=\"copy-pointer\" data-node=\""
                            + namespace, meter: &meter)
                    try output.decimal(id, meter: &meter)
                    try output.append(
                        "\">Copy Pointer (RFC 6901)</button><button type=\"button\" data-action=\"copy-pointer-escaped\" data-node=\""
                            + namespace, meter: &meter)
                    try output.decimal(id, meter: &meter)
                    try output.append(
                        "\">Copy Pointer as JSON string</button><button type=\"button\" data-action=\"download-pointer\" data-node=\""
                            + namespace, meter: &meter)
                    try output.decimal(id, meter: &meter)
                    try output.append("\">Download Pointer</button></span>", meter: &meter)
                }
                let preview = plan.nodes[Int(id)]
                if case .color(let color) = preview.primary {
                    try color.emit(
                        ordinal: id, namespace: namespace, label: preview.prefix, output: &output,
                        meter: &meter
                    )
                }
                if case .image(let image) = preview.primary {
                    try image.emit(output: &output, meter: &meter)
                }
                switch node {
                case .object(let members) where !members.isEmpty:
                    try output.append(
                        interactive
                            ? "</summary><dl class=\"object-form\">"
                            : "</header><dl class=\"object-form\">",
                        meter: &meter)
                    try push(
                        .end(interactive ? "</dl></details>" : "</dl></section>", component != nil),
                        &meter)
                    for member in members.reversed() {
                        try meter.work()
                        try push(.objectMember(member.value, member.key, depth + 1), &meter)
                    }
                case .array(let values) where !values.isEmpty:
                    let flow = try scalarFlow(values, meter: &meter)
                    var records = false
                    for child in values {
                        try meter.work()
                        if case .object = child {
                            records = true
                            break
                        }
                        if case .array = child {
                            records = true
                            break
                        }
                    }
                    try output.append(interactive ? "</summary>" : "</header>", meter: &meter)
                    try output.append(
                        flow ? "<ol class=\"scalar-flow\">" : "<ol class=\"indexed-list\">",
                        meter: &meter)
                    try push(
                        .end(interactive ? "</ol></details>" : "</ol></section>", component != nil),
                        &meter)
                    for index in values.indices.reversed() {
                        try meter.work()
                        try push(
                            .arrayMember(values[index], index, depth + 1, flow, records), &meter)
                    }
                case .string(let string):
                    let prefix = preview.prefix!
                    let usePrefix = profile == .inspection
                    try output.append("<span class=\"display-value\" data-search>", meter: &meter)
                    if case .inline(let inline) = preview.primary, inline.formatted {
                        try output.append(
                            "<span class=\"preview-kind\">Inline preview: </span>", meter: &meter)
                        try inline.emit(output: &output, meter: &meter)
                    } else {
                        try JSONHTMLDisplay.text(
                            usePrefix ? prefix.source : string, quoted: true, output: &output,
                            meter: &meter)
                    }
                    try output.append("</span>", meter: &meter)
                    if prefix.shortened
                        && (usePrefix
                            || {
                                if case .inline = preview.primary { return true }
                                return false
                            }())
                    {
                        try output.addDOM(4, meter: &meter)
                        try output.append(
                            "<span class=\"preview-label\">… String preview · first ", meter: &meter
                        )
                        try output.decimal(prefix.scalars, meter: &meter)
                        try output.append(
                            " decoded scalars (bounded display)</span>", meter: &meter)
                    }
                    let needsOriginal: Bool
                    switch preview.primary {
                    case .literal: needsOriginal = usePrefix && prefix.shortened
                    default: needsOriginal = true
                    }
                    if needsOriginal {
                        try output.addDOM(6, meter: &meter)
                        if profile == .complete {
                            try output.append(
                                "<div class=\"original-value\"><span>Original value (complete)</span><code>",
                                meter: &meter)
                        } else {
                            try output.append(
                                "<details class=\"original-value\"><summary>Original value (complete)</summary><code>",
                                meter: &meter)
                        }
                        try JSONHTMLDisplay.text(
                            string, quoted: true, output: &output, meter: &meter)
                        try output.append(
                            profile == .complete ? "</code></div>" : "</code></details>",
                            meter: &meter)
                    }
                    try push(.end("</div>", component != nil), &meter)
                default:
                    try output.append("<code class=\"display-value\" data-search>", meter: &meter)
                    if empty {
                        try output.append(kind == "object" ? "{}" : "[]", meter: &meter)
                    } else {
                        try highlighted(
                            node, options: writingOptions, output: &output, meter: &meter)
                    }
                    try output.append("</code>", meter: &meter)
                    try push(.end("</div>", component != nil), &meter)
                }
            }
            try meter.release(256)
        }
    }
}
