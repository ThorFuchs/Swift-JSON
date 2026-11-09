// SPDX-License-Identifier: Apache-2.0
import JSON
/// A provisional root-array element with its original source span, or certified completion.
///
/// Spans are zero-based half-open UTF-8 byte offsets in the complete stream.
/// Whitespace and separators outside the element are excluded. A span does not
/// certify the enclosing array, stable backing bytes or durable admission.
public enum JSONLocatedTopLevelArrayEvent: Sendable {
    /// A zero-based indexed element and its byte span; the enclosing document remains provisional.
    case element(index: UInt64, value: JSON, sourceSpan: JSONSourceSpan)
    /// The outer array, trailing whitespace and EOF have been certified.
    case documentCompleted(JSONStreamSummary)
}
/// A pull-driven root-array reader that also reports each element's original byte span.
///
/// Uses the same strict grammar, pull driver, finite quotas and completion boundary
/// as ``JSONTopLevelArraySequence``; only the yielded event carries a location.
/// No original-byte buffer, alternate parser, prefetch task or file is owned here.
/// Callers needing raw slices must retain an immutable source separately and keep
/// each element provisional until `documentCompleted`. The framing option is ignored.
public struct JSONLocatedTopLevelArraySequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    /// The located event yielded by this sequence, as declared below.
    public typealias Element = JSONLocatedTopLevelArrayEvent
    let source: Source
    let options: JSONStreamingOptions
    /// Wraps a caller-owned source for one root array; framing is always single-document.
    ///
    /// - Parameters:
    ///   - source: The caller-owned asynchronous source of owned UTF-8 chunks.
    ///   - options: The value configuration used by this facade or operation.
    public init(_ source: Source, options: JSONStreamingOptions = .init()) { self.source = source; self.options = options }
    /// Creates an independent iterator with exclusive mutable state and no prefetch task.
    public func makeAsyncIterator() -> Iterator { .init(source: source.makeAsyncIterator(), limits: options.limits) }
    /// Exclusive pull iterator; never call next concurrently.
    ///
    /// Each iterator owns its budget, parsing state and span origin. Conditional
    /// Sendable of the sequence does not make this mutable iterator safe for concurrent access.
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let limits: JSONLimits
        private var driver: JSONArrayStreamDriver<Source.AsyncIterator>?
        fileprivate init(source: Source.AsyncIterator, limits: JSONLimits) { self.source = source; self.limits = limits }
        /// Pulls at most one located result through exclusively owned iterator state.
        ///
        /// Continue until the certified boundary or nil required by the sequence contract.
        /// An error or cancellation makes an initialized iterator terminal and prevents later pulls.
        /// - Returns: The next located event, or nil after termination.
        /// - Throws: Source, syntax or resource errors, or cancellation.
        public mutating func next() async throws -> Element? {
            if driver == nil { driver = try JSONArrayStreamDriver(upstream: source!, limits: limits); source = nil }
            return try await driver!.nextLocated()
        }
    }
}
extension JSONLocatedTopLevelArraySequence: Sendable where Source: Sendable {}
