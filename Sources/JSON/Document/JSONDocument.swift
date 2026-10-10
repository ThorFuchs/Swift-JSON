// SPDX-License-Identifier: Apache-2.0
import Foundation
/// Immutable coherent source snapshot. Replacement deliberately discards stale spans.
public struct JSONDocument: Sendable {
    public let root: JSON
    public let source: String?
    public let sourceBytes: Data?
    public let sourceMap: JSONSourceMap?
    public init(root: JSON) { self.root = root; source = nil; sourceBytes = nil; sourceMap = nil }
    package init(root: JSON, source: String?, bytes: Data, map: JSONSourceMap) {
        self.root = root; self.source = source; sourceBytes = bytes; sourceMap = map
    }
    public func replacingRoot(_ root: JSON) -> Self { Self(root: root) }
}

extension JSONParser {
    public func parseDocument(_ data: Data, source: String? = nil) throws -> JSONDocument {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .parsing)
        if let source { try JSONAdmission.text(source, meter: &meter, owned: true) }
        var bytes: [UInt8] = []
        for byte in data { try meter.work(); try meter.require(.inputBytes, UInt64(bytes.count) + 1); try meter.retain(1); bytes.append(byte) }
        var machine = JSONTokenMachine(), assembler = JSONValueAssembler(), mapping = JSONSourceMapBuilder(), index = 0
        var result: JSON?
        while index < bytes.count {
            if let event = try machine.next(in: bytes, index: &index, meter: &meter) {
                try mapping.consume(event, meter: &meter)
                if let value = try assembler.consume(event, meter: &meter) { result = value }
            }
        }
        while machine.state != .finished {
            if let event = try machine.finish(meter: &meter) {
                try mapping.consume(event, meter: &meter)
                if let value = try assembler.consume(event, meter: &meter) { result = value }
            }
        }
        guard let result else { throw JSONFailure(.syntax, code: .unexpectedEOF) }
        for _ in bytes { try meter.work(); try meter.retain(1) }
        return .init(root: result, source: source, bytes: Data(bytes), map: mapping.finish())
    }
}
