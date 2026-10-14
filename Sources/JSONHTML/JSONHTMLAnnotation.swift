// SPDX-License-Identifier: Apache-2.0
import JSON

/// A caller-supplied diagnostic addressed by exact typed JSON location.
///
/// Rendering does not validate schemas. An empty list makes no validity claim.
/// Negative array indices fail at rendering entry, including after a missing component.
public struct JSONHTMLAnnotation: Sendable {
    /// Human-readable severity; it does not change or establish validation results.
    public enum Severity: String, Sendable {
        /// Informational caller diagnostic.
        case information
        /// Warning supplied by the caller.
        case warning
        /// Error supplied by the caller, independent of renderer operational failures.
        case error
    }
    /// Exact keys and array indices; numeric keys remain keys.
    public let path: [JSONLocationComponent]
    /// The caller's diagnostic classification.
    public let severity: Severity
    /// Plain scalar text, escaped visibly and admitted under finite diagnostic/text limits.
    public let message: String
    /// Creates a diagnostic without traversing a root or allocating a renderer.
    /// - Parameters:
    ///   - path: Typed target; a missing target is identified at its nearest existing parent.
    ///   - severity: Caller diagnostic classification, displayed as text.
    ///   - message: Plain text; no arbitrary Error description is obtained automatically.
    public init(path: [JSONLocationComponent], severity: Severity, message: String) {
        self.path = path; self.severity = severity; self.message = message
    }
}

// Borrow caller annotations by ordinal; do not copy payloads or retain roots in output.
package struct JSONHTMLBoundAnnotation {
    package let index: Int
    package let prefixCount: Int
    package var ordinal: UInt64 = 0
    package var span: JSONSourceSpan?
}
private enum AnnotationStep {
    case node(JSON, JSONLocationComponent?)
    case pop
}

extension JSONHTMLRenderer {
    // Every admission, selection, comparison and map scan uses the enclosing writing meter.
    package func bindAnnotations(_ value: JSON, document: JSONDocument?, meter: inout JSONWorkMeter) throws -> [JSONHTMLBoundAnnotation] {
        try JSONHTMLDocumentBuffer.require(.annotations, UInt64(options.annotations.count), options.limits.maxAnnotations)
        guard !options.annotations.isEmpty else { return [] }
        if let map = document?.sourceMap, let bytes = document?.sourceBytes {
            try meter.require(.sourceMapEntries, UInt64(map.entries.count))
            try meter.require(.inputBytes, UInt64(bytes.count))
        }
        var records: [JSONHTMLBoundAnnotation] = []
        for (index, annotation) in options.annotations.enumerated() {
            try meter.work()
            try meter.require(.pointerTokens, UInt64(annotation.path.count))
            try JSONAdmission.text(annotation.message, meter: &meter)
            for _ in annotation.message.utf8 { try meter.work(); try meter.charge(.diagnosticBytes) }
            var pathBytes: UInt64 = 0
            for component in annotation.path {
                try meter.work()
                // Count the full RFC 6901 spelling, including failed suffixes, before binding.
                pathBytes = try meter.adding(.pointerBytes, pathBytes, 1)
                switch component {
                case .key(let key):
                    try JSONAdmission.text(key.string, key: true, meter: &meter)
                    for byte in key.string.utf8 {
                        try meter.work(); try meter.charge(.diagnosticBytes)
                        pathBytes = try meter.adding(.pointerBytes, pathBytes, byte == 126 || byte == 47 ? 2 : 1)
                    }
                case .index(let index):
                    guard index >= 0 else { throw JSONHTMLFailure.invalidConfiguration }
                    var number = index
                    repeat {
                        try meter.work(); try meter.charge(.diagnosticBytes)
                        pathBytes = try meter.adding(.pointerBytes, pathBytes, 1); number /= 10
                    } while number > 0
                }
            }
            var selected = value, prefix = 0
            for component in annotation.path {
                try meter.work()
                let next: JSON?
                switch (selected, component) {
                case (.object(let object), .key(let key)): next = try object.lookup(key.string, meter: &meter)
                case (.array(let array), .index(let index)):
                    // JSON itself admits nil literals; a ternary can wrap JSON.null in Optional.
                    if index < array.count { next = array[index] } else { next = nil }
                default: next = nil
                }
                guard let next else { break }
                selected = next; prefix += 1
            }
            try meter.retain(64); records.append(.init(index: index, prefixCount: prefix))
        }
        var path: [JSONLocationComponent] = [], steps: [AnnotationStep] = []
        func push(_ step: AnnotationStep, meter: inout JSONWorkMeter) throws {
            try meter.retain(JSONLogicalWeights.frame); steps.append(step)
        }
        try push(.node(value, nil), meter: &meter)
        var ordinal: UInt64 = 0
        while let step = steps.popLast() {
            try meter.release(JSONLogicalWeights.frame); try meter.work()
            switch step {
            case .pop: path.removeLast(); try meter.release(JSONLogicalWeights.frame)
            case .node(let node, let component):
                if let component {
                    try meter.retain(JSONLogicalWeights.frame); path.append(component)
                    try push(.pop, meter: &meter)
                }
                for index in records.indices {
                    try meter.work()
                    let record = records[index], annotation = options.annotations[record.index]
                    guard record.prefixCount == path.count else { continue }
                    var equal = true
                    for part in path.indices {
                        try meter.work()
                        switch (path[part], annotation.path[part]) {
                        case (.key(let a), .key(let b)): equal = try JSONComparison.textEquals(a.string, b.string, meter: &meter)
                        case (.index(let a), .index(let b)): equal = a == b
                        default: equal = false
                        }
                        if !equal { break }
                    }
                    if equal {
                        records[index].ordinal = ordinal
                        if let map = document?.sourceMap {
                            records[index].span = try map.span(at: path, meter: &meter)
                        }
                    }
                }
                ordinal = try JSONHTMLDocumentBuffer.adding(.renderedJSONNodes, ordinal, 1, options.limits.maxRenderedJSONNodes)
                switch node {
                case .object(let object):
                    for member in object.reversed() { try meter.work(); try push(.node(member.value, .key(member.key)), meter: &meter) }
                case .array(let array):
                    for index in array.indices.reversed() { try meter.work(); try push(.node(array[index], .index(index)), meter: &meter) }
                default: break
                }
            }
        }
        return records
    }

    package func hasAnnotations(at ordinal: UInt64, in records: [JSONHTMLBoundAnnotation], meter: inout JSONWorkMeter) throws -> Bool {
        for record in records { try meter.work(); if record.ordinal == ordinal { return true } }
        return false
    }
    package func annotationDescription(at ordinal: UInt64, in records: [JSONHTMLBoundAnnotation], output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        var started = false
        for record in records {
            try meter.work()
            guard record.ordinal == ordinal else { continue }
            try output.append(started ? " jh-a-" : " aria-describedby=\"jh-a-", meter: &meter)
            try output.decimal(UInt64(record.index), meter: &meter); started = true
        }
        if started { try output.append("\"", meter: &meter) }
    }
    package func annotationSection(_ records: [JSONHTMLBoundAnnotation], output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        output.setAnnotations(UInt64(records.count))
        guard !records.isEmpty else { return }
        try output.addDOM(16, meter: &meter)
        try output.append("<section aria-label=\"Caller diagnostics\"><h2>Caller diagnostics</h2><p>Supplied annotations; rendering does not establish schema validity. Source spans are zero-based half-open UTF-8 byte ranges.</p><ol>", meter: &meter)
        for record in records {
            try meter.work(); try output.addDOM(32, meter: &meter)
            let annotation = options.annotations[record.index]
            let missing = record.prefixCount != annotation.path.count
            try output.append("<li id=\"jh-a-", meter: &meter)
            try output.decimal(UInt64(record.index), meter: &meter)
            try output.append("\" data-missing=\"", meter: &meter)
            try output.append(missing ? "true" : "false", meter: &meter)
            try output.append("\"><strong>", meter: &meter)
            try output.append(annotation.severity.rawValue, meter: &meter)
            try output.append("</strong>: <a href=\"#jh-n-", meter: &meter)
            try output.decimal(record.ordinal, meter: &meter)
            try output.append("\" data-target=\"jh-n-", meter: &meter)
            try output.decimal(record.ordinal, meter: &meter)
            try output.append("\">", meter: &meter)
            try output.append(missing ? "Missing target; nearest existing parent" : "Target value", meter: &meter)
            try output.append("</a><p>Attempted typed path: <code>Root", meter: &meter)
            for component in annotation.path {
                try meter.work(); try output.addDOM(2, meter: &meter)
                switch component {
                case .key(let key):
                    try output.append(" / key ", meter: &meter)
                    try annotationText(key.string, output: &output, meter: &meter)
                case .index(let index):
                    try output.append(" / index [", meter: &meter); try output.decimal(UInt64(index), meter: &meter)
                    try output.append("]", meter: &meter)
                }
            }
            try output.append("</code></p><p>Message: <code>", meter: &meter)
            try annotationText(annotation.message, output: &output, meter: &meter)
            try output.append("</code></p>", meter: &meter)
            if let span = record.span {
                try output.append(missing ? "<p>Parent source span: " : "<p>Value source span: ", meter: &meter)
                try output.decimal(span.start, meter: &meter); try output.append("..&lt;", meter: &meter)
                try output.decimal(span.end, meter: &meter); try output.append(" bytes</p>", meter: &meter)
            }
            try output.append("</li>", meter: &meter)
        }
        try output.append("</ol></section>", meter: &meter)
    }
    private func annotationText(_ text: String, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        // Visible JSON-style quoting plus explicit C1/bidi-control spelling prevents
        // presentation normalization/spoofing; exact target identity uses the original path.
        try output.escaped(34, meter: &meter)
        for scalar in text.unicodeScalars {
            try meter.work()
            let value = scalar.value
            if value < 32 || (127...159).contains(value) || (0x202a...0x202e).contains(value) || (0x2066...0x2069).contains(value) {
                try output.append("\\u", meter: &meter)
                for shift in [12,8,4,0] {
                    try meter.work()
                    let digit = UInt8((value >> shift) & 15)
                    try output.appendByte(digit < 10 ? digit + 48 : digit + 87, meter: &meter)
                }
            } else if value == 34 || value == 92 {
                try output.escaped(92, meter: &meter); try output.escaped(UInt8(value), meter: &meter)
            } else {
                try meter.work(4); try meter.retain(4)
                let spelling = String(scalar)
                for byte in spelling.utf8 { try output.escaped(byte, meter: &meter) }
                try meter.release(4)
            }
        }
        try output.escaped(34, meter: &meter)
    }
}
