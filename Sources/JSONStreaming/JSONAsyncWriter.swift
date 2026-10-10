// SPDX-License-Identifier: Apache-2.0
import JSON
/// A successful sink return accepts the entire owned chunk. One handoff is outstanding.
public struct JSONAsyncWriter: Sendable {
    public let options: JSONWritingOptions
    public let chunkSize: Int
    public init(options: JSONWritingOptions = .init(), chunkSize: Int = 16_384) { self.options = options; self.chunkSize = chunkSize }
    public func write(_ value: JSON, to sink: @Sendable (JSONByteChunk) async throws -> Void) async throws {
        _ = try await writeWithReport(value, to: sink)
    }
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
