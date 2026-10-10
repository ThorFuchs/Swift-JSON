// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONTopLevelArraySequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    public typealias Element = JSONTopLevelArrayEvent
    let source: Source
    let options: JSONStreamingOptions
    public init(_ source: Source, options: JSONStreamingOptions = .init()) { self.source = source; self.options = options }
    public func makeAsyncIterator() -> Iterator { .init(source: source.makeAsyncIterator(), limits: options.limits) }
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let limits: JSONLimits
        private var driver: JSONArrayStreamDriver<Source.AsyncIterator>?
        fileprivate init(source: Source.AsyncIterator, limits: JSONLimits) { self.source = source; self.limits = limits }
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
