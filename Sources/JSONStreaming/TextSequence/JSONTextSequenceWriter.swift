// SPDX-License-Identifier: Apache-2.0
// Original RFC 7464 (application/json-seq) writer over the strict writing cursor.
import Foundation
import JSON
/// Writes RFC 7464 JSON text sequences (`application/json-seq`).
///
/// Every value becomes one text: the record separator byte (RS, `0x1E`), the strict
/// JSON bytes of ``JSONWritingOptions``, then one LF. The trailing LF lets readers
/// detect truncated top-level scalars. Indented output is allowed, because the
/// LF bytes inside a text are JSON whitespace.
public struct JSONTextSequenceWriter: Sendable {
    /// The strict writing configuration used for each text.
    public let options: JSONWritingOptions
    /// Maximum bytes per awaited handoff; must be positive and fit the chunkBytes limit.
    public let chunkSize: Int
    /// Configures the writer; positive chunk size and finite capacity are checked on write.
    ///
    /// - Parameters:
    ///   - options: The strict writing configuration and finite limits.
    ///   - chunkSize: Maximum bytes per awaited handoff; validated at write entry.
    public init(options: JSONWritingOptions = .init(), chunkSize: Int = 16_384) { self.options = options; self.chunkSize = chunkSize }

    /// Encodes the values as one complete sequence.
    ///
    /// - Returns: The sequence bytes; an empty array gives empty data.
    /// - Throws: Resource or configuration failure, or cancellation.
    ///
    /// - Parameters:
    ///   - values: The exact roots, written in order, one text each.
    public func encode(_ values: [JSON]) throws -> Data { try encodeWithReport(values).result }
    /// Encodes the values with one cumulative work ledger for the whole sequence.
    ///
    /// - Returns: The sequence bytes and the ledger's charged counts.
    /// - Throws: Resource or configuration failure, or cancellation.
    ///
    /// - Parameters:
    ///   - values: The exact roots, written in order, one text each.
    public func encodeWithReport(_ values: [JSON]) throws -> JSONOperationReport<Data> {
        var meter = try configuredMeter()
        var bytes: [UInt8] = []
        for value in values {
            try meter.checkpoint(); try meter.resetValueBounds()
            try text(value, meter: &meter) { byte, meter in try meter.retain(1); bytes.append(byte) }
        }
        try meter.checkpoint()
        return .init(result: Data(bytes), statistics: meter.statistics())
    }

    /// Writes one value as one text by awaiting full acceptance of each bounded owned chunk.
    ///
    /// Call once per value to produce a sequence. No later handoff occurs after a sink
    /// error or cancellation; accepted bytes cannot be recalled, and readers skip or
    /// reject the partial text.
    /// - Throws: Sink errors, resource/configuration failure or cancellation.
    ///
    /// - Parameters:
    ///   - value: The exact root to admit and write as one text.
    ///   - sink: The awaited callback; successful return accepts the entire owned chunk.
    public func write(_ value: JSON, to sink: @Sendable (JSONByteChunk) async throws -> Void) async throws {
        _ = try await writeWithReport(value, to: sink)
    }
    /// Writes one text in awaited chunks and returns successful output accounting.
    ///
    /// - Returns: Counts only after every handoff and final cancellation checkpoint succeeds.
    /// - Throws: Sink errors, resource/configuration failure or cancellation; accepted bytes cannot be recalled.
    ///
    /// - Parameters:
    ///   - value: The exact root to admit and write as one text.
    ///   - sink: The awaited callback; successful return accepts the entire owned chunk.
    public func writeWithReport(_ value: JSON, to sink: @Sendable (JSONByteChunk) async throws -> Void) async throws -> JSONOperationStatistics {
        var meter = try configuredMeter()
        guard chunkSize > 0, UInt64(chunkSize) <= options.limits[.chunkBytes] else { throw JSONFailure(.configuration, code: .invalidLimits) }
        try JSONAdmission.value(value, meter: &meter)
        var cursor = JSONWritingCursor(value: value, options: options), bytes: [UInt8] = []
        var phase = 0 // 0: RS, 1: JSON bytes, 2: LF, 3: done
        while phase < 3 {
            let byte: UInt8
            switch phase {
            case 0: byte = 0x1E; phase = 1
            case 1:
                guard let next = try cursor.next(meter: &meter) else { phase = 2; continue }
                byte = next
            default: byte = 0x0A; phase = 3
            }
            try meter.charge(.outputBytes); try meter.retain(1); bytes.append(byte)
            if bytes.count == chunkSize || (phase == 3 && !bytes.isEmpty) {
                try meter.checkpoint(); try await sink(JSONByteChunk(bytes)); try meter.checkpoint()
                try meter.release(UInt64(bytes.count)); bytes = []
            }
        }
        return meter.statistics()
    }

    private func configuredMeter() throws -> JSONWorkMeter {
        let meter = try JSONWorkMeter(limits: options.limits, domain: .writing)
        guard options.indentation.map({ (0...8).contains($0) }) ?? true else { throw JSONFailure(.configuration, code: .invalidLimits) }
        return meter
    }
    /// Emits RS, the strict JSON bytes and LF, charging every output byte.
    private func text(_ value: JSON, meter: inout JSONWorkMeter, emit: (UInt8, inout JSONWorkMeter) throws -> Void) throws {
        try JSONAdmission.value(value, meter: &meter)
        try meter.charge(.outputBytes); try emit(0x1E, &meter)
        var cursor = JSONWritingCursor(value: value, options: options)
        while let byte = try cursor.next(meter: &meter) { try meter.charge(.outputBytes); try emit(byte, &meter) }
        try meter.charge(.outputBytes); try emit(0x0A, &meter)
    }
}
