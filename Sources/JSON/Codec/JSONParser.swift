// SPDX-License-Identifier: Apache-2.0
import Foundation
public struct JSONParser: Sendable {
    public let options: JSONParsingOptions
    public init(options: JSONParsingOptions = .init()) { self.options = options }
    public func parse(_ text: String) throws -> JSON { try copyAndParse(text.utf8) }
    public func parse(_ data: Data) throws -> JSON { try copyAndParse(data) }
    private func copyAndParse<C: Collection>(_ input: C) throws -> JSON where C.Element == UInt8 {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .parsing)
        var bytes: [UInt8] = []
        for byte in input {
            try meter.work(); try meter.require(.inputBytes, UInt64(bytes.count) + 1)
            try meter.retain(1); bytes.append(byte)
        }
        return try parse(bytes, meter: &meter)
    }
    public func parse(_ bytes: [UInt8]) throws -> JSON { try parseWithReport(bytes).result }
    public func parseWithReport(_ bytes: [UInt8]) throws -> JSONOperationReport<JSON> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .parsing)
        let value = try parse(bytes, meter: &meter)
        return .init(result: value, statistics: meter.statistics())
    }
    package func parse(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws -> JSON {
        try meter.require(.inputBytes, UInt64(bytes.count))
        var machine = JSONTokenMachine(), assembler = JSONValueAssembler(), index = 0
        var result: JSON?
        while index < bytes.count {
            if let event = try machine.next(in: bytes, index: &index, meter: &meter),
               let value = try assembler.consume(event, meter: &meter) { result = value }
        }
        while machine.state != .finished {
            if let event = try machine.finish(meter: &meter), let value = try assembler.consume(event, meter: &meter) { result = value }
        }
        guard let result else { throw JSONFailure(.syntax, code: .unexpectedEOF) }
        return result
    }
}
