// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

/// Successful native preparation and its cumulative accounting.
public struct JSONExportReport<Result> {
    /// The complete immutable result; failures return no partial document.
    public let result: Result
    /// Shared admission, traversal, output and peak logical retention counts.
    public let operation: JSONOperationStatistics
    /// Exact byte counts for each prepared artifact.
    public let representationBytes: [JSONExportFormat: UInt64]
    /// Sum of all prepared artifact bytes, including subsequently hidden formats.
    public let preparedBytes: UInt64
}
extension JSONExportReport: Sendable where Result: Sendable {}

/// Prepared immutable bytes, with per-item advertisement and no renderer, cache or source root.
///
/// Native JSON preserves insertion order, decoded scalar identity and original
/// numeric lexemes when present. Presentation formats are export-only. Preparation
/// uses one cumulative meter. Transport and receiving-app work are outside it.
public struct JSONExportDocument: Sendable {
    private let artifacts: [JSONExportFormat: Data]
    private let maximumRepresentationBytes: UInt64
    private let maximumPreparedBytes: UInt64
    /// Exact artifact identifiers retained by this item, including hidden artifacts.
    public let availableFormats: Set<JSONExportFormat>
    /// Exact artifact identifiers offered for this item; subtype matching is system policy.
    public let advertisedFormats: Set<JSONExportFormat>
    /// Validated filename component; extensions are added per representation.
    public let filenameStem: String

    private init(artifacts: [JSONExportFormat: Data], advertised: Set<JSONExportFormat>, filename: String, representationLimit: UInt64, preparedLimit: UInt64) {
        maximumRepresentationBytes = representationLimit; maximumPreparedBytes = preparedLimit
        self.artifacts = artifacts; availableFormats = Set(artifacts.keys)
        advertisedFormats = advertised; filenameStem = filename
    }

    /// Prepares all requested native artifacts atomically without executing a browser.
    /// - Parameters:
    ///   - value: Exact root admitted once for the entire preparation.
    ///   - options: Finite capacities and explicit format/presentation choices.
    /// - Returns: An immutable prepared item.
    /// - Throws: Configuration, resource, unsupported format or cancellation failure.
    public static func prepare(_ value: JSON, options: JSONExportOptions = .init()) throws -> Self {
        try prepareWithReport(value, options: options).result
    }

    /// Prepares requested native artifacts with one cumulative successful report.
    /// - Parameters:
    ///   - value: Exact root admitted once across all formats.
    ///   - options: Finite capacities and explicit format/presentation choices.
    /// - Returns: Complete artifacts and logical owned-operation accounting.
    /// - Throws: Configuration, resource, unsupported format or cancellation failure.
    public static func prepareWithReport(_ value: JSON, options: JSONExportOptions = .init()) throws -> JSONExportReport<Self> {
        var meter = try JSONWorkMeter(limits: options.limits.core.intersection(options.htmlLimits.core), domain: .writing)
        return try prepare(value, options: options, meter: &meter)
    }

    /// Returns an existing exact artifact without rendering or content-type negotiation.
    /// - Parameters:
    ///   - format: The exact identifier to look up, even if hidden from advertisement.
    /// - Returns: Immutable owned bytes; subsequent caller copies are caller work.
    /// - Throws: A bounded unavailable-format failure.
    public func data(for format: JSONExportFormat) throws -> Data {
        guard let data = artifacts[format] else { throw JSONExportFailure.unavailableFormat(format) }
        return data
    }

    // Some SDK transport helpers negotiate against the static representation list.
    // Conditions govern advertisement; guard the closure too so hidden bytes cannot escape.
    package func transferData(for format: JSONExportFormat) throws -> Data {
        guard advertisedFormats.contains(format) else { throw JSONExportFailure.unavailableFormat(format) }
        return try data(for: format)
    }

    /// Returns a value advertising only the selected existing artifacts.
    ///
    /// Existing immutable buffers are shared without regeneration. Hidden artifacts
    /// remain available and remain in the preparation's aggregate accounting.
    /// - Parameters:
    ///   - formats: Nonempty subset of available formats.
    /// - Returns: A new item with the exact per-item advertisement.
    /// - Throws: Empty or unavailable selection failure.
    public func selecting(_ formats: Set<JSONExportFormat>) throws -> Self {
        guard !formats.isEmpty else { throw JSONExportFailure.invalidConfiguration }
        for format in JSONExportFormat.allCases where formats.contains(format) && !availableFormats.contains(format) {
            throw JSONExportFailure.unavailableFormat(format)
        }
        return .init(artifacts: artifacts, advertised: formats, filename: filenameStem, representationLimit: maximumRepresentationBytes, preparedLimit: maximumPreparedBytes)
    }

    package static func prepare(_ value: JSON, options: JSONExportOptions, meter: inout JSONWorkMeter) throws -> JSONExportReport<Self> {
        let retainedAtEntry = meter.used(.retainedBytes)
        do { return try prepareBody(value, options: options, meter: &meter) }
        catch {
            meter.recordFailure(error)
            try meter.release(meter.used(.retainedBytes) - retainedAtEntry)
            throw error
        }
    }

    private static func prepareBody(_ value: JSON, options: JSONExportOptions, meter: inout JSONWorkMeter) throws -> JSONExportReport<Self> {
        try meter.checkpoint(); try options.limits.validate(); try options.htmlLimits.validate()
        guard !options.formats.isEmpty, (0...8).contains(options.indentation), (1...8).contains(options.tabWidth) else {
            throw JSONExportFailure.invalidConfiguration
        }
        if options.formats.contains(.pdf) { throw JSONExportFailure.preparationRequired(.pdf) }
        let titleBytes = try metadata(options.title, filename: false, limit: options.limits.maxTitleBytes, meter: &meter)
        _ = try metadata(options.filenameStem, filename: true, limit: options.limits.maxFilenameBytes, meter: &meter)
        try JSONAdmission.value(value, meter: &meter)
        var artifacts: [JSONExportFormat: Data] = [:]
        var counts: [JSONExportFormat: UInt64] = [:]
        var aggregate: UInt64 = 0

        func install(_ bytes: [UInt8], as format: JSONExportFormat, meter: inout JSONWorkMeter) throws {
            try JSONExportBuffer.require(.representationBytes, UInt64(bytes.count), options.limits.maxRepresentationBytes)
            aggregate = try JSONExportBuffer.adding(.preparedBytes, aggregate, UInt64(bytes.count), options.limits.maxPreparedBytes)
            // Each artifact is a logical owned copy even when Foundation internally shares storage.
            try meter.retain(48); try meter.work()
            for _ in bytes { try meter.work(); try meter.retain(1) }
            artifacts[format] = Data(bytes); counts[format] = UInt64(bytes.count)
            try meter.checkpoint()
        }

        let needsPretty = options.formats.contains(.plainText) || options.formats.contains(.markdown)
            || (options.formats.contains(.json) && !options.compactJSON)
        if needsPretty {
            let body = try writing(value, indentation: options.indentation, options: options, meter: &meter)
            if options.formats.contains(.json) && !options.compactJSON { try install(body, as: .json, meter: &meter) }
            if options.formats.contains(.plainText) { try install(body, as: .plainText, meter: &meter) }
            if options.formats.contains(.markdown) {
                var longest: UInt64 = 0, run: UInt64 = 0
                for byte in body {
                    try meter.work()
                    run = byte == 96 ? try JSONExportBuffer.adding(.representationBytes, run, 1, options.limits.maxRepresentationBytes) : 0
                    longest = max(longest, run)
                }
                let fence = max(3, try JSONExportBuffer.adding(.representationBytes, longest, 1, options.limits.maxRepresentationBytes))
                var markdown = JSONExportBuffer(limit: options.limits.maxRepresentationBytes)
                for _ in 0..<fence { try markdown.append(96, meter: &meter) }
                try markdown.append("json\n".utf8, meter: &meter)
                try markdown.append(body, meter: &meter); try markdown.append(10, meter: &meter)
                for _ in 0..<fence { try markdown.append(96, meter: &meter) }
                try markdown.append(10, meter: &meter)
                try install(markdown.bytes, as: .markdown, meter: &meter)
                try meter.release(UInt64(markdown.bytes.count))
            }
            try meter.release(UInt64(body.count))
        }
        if options.formats.contains(.json) && options.compactJSON {
            let body = try writing(value, indentation: nil, options: options, meter: &meter)
            try install(body, as: .json, meter: &meter); try meter.release(UInt64(body.count))
        }
        if options.formats.contains(.html) {
            var htmlLimits = options.htmlLimits
            htmlLimits.maxDocumentBytes = min(htmlLimits.maxDocumentBytes, options.limits.maxRepresentationBytes)
            let renderer = JSONHTMLRenderer(options: .init(title: options.title, theme: options.theme,
                indentation: options.indentation, indentationUnit: options.indentationUnit,
                tabWidth: options.tabWidth, limits: htmlLimits))
            let html = try renderer.renderAdmitted(value, meter: &meter)
            try install(html.bytes, as: .html, meter: &meter); try meter.release(UInt64(html.bytes.count))
        }
        if options.formats.contains(.rtf) {
            let rtf = try JSONRTFWriter.write(value, options: options, meter: &meter)
            try install(rtf, as: .rtf, meter: &meter); try meter.release(UInt64(rtf.count))
        }
        try meter.retain(16); try meter.work()
        try meter.release(titleBytes)
        try meter.checkpoint()
        return .init(result: .init(artifacts: artifacts, advertised: options.formats, filename: options.filenameStem, representationLimit: options.limits.maxRepresentationBytes, preparedLimit: options.limits.maxPreparedBytes),
                     operation: meter.statistics(), representationBytes: counts, preparedBytes: aggregate)
    }

    package func pdfInput() throws -> (html: Data, bytes: UInt64, previousPDFBytes: UInt64, representationLimit: UInt64, preparedLimit: UInt64) {
        guard let html = artifacts[.html] else { throw JSONPDFFailure.missingHTML }
        var total: UInt64 = 0
        for data in artifacts.values { total = try pdfAdd(.preparedBytes, total, UInt64(data.count), UInt64(Int.max) - 1) }
        return (html, total, UInt64(artifacts[.pdf]?.count ?? 0), maximumRepresentationBytes, maximumPreparedBytes)
    }
    // Package-only installation of a qualified artifact; no public injection API.
    package func addingPDF(_ pdf: Data) -> Self {
        var copy = artifacts; copy[.pdf] = pdf
        return .init(artifacts: copy, advertised: advertisedFormats.union([.pdf]), filename: filenameStem,
                     representationLimit: maximumRepresentationBytes, preparedLimit: maximumPreparedBytes)
    }

    private static func writing(_ value: JSON, indentation: Int?, options: JSONExportOptions, meter: inout JSONWorkMeter) throws -> [UInt8] {
        var cursor = JSONWritingCursor(value: value, options: .init(limits: options.limits.core,
            indentation: indentation, numberStyle: .preserved, indentationUnit: options.indentationUnit))
        var buffer = JSONExportBuffer(limit: options.limits.maxRepresentationBytes)
        while let byte = try cursor.next(meter: &meter) { try buffer.append(byte, meter: &meter) }
        return buffer.bytes
    }

    private static func metadata(_ text: String, filename: Bool, limit: UInt64, meter: inout JSONWorkMeter) throws -> UInt64 {
        let metric: JSONExportResourceMetric = filename ? .filenameBytes : .titleBytes
        var count: UInt64 = 0
        // Reject dot components, separators, controls and bidi controls in suggested names.
        if filename && (text.isEmpty || text == "." || text == "..") { throw JSONExportFailure.invalidConfiguration }
        for byte in text.utf8 {
            try meter.work(); count = try JSONExportBuffer.adding(metric, count, 1, limit)
            guard byte >= 32 && byte != 127, !filename || (byte != 47 && byte != 92 && byte != 58) else {
                throw JSONExportFailure.invalidConfiguration
            }
            try meter.retain(1)
        }
        for scalar in text.unicodeScalars {
            try meter.work()
            guard !(0x80...0x9f).contains(scalar.value),
                  !filename || (!(0x202a...0x202e).contains(scalar.value) && !(0x2066...0x2069).contains(scalar.value)) else {
                throw JSONExportFailure.invalidConfiguration
            }
        }
        return count
    }
}

package struct JSONExportBuffer {
    package var bytes: [UInt8] = []
    package let limit: UInt64
    package static func require(_ metric: JSONExportResourceMetric, _ attempted: UInt64, _ limit: UInt64) throws {
        guard attempted <= limit else { throw JSONExportFailure.limitExceeded(metric, limit: limit, attempted: attempted) }
    }
    package static func adding(_ metric: JSONExportResourceMetric, _ value: UInt64, _ amount: UInt64, _ limit: UInt64) throws -> UInt64 {
        let (next, overflow) = value.addingReportingOverflow(amount)
        guard !overflow else { throw JSONExportFailure.counterOverflow(metric) }
        try require(metric, next, limit); return next
    }
    package mutating func append(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
        try meter.work(); _ = try Self.adding(.representationBytes, UInt64(bytes.count), 1, limit)
        try meter.charge(.outputBytes); try meter.retain(1); bytes.append(byte)
    }
    package mutating func append<S: Sequence>(_ bytes: S, meter: inout JSONWorkMeter) throws where S.Element == UInt8 {
        for byte in bytes { try append(byte, meter: &meter) }
    }
}
