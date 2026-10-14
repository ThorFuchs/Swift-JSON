// SPDX-License-Identifier: Apache-2.0
import JSON

package enum FilterLexer {
    package static func lex(_ source: String, context: inout CLIJobContext) throws -> [FilterToken] {
        let count = UInt64(source.utf8.count)
        try context.charge(.querySourceBytes, count); try context.meter.retain(count); try context.work(count)
        let bytes = Array(source.utf8)
        var tokens: [FilterToken] = [], i = 0
        func append(_ kind: FilterToken.Kind, _ start: Int, _ end: Int, context: inout CLIJobContext) throws {
            try context.charge(.queryTokens); try context.meter.retain(48)
            tokens.append(.init(kind: kind, range: start..<end))
        }
        func nameStart(_ byte: UInt8) -> Bool { byte == 95 || (65...90).contains(byte) || (97...122).contains(byte) }
        func nameByte(_ byte: UInt8) -> Bool { nameStart(byte) || (48...57).contains(byte) }
        while i < bytes.count {
            try context.work(); let start = i, byte = bytes[i]
            if [9,10,13,32].contains(byte) { i += 1; continue }
            if byte == 35 { while i < bytes.count && bytes[i] != 10 { try context.work(); i += 1 }; continue }
            if byte == 34 {
                i += 1; var escaped = false, closed = false
                while i < bytes.count {
                    try context.work(); let b = bytes[i]; i += 1
                    if escaped { escaped = false; continue }
                    if b == 92 { escaped = true; continue }
                    if b == 34 { closed = true; break }
                }
                guard closed else { throw FilterCompileFailure("unterminatedString", at: start) }
                let value: JSON
                let copyBytes = UInt64(i-start)
                try context.work(copyBytes); try context.meter.retain(copyBytes)
                defer { try? context.meter.release(copyBytes) }
                do { value = try JSONParser().parse(Array(bytes[start..<i]), meter: &context.meter) }
                catch let error as JSONFailure where error.category == .syntax { throw FilterCompileFailure("invalidString", at: start) }
                try append(.literal(value), start, i, context: &context); continue
            }
            if (48...57).contains(byte) {
                i += 1
                while i < bytes.count {
                    let b = bytes[i]
                    if (48...57).contains(b) || b == 46 || b == 101 || b == 69 || (b == 43 || b == 45) && (bytes[i-1] == 101 || bytes[i-1] == 69) { try context.work(); i += 1 }
                    else { break }
                }
                let number: JSONNumber
                do { number = try .parse(bytes[start..<i], meter: &context.meter) }
                catch let error as JSONFailure where error.category == .syntax { throw FilterCompileFailure("invalidNumber", at: start) }
                try append(.literal(.number(number)), start, i, context: &context); continue
            }
            if byte == 36 || nameStart(byte) {
                let variable = byte == 36; if variable { i += 1 }
                guard i < bytes.count, nameStart(bytes[i]) else { throw FilterCompileFailure("invalidIdentifier", at: start) }
                let textStart = i; i += 1
                while i < bytes.count && nameByte(bytes[i]) { try context.work(); i += 1 }
                try context.meter.retain(UInt64(i-textStart)); try context.work(UInt64(i-textStart))
                let text = String(decoding: bytes[textStart..<i], as: UTF8.self)
                let kind: FilterToken.Kind
                if variable { kind = .variable(text) }
                else if text == "true" || text == "false" { kind = .literal(.boolean(text == "true")) }
                else if text == "null" { kind = .literal(.null) }
                else { kind = .name(text) }
                try append(kind, start, i, context: &context); continue
            }
            if i+1 < bytes.count {
                let pair = String(decoding: bytes[i...i+1], as: UTF8.self)
                if ["..", "//", "==", "!=", "<=", ">=", "|=", "+=", "-=", "*=", "/=", "%="].contains(pair) {
                    i += 2; try append(.symbol(pair), start, i, context: &context); continue
                }
            }
            guard [46,44,124,40,41,91,93,123,125,58,59,63,43,45,42,47,37,60,62,61,64].contains(byte) else { throw FilterCompileFailure("unexpectedByte", at: start) }
            i += 1; try append(.symbol(String(Unicode.Scalar(byte))), start, i, context: &context)
        }
        return tokens
    }
}
