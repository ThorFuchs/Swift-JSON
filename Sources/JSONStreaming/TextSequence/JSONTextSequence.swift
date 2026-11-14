// SPDX-License-Identifier: Apache-2.0
// Original RFC 7464 (application/json-seq) reader over the shared stream input.
import JSON
/// A pull reader for RFC 7464 JSON text sequences (`application/json-seq`).
///
/// Each text starts with the record separator byte (RS, `0x1E`) and runs to the
/// next RS or the end of input. Consecutive RS bytes are not empty texts. Each text
/// is parsed by the strict UTF-8 grammar, so surrounding whitespace, including the
/// LF that writers append, is allowed.
///
/// A text that is a top-level number, `true`, `false` or `null` must end in
/// whitespace; otherwise it may have been truncated and is malformed (RFC 7464
/// section 2.4). Bytes before the first RS are a malformed text too. Malformed
/// texts end the sequence by default; ``JSONTextSequenceOptions/MalformedTexts/skip``
/// continues with the next text instead.
///
/// Failures report the absolute byte offset, the one-based text number as `record`,
/// and the line and column within the text.
public struct JSONTextSequence<Source: AsyncSequence>: AsyncSequence where Source.Element == JSONByteChunk {
    /// Each complete JSON text, in order.
    public typealias Element = JSON
    let source: Source
    let options: JSONTextSequenceOptions
    /// Wraps a caller-owned source of `application/json-seq` bytes.
    ///
    /// - Parameters:
    ///   - source: The caller-owned asynchronous source of owned UTF-8 chunks.
    ///   - options: Limits and the malformed-text policy.
    public init(_ source: Source, options: JSONTextSequenceOptions = .init()) { self.source = source; self.options = options }
    /// Creates an independent iterator with exclusive mutable state and no prefetch task.
    public func makeAsyncIterator() -> Iterator { .init(source: source.makeAsyncIterator(), options: options) }
    /// Exclusive pull iterator; never call next concurrently.
    ///
    /// Each iterator owns its budget and parsing state. Conditional Sendable of the
    /// sequence does not make this mutable iterator safe for concurrent access.
    public struct Iterator: AsyncIteratorProtocol {
        private var source: Source.AsyncIterator?
        private let options: JSONTextSequenceOptions
        private var driver: JSONTextSequenceDriver<Source.AsyncIterator>?
        fileprivate init(source: Source.AsyncIterator, options: JSONTextSequenceOptions) { self.source = source; self.options = options }
        /// The number of malformed texts skipped so far; always zero with the `fail` policy.
        public var skippedTexts: Int { driver?.skipped ?? 0 }
        /// Pulls at most one value through exclusively owned iterator state.
        ///
        /// An error or cancellation makes an initialized iterator terminal and prevents later pulls.
        /// - Returns: The next JSON text's value, or nil at the end of input.
        /// - Throws: Source, syntax or resource errors, or cancellation.
        public mutating func next() async throws -> JSON? {
            if driver == nil { driver = try JSONTextSequenceDriver(upstream: source!, options: options); source = nil }
            return try await driver!.next()
        }
    }
}
extension JSONTextSequence: Sendable where Source: Sendable {}

private final class JSONTextSequenceDriver<Upstream: AsyncIteratorProtocol> where Upstream.Element == JSONByteChunk {
    static var separator: UInt8 { 0x1E }
    let input: JSONStreamInput<Upstream>
    let skipMalformed: Bool
    var terminal = false, resetOnNext = false, afterSeparator = false
    var offset: UInt64 = 0, texts: UInt64 = 0
    var skipped = 0
    init(upstream: Upstream, options: JSONTextSequenceOptions) throws {
        input = try JSONStreamInput(upstream: upstream, limits: options.limits); skipMalformed = options.malformedTexts == .skip
    }
    func next() async throws -> JSON? {
        guard !terminal else { return nil }
        do {
            try input.meter.checkpoint(); try input.meter.require(.pendingValues, 1)
            while true {
                if resetOnNext { try input.resetRecord(); resetOnNext = false }
                let introduced = afterSeparator, start = offset
                var text: [UInt8] = [], ended = false
                while true {
                    guard try await input.ensureBytes() else { ended = true; break }
                    let byte = input.bytes[input.index]; input.index += 1; offset += 1
                    try input.meter.work()
                    if byte == Self.separator { break }
                    try input.meter.require(.inputBytes, UInt64(text.count) + 1); try input.meter.retain(1); text.append(byte)
                }
                afterSeparator = !ended
                // Empty segments: input that starts with RS, consecutive RS bytes, or a final RS.
                if text.isEmpty {
                    if ended { terminal = true; return nil }
                    continue
                }
                texts += 1; resetOnNext = true
                do {
                    let value = try parse(text, introduced: introduced)
                    try input.meter.charge(.totalRecords)
                    if ended { terminal = true }
                    return value
                } catch let failure as JSONFailure {
                    let relative = failure.location?.byteOffset ?? 0
                    let located = JSONFailure(failure.category, code: failure.code,
                                              location: .init(byteOffset: start + relative, line: failure.location?.line,
                                                              column: failure.location?.column, record: texts),
                                              resource: failure.resource)
                    guard skipMalformed, failure.category == .syntax else { throw located }
                    try input.meter.charge(.totalRecords); skipped += 1
                    if ended { terminal = true; return nil }
                }
            }
        } catch { terminal = true; input.failed = true; throw error }
    }
    /// Parses one text; a missing leading RS or a possibly truncated scalar is a syntax failure.
    private func parse(_ text: [UInt8], introduced: Bool) throws -> JSON {
        guard introduced else { throw JSONFailure(.syntax, code: .invalidSyntax, location: .init(byteOffset: 0, line: 1, column: 1)) }
        let value = try JSONParser().parse(text, meter: &input.meter)
        switch value {
        case .object, .array, .string: return value
        default:
            // RFC 7464 section 2.4: a top-level scalar without trailing whitespace may be truncated.
            guard let last = text.last, last == 0x20 || last == 0x09 || last == 0x0A || last == 0x0D else {
                throw JSONFailure(.syntax, code: .unexpectedEOF, location: .init(byteOffset: UInt64(text.count)))
            }
            return value
        }
    }
}
