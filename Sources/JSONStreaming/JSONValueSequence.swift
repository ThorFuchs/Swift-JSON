// SPDX-License-Identifier: Apache-2.0
import JSON
/// A pull-driven sequence of complete JSON values with explicit framing.
///
/// A single document is yielded only after trailing whitespace and EOF. Multiple
/// roots require real whitespace separation. Iterator-lifetime budgets are cumulative.
public struct JSONValueSequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    /// The event or complete value yielded by this sequence, as declared below.
    public typealias Element = JSON
    let source: Source
    let options: JSONStreamingOptions
    /// Wraps a caller-owned chunk source with strict value framing; no prefetch starts.
    ///
    /// - Parameters:
    ///   - source: The caller-owned asynchronous source of owned UTF-8 chunks.
    ///   - options: The value configuration used by this facade or operation.
    public init(_ source: Source, options: JSONStreamingOptions = .init()) { self.source = source; self.options = options }
    /// Creates an independent iterator with exclusive mutable state and no prefetch task.
    public func makeAsyncIterator() -> Iterator { .init(source: source.makeAsyncIterator(), options: options) }
    /// Exclusive pull iterator; never call next concurrently.
    ///
    /// Each iterator owns its budget and parsing state. Conditional Sendable of the
    /// sequence does not make this mutable iterator safe for concurrent access.
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let options: JSONStreamingOptions
        private var driver: JSONEventDriver<Source.AsyncIterator>?
        private var assembler = JSONValueAssembler()
        private var value: JSON?
        fileprivate init(source: Source.AsyncIterator, options: JSONStreamingOptions) { self.source = source; self.options = options }
        /// Pulls at most one result through exclusively owned iterator state.
        ///
        /// Continue until the certified boundary or nil required by the sequence contract.
        /// An error or cancellation makes an initialized iterator terminal and prevents later pulls.
        /// - Returns: The next event/value, or nil after termination.
        /// - Throws: Source, syntax or resource errors, or cancellation.
        public mutating func next() async throws -> JSON? {
            if driver == nil { driver = try JSONEventDriver(upstream: source!, options: options); source = nil }
            let driver = driver!
            do {
                try driver.input.meter.require(.pendingValues, 1)
                while let event = try await driver.next() {
                    let kind: JSONMachineEvent.Kind
                    switch event {
                    case .recordCompleted, .documentCompleted:
                        guard let completed = value else { throw JSONFailure(.syntax, code: .unexpectedEOF) }
                        value = nil; assembler = JSONValueAssembler()
                        return completed
                    case .startObject: kind = .startObject
                    case .endObject: kind = .endObject
                    case .startArray: kind = .startArray
                    case .endArray: kind = .endArray
                    case .key(let key): kind = .key(key)
                    case .scalar(let scalar): kind = .scalar(scalar)
                    }
                    if let root = try assembler.consume(.init(kind: kind, start: 0, end: 0), meter: &driver.input.meter) { value = root }
                }
                return nil
            } catch { driver.terminal = true; value = nil; assembler = JSONValueAssembler(); throw error }
        }
    }
}
extension JSONValueSequence: Sendable where Source: Sendable {}
