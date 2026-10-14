// SPDX-License-Identifier: Apache-2.0
import JSON

/// Successful counts from one complete HTML rendering invocation.
public struct JSONHTMLStatistics: Sendable, Equatable {
    /// Shared admission, token formatting, escaping, assets and final-copy accounting.
    public let operation: JSONOperationStatistics
    /// Number of JSON values actually emitted; keys are excluded.
    public let renderedJSONNodes: UInt64
    /// Conservative DOM node upper bound, not measured browser allocation or heap.
    public let domNodeUpperBound: UInt64
    /// Complete document bytes; final result copies do not add output bytes.
    public let documentBytes: UInt64
    /// Emitted container outline entries; zero in formatted mode or when disabled.
    public let outlineEntries: UInt64
    /// Emitted Base64 metadata bytes; distinct from complete document and raw copy bytes.
    public let metadataBytes: UInt64
    /// Raw exact JSON bytes embedded for interactive copy/download; zero in formatted mode.
    public let copyJSONBytes: UInt64
    /// Accepted caller-supplied diagnostics; zero does not assert schema validity.
    public let annotations: UInt64
    package init(operation: JSONOperationStatistics, nodes: UInt64, dom: UInt64, bytes: UInt64, outline: UInt64, metadata: UInt64, copyBytes: UInt64, annotations: UInt64) {
        self.operation = operation; renderedJSONNodes = nodes
        domNodeUpperBound = dom; documentBytes = bytes
        outlineEntries = outline; metadataBytes = metadata; copyJSONBytes = copyBytes; self.annotations = annotations
    }
}

/// A complete result and its successful cumulative rendering statistics.
///
/// No partial result or successful report is returned after failure or cancellation.
public struct JSONHTMLRenderReport<Result> {
    /// Complete owned UTF-8 HTML bytes or text.
    public let result: Result
    /// Counts from the same invocation, including the owned final result copy.
    public let statistics: JSONHTMLStatistics
    package init(result: Result, statistics: JSONHTMLStatistics) {
        self.result = result; self.statistics = statistics
    }
}
extension JSONHTMLRenderReport: Sendable where Result: Sendable {}
