// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

/// An immutable facade producing complete highlighted standalone HTML.
///
/// Rendering is actor-independent and executes no browser or UI framework. It uses
/// the strict JSON writer's exact bytes, insertion order and preserved lexemes.
/// Assets are fixed and hash-authorized. Interactive mode needs no external resources.
/// Formatted mode remains script-free; interactive disclosures work without scripting.
public struct JSONHTMLRenderer: Sendable {
    /// Immutable configuration; finite capacities are checked on every invocation.
    public let options: JSONHTMLRenderingOptions

    /// Creates a renderer without allocating a document or invoking UI.
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
        try meter.checkpoint()
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
        try meter.checkpoint()
        return .init(result: result, statistics: document.statistics(meter.statistics()))
    }

    /// Renders a coherent source document as complete HTML bytes.
    /// - Parameter document: Immutable root and optional parser-owned source mapping.
    /// - Returns: Owned UTF-8 HTML; annotations use coherent value spans only.
    /// - Throws: Resource/configuration failure or cancellation.
    public func render(_ document: JSONDocument) throws -> Data { try renderWithReport(document).result }

    /// Renders a coherent source document as complete HTML text.
    /// - Parameter document: Immutable root and optional parser-owned source mapping.
    /// - Returns: Owned complete HTML text.
    /// - Throws: Resource/configuration failure or cancellation.
    public func renderString(_ document: JSONDocument) throws -> String { try renderStringWithReport(document).result }

    /// Renders document bytes with one cumulative invocation report.
    /// - Parameter document: Immutable root and optional coherent mapping; source bytes are not archived.
    /// - Returns: Complete HTML and successful accounting including its Data copy.
    /// - Throws: Resource/configuration failure or cancellation.
    public func renderWithReport(_ document: JSONDocument) throws -> JSONHTMLRenderReport<Data> {
        var meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
        let buffer = try render(document.root, document: document, meter: &meter)
        try chargeCopy(buffer.bytes, meter: &meter)
        let result = Data(buffer.bytes)
        try meter.release(UInt64(buffer.bytes.count)); try meter.checkpoint()
        return .init(result: result, statistics: buffer.statistics(meter.statistics()))
    }

    /// Renders document text with one cumulative invocation report.
    /// - Parameter document: Immutable root and optional coherent mapping; replaced roots have none.
    /// - Returns: Complete HTML and successful accounting including its String copy.
    /// - Throws: Resource/configuration failure or cancellation.
    public func renderStringWithReport(_ document: JSONDocument) throws -> JSONHTMLRenderReport<String> {
        var meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
        let buffer = try render(document.root, document: document, meter: &meter)
        try chargeCopy(buffer.bytes, meter: &meter)
        let result = String(decoding: buffer.bytes, as: UTF8.self)
        try meter.release(UInt64(buffer.bytes.count)); try meter.checkpoint()
        return .init(result: result, statistics: buffer.statistics(meter.statistics()))
    }

    private func chargeCopy(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws {
        for _ in bytes { try meter.work(); try meter.retain(1) }
    }

    package func render(_ value: JSON, document: JSONDocument? = nil, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        let retainedAtEntry = meter.used(.retainedBytes)
        do { return try renderBody(value, document: document, meter: &meter) }
        catch {
            meter.recordFailure(error)
            // Invocation-owned scratch is gone on failure; preserve an enclosing reservation.
            try meter.release(meter.used(.retainedBytes) - retainedAtEntry)
            throw error
        }
    }
    // Caller has already admitted this root under the same invocation meter.
    package func renderAdmitted(_ value: JSON, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        try renderBody(value, admitted: true, meter: &meter)
    }
    private func renderBody(_ value: JSON, admitted: Bool = false, document: JSONDocument? = nil, meter: inout JSONWorkMeter) throws -> JSONHTMLDocumentBuffer {
        try meter.checkpoint()
        try options.limits.validate()
        guard (0...8).contains(options.indentation), (1...8).contains(options.tabWidth),
              options.initiallyExpandedDepth >= 0, options.outlineDepth.map({ $0 >= 0 }) ?? true else {
            throw JSONHTMLFailure.invalidConfiguration
        }
        try JSONAdmission.text(options.title, meter: &meter)
        for byte in options.title.utf8 {
            try meter.work()
            guard byte >= 32 && byte != 127 else { throw JSONHTMLFailure.invalidConfiguration }
        }
        // One admission and one ledger; the cursor never calls a public writer facade.
        if !admitted { try JSONAdmission.value(value, meter: &meter) }
        try JSONHTMLDocumentBuffer.require(.renderedJSONNodes, meter.used(.nodes), options.limits.maxRenderedJSONNodes)
        let annotations = try bindAnnotations(value, document: document, meter: &meter)
        if options.presentation == .interactive {
            let result = try renderInteractive(value, annotations: annotations, meter: &meter)
            try meter.release(UInt64(annotations.count) * 64)
            return result
        }
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
        var ordinal: UInt64 = 0
        while let token = try cursor.nextToken(meter: &meter) {
            if token.beginsValue {
                try output.addNode(meter: &meter)
                if try hasAnnotations(at: ordinal, in: annotations, meter: &meter) {
                    if let active, active != .whitespace { try output.append("</span>", meter: &meter) }
                    active = nil
                    try output.addDOM(4, meter: &meter)
                    try output.append("<span tabindex=\"-1\" id=\"jh-n-", meter: &meter)
                    try output.decimal(ordinal, meter: &meter)
                    try output.append("\"", meter: &meter)
                    try annotationDescription(at: ordinal, in: annotations, output: &output, meter: &meter)
                    try output.append("></span>", meter: &meter)
                }
                ordinal = try JSONHTMLDocumentBuffer.adding(.renderedJSONNodes, ordinal, 1, options.limits.maxRenderedJSONNodes)
            }
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
        try output.append("</code></pre>", meter: &meter)
        try annotationSection(annotations, output: &output, meter: &meter)
        try meter.release(UInt64(annotations.count) * 64)
        try output.append("</main></body></html>\n", meter: &meter)
        try meter.checkpoint()
        return output
    }
}

package struct JSONHTMLDocumentBuffer {
    package var bytes: [UInt8] = []
    private var nodes: UInt64 = 0
    private var dom: UInt64 = 0
    private var outline: UInt64 = 0
    private var metadata: UInt64 = 0
    private var annotations: UInt64 = 0
    private var copyBytes: UInt64 = 0
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
    package mutating func setAnnotations(_ count: UInt64) { annotations = count }
    package mutating func setCopyBytes(_ count: UInt64) { copyBytes = count }
    package mutating func addOutline(meter: inout JSONWorkMeter) throws {
        try meter.work(); outline = try Self.adding(.outlineEntries, outline, 1, limits.maxOutlineEntries)
    }
    package mutating func addMetadata(meter: inout JSONWorkMeter) throws {
        try meter.work(); metadata = try Self.adding(.metadataBytes, metadata, 1, limits.maxMetadataBytes)
    }
    package mutating func appendByte(_ byte: UInt8, meter: inout JSONWorkMeter) throws { try append(byte, meter: &meter) }
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
        .init(operation: operation, nodes: nodes, dom: dom, bytes: UInt64(bytes.count), outline: outline, metadata: metadata, copyBytes: copyBytes, annotations: annotations)
    }
}
