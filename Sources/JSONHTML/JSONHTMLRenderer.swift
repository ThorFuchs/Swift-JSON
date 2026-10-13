// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

/// An immutable facade producing complete, expanded, highlighted standalone HTML.
///
/// Rendering is actor-independent and executes no browser or UI framework. It uses
/// the strict JSON writer's exact bytes, insertion order and preserved lexemes.
/// CSS is fixed and hash-authorized; scripts and external resources are denied.
public struct JSONHTMLRenderer: Sendable {
    /// Immutable configuration; finite capacities are checked on every invocation.
    public let options: JSONHTMLRenderingOptions

    /// Creates a formatted renderer without allocating a document or invoking UI.
    /// - Parameters:
    ///   - options: Presentation choices and finite capacities for each independent call.
    public init(options: JSONHTMLRenderingOptions = .init()) { self.options = options }

    /// Renders a complete UTF-8 HTML document.
    /// - Returns: Owned document bytes.
    /// - Throws: HTML or core resource/configuration failure, or cancellation.
    /// - Parameters:
    ///   - value: Exact JSON root to admit and format.
    public func render(_ value: JSON) throws -> Data { try renderWithReport(value).result }

    /// Renders a complete UTF-8 HTML document as text.
    /// - Returns: Owned complete HTML text.
    /// - Throws: HTML or core resource/configuration failure, or cancellation.
    /// - Parameters:
    ///   - value: Exact JSON root to admit and format.
    public func renderString(_ value: JSON) throws -> String { try renderStringWithReport(value).result }

    /// Renders bytes with cumulative successful accounting, including the final Data copy.
    /// - Returns: Complete HTML bytes and rendering statistics.
    /// - Throws: HTML or core resource/configuration failure, or cancellation.
    /// - Parameters:
    ///   - value: Exact JSON root to admit and format.
    public func renderWithReport(_ value: JSON) throws -> JSONHTMLRenderReport<Data> {
        var meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
        let document = try render(value, meter: &meter)
        try chargeCopy(document.bytes, meter: &meter)
        let result = Data(document.bytes)
        try meter.release(UInt64(document.bytes.count))
        return .init(result: result, statistics: document.statistics(meter.statistics()))
    }

    /// Renders text with cumulative successful accounting, including the final String copy.
    /// - Returns: Complete HTML text and rendering statistics.
    /// - Throws: HTML or core resource/configuration failure, or cancellation.
    /// - Parameters:
    ///   - value: Exact JSON root to admit and format.
    public func renderStringWithReport(_ value: JSON) throws -> JSONHTMLRenderReport<String> {
        var meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
        let document = try render(value, meter: &meter)
        try chargeCopy(document.bytes, meter: &meter)
        let result = String(decoding: document.bytes, as: UTF8.self)
        try meter.release(UInt64(document.bytes.count))
        return .init(result: result, statistics: document.statistics(meter.statistics()))
    }

    private func chargeCopy(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws {
        for _ in bytes { try meter.work(); try meter.retain(1) }
    }

    package func render(_ value: JSON, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        let retainedAtEntry = meter.used(.retainedBytes)
        do { return try renderBody(value, meter: &meter) }
        catch {
            meter.recordFailure(error)
            // Invocation-owned scratch is gone on failure; preserve an enclosing reservation.
            try meter.release(meter.used(.retainedBytes) - retainedAtEntry)
            throw error
        }
    }
    private func renderBody(_ value: JSON, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        try meter.checkpoint()
        try options.limits.validate()
        guard (0...8).contains(options.indentation), (1...8).contains(options.tabWidth) else {
            throw JSONHTMLFailure.invalidConfiguration
        }
        try JSONAdmission.text(options.title, meter: &meter)
        for byte in options.title.utf8 {
            try meter.work()
            guard byte >= 32 && byte != 127 else { throw JSONHTMLFailure.invalidConfiguration }
        }
        // One admission and one ledger; the cursor never calls a public writer facade.
        try JSONAdmission.value(value, meter: &meter)
        try JSONHTMLDocumentBuffer.require(.renderedJSONNodes, meter.used(.nodes), options.limits.maxRenderedJSONNodes)
        var output = JSONHTMLDocumentBuffer(limits: options.limits)
        try output.addDOM(24, meter: &meter) // Includes fixed tags, text and optional parser-created nodes.
        try output.append("<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'none'; style-src 'sha256-", meter: &meter)
        try output.append(JSONHTMLAssets.cssHash, meter: &meter)
        try output.append("'; base-uri 'none'; form-action 'none'\"><title>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</title><style>", meter: &meter)
        try output.append(JSONHTMLAssets.css, meter: &meter)
        try output.append("</style></head><body class=\"", meter: &meter)
        try output.append(options.theme.rawValue, meter: &meter)
        try output.append(" tabs-", meter: &meter)
        try output.append(String(options.tabWidth), meter: &meter)
        try output.append("\"><main><h1>", meter: &meter)
        try output.escaped(options.title, meter: &meter)
        try output.append("</h1><pre><code>", meter: &meter)
        let writing = JSONWritingOptions(limits: options.limits.core, indentation: options.indentation,
                                         numberStyle: .preserved, indentationUnit: options.indentationUnit)
        var cursor = JSONWritingCursor(value: value, options: writing)
        var active: JSONWritingTokenKind?
        while let token = try cursor.nextToken(meter: &meter) {
            if token.beginsValue { try output.addNode(meter: &meter) }
            if token.kind != active {
                if let active, active != .whitespace { try output.append("</span>", meter: &meter) }
                // Four is a conservative upper bound for one span/text run or whitespace run.
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
        try output.append("</code></pre></main></body></html>\n", meter: &meter)
        try meter.checkpoint()
        return output
    }
}

package struct JSONHTMLDocumentBuffer {
    package var bytes: [UInt8] = []
    private var nodes: UInt64 = 0
    private var dom: UInt64 = 0
    private let limits: JSONHTMLLimits
    package init(limits: JSONHTMLLimits) { self.limits = limits }
    package static func require(_ metric: JSONHTMLResourceMetric, _ count: UInt64, _ limit: UInt64) throws {
        guard count <= limit else { throw JSONHTMLFailure.limitExceeded(metric, limit: limit, attempted: count) }
    }
    package static func adding(_ metric: JSONHTMLResourceMetric, _ count: UInt64, _ amount: UInt64, _ limit: UInt64) throws -> UInt64 {
        let (next, overflow) = count.addingReportingOverflow(amount)
        guard !overflow else { throw JSONHTMLFailure.counterOverflow(metric) }
        try require(metric, next, limit)
        return next
    }
    package mutating func addDOM(_ amount: UInt64, meter: inout JSONWorkMeter) throws {
        try meter.work()
        dom = try Self.adding(.domNodes, dom, amount, limits.maxDOMNodes)
    }
    package mutating func addNode(meter: inout JSONWorkMeter) throws {
        try meter.work()
        nodes = try Self.adding(.renderedJSONNodes, nodes, 1, limits.maxRenderedJSONNodes)
    }
    package mutating func append(_ text: String, meter: inout JSONWorkMeter) throws {
        for byte in text.utf8 { try append(byte, meter: &meter) }
    }
    private mutating func append(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
        try meter.work()
        _ = try Self.adding(.documentBytes, UInt64(bytes.count), 1, limits.maxDocumentBytes)
        try meter.charge(.outputBytes); try meter.retain(1)
        bytes.append(byte)
    }
    package mutating func escaped(_ text: String, meter: inout JSONWorkMeter) throws {
        for byte in text.utf8 { try meter.work(); try escaped(byte, meter: &meter) }
    }
    package mutating func escaped(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
        try meter.work()
        switch byte {
        case 38: try append("&amp;", meter: &meter)
        case 60: try append("&lt;", meter: &meter)
        case 62: try append("&gt;", meter: &meter)
        case 34: try append("&quot;", meter: &meter)
        case 39: try append("&#39;", meter: &meter)
        default: try append(byte, meter: &meter)
        }
    }
    package func statistics(_ operation: JSONOperationStatistics) -> JSONHTMLStatistics {
        .init(operation: operation, nodes: nodes, dom: dom, bytes: UInt64(bytes.count))
    }
}
