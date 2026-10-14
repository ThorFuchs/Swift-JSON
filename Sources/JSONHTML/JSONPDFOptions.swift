// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

/// Qualified fixed paper sizes, in PDF points (72 points per inch).
public enum JSONPDFPaper: String, Sendable {
    /// ISO A4: 595.275590551 by 841.889763780 points.
    case a4
    /// US Letter: 612 by 792 points.
    case usLetter
    package var width: Double { self == .a4 ? 595.275590551 : 612 }
    package var height: Double { self == .a4 ? 841.889763780 : 792 }
}

/// Explicit PDF geometry; a continuous page never substitutes for pagination.
public enum JSONPDFLayout: String, Sendable {
    /// Visible text ranges composed onto actual paper-sized pages.
    case paginated
    /// One measured tall page, using the selected paper's width.
    case continuous
}

/// Finite policy for one explicit PDF operation, independent of native preparation.
public struct JSONPDFLimits: Sendable {
    /// One cumulative owned-work/output/retention meter; opaque SDK work is separate.
    public var core: JSONLimits
    /// Inclusive bytes in the document-owned HTML input.
    public var maxHTMLBytes: UInt64
    /// Inclusive aggregate intermediate page PDF bytes (CoreText or WebPage).
    public var maxCaptureBytes: UInt64
    /// Inclusive final PDF bytes; native buffers are checked after SDK return.
    public var maxPDFBytes: UInt64
    /// Inclusive final bundle bytes, also constrained by the original export policy.
    public var maxPreparedBytes: UInt64
    /// Inclusive output page count, checked before every page capture.
    public var maxPages: UInt64
    /// Inclusive measured content height in points; the backend supports at most 14,400.
    public var maxContentHeightPoints: UInt64

    /// Creates finite initial policy; zero forbids the corresponding usage.
    /// - Parameters:
    ///   - core: Cumulative native accounting capacities.
    ///   - maxHTMLBytes: Maximum document-owned HTML bytes.
    ///   - maxCaptureBytes: Maximum aggregate intermediate page PDF bytes.
    ///   - maxPDFBytes: Maximum final PDF bytes.
    ///   - maxPreparedBytes: Maximum final bundle bytes, including hidden artifacts.
    ///   - maxPages: Maximum actual PDF pages.
    ///   - maxContentHeightPoints: Maximum measured layout height, at most 14,400.
    public init(core: JSONLimits = .balanced, maxHTMLBytes: UInt64 = 8_388_608,
                maxCaptureBytes: UInt64 = 8_388_608, maxPDFBytes: UInt64 = 8_388_608,
                maxPreparedBytes: UInt64 = 16_777_216, maxPages: UInt64 = 64,
                maxContentHeightPoints: UInt64 = 14_400) {
        self.core = core; self.maxHTMLBytes = maxHTMLBytes; self.maxCaptureBytes = maxCaptureBytes
        self.maxPDFBytes = maxPDFBytes; self.maxPreparedBytes = maxPreparedBytes
        self.maxPages = maxPages; self.maxContentHeightPoints = maxContentHeightPoints
    }
    package func validate() throws {
        try core.validate()
        guard [maxHTMLBytes, maxCaptureBytes, maxPDFBytes, maxPreparedBytes, maxPages,
               maxContentHeightPoints].allSatisfy({ $0 < UInt64(Int.max) }),
              maxContentHeightPoints <= 14_400 else { throw JSONPDFFailure.invalidConfiguration }
    }
}

/// Immutable-by-invocation choices for explicit Apple PDF preparation.
public struct JSONPDFOptions: Sendable {
    /// Paginated A4 by default; continuous output must be requested explicitly.
    public var layout: JSONPDFLayout
    /// A4 or US Letter; also determines continuous document width.
    public var paper: JSONPDFPaper
    /// Equal margins in points, finite and within zero through 144.
    public var marginPoints: Double
    /// Responsiveness deadline, at most 600,000 milliseconds; zero expires immediately.
    public var timeoutMilliseconds: UInt64
    /// Finite input, capture, output, page and cumulative owned-operation policy.
    public var limits: JSONPDFLimits

    /// Creates explicit PDF choices with 36-point margins, Menlo 11 and 16-point lines.
    /// - Parameters:
    ///   - layout: Genuine pagination or an explicit continuous page.
    ///   - paper: Qualified fixed paper size.
    ///   - marginPoints: Equal margins, zero through 144 points.
    ///   - timeoutMilliseconds: Finite responsiveness policy, at most ten minutes.
    ///   - limits: Finite PDF operation capacities.
    public init(layout: JSONPDFLayout = .paginated, paper: JSONPDFPaper = .a4,
                marginPoints: Double = 36, timeoutMilliseconds: UInt64 = 30_000,
                limits: JSONPDFLimits = .init()) {
        self.layout = layout; self.paper = paper; self.marginPoints = marginPoints
        self.timeoutMilliseconds = timeoutMilliseconds; self.limits = limits
    }
    package func validate() throws {
        try limits.validate()
        guard marginPoints.isFinite, (0...144).contains(marginPoints),
              timeoutMilliseconds <= 600_000 else { throw JSONPDFFailure.invalidConfiguration }
    }
}

/// PDF-specific inclusive capacities; existing core failures retain their native detail.
public enum JSONPDFResourceMetric: String, Sendable {
    /// Prepared static HTML input bytes.
    case htmlBytes
    /// Aggregate intermediate page PDF bytes.
    case captureBytes
    /// Final PDF bytes.
    case pdfBytes
    /// All final artifacts, including hidden formats.
    case preparedBytes
    /// Actual PDF pages.
    case pages
    /// Measured layout or continuous page height.
    case contentHeightPoints
}

/// Bounded PDF failures without payloads, native errors or rejected URLs.
public enum JSONPDFFailure: Error, Sendable, Equatable {
    /// Invalid finite options or unsupported geometry.
    case invalidConfiguration
    /// The original document has no static HTML artifact.
    case missingHTML
    /// No qualified Apple WebPage/CoreGraphics backend exists on this platform.
    case backendUnavailable
    /// Navigation did not finish successfully.
    case navigationFailed
    /// Native layout did not match the qualified print profile.
    case layoutFailed
    /// A native page/PDF operation failed or produced invalid geometry.
    case captureFailed
    /// The responsiveness deadline expired; platform work may finish later.
    case timedOut
    /// An inclusive PDF capacity was exceeded.
    case limitExceeded(JSONPDFResourceMetric, limit: UInt64, attempted: UInt64)
    /// Checked PDF counter addition overflowed.
    case counterOverflow(JSONPDFResourceMetric)
}

/// Successful explicit PDF operation and accounting, distinct from the first preparation.
public struct JSONPDFPreparationReport: Sendable {
    /// New immutable document containing a complete PDF artifact.
    public let result: JSONExportDocument
    /// Cumulative owned work/output and logical retention; not platform instructions or RSS.
    public let operation: JSONOperationStatistics
    /// Bytes in the document-owned HTML prerequisite.
    public let inputHTMLBytes: UInt64
    /// All artifacts held by the original document, including hidden formats.
    public let existingPreparedBytes: UInt64
    /// Aggregate native intermediate page PDF bytes checked after SDK return.
    public let capturedPDFBytes: UInt64
    /// Complete final PDF bytes.
    public let outputPDFBytes: UInt64
    /// Actual complete output pages.
    public let pageCount: UInt64
    /// Actual backend identity: CoreText pagination or WebPage continuous capture.
    public let backend: String
    /// Actual elapsed time, including platform waits; not an owned-work quota.
    public let elapsed: Duration
}

package func pdfRequire(_ metric: JSONPDFResourceMetric, _ usage: UInt64, _ limit: UInt64) throws {
    guard usage <= limit else { throw JSONPDFFailure.limitExceeded(metric, limit: limit, attempted: usage) }
}
package func pdfAdd(_ metric: JSONPDFResourceMetric, _ a: UInt64, _ b: UInt64, _ limit: UInt64) throws -> UInt64 {
    let (value, overflow) = a.addingReportingOverflow(b)
    guard !overflow else { throw JSONPDFFailure.counterOverflow(metric) }
    try pdfRequire(metric, value, limit); return value
}
package enum JSONPDFStage: String, Sendable { case input, loading, layout, extraction, capture, composition, installation }
package struct JSONPDFGeometry: Sendable { let width: Double; let height: Double; let lineHeight: Double }
package struct JSONPDFRectangle: Sendable { let x: Double; let y: Double; let width: Double; let height: Double }

package struct JSONPDFTextRun: Sendable { let kind: String; let text: String }
package struct JSONPDFText: Sendable { let runs: [JSONPDFTextRun]; let tabWidth: Double }
package struct JSONPDFTextPage: Sendable { let data: Data; let isComplete: Bool; let utf16Units: UInt64; let heightPoints: UInt64 }

package struct JSONPDFTextInfo: Sendable { let count: Int; let tabWidth: Double }
