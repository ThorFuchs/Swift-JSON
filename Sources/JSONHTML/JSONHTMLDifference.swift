// SPDX-License-Identifier: Apache-2.0
// Original static, script-free rendering of a structural difference as one combined tree.
import Foundation
import JSON

extension JSONHTMLRenderer {
    /// Renders the difference between two values as one combined, script-free HTML tree.
    ///
    /// The page uses the same exact equality and structure as
    /// `JSONPatch.difference(from:to:options:)`: equal decimals, decoded scalar keys
    /// and order-independent objects are unchanged; objects compare by exact key;
    /// arrays keep their equal prefix and suffix and compare the rest by position.
    ///
    /// Added values are marked `+` in `<ins>`, removed values `−` in `<del>` at their
    /// source position, and changed values show the source value followed by the
    /// target value. Markers carry visually hidden text, so the view never relies on
    /// color alone. Unchanged values and element runs are collapsed behind native
    /// disclosures, and a CSS-only control hides them. A list of changes links to each
    /// change by its JSON Pointer. The exact RFC 6902 patch, and both documents, can be
    /// downloaded without JavaScript.
    ///
    /// The view is always static: ``JSONHTMLRenderingOptions/presentation``,
    /// ``JSONHTMLRenderingOptions/layout`` and the preview settings are not used.
    /// Title, theme, indentation and limits apply. Both values, the comparison and
    /// the whole document share one cumulative core budget and the HTML capacities.
    ///
    /// - Returns: Owned UTF-8 HTML.
    /// - Throws: HTML or core resource/configuration failure, or cancellation.
    /// - Parameters:
    ///   - source: The earlier value.
    ///   - target: The later value.
    public func renderDifference(from source: JSON, to target: JSON) throws -> Data {
        try renderDifferenceWithReport(from: source, to: target).result
    }

    /// Renders the difference with cumulative successful accounting, including the final Data copy.
    ///
    /// See ``renderDifference(from:to:)`` for the view.
    ///
    /// - Returns: Complete HTML bytes and rendering statistics.
    /// - Throws: HTML or core resource/configuration failure, or cancellation.
    /// - Parameters:
    ///   - source: The earlier value.
    ///   - target: The later value.
    public func renderDifferenceWithReport(from source: JSON, to target: JSON) throws -> JSONHTMLRenderReport<Data> {
        var meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
        let retainedAtEntry = meter.used(.retainedBytes)
        let document: JSONHTMLDocumentBuffer
        do { document = try renderDifferenceBody(source, target, meter: &meter) }
        catch {
            meter.recordFailure(error)
            try meter.release(meter.used(.retainedBytes) - retainedAtEntry)
            throw error
        }
        for _ in document.bytes { try meter.work(); try meter.retain(1) }
        let result = Data(document.bytes)
        try meter.release(UInt64(document.bytes.count)); try meter.checkpoint()
        return .init(result: result, statistics: document.statistics(meter.statistics()))
    }

    private enum DifferenceKind { case added, removed, changed }
    private struct DifferenceChange { let kind: DifferenceKind; let path: [JSONLocationComponent] }
    private enum DifferenceLabel { case key(JSONKey), element(source: Int?, target: Int?) }

    private func renderDifferenceBody(_ source: JSON, _ target: JSON, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        try meter.checkpoint()
        try options.limits.validate()
        guard (0...8).contains(options.indentation), (1...8).contains(options.tabWidth) else { throw JSONHTMLFailure.invalidConfiguration }
        try JSONAdmission.text(options.title, meter: &meter)
        for byte in options.title.utf8 {
            try meter.work()
            guard byte >= 32 && byte != 127 else { throw JSONHTMLFailure.invalidConfiguration }
        }
        try JSONAdmission.value(source, meter: &meter)
        try meter.resetValueBounds(); try JSONAdmission.value(target, meter: &meter)
        let writing = JSONWritingOptions(limits: options.limits.core, indentation: options.indentation,
                                         numberStyle: .preserved, indentationUnit: options.indentationUnit)

        // Pass 1: the ordered list of changes, with their locations.
        var changes: [DifferenceChange] = []
        do {
            var walker = JSONDifferenceWalker(source: source, target: target)
            var path: [JSONLocationComponent] = [], pending: JSONLocationComponent? = nil
            func record(_ kind: DifferenceKind, meter: inout JSONWorkMeter) throws {
                var location = path
                if let pending { location.append(pending) }
                for _ in location { try meter.work() }
                try meter.retain(JSONLogicalWeights.frame + 16 * UInt64(location.count))
                changes.append(.init(kind: kind, path: location))
            }
            while let event = try walker.next(meter: &meter) {
                switch event {
                case .member(let key): pending = .key(key)
                case .element(let s, let t): pending = .index(t ?? s ?? 0)
                case .same, .sameElements: pending = nil
                case .added: try record(.added, meter: &meter); pending = nil
                case .removed: try record(.removed, meter: &meter); pending = nil
                case .replaced: try record(.changed, meter: &meter); pending = nil
                case .beginObject, .beginArray:
                    if let pending { try meter.retain(16); path.append(pending) }
                    pending = nil
                case .endObject, .endArray: if !path.isEmpty { path.removeLast() }
                }
            }
        }
        let added = changes.filter { $0.kind == .added }.count
        let removed = changes.filter { $0.kind == .removed }.count
        let changed = changes.count - added - removed

        var output = JSONHTMLDocumentBuffer(limits: options.limits)
        try output.addDOM(40, meter: &meter)
        try output.append("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'none'; style-src 'sha256-", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.styleHash, meter: &meter)
        try output.append("' 'sha256-", meter: &meter)
        try output.append(JSONHTMLDifferenceAssets.cssHash, meter: &meter)
        try output.append("'; base-uri 'none'; form-action 'none'; object-src 'none'\"><title>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</title><style>", meter: &meter)
        try output.append(JSONHTMLAssets.css, meter: &meter)
        try output.append("\n", meter: &meter)
        try output.append(JSONHTMLInteractiveAssets.css, meter: &meter)
        try output.append("</style><style>", meter: &meter)
        try output.append(JSONHTMLDifferenceAssets.css, meter: &meter)
        try output.append("</style></head><body class=\"rich diff ", meter: &meter)
        try output.append(options.theme.rawValue, meter: &meter)
        try output.append(" tabs-", meter: &meter)
        try output.decimal(UInt64(options.tabWidth), meter: &meter)
        try output.append("\"><main><header class=\"document-header\"><h1>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</h1><p class=\"diff-summary\">", meter: &meter)
        if changes.isEmpty {
            try output.append("No differences: both values are equal.", meter: &meter)
        } else {
            try output.append("<span class=\"diff-count diff-added\">", meter: &meter)
            try output.decimal(UInt64(added), meter: &meter)
            try output.append(" added</span> <span class=\"diff-count diff-removed\">", meter: &meter)
            try output.decimal(UInt64(removed), meter: &meter)
            try output.append(" removed</span> <span class=\"diff-count diff-changed\">", meter: &meter)
            try output.decimal(UInt64(changed), meter: &meter)
            try output.append(" changed</span>", meter: &meter)
        }
        try output.append("</p></header>", meter: &meter)

        // Downloads: the exact patch and both documents, as native writer bytes.
        let patch = try patchBytes(source, target, meter: &meter)
        output.setCopyBytes(UInt64(patch.count))
        try output.addDOM(12, meter: &meter)
        try output.append("<p class=\"source-download diff-downloads\"><a download=\"patch.json\" href=\"data:application/json-patch+json;charset=utf-8;base64,", meter: &meter)
        try output.base64(patch, meter: &meter)
        try output.append("\">Download RFC 6902 patch</a>", meter: &meter)
        try meter.release(UInt64(patch.count))
        for (name, value) in [("source", source), ("target", target)] {
            let bytes = try nativeBytes(value, options: writing, meter: &meter)
            try output.append(" <a download=\"" + name + ".json\" href=\"data:application/json;charset=utf-8;base64,", meter: &meter)
            try output.base64(bytes, meter: &meter)
            try output.append("\">Download " + name + " JSON</a>", meter: &meter)
            try meter.release(UInt64(bytes.count))
        }
        try output.append("</p>", meter: &meter)
        if !changes.isEmpty {
            try output.append("<p class=\"diff-filter\"><input type=\"checkbox\" id=\"jd-only\"><label for=\"jd-only\">Show changes only</label></p>", meter: &meter)
        }

        try output.append("<div class=\"layout\"><section class=\"tree diff-tree\" aria-label=\"Combined difference\">", meter: &meter)
        try differenceTree(source, target, writing: writing, output: &output, meter: &meter)
        try output.append("</section>", meter: &meter)
        if !changes.isEmpty {
            try output.append("<nav class=\"outline diff-changes\" aria-label=\"Changes\"><h2>Changes</h2><ol>", meter: &meter)
            for (ordinal, change) in changes.enumerated() {
                try meter.work()
                try output.addOutline(meter: &meter)
                try output.addDOM(8, meter: &meter)
                try output.append("<li class=\"", meter: &meter)
                try output.append(Self.differenceClass(change.kind), meter: &meter)
                try output.append("\"><a href=\"#jd-c-", meter: &meter)
                try output.decimal(UInt64(ordinal), meter: &meter)
                try output.append("\">", meter: &meter)
                try output.append(Self.differenceWord(change.kind), meter: &meter)
                try output.append(" <code>", meter: &meter)
                let pointer = try pointerBytes(change.path, meter: &meter)
                if pointer.isEmpty { try output.append("(root)", meter: &meter) }
                else { for byte in pointer { try output.escaped(byte, meter: &meter) } }
                try meter.release(UInt64(pointer.count))
                try output.append("</code></a></li>", meter: &meter)
            }
            try output.append("</ol></nav>", meter: &meter)
        }
        try output.append("</div></main></body></html>\n", meter: &meter)
        try meter.checkpoint()
        return output
    }

    private static func differenceClass(_ kind: DifferenceKind) -> String {
        switch kind { case .added: "diff-added"; case .removed: "diff-removed"; case .changed: "diff-changed" }
    }
    private static func differenceWord(_ kind: DifferenceKind) -> String {
        switch kind { case .added: "Added"; case .removed: "Removed"; case .changed: "Changed" }
    }

    /// The RFC 6902 operations as compact native JSON bytes.
    private func patchBytes(_ source: JSON, _ target: JSON, meter: inout JSONWorkMeter) throws -> [UInt8] {
        let operations = try JSONDifferenceWalker.operations(from: source, to: target, meter: &meter)
        var values: [JSON] = []
        for operation in operations {
            try meter.work()
            let pointer = try JSONPointer.decodedTokens(operation.path, meter: &meter).encodedString(meter: &meter)
            let name = switch operation.kind { case .add: "add"; case .remove: "remove"; case .replace: "replace" }
            var members = [JSONMember("op", value: .string(name)), JSONMember("path", value: .string(pointer))]
            if let value = operation.value { members.append(JSONMember("value", value: value)) }
            try meter.retain(JSONLogicalWeights.frame)
            values.append(.object(try JSONObject.checked(members: members, meter: &meter)))
        }
        return try nativeBytes(.array(values), options: .init(limits: options.limits.core, numberStyle: .preserved), meter: &meter)
    }

    /// Pass 2: the combined tree, with one anchor per change in the same order as pass 1.
    private func differenceTree(_ source: JSON, _ target: JSON, writing: JSONWritingOptions,
                                output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        var walker = JSONDifferenceWalker(source: source, target: target)
        var closers: [String] = []
        var inArray: [Bool] = []
        var pending: DifferenceLabel? = nil
        var ordinal: UInt64 = 0
        func open(_ classes: String, change: Bool, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
            try output.addNode(meter: &meter)
            try output.addDOM(8, meter: &meter)
            let element = inArray.last == true
            try output.append(element ? "<li class=\"diff-row " : "<div class=\"field-row diff-row ", meter: &meter)
            try output.append(classes, meter: &meter)
            try output.append("\"", meter: &meter)
            if change {
                try output.append(" id=\"jd-c-", meter: &meter); try output.decimal(ordinal, meter: &meter)
                try output.append("\" tabindex=\"-1\"", meter: &meter)
                ordinal += 1
            }
            try output.append(">", meter: &meter)
            switch pending {
            case .key(let key):
                try output.append("<dt>", meter: &meter)
                try label(.key(key), output: &output, meter: &meter, searchable: false)
                try output.append("</dt><dd>", meter: &meter)
            case .element(let s, let t):
                try output.append("<span class=\"index-label\">", meter: &meter)
                if let t { try output.append("#", meter: &meter); try output.decimal(UInt64(t), meter: &meter) }
                else if let s { try output.append("was #", meter: &meter); try output.decimal(UInt64(s), meter: &meter) }
                try output.append("</span> ", meter: &meter)
            case nil:
                try output.append("<span class=\"index-label\">Root</span> ", meter: &meter)
            }
        }
        func close(output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
            if case .key = pending { try output.append("</dd>", meter: &meter) }
            try output.append(inArray.last == true ? "</li>" : "</div>", meter: &meter)
            pending = nil
        }
        func mark(_ symbol: String, _ text: String, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
            try output.append("<span class=\"diff-mark\" aria-hidden=\"true\">" + symbol + "</span><span class=\"visually-hidden\">" + text + "</span>", meter: &meter)
        }
        func value(_ value: JSON, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
            let container: Bool
            switch value { case .object, .array: container = true; default: container = false }
            try output.addDOM(4, meter: &meter)
            try output.append(container ? "<pre class=\"diff-value\"><code>" : "<code class=\"diff-value\">", meter: &meter)
            try highlighted(value, options: container ? writing : .init(limits: writing.limits, numberStyle: .preserved), output: &output, meter: &meter)
            try output.append(container ? "</code></pre>" : "</code>", meter: &meter)
        }
        func summary(_ value: JSON) -> String {
            switch value {
            case .object(let o): "Unchanged object, \(o.count) member\(o.count == 1 ? "" : "s")"
            case .array(let a): "Unchanged array, \(a.count) element\(a.count == 1 ? "" : "s")"
            default: "Unchanged"
            }
        }
        while let event = try walker.next(meter: &meter) {
            switch event {
            case .member(let key): pending = .key(key)
            case .element(let s, let t): pending = .element(source: s, target: t)
            case .same(let v):
                try open("diff-same", change: false, output: &output, meter: &meter)
                switch v {
                case .object, .array:
                    try output.addDOM(3, meter: &meter)
                    try output.append("<details class=\"diff-unchanged\"><summary>" + summary(v) + "</summary>", meter: &meter)
                    try value(v, output: &output, meter: &meter)
                    try output.append("</details>", meter: &meter)
                default: try value(v, output: &output, meter: &meter)
                }
                try close(output: &output, meter: &meter)
            case .sameElements(let run, let s, let t):
                try output.addNode(meter: &meter); try output.addDOM(6, meter: &meter)
                try output.append("<li class=\"diff-row diff-same diff-run\"><details class=\"diff-unchanged\"><summary>", meter: &meter)
                try output.append(run.count == 1 ? "Element #" : "Elements #", meter: &meter)
                try output.decimal(UInt64(t), meter: &meter)
                if run.count > 1 { try output.append("–#", meter: &meter); try output.decimal(UInt64(t + run.count - 1), meter: &meter) }
                try output.append(" unchanged", meter: &meter)
                if s != t { try output.append(" (was #", meter: &meter); try output.decimal(UInt64(s), meter: &meter); try output.append(")", meter: &meter) }
                try output.append("</summary><ol class=\"diff-list\" start=\"", meter: &meter)
                try output.decimal(UInt64(t), meter: &meter)
                try output.append("\">", meter: &meter)
                for element in run {
                    try meter.work(); try output.addDOM(2, meter: &meter)
                    try output.append("<li>", meter: &meter); try value(element, output: &output, meter: &meter); try output.append("</li>", meter: &meter)
                }
                try output.append("</ol></details></li>", meter: &meter)
                pending = nil
            case .added(let v):
                try open("diff-added", change: true, output: &output, meter: &meter)
                try mark("+", "Added: ", output: &output, meter: &meter)
                try output.append("<ins>", meter: &meter); try value(v, output: &output, meter: &meter); try output.append("</ins>", meter: &meter)
                try close(output: &output, meter: &meter)
            case .removed(let v):
                try open("diff-removed", change: true, output: &output, meter: &meter)
                try mark("−", "Removed: ", output: &output, meter: &meter)
                try output.append("<del>", meter: &meter); try value(v, output: &output, meter: &meter); try output.append("</del>", meter: &meter)
                try close(output: &output, meter: &meter)
            case .replaced(let a, let b):
                try open("diff-changed", change: true, output: &output, meter: &meter)
                try mark("~", "Changed from ", output: &output, meter: &meter)
                try output.append("<del>", meter: &meter); try value(a, output: &output, meter: &meter)
                try output.append("</del> <span class=\"diff-arrow\" aria-hidden=\"true\">→</span><span class=\"visually-hidden\"> to </span> <ins>", meter: &meter)
                try value(b, output: &output, meter: &meter); try output.append("</ins>", meter: &meter)
                try close(output: &output, meter: &meter)
            case .beginObject, .beginArray:
                let array: Bool
                if case .beginArray = event { array = true } else { array = false }
                try open("diff-nested", change: false, output: &output, meter: &meter)
                try output.addDOM(4, meter: &meter)
                try output.append(array ? "<details open class=\"node container array diff-container\"><summary>Array with changes</summary><ol class=\"diff-list\">"
                                        : "<details open class=\"node container object diff-container\"><summary>Object with changes</summary><dl class=\"object-form\">", meter: &meter)
                var closing = array ? "</ol></details>" : "</dl></details>"
                if case .key = pending { closing += "</dd>" }
                closing += inArray.last == true ? "</li>" : "</div>"
                try meter.retain(JSONLogicalWeights.frame + UInt64(closing.utf8.count))
                closers.append(closing); inArray.append(array); pending = nil
            case .endObject, .endArray:
                inArray.removeLast()
                let closing = closers.removeLast()
                try output.append(closing, meter: &meter)
                try meter.release(JSONLogicalWeights.frame + UInt64(closing.utf8.count))
            }
        }
    }
}
