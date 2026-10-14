// SPDX-License-Identifier: Apache-2.0
import JSON

extension JSONHTMLRenderer {
    package func renderInteractive(_ value: JSON, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        let writing = JSONWritingOptions(limits: options.limits.core, indentation: options.indentation,
                                         numberStyle: .preserved, indentationUnit: options.indentationUnit)
        var copy = try nativeBytes(value, options: writing, meter: &meter)
        var output = JSONHTMLDocumentBuffer(limits: options.limits)
        output.setCopyBytes(UInt64(copy.count))
        try output.addDOM(96, meter: &meter)
        try output.append("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'sha256-", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.scriptHash, meter: &meter)
        try output.append("'; style-src 'sha256-", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.styleHash, meter: &meter)
        try output.append("'; base-uri 'none'; form-action 'none'\"><title>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</title><style>", meter: &meter)
        try output.append(JSONHTMLAssets.css, meter: &meter)
        try output.append("\n", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.css, meter: &meter)
        try output.append("</style></head><body class=\"interactive ", meter: &meter)
        try output.append(options.theme.rawValue, meter: &meter)
        try output.append(" tabs-", meter: &meter)
        try output.decimal(UInt64(options.tabWidth), meter: &meter)
        try output.append("\"><main><h1>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</h1><div id=\"jh-toolbar\" class=\"toolbar\" hidden><button data-action=\"copy-json\" type=\"button\">Copy JSON</button><button data-action=\"download-json\" type=\"button\">Download JSON (UTF-8)</button><button data-action=\"expand\" type=\"button\">Expand all</button><button data-action=\"collapse\" type=\"button\">Collapse all</button><label for=\"jh-query\">Search rendered JSON</label><input id=\"jh-query\" type=\"search\" data-byte-limit=\"", meter: &meter)
        try output.decimal(UInt64(options.limits.maxSearchQueryBytes), meter: &meter)
        try output.append("\"><button data-action=\"clear\" type=\"button\">Clear search</button></div><p id=\"jh-status\" role=\"status\" aria-live=\"polite\"></p><ul id=\"jh-results\" class=\"search-results\" aria-label=\"Search results\"></ul><section id=\"jh-manual\" class=\"manual-copy\" hidden><label for=\"jh-manual-text\">Manual copy text (raw controls may be invisible)</label><textarea id=\"jh-manual-text\" readonly></textarea><button type=\"button\" data-action=\"select\">Select text</button></section><noscript><p>Native disclosure works without JavaScript. Enhanced navigation, search and copy require scripting. Printing includes the complete formatted JSON.</p></noscript><div id=\"jh-copy-json\" hidden data-bytes=\"", meter: &meter)
        try output.base64(copy, meter: &meter)
        try output.append("\"></div>", meter: &meter)
        try meter.release(UInt64(copy.count)); copy = []

        var path: [JSONLocationComponent] = []
        var steps: [InteractiveStep] = []
        var outline: [OutlineEntry] = []
        func push(_ step: InteractiveStep, meter: inout JSONWorkMeter) throws {
            try meter.retain(JSONLogicalWeights.frame); steps.append(step)
        }
        try output.append("<div class=\"layout\"><section id=\"jh-tree\" class=\"tree\" aria-label=\"JSON value tree\">", meter: &meter)
        try push(.node(value, nil, 0), meter: &meter)
        var ordinal: UInt64 = 0
        while let step = steps.popLast() {
            try meter.release(JSONLogicalWeights.frame); try meter.work()
            switch step {
            case .close(let container, let popPath):
                try output.append(container ? "</div></details>" : "</div>", meter: &meter)
                if popPath { path.removeLast(); try meter.release(JSONLogicalWeights.frame) }
            case .node(let node, let component, let level):
                if let component { try meter.retain(JSONLogicalWeights.frame); path.append(component) }
                try output.addNode(meter: &meter)
                let id = ordinal
                ordinal = try JSONHTMLDocumentBuffer.adding(.renderedJSONNodes, ordinal, 1, options.limits.maxRenderedJSONNodes)
                try output.addDOM(32, meter: &meter)
                let container: Bool
                switch node { case .array, .object: container = true; default: container = false }
                if container, let depth = options.outlineDepth, level <= depth {
                    try output.addOutline(meter: &meter)
                    try meter.retain(40); outline.append(.init(ordinal: id, component: component, level: level))
                }
                try output.append(container ? "<details class=\"node container\"" : "<div class=\"node scalar\"", meter: &meter)
                try output.append(" tabindex=\"-1\" id=\"jh-n-", meter: &meter)
                try output.decimal(UInt64(id), meter: &meter)
                try output.append("\" data-pointer=\"", meter: &meter)
                var pointer = try pointerBytes(path, meter: &meter)
                try output.base64(pointer, meter: &meter)
                // This additional owned String is admitted before conversion; no browser JSON quoting.
                for _ in pointer { try meter.work(); try meter.retain(1) }
                var pointerText = String(decoding: pointer, as: UTF8.self)
                var quotedPointer = try nativeBytes(.string(pointerText), options: .init(numberStyle: .preserved), meter: &meter)
                try meter.release(UInt64(pointer.count)); pointerText = ""
                try output.append("\" data-pointer-escaped=\"", meter: &meter)
                try output.base64(quotedPointer, meter: &meter)
                try meter.release(UInt64(pointer.count)); pointer = []
                try output.append("\"", meter: &meter)
                if container && level < options.initiallyExpandedDepth { try output.append(" open", meter: &meter) }
                try output.append(container ? "><summary>" : ">", meter: &meter)
                try label(component, output: &output, meter: &meter, searchable: true)
                switch node {
                case .object(let members):
                    try output.append(" <span class=\"kind\">object (", meter: &meter)
                    try output.decimal(UInt64(members.count), meter: &meter)
                    try output.append(" members)</span>", meter: &meter)
                case .array(let values):
                    try output.append(" <span class=\"kind\">array (", meter: &meter)
                    try output.decimal(UInt64(values.count), meter: &meter)
                    try output.append(" items)</span>", meter: &meter)
                default:
                    try output.append(" <code class=\"node-text\" data-search>", meter: &meter)
                    try highlighted(node, options: writing, output: &output, meter: &meter)
                    try output.append("</code>", meter: &meter)
                }
                try output.append(" <span class=\"pointer-label\" aria-label=\"Pointer as JSON string\">", meter: &meter)
                for byte in quotedPointer { try output.escaped(byte, meter: &meter) }
                try meter.release(UInt64(quotedPointer.count)); quotedPointer = []
                try output.append("</span><span class=\"pointer-actions\">", meter: &meter)
                for (action, title) in [("copy-pointer", "Copy Pointer (RFC 6901)"), ("copy-pointer-escaped", "Copy Pointer as JSON string"), ("download-pointer", "Download Pointer (UTF-8)")] {
                    try meter.work()
                    try output.append("<button type=\"button\" data-action=\"", meter: &meter)
                    try output.append(action, meter: &meter)
                    try output.append("\" data-node=\"jh-n-", meter: &meter)
                    try output.decimal(UInt64(id), meter: &meter)
                    try output.append("\">", meter: &meter)
                    try output.append(title, meter: &meter)
                    try output.append("</button>", meter: &meter)
                }
                try output.append("</span>", meter: &meter)
                try push(.close(container, component != nil), meter: &meter)
                switch node {
                case .object(let members):
                    try output.append("</summary><div class=\"children\">", meter: &meter)
                    for member in members.reversed() { try meter.work(); try push(.node(member.value, .key(member.key), level + 1), meter: &meter) }
                case .array(let values):
                    try output.append("</summary><div class=\"children\">", meter: &meter)
                    for index in values.indices.reversed() { try meter.work(); try push(.node(values[index], .index(index), level + 1), meter: &meter) }
                default: break
                }
            }
        }
        try output.append("</section>", meter: &meter)
        if options.outlineDepth != nil {
            try output.append("<nav class=\"outline\" aria-label=\"Container outline\"><h2>Container outline</h2><ul>", meter: &meter)
            for entry in outline {
                try meter.work(); try output.addDOM(8, meter: &meter)
                try output.append("<li><a data-target=\"jh-n-", meter: &meter)
                try output.decimal(UInt64(entry.ordinal), meter: &meter)
                try output.append("\" href=\"#jh-n-", meter: &meter)
                try output.decimal(UInt64(entry.ordinal), meter: &meter)
                try output.append("\">Level ", meter: &meter)
                try output.decimal(UInt64(entry.level), meter: &meter)
                try output.append(": ", meter: &meter)
                try label(entry.component, output: &output, meter: &meter, searchable: false)
                try output.append("</a></li>", meter: &meter)
                try meter.release(40)
            }
            outline = []
            try output.append("</ul></nav>", meter: &meter)
        }
        try output.append("</div><section class=\"print-json\" aria-label=\"Complete formatted JSON for printing\"><pre><code>", meter: &meter)
        try highlighted(value, options: writing, output: &output, meter: &meter)
        try output.append("</code></pre></section></main><script>", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.script, meter: &meter)
        try output.append("</script></body></html>\n", meter: &meter)
        try meter.checkpoint()
        return output
    }

    private func nativeBytes(_ value: JSON, options: JSONWritingOptions, meter: inout JSONWorkMeter) throws -> [UInt8] {
        var cursor = JSONWritingCursor(value: value, options: options), bytes: [UInt8] = []
        while let byte = try cursor.next(meter: &meter) {
            try meter.work(); try meter.charge(.outputBytes); try meter.retain(1); bytes.append(byte)
        }
        return bytes
    }
    private func highlighted(_ value: JSON, options: JSONWritingOptions, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        var cursor = JSONWritingCursor(value: value, options: options)
        var active: JSONWritingTokenKind?
        while let token = try cursor.nextToken(meter: &meter) {
            if token.kind != active {
                if let active, active != .whitespace { try output.append("</span>", meter: &meter) }
                try output.addDOM(4, meter: &meter)
                if token.kind != .whitespace {
                    try output.append("<span class=\"", meter: &meter)
                    try output.append(token.kind.rawValue, meter: &meter)
                    try output.append("\">", meter: &meter)
                }
                active = token.kind
            }
            try output.escaped(token.byte, meter: &meter)
        }
        if let active, active != .whitespace { try output.append("</span>", meter: &meter) }
    }
    private func label(_ component: JSONLocationComponent?, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter, searchable: Bool) throws {
        switch component {
        case .key(let key):
            try output.append(searchable ? "<code class=\"key-label key\" data-search>" : "<code class=\"key\">", meter: &meter)
            var cursor = JSONWritingCursor(value: .string(key.string), options: .init(numberStyle: .preserved))
            while let byte = try cursor.next(meter: &meter) { try output.escaped(byte, meter: &meter) }
            try output.append("</code>", meter: &meter)
        case .index(let index):
            try output.append("[", meter: &meter); try output.decimal(UInt64(index), meter: &meter); try output.append("]", meter: &meter)
        case nil: try output.append("Root", meter: &meter)
        }
    }
    private func pointerBytes(_ path: [JSONLocationComponent], meter: inout JSONWorkMeter) throws -> [UInt8] {
        try meter.require(.pointerTokens, UInt64(path.count))
        var result: [UInt8] = []
        func emit(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
            try meter.work(); try meter.require(.pointerBytes, UInt64(result.count) + 1)
            try meter.charge(.outputBytes); try meter.retain(1); result.append(byte)
        }
        for component in path {
            try emit(47, meter: &meter)
            let token: String
            switch component {
            case .key(let key): token = key.string
            case .index(let index): try meter.retain(20); try meter.work(20); token = String(index)
            }
            for byte in token.utf8 {
                try meter.work()
                if byte == 126 || byte == 47 { try emit(126, meter: &meter); try emit(byte == 126 ? 48 : 49, meter: &meter) }
                else { try emit(byte, meter: &meter) }
            }
            if case .index = component { try meter.release(20) }
        }
        return result
    }
}

private enum InteractiveStep {
    case node(JSON, JSONLocationComponent?, Int)
    case close(Bool, Bool)
}
private struct OutlineEntry {
    let ordinal: UInt64
    let component: JSONLocationComponent?
    let level: Int
}

extension JSONHTMLDocumentBuffer {
    // Reserve the complete fixed decimal scratch before any owned formatting.
    package mutating func decimal(_ value: UInt64, meter: inout JSONWorkMeter) throws {
        try meter.retain(20)
        var remainder = value, digits: [UInt8] = []
        repeat { try meter.work(); digits.append(UInt8(remainder % 10) + 48); remainder /= 10 } while remainder > 0
        for byte in digits.reversed() { try appendByte(byte, meter: &meter) }
        try meter.release(20)
    }
    package mutating func base64(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws {
        let table = JSONHTMLInteractiveAssets.base64Alphabet
        var index = 0
        while index < bytes.count {
            try meter.work()
            let a = bytes[index], b = index + 1 < bytes.count ? bytes[index + 1] : 0, c = index + 2 < bytes.count ? bytes[index + 2] : 0
            try meter.retain(4)
            for byte in [table[Int(a >> 2)], table[Int((a & 3) << 4 | b >> 4)], index + 1 < bytes.count ? table[Int((b & 15) << 2 | c >> 6)] : 61, index + 2 < bytes.count ? table[Int(c & 63)] : 61] {
                try meter.work(); try addMetadata(meter: &meter); try appendByte(byte, meter: &meter)
            }
            try meter.release(4)
            index += min(3, bytes.count - index)
        }
    }
}
