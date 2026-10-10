// SPDX-License-Identifier: Apache-2.0
import JSON
public struct NDJSONValueSequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    public typealias Element = JSON
    let source: Source
    let options: NDJSONOptions
    public init(_ source: Source, options: NDJSONOptions = .init()) { self.source = source; self.options = options }
    public func makeAsyncIterator() -> Iterator { .init(source: source.makeAsyncIterator(), limits: options.limits) }
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let limits: JSONLimits
        private var driver: NDJSONDriver<Source.AsyncIterator>?
        fileprivate init(source: Source.AsyncIterator, limits: JSONLimits) { self.source = source; self.limits = limits }
        public mutating func next() async throws -> JSON? {
            if driver == nil { driver = try NDJSONDriver(upstream: source!, limits: limits); source = nil }
            return try await driver!.next()
        }
    }
}
extension NDJSONValueSequence: Sendable where Source: Sendable {}
private final class NDJSONDriver<Upstream: AsyncIteratorProtocol> where Upstream.Element == JSONByteChunk {
    let input: JSONStreamInput<Upstream>
    var terminal = false, resetOnNext = false
    var offset: UInt64 = 0, record: UInt64 = 1
    init(upstream: Upstream, limits: JSONLimits) throws { input = try JSONStreamInput(upstream: upstream, limits: limits) }
    func next() async throws -> JSON? {
        guard !terminal else { return nil }
        var line: [UInt8] = []
        let start = offset
        do {
            try input.meter.checkpoint(); try input.meter.require(.pendingValues, 1)
            if resetOnNext { try input.resetRecord(); resetOnNext = false }
            while true {
                guard try await input.ensureBytes() else {
                    if line.isEmpty { terminal = true; return nil }
                    terminal = true; break
                }
                let byte = input.bytes[input.index]; input.index += 1; offset += 1
                try input.meter.work()
                if byte == 10 { break }
                try input.meter.require(.inputBytes, UInt64(line.count) + 1); try input.meter.retain(1); line.append(byte)
            }
            let value = try JSONParser().parse(line, meter: &input.meter)
            try input.meter.charge(.totalRecords)
            record += 1; resetOnNext = !terminal
            return value
        } catch let failure as JSONFailure {
            terminal = true; input.failed = true
            let relative = failure.location?.byteOffset ?? 0
            throw JSONFailure(failure.category, code: failure.code,
                              location: .init(byteOffset: start + relative, line: record, column: relative + 1, record: record), resource: failure.resource)
        } catch { terminal = true; input.failed = true; throw error }
    }
}
