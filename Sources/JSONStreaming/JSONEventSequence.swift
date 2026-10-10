// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONEventSequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    public typealias Element = JSONEvent
    let source: Source
    let options: JSONStreamingOptions
    public init(_ source: Source, options: JSONStreamingOptions = .init()) { self.source = source; self.options = options }
    public func makeAsyncIterator() -> Iterator { Iterator(source: source.makeAsyncIterator(), options: options) }
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let options: JSONStreamingOptions
        private var driver: JSONEventDriver<Source.AsyncIterator>?
        fileprivate init(source: Source.AsyncIterator, options: JSONStreamingOptions) { self.source = source; self.options = options }
        public mutating func next() async throws -> JSONEvent? {
            if driver == nil { driver = try JSONEventDriver(upstream: source!, options: options); source = nil }
            return try await driver!.next()
        }
    }
}
extension JSONEventSequence: Sendable where Source: Sendable {}
final class JSONEventDriver<Upstream: AsyncIteratorProtocol> where Upstream.Element == JSONByteChunk {
    let input: JSONStreamInput<Upstream>
    let options: JSONStreamingOptions
    var machine = JSONTokenMachine()
    var terminal = false
    var resetOnNext = false
    var betweenRecords = false
    init(upstream: Upstream, options: JSONStreamingOptions) throws {
        self.options = options; input = try JSONStreamInput(upstream: upstream, limits: options.limits)
    }
    func summary() -> JSONStreamSummary { .init(records: input.meter.used(.totalRecords), statistics: input.meter.statistics()) }
    func next() async throws -> JSONEvent? {
        guard !terminal else { return nil }
        do {
            try input.meter.checkpoint(); try input.meter.require(.pendingEvents, 1)
            if resetOnNext {
                try input.resetRecord(); machine = JSONTokenMachine(offset: machine.offset); resetOnNext = false; betweenRecords = true
            }
            while true {
                if machine.hasCompleteRoot && options.framing == .whitespaceSeparatedValues {
                    let available = try await input.ensureBytes()
                    if available {
                        guard JSONLexer.whitespace(input.bytes[input.index]) else {
                            throw JSONFailure(.syntax, code: .trailingData, location: .init(byteOffset: machine.offset))
                        }
                        _ = try machine.next(in: input.bytes, index: &input.index, through: input.index + 1, meter: &input.meter)
                        try input.meter.charge(.totalRecords); resetOnNext = true
                        return .recordCompleted(summary())
                    }
                    _ = try machine.finish(meter: &input.meter)
                    try input.meter.charge(.totalRecords); terminal = true
                    return .recordCompleted(summary())
                }
                if try await input.ensureBytes() {
                    if let event = try machine.next(in: input.bytes, index: &input.index, meter: &input.meter) { betweenRecords = false; return JSONEvent(event) }
                } else {
                    if betweenRecords { terminal = true; return nil }
                    if let event = try machine.finish(meter: &input.meter) { return JSONEvent(event) }
                    try input.meter.charge(.totalRecords); terminal = true
                    return options.framing == .singleDocument ? .documentCompleted(summary()) : .recordCompleted(summary())
                }
            }
        } catch { terminal = true; input.failed = true; throw error }
    }
}
