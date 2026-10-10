// SPDX-License-Identifier: Apache-2.0
import JSON
/// Exclusive iterator state; no global buffers or detached producer.
final class JSONStreamInput<Upstream: AsyncIteratorProtocol> where Upstream.Element == JSONByteChunk {
    var upstream: Upstream
    var meter: JSONWorkMeter
    var bytes: [UInt8] = []
    var index = 0
    var eof = false
    var failed = false
    init(upstream: Upstream, limits: JSONLimits) throws {
        self.upstream = upstream; meter = try JSONWorkMeter(limits: limits, domain: .streaming)
    }
    var liveChunkBytes: UInt64 { UInt64(bytes.count) }
    func ensureBytes() async throws -> Bool {
        if index < bytes.count { return true }
        try meter.release(UInt64(bytes.count)); bytes = []; index = 0
        while !eof {
            try meter.checkpoint(); try meter.work()
            guard let chunk = try await upstream.next() else { try meter.checkpoint(); eof = true; return false }
            try meter.checkpoint(); try meter.require(.chunkBytes, UInt64(chunk.count))
            try meter.charge(.totalInputBytes, UInt64(chunk.count))
            for byte in chunk.bytes { try meter.work(); try meter.retain(1); bytes.append(byte) }
            if !bytes.isEmpty { return true }
        }
        return false
    }
    func resetRecord(outerFrames: UInt64 = 0) throws {
        try meter.resetRecord(liveBytes: liveChunkBytes + outerFrames * JSONLogicalWeights.frame)
    }
}
