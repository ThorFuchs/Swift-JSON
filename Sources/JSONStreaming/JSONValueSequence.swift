// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONValueSequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    public typealias Element = JSON
    let source: Source
    let options: JSONStreamingOptions
    public init(_ source: Source, options: JSONStreamingOptions = .init()) { self.source = source; self.options = options }
    public func makeAsyncIterator() -> Iterator { .init(source: source.makeAsyncIterator(), options: options) }
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let options: JSONStreamingOptions
        private var driver: JSONEventDriver<Source.AsyncIterator>?
        private var assembler = JSONValueAssembler()
        private var value: JSON?
        fileprivate init(source: Source.AsyncIterator, options: JSONStreamingOptions) { self.source = source; self.options = options }
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
