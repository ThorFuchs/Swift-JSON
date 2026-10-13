// SPDX-License-Identifier: Apache-2.0
import JSON

/// Successful counts from one complete formatted rendering invocation.
public struct JSONHTMLStatistics: Sendable, Equatable {
    /// Shared admission, token formatting, escaping, assets and final-copy accounting.
    public let operation: JSONOperationStatistics
    /// Number of JSON values actually emitted; keys are excluded.
    public let renderedJSONNodes: UInt64
    /// Conservative DOM node upper bound, not measured browser allocation or heap.
    public let domNodeUpperBound: UInt64
    /// Complete document bytes; final result copies do not add output bytes.
    public let documentBytes: UInt64
    package init(operation: JSONOperationStatistics, nodes: UInt64, dom: UInt64, bytes: UInt64) {
        self.operation = operation; renderedJSONNodes = nodes
        domNodeUpperBound = dom; documentBytes = bytes
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
