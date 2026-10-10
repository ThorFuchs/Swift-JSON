// SPDX-License-Identifier: Apache-2.0
import JSON
/// An awaited strict JSON writer with one outstanding chunk handoff.
///
/// A successful sink return accepts the entire chunk. Failure or cancellation stops
/// later writes; accepted bytes cannot be recalled. Stage in a caller-owned sink
/// when publication must be atomic.
public struct JSONAsyncWriter: Sendable {
    /// The immutable configuration used to create each invocation.
    public let options: JSONWritingOptions
    /// Maximum output chunk bytes; must be positive and fit the chunkBytes limit when writing.
    public let chunkSize: Int
    /// Configures an awaited writer; positive chunk size and finite capacity are checked on write.
    ///
    /// - Parameters:
    ///   - options: The value configuration used by this facade or operation.
    ///   - chunkSize: Maximum bytes per handoff; validated at write entry.
    public init(options: JSONWritingOptions = .init(), chunkSize: Int = 16_384) { self.options = options; self.chunkSize = chunkSize }
    /// Writes strict JSON by awaiting full acceptance of each bounded owned chunk.
    ///
    /// No later handoff occurs after a sink error or cancellation. Accepted bytes remain
    /// accepted, so atomic publication requires caller staging.
    /// - Throws: Sink errors, resource/configuration failure or cancellation.
    ///
    /// - Parameters:
    ///   - value: The exact root to admit and write as strict UTF-8 JSON.
    ///   - sink: The awaited callback; successful return accepts the entire owned chunk.
    public func write(_ value: JSON, to sink: @Sendable (JSONByteChunk) async throws -> Void) async throws {
        _ = try await writeWithReport(value, to: sink)
    }
    /// Writes awaited chunks and returns successful output accounting.
    ///
    /// - Returns: Counts only after every handoff and final cancellation checkpoint succeeds.
    /// - Throws: Sink errors, resource/configuration failure or cancellation; accepted bytes cannot be recalled.
    ///
    /// - Parameters:
    ///   - value: The exact root to admit and write as strict UTF-8 JSON.
    ///   - sink: The awaited callback; successful return accepts the entire owned chunk.
    public func writeWithReport(_ value: JSON, to sink: @Sendable (JSONByteChunk) async throws -> Void) async throws -> JSONOperationStatistics {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .writing)
        guard chunkSize > 0, UInt64(chunkSize) <= options.limits[.chunkBytes], options.indentation.map({ (0...8).contains($0) }) ?? true else { throw JSONFailure(.configuration, code: .invalidLimits) }
        try JSONAdmission.value(value, meter: &meter)
        var cursor = JSONWritingCursor(value: value, options: options), bytes: [UInt8] = []
        while let byte = try cursor.next(meter: &meter) {
            try meter.charge(.outputBytes); try meter.retain(1); bytes.append(byte)
            if bytes.count == chunkSize {
                try meter.checkpoint(); try await sink(JSONByteChunk(bytes)); try meter.checkpoint()
                try meter.release(UInt64(bytes.count)); bytes = []
            }
        }
        if !bytes.isEmpty {
            try meter.checkpoint(); try await sink(JSONByteChunk(bytes)); try meter.checkpoint()
            try meter.release(UInt64(bytes.count)); bytes = []
        }
        return meter.statistics()
    }
}
