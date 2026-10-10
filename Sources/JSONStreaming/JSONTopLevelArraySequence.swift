// SPDX-License-Identifier: Apache-2.0
import JSON
/// A pull-driven root-array reader with provisional elements and final completion.
///
/// Each element has value quotas; outer-array depth and lifetime scan/work quotas
/// remain charged. Only `documentCompleted` certifies the enclosing document.
/// The framing option is ignored: this reader always requires one root array.
public struct JSONTopLevelArraySequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    /// The event or complete value yielded by this sequence, as declared below.
    public typealias Element = JSONTopLevelArrayEvent
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
    /// Each iterator owns its budget and parsing state. Conditional Sendable of the
    /// sequence does not make this mutable iterator safe for concurrent access.
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let limits: JSONLimits
        private var driver: JSONArrayStreamDriver<Source.AsyncIterator>?
        fileprivate init(source: Source.AsyncIterator, limits: JSONLimits) { self.source = source; self.limits = limits }
        /// Pulls at most one result through exclusively owned iterator state.
        ///
        /// Continue until the certified boundary or nil required by the sequence contract.
        /// An error or cancellation makes an initialized iterator terminal and prevents later pulls.
        /// - Returns: The next event/value, or nil after termination.
        /// - Throws: Source, syntax or resource errors, or cancellation.
        public mutating func next() async throws -> Element? {
            if driver == nil { driver = try JSONArrayStreamDriver(upstream: source!, limits: limits); source = nil }
            return try await driver!.next()
        }
    }
}
extension JSONTopLevelArraySequence: Sendable where Source: Sendable {}
private final class JSONArrayStreamDriver<Upstream: AsyncIteratorProtocol> where Upstream.Element == JSONByteChunk {
    let input: JSONStreamInput<Upstream>
    var machine = JSONTokenMachine(topLevelArrayStreaming: true)
    var assembler = JSONValueAssembler()
    var began = false, closed = false, terminal = false, resetOnNext = false
    init(upstream: Upstream, limits: JSONLimits) throws { input = try JSONStreamInput(upstream: upstream, limits: limits) }
    func next() async throws -> JSONTopLevelArrayEvent? {
        guard !terminal else { return nil }
        do {
            try input.meter.checkpoint(); try input.meter.require(.pendingValues, 1)
            if resetOnNext { try input.resetRecord(outerFrames: 1); resetOnNext = false }
            while true {
                let event: JSONMachineEvent?
                if try await input.ensureBytes() { event = try machine.next(in: input.bytes, index: &input.index, meter: &input.meter) }
                else {
                    event = try machine.finish(meter: &input.meter)
                    if event == nil {
                        guard closed else { throw JSONFailure(.syntax, code: .unexpectedEOF) }
                        terminal = true
                        return .documentCompleted(.init(records: input.meter.used(.totalRecords), statistics: input.meter.statistics()))
                    }
                }
                guard let event else { continue }
                if !began {
                    guard case .startArray = event.kind else { throw JSONFailure(.syntax, code: .invalidSyntax) }
                    began = true; continue
                }
                // A closing outer array never enters the element assembler.
                if machine.hasCompleteRoot {
                    guard case .endArray = event.kind else { throw JSONFailure(.syntax, code: .invalidSyntax) }
                    closed = true; continue
                }
                if let value = try assembler.consume(event, meter: &input.meter) {
                    let index = input.meter.used(.totalRecords)
                    try input.meter.charge(.totalRecords); assembler = JSONValueAssembler(); resetOnNext = true
                    return .element(index: index, value: value)
                }
            }
        } catch { terminal = true; input.failed = true; assembler = JSONValueAssembler(); throw error }
    }
}
