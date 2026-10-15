// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONFilterRuntime

package enum CLIInputFraming: String, Sendable { case values, document, ndjson, array, rawLines, rawText }
/// One lazy invocation cursor serves both the command driver and input/inputs.
/// It feeds the native grammar, never a permissive second JSON parser.
package struct CLIInputCursor: FilterInput {
    private let files: [String]
    private let framing: CLIInputFraming
    private var fileIndex = 0
    private var source: CLIInput?
    private var buffer: [UInt8] = []
    private var index = 0
    private var eof = false
    private var fileRecords = 0
    private var machine: JSONTokenMachine
    private var assembler = JSONValueAssembler()
    private var ready: JSON?
    private var recordSawData = false
    private var recordStarted = false
    private var recordEntry: UInt64 = 0
    private var entryBuffer: UInt64 = 0
    private var entryOuter: UInt64 = 0
    private var outerBytes: UInt64 = 0
    private var outerStarted = false
    private var outerClosed = false
    private var failed = false
    package init(files: [String], framing: CLIInputFraming = .values) {
        self.files = files.isEmpty ? ["-"] : files; self.framing = framing
        machine = .init(topLevelArrayStreaming: framing == .array)
    }
    private static func whitespace(_ byte: UInt8) -> Bool { [9,10,13,32].contains(byte) }
    private mutating func peek(context: inout CLIJobContext) throws -> UInt8? {
        try context.checkpoint()
        if index < buffer.count { return buffer[index] }
        if !buffer.isEmpty { try context.meter.release(UInt64(buffer.count)); buffer = []; index = 0 }
        if eof { return nil }
        if source == nil {
            guard fileIndex < files.count else { return nil }
            try context.work(UInt64(files[fileIndex].utf8.count) + 1)
            source = try CLIInput(path: files[fileIndex])
        }
        if let chunk = try source!.next(context: &context) { buffer = chunk; index = 0; return buffer[0] }
        eof = true; return nil
    }
    private mutating func beginRecord(context: inout CLIJobContext) throws {
        try context.domain(.streaming); try context.meter.resetValueBounds()
        recordStarted = true; recordEntry = context.meter.used(.retainedBytes)
        entryBuffer = UInt64(buffer.count); entryOuter = outerBytes
    }
    private func ownedRecordBytes(context: borrowing CLIJobContext) throws -> UInt64 {
        let end = context.meter.used(.retainedBytes) + entryBuffer + entryOuter
        let start = recordEntry + UInt64(buffer.count) + outerBytes
        guard end >= start else { throw CLIError(.usage, "invalidCursorOwnership") }
        return end - start
    }
    private mutating func finishFile() {
        source = nil; fileIndex += 1; eof = false; fileRecords = 0
        machine = .init(topLevelArrayStreaming: framing == .array); assembler = .init()
        outerStarted = false; outerClosed = false; outerBytes = 0
    }
    private mutating func yield(_ value: JSON, context: inout CLIJobContext) throws -> FilterYield {
        let bytes = try ownedRecordBytes(context: context)
        try context.charge(.totalRecords); try context.meter.charge(.totalRecords)
        let lease = try CLIValueLease(ownedRetained: bytes, context: &context)
        recordStarted = false; recordSawData = false; ready = nil; fileRecords += 1
        return .init(value: value, lease: lease)
    }
    private mutating func consume(_ event: JSONMachineEvent, context: inout CLIJobContext) throws {
        if framing == .array {
            if !outerStarted {
                guard case .startArray = event.kind else { throw JSONFailure(.syntax, code: .invalidSyntax) }
                outerStarted = true; outerBytes = JSONLogicalWeights.frame; return
            }
            if machine.hasCompleteRoot {
                guard case .endArray = event.kind else { throw JSONFailure(.syntax, code: .invalidSyntax) }
                outerClosed = true; outerBytes = 0; return
            }
        }
        if let value = try assembler.consume(event, meter: &context.meter) { ready = value }
    }
    package mutating func next(context: inout CLIJobContext) throws -> FilterYield? {
        guard !failed else { throw CLIError(.input, "cursorTerminal") }
        do {
            switch framing {
            case .rawLines, .rawText, .ndjson: return try line(context: &context)
            case .values, .document, .array: return try json(context: &context)
            }
        } catch { failed = true; context.latch(error); throw error }
    }
    private mutating func json(context: inout CLIJobContext) throws -> FilterYield? {
        while fileIndex < files.count {
            if !recordStarted { try beginRecord(context: &context) }
            if let value = ready {
                if framing == .array {
                    // This element is provisional. Closing outer syntax and EOF are
                    // still mandatory when next()/drain() resumes this cursor.
                    return try yield(value, context: &context)
                }
                if framing == .values {
                    if let byte = try peek(context: &context) {
                        guard Self.whitespace(byte) else { throw JSONFailure(.syntax, code: .trailingData, location: .init(byteOffset: machine.offset)) }
                        _ = try machine.next(in: buffer, index: &index, through: index + 1, meter: &context.meter)
                        let offset = machine.offset
                        let result = try yield(value, context: &context)
                        machine = .init(offset: offset); assembler = .init(); return result
                    }
                    _ = try machine.finish(meter: &context.meter)
                    let result = try yield(value, context: &context)
                    finishFile(); return result
                }
            }
            if let byte = try peek(context: &context) {
                if !Self.whitespace(byte) { recordSawData = true }
                if let event = try machine.next(in: buffer, index: &index, through: index + 1, meter: &context.meter) {
                    try consume(event, context: &context)
                }
                continue
            }
            if !recordSawData && ready == nil && framing == .values {
                recordStarted = false; finishFile(); continue
            }
            if let event = try machine.finish(meter: &context.meter) { try consume(event, context: &context); continue }
            if framing == .array {
                guard outerStarted && outerClosed else { throw JSONFailure(.syntax, code: .unexpectedEOF) }
                recordStarted = false; finishFile(); continue
            }
            guard let value = ready else { throw JSONFailure(.syntax, code: .unexpectedEOF) }
            let result = try yield(value, context: &context)
            finishFile(); return result
        }
        return nil
    }
    private mutating func line(context: inout CLIJobContext) throws -> FilterYield? {
        while fileIndex < files.count {
            if !recordStarted { try beginRecord(context: &context) }
            var bytes: [UInt8] = [], sawLF = false
            while let byte = try peek(context: &context) {
                try context.work(); try context.meter.require(.inputBytes, UInt64(bytes.count) + 1)
                try context.meter.retain(1); bytes.append(byte); index += 1
                if framing != .rawText && byte == 10 { sawLF = true; break }
            }
            if bytes.isEmpty && framing != .rawText {
                if framing == .ndjson && fileRecords == 0 { throw JSONFailure(.syntax, code: .unexpectedEOF) }
                recordStarted = false; finishFile(); continue
            }
            let value: JSON
            if framing == .ndjson {
                value = try JSONParser().parse(bytes, meter: &context.meter)
            } else {
                if framing == .rawLines && sawLF {
                    bytes.removeLast(); try context.meter.release(1)
                    if bytes.last == 13 { bytes.removeLast(); try context.meter.release(1) }
                }
                try context.work(UInt64(bytes.count)); try context.meter.retain(UInt64(bytes.count))
                guard let text = String(bytes: bytes, encoding: .utf8) else { throw JSONFailure(.syntax, code: .invalidUTF8) }
                value = .string(text)
                try JSONAdmission.value(value, meter: &context.meter, owned: true)
                try context.meter.release(UInt64(bytes.count))
            }
            let owned = try ownedRecordBytes(context: context)
            guard owned >= UInt64(bytes.count) else { throw CLIError(.usage, "invalidLineOwnership") }
            let graph = owned - UInt64(bytes.count)
            try context.meter.release(UInt64(bytes.count))
            // The line source reservation has transferred; close() must not refund
            // its discarded byte buffer if the final record quota fails.
            recordEntry = context.meter.used(.retainedBytes) - graph
            entryBuffer = UInt64(buffer.count); entryOuter = 0
            try context.charge(.totalRecords); try context.meter.charge(.totalRecords)
            let lease = try CLIValueLease(ownedRetained: graph, context: &context)
            recordStarted = false; fileRecords += 1
            if !sawLF || framing == .rawText { finishFile() }
            return .init(value: value, lease: lease)
        }
        return nil
    }
    package mutating func drain(context: inout CLIJobContext) throws {
        while var value = try next(context: &context) { try value.release(context: &context) }
    }
    package mutating func close(context: inout CLIJobContext) throws {
        if recordStarted {
            let bytes = try ownedRecordBytes(context: context)
            try context.meter.release(bytes)
        }
        if !buffer.isEmpty { try context.meter.release(UInt64(buffer.count)) }
        if outerBytes > 0 { try context.meter.release(outerBytes) }
        buffer = []; source = nil; ready = nil; assembler = .init(); machine = .init()
        outerBytes = 0; recordStarted = false; failed = true
        try context.reclaimValueLeases()
    }
}
