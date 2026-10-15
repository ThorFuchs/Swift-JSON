// SPDX-License-Identifier: Apache-2.0
import JSON

package enum JSONHTMLInlineToken {
    case text(Range<Int>)
    case escaped(Int)
    case open(String)
    case close(String)
    case math(JSONHTMLMathTree)
    case link(String, [JSONHTMLInlineToken], Bool)
    case image(JSONHTMLRaster, String)
    case imageReference(String, String)
}
package struct JSONHTMLInlinePlan {
    package let source: [Unicode.Scalar]
    package let tokens: [JSONHTMLInlineToken]
    package let formatted: Bool
    package let reservation: UInt64
    package func emit(output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        enum Step {
            case token(JSONHTMLInlineToken)
            case closeLink
        }
        var stack: [Step] = []
        func push(_ v: Step, _ m: inout JSONWorkMeter) throws {
            try m.retain(64)
            stack.append(v)
        }
        for t in tokens.reversed() {
            try meter.work()
            try push(.token(t), &meter)
        }
        while let step = stack.popLast() {
            try meter.release(64)
            try meter.work()
            switch step {
            case .closeLink: try output.append("</a>", meter: &meter)
            case .token(let t):
                switch t {
                case .text(let r):
                    for i in r {
                        try meter.work()
                        try JSONHTMLDisplay.text(
                            String(source[i]), quoted: false, output: &output, meter: &meter)
                    }
                case .escaped(let i):
                    try JSONHTMLDisplay.text(
                        String(source[i]), quoted: false, output: &output, meter: &meter)
                case .open(let tag):
                    try output.addDOM(2, meter: &meter)
                    try output.append("<" + tag + ">", meter: &meter)
                case .close(let tag): try output.append("</" + tag + ">", meter: &meter)
                case .math(let tree): try tree.emit(output: &output, meter: &meter)
                case .link(let destination, let label, let active):
                    try output.addDOM(4, meter: &meter)
                    if active {
                        try output.append(
                            "<a rel=\"noopener noreferrer\" referrerpolicy=\"no-referrer\" href=\"",
                            meter: &meter
                        )
                        try output.escaped(destination, meter: &meter)
                        try output.append("\">", meter: &meter)
                        try push(.closeLink, &meter)
                    } else {
                        try output.append("<span class=\"inert-link\">", meter: &meter)
                        try JSONHTMLDisplay.text(
                            destination, quoted: false, output: &output, meter: &meter)
                        try output.append(" · </span>", meter: &meter)
                    }
                    for v in label.reversed() {
                        try meter.work()
                        try push(.token(v), &meter)
                    }
                case .image(let image, let alt):
                    try image.emit(alt: alt, output: &output, meter: &meter)
                    try output.addDOM(2, meter: &meter)
                    try output.append("<span class=\"image-alt\">", meter: &meter)
                    try JSONHTMLDisplay.text(alt, quoted: false, output: &output, meter: &meter)
                    try output.append("</span>", meter: &meter)
                case .imageReference(let alt, let destination):
                    try output.addDOM(2, meter: &meter)
                    try output.append(
                        "<span class=\"inert-image\">Image reference (not loaded): ", meter: &meter)
                    try JSONHTMLDisplay.text(alt, quoted: false, output: &output, meter: &meter)
                    try output.append(" · ", meter: &meter)
                    try JSONHTMLDisplay.text(
                        destination, quoted: false, output: &output, meter: &meter)
                    try output.append("</span>", meter: &meter)
                }
            }
        }
    }
}
private struct InlineFrame { let marker: Int, start: Int, token: Int }
package enum JSONHTMLInlineScanner {
    package static func scan(
        _ source: String, options: JSONHTMLRenderingOptions, ledger: inout JSONHTMLMediaLedger,
        meter: inout JSONWorkMeter
    ) throws -> JSONHTMLInlinePlan {
        let entry = meter.used(.retainedBytes)
        var chars: [Unicode.Scalar] = []
        for c in source.unicodeScalars {
            try meter.work()
            try meter.retain(4)
            chars.append(c)
        }
        let beforeBody = meter.used(.retainedBytes)
        let previousLedger = ledger
        let result: ([JSONHTMLInlineToken], Bool)
        do {
            result = try scanBody(
                chars, options: options, labelOnly: false, ledger: &ledger, meter: &meter)
        } catch is JSONHTMLPreviewRejection {
            try meter.release(meter.used(.retainedBytes) - beforeBody)
            ledger = previousLedger
            try meter.retain(64)
            result = ([.text(0..<chars.count)], false)
        }
        return .init(
            source: chars, tokens: result.0, formatted: result.1,
            reservation: meter.used(.retainedBytes) - entry)
    }
    private static func scanBody(
        _ chars: [Unicode.Scalar], options: JSONHTMLRenderingOptions, labelOnly: Bool,
        ledger: inout JSONHTMLMediaLedger, meter: inout JSONWorkMeter
    ) throws -> ([JSONHTMLInlineToken], Bool) {
        var tokens: [JSONHTMLInlineToken] = []
        var frames: [InlineFrame] = []
        var i = 0
        var formatted = false
        func append(_ t: JSONHTMLInlineToken, _ m: inout JSONWorkMeter) throws {
            try m.work()
            guard UInt64(tokens.count) < options.previewPolicy.maxInlineTokens else {
                throw JSONHTMLPreviewRejection.eligibility
            }
            try m.retain(64)
            tokens.append(t)
        }
        func plain(_ range: Range<Int>, _ m: inout JSONWorkMeter) throws {
            if !range.isEmpty { try append(.text(range), &m) }
        }
        func isSpace(_ c: Unicode.Scalar) -> Bool {
            c == " " || c == "\n" || c == "\r" || c == "\t"
        }
        func slice(_ r: Range<Int>, _ m: inout JSONWorkMeter) throws -> String {
            var s = ""
            for n in r {
                try m.work()
                for _ in chars[n].utf8 {
                    try m.work()
                    try m.retain(1)
                }
                s.unicodeScalars.append(chars[n])
            }
            return s
        }
        while i < chars.count {
            try meter.work()
            // Block-looking lines and fence/backtick ranges remain intact literal source.
            let lineStart = i == 0 || chars[i - 1] == "\n"
            var listMarker = false
            if lineStart && (48...57).contains(chars[i].value) {
                var n = i
                while n < chars.count && (48...57).contains(chars[n].value) {
                    try meter.work()
                    n += 1
                }
                listMarker = n + 1 < chars.count && chars[n] == "." && isSpace(chars[n + 1])
            }
            let indentedBlock =
                lineStart
                && (chars[i] == "\t"
                    || i + 3 < chars.count && chars[i] == " " && chars[i + 1] == " "
                        && chars[i + 2] == " "
                        && chars[i + 3] == " ")
            if indentedBlock
                || lineStart
                    && (chars[i] == "#" || chars[i] == ">" || chars[i] == "|"
                        || ((chars[i] == "-" || chars[i] == "+" || chars[i] == "*")
                            && i + 1 < chars.count
                            && isSpace(chars[i + 1]))
                        || listMarker)
            {
                var end = i
                while end < chars.count && chars[end] != "\n" {
                    try meter.work()
                    end += 1
                }
                try plain(i..<end, &meter)
                i = end
                continue
            }
            if chars[i] == "`"
                || lineStart && chars[i] == "~" && i + 2 < chars.count && chars[i + 1] == "~"
                    && chars[i + 2] == "~"
            {
                let marker = chars[i]
                var width = 1
                while i + width < chars.count && chars[i + width] == marker {
                    try meter.work()
                    width += 1
                }
                var at = i + width
                var end = chars.count
                while at < chars.count {
                    try meter.work()
                    if chars[at] == marker {
                        var run = 1
                        while at + run < chars.count && chars[at + run] == marker {
                            try meter.work()
                            run += 1
                        }
                        if run == width
                            && (!(lineStart && width >= 3) || at == 0 || chars[at - 1] == "\n")
                        {
                            end = at + run
                            break
                        }
                        at += run
                    } else {
                        at += 1
                    }
                }
                try plain(i..<end, &meter)
                i = end
                continue
            }
            if chars[i] == "\\", i + 1 < chars.count,
                "\\`*[]()!$~".unicodeScalars.contains(chars[i + 1])
            {
                // Parenthesized math is recognized before ordinary punctuation escaping.
                if !labelOnly && chars[i + 1] == "(" {
                    let start = i
                    var at = i + 2
                    var close: Int?
                    while at + 1 < chars.count && chars[at] != "\n" {
                        try meter.work()
                        if chars[at] == "\\" && chars[at + 1] == ")" {
                            close = at
                            break
                        }
                        at += 1
                    }
                    if let close {
                        let interior = try slice((i + 2)..<close, &meter)
                        if let tree = try JSONHTMLMiniMath.parse(
                            interior, policy: options.previewPolicy, meter: &meter)
                        {
                            try append(.math(tree), &meter)
                            formatted = true
                        } else {
                            try plain(start..<(close + 2), &meter)
                        }
                        try meter.release(UInt64(interior.utf8.count))
                        i = close + 2
                        continue
                    }
                    try plain(start..<chars.count, &meter)
                    i = chars.count
                    continue
                }
                try append(.escaped(i + 1), &meter)
                i += 2
                continue
            }
            if !labelOnly && chars[i] == "$" {
                if i + 1 < chars.count && chars[i + 1] == "$" {
                    var at = i + 2
                    while at + 1 < chars.count && !(chars[at] == "$" && chars[at + 1] == "$") {
                        try meter.work()
                        at += 1
                    }
                    let end = at + 1 < chars.count ? at + 2 : chars.count
                    try plain(i..<end, &meter)
                    i = end
                    continue
                }
                var at = i + 1
                var close: Int?
                while at < chars.count && chars[at] != "\n" {
                    try meter.work()
                    if chars[at] == "\\" && at + 1 < chars.count {
                        at += 2
                        continue
                    }
                    if chars[at] == "$" {
                        close = at
                        break
                    }
                    at += 1
                }
                if let close {
                    let valid =
                        close > i + 1 && !isSpace(chars[i + 1]) && !isSpace(chars[close - 1])
                        && (close + 1 == chars.count || chars[close + 1] != "$")
                    if valid {
                        let interior = try slice((i + 1)..<close, &meter)
                        if let tree = try JSONHTMLMiniMath.parse(
                            interior, policy: options.previewPolicy, meter: &meter)
                        {
                            try append(.math(tree), &meter)
                            formatted = true
                        } else {
                            try plain(i..<(close + 1), &meter)
                        }
                        try meter.release(UInt64(interior.utf8.count))
                    } else {
                        try plain(i..<(close + 1), &meter)
                    }
                    i = close + 1
                    continue
                }
                try plain(i..<chars.count, &meter)
                i = chars.count
                continue
            }
            if !labelOnly
                && (chars[i] == "["
                    || chars[i] == "!" && i + 1 < chars.count && chars[i + 1] == "[")
            {
                let start = i
                let image = chars[i] == "!"
                let labelStart = i + (chars[i] == "!" ? 2 : 1)
                var at = labelStart
                var closeLabel: Int?
                while at < chars.count {
                    try meter.work()
                    if chars[at] == "\\" && at + 1 < chars.count {
                        at += 2
                        continue
                    }
                    if chars[at] == "]" {
                        closeLabel = at
                        break
                    }
                    at += 1
                }
                if let closeLabel, closeLabel + 1 < chars.count, chars[closeLabel + 1] == "(" {
                    at = closeLabel + 2
                    var depth = 1
                    var destination = ""
                    var valid = true
                    while at < chars.count && depth > 0 {
                        try meter.work()
                        let c = chars[at]
                        if c == "\\", at + 1 < chars.count,
                            "()\\".unicodeScalars.contains(chars[at + 1])
                        {
                            at += 1
                            let c = chars[at]
                            if UInt64(destination.utf8.count) + UInt64(c.utf8.count)
                                > options.previewPolicy.maxDestinationUTF8Bytes
                            {
                                valid = false
                            }
                            if valid {
                                for _ in c.utf8 {
                                    try meter.work()
                                    try meter.retain(1)
                                }
                                destination.unicodeScalars.append(c)
                            }
                            at += 1
                            continue
                        }
                        if c == "(" {
                            depth += 1
                            if UInt64(depth) > options.previewPolicy.maxInlineNesting {
                                valid = false
                            }
                        }
                        if c == ")" {
                            depth -= 1
                            if depth == 0 {
                                at += 1
                                break
                            }
                        }
                        if JSONHTMLDisplay.protected(c) || isSpace(c) || c == "\"" { valid = false }
                        if UInt64(destination.utf8.count) + UInt64(c.utf8.count)
                            > options.previewPolicy.maxDestinationUTF8Bytes
                        {
                            valid = false
                        }
                        if valid {
                            for _ in c.utf8 {
                                try meter.work()
                                try meter.retain(1)
                            }
                            destination.unicodeScalars.append(c)
                        }
                        at += 1
                    }
                    var label: [Unicode.Scalar] = []
                    var compound = false
                    for n in labelStart..<closeLabel {
                        try meter.work()
                        if "[]!$".unicodeScalars.contains(chars[n]) { compound = true }
                        try meter.retain(4)
                        label.append(chars[n])
                    }
                    valid =
                        valid && depth == 0 && !destination.isEmpty && !label.isEmpty && !compound
                    if valid && image && UInt64(label.count) <= options.previewPolicy.maxAltScalars
                    {
                        let alt = try slice(labelStart..<closeLabel, &meter)
                        if options.embeddedImagePreviews,
                            let media = try JSONHTMLRasterAdmission.decode(
                                destination, type: nil, policy: options.previewPolicy,
                                ledger: &ledger,
                                meter: &meter)
                        {
                            try append(.image(media, alt), &meter)
                        } else {
                            try append(.imageReference(alt, destination), &meter)
                        }
                        formatted = true
                    } else if valid && !image {
                        // Exactly one bounded label helper; nested links/images/math are rejected above.
                        var labelTokens = try scanBody(
                            label, options: options, labelOnly: true, ledger: &ledger, meter: &meter
                        )
                        // Label text ranges use the parent's scalar array, preserving one source authority.
                        for n in labelTokens.0.indices {
                            try meter.work()
                            switch labelTokens.0[n] {
                            case .text(let r):
                                labelTokens.0[n] = .text(
                                    (r.lowerBound + labelStart)..<(r.upperBound + labelStart))
                            case .escaped(let i): labelTokens.0[n] = .escaped(i + labelStart)
                            default: break
                            }
                        }
                        let active =
                            try options.linkActivation == .httpAndHTTPS
                            && activeURL(destination, meter: &meter)
                        try append(.link(destination, labelTokens.0, active), &meter)
                        formatted = true
                    } else {
                        try plain(start..<at, &meter)
                        try meter.release(UInt64(destination.utf8.count))
                    }
                    try meter.release(UInt64(label.count) * 4)
                    i = at
                    continue
                }
            }
            if chars[i] == "*" {
                var run = 1
                while i + run < chars.count && chars[i + run] == "*" {
                    try meter.work()
                    run += 1
                }
                let start = i
                var remaining = run
                if i > 0 && !isSpace(chars[i - 1]) {
                    while let frame = frames.last, remaining >= frame.marker {
                        try meter.work()
                        frames.removeLast()
                        try meter.release(32)
                        try append(.close(frame.marker == 2 ? "strong" : "em"), &meter)
                        formatted = true
                        remaining -= frame.marker
                        i += frame.marker
                    }
                }
                while remaining > 0 {
                    let width = remaining >= 2 ? 2 : 1
                    if i + remaining < chars.count && !isSpace(chars[i + remaining])
                        && UInt64(frames.count) < options.previewPolicy.maxInlineNesting
                    {
                        try meter.retain(32)
                        frames.append(.init(marker: width, start: i, token: tokens.count))
                        try append(.open(width == 2 ? "strong" : "em"), &meter)
                    } else {
                        try plain(i..<(i + width), &meter)
                    }
                    i += width
                    remaining -= width
                }
                if i == start { i += run }
                continue
            }
            let start = i
            i += 1
            while i < chars.count && !"*[$!\\`\n".unicodeScalars.contains(chars[i]) {
                try meter.work()
                i += 1
            }
            try plain(start..<i, &meter)
        }
        // Unmatched frames become literal delimiters, never synthetic repaired closers.
        for frame in frames {
            try meter.work()
            tokens[frame.token] = .text(frame.start..<(frame.start + frame.marker))
            try meter.release(32)
        }
        return (tokens, formatted)
    }
    package static func activeURL(_ source: String, meter: inout JSONWorkMeter) throws -> Bool {
        let entry = meter.used(.retainedBytes)
        var bytes: [UInt8] = []
        for b in source.utf8 {
            try meter.work()
            guard b > 32, b < 127, !Array("<>\\\"`{}|".utf8).contains(b) else {
                try meter.release(meter.used(.retainedBytes) - entry)
                return false
            }
            try meter.retain(1)
            bytes.append(b)
        }
        defer { bytes = [] }
        let result = try urlBytes(bytes, meter: &meter)
        try meter.release(UInt64(bytes.count))
        return result
    }
    private static func urlBytes(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws -> Bool {
        var start = 0
        if bytes.prefix(7).map({ $0 >= 65 && $0 <= 90 ? $0 + 32 : $0 }) == Array("http://".utf8) {
            start = 7
        } else if bytes.prefix(8).map({ $0 >= 65 && $0 <= 90 ? $0 + 32 : $0 })
            == Array("https://".utf8)
        {
            start = 8
        } else {
            return false
        }
        var end = start
        while end < bytes.count && ![47, 63, 35].contains(bytes[end]) {
            try meter.work()
            end += 1
        }
        guard end > start else { return false }
        for b in bytes[start..<end] {
            try meter.work()
            guard b != 64, b != 37,
                (48...57).contains(b) || (65...90).contains(b) || (97...122).contains(b)
                    || [45, 46, 58, 91, 93].contains(b)
            else { return false }
        }
        let authority = bytes[start..<end]
        if authority.first == 91 {
            guard let close = authority.firstIndex(of: 93), close > start + 1 else { return false }
            for b in bytes[(start + 1)..<close] {
                try meter.work()
                guard
                    (48...57).contains(b) || (65...70).contains(b) || (97...102).contains(b)
                        || b == 58
                        || b == 46
                else { return false }
            }
            if close + 1 < end {
                guard bytes[close + 1] == 58, try port(bytes[(close + 2)..<end], meter: &meter)
                else {
                    return false
                }
            }
        } else {
            var hostEnd = end
            if let colon = authority.firstIndex(of: 58) {
                hostEnd = colon
                guard try port(bytes[(colon + 1)..<end], meter: &meter) else { return false }
            }
            guard hostEnd > start else { return false }
            var labelStart = start
            for n in start...hostEnd {
                try meter.work()
                if n == hostEnd || bytes[n] == 46 {
                    guard n > labelStart, n - labelStart <= 63, bytes[labelStart] != 45,
                        bytes[n - 1] != 45
                    else { return false }
                    labelStart = n + 1
                } else {
                    guard
                        (48...57).contains(bytes[n]) || (65...90).contains(bytes[n])
                            || (97...122).contains(bytes[n]) || bytes[n] == 45
                    else { return false }
                }
            }
        }
        var i = end
        while i < bytes.count {
            try meter.work()
            if bytes[i] == 37 {
                guard i + 2 < bytes.count else { return false }
                for b in bytes[(i + 1)...(i + 2)] {
                    guard (48...57).contains(b) || (65...70).contains(b) || (97...102).contains(b)
                    else {
                        return false
                    }
                }
                i += 3
            } else {
                i += 1
            }
        }
        return true
    }
    private static func port(_ bytes: ArraySlice<UInt8>, meter: inout JSONWorkMeter) throws -> Bool
    {
        guard !bytes.isEmpty, bytes.count <= 5 else { return false }
        var n: UInt64 = 0
        for b in bytes {
            try meter.work()
            guard (48...57).contains(b) else { return false }
            n = n * 10 + UInt64(b - 48)
        }
        return n > 0 && n <= 65535
    }
}
