// SPDX-License-Identifier: Apache-2.0
import JSON

extension JSONHTMLRenderer {
    package func nativeBytes(_ value: JSON, options: JSONWritingOptions, meter: inout JSONWorkMeter) throws -> [UInt8] {
        var cursor = JSONWritingCursor(value: value, options: options), bytes: [UInt8] = []
        while let byte = try cursor.next(meter: &meter) {
            try meter.work(); try meter.charge(.outputBytes); try meter.retain(1); bytes.append(byte)
        }
        return bytes
    }
    package func highlighted(_ value: JSON, options: JSONWritingOptions, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter) throws {
        var cursor = JSONWritingCursor(value: value, options: options)
        var active: JSONWritingTokenKind?
        while let token = try cursor.nextToken(meter: &meter) {
            if token.kind != active {
                if let active, active != .whitespace { try output.append("</span>", meter: &meter) }
                try output.addDOM(4, meter: &meter)
                if token.kind != .whitespace {
                    try output.append("<span class=\"", meter: &meter)
                    try output.append(token.kind.rawValue, meter: &meter)
                    try output.append("\">", meter: &meter)
                }
                active = token.kind
            }
            try output.escaped(token.byte, meter: &meter)
        }
        if let active, active != .whitespace { try output.append("</span>", meter: &meter) }
    }
    package func label(_ component: JSONLocationComponent?, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter, searchable: Bool) throws {
        switch component {
        case .key(let key):
            try output.append(searchable ? "<code class=\"key-label key\" data-search>" : "<code class=\"key\">", meter: &meter)
            var cursor = JSONWritingCursor(value: .string(key.string), options: .init(numberStyle: .preserved))
            while let byte = try cursor.next(meter: &meter) { try output.escaped(byte, meter: &meter) }
            try output.append("</code>", meter: &meter)
        case .index(let index):
            try output.append("[", meter: &meter); try output.decimal(UInt64(index), meter: &meter); try output.append("]", meter: &meter)
        case nil: try output.append("Root", meter: &meter)
        }
    }
    package func pointerBytes(_ path: [JSONLocationComponent], meter: inout JSONWorkMeter) throws -> [UInt8] {
        try meter.require(.pointerTokens, UInt64(path.count))
        var result: [UInt8] = []
        func emit(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
            try meter.work(); try meter.require(.pointerBytes, UInt64(result.count) + 1)
            try meter.charge(.outputBytes); try meter.retain(1); result.append(byte)
        }
        for component in path {
            try emit(47, meter: &meter)
            let token: String
            switch component {
            case .key(let key): token = key.string
            case .index(let index): try meter.retain(20); try meter.work(20); token = String(index)
            }
            for byte in token.utf8 {
                try meter.work()
                if byte == 126 || byte == 47 { try emit(126, meter: &meter); try emit(byte == 126 ? 48 : 49, meter: &meter) }
                else { try emit(byte, meter: &meter) }
            }
            if case .index = component { try meter.release(20) }
        }
        return result
    }
}

extension JSONHTMLDocumentBuffer {
    // Reserve the complete fixed decimal scratch before any owned formatting.
    package mutating func decimal(_ value: UInt64, meter: inout JSONWorkMeter) throws {
        try meter.retain(20)
        var remainder = value, digits: [UInt8] = []
        repeat { try meter.work(); digits.append(UInt8(remainder % 10) + 48); remainder /= 10 } while remainder > 0
        for byte in digits.reversed() { try appendByte(byte, meter: &meter) }
        try meter.release(20)
    }
    package mutating func base64(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws {
        let table = JSONHTMLInteractiveAssets.base64Alphabet
        var index = 0
        while index < bytes.count {
            try meter.work()
            let a = bytes[index], b = index + 1 < bytes.count ? bytes[index + 1] : 0, c = index + 2 < bytes.count ? bytes[index + 2] : 0
            try meter.retain(4)
            for byte in [table[Int(a >> 2)], table[Int((a & 3) << 4 | b >> 4)], index + 1 < bytes.count ? table[Int((b & 15) << 2 | c >> 6)] : 61, index + 2 < bytes.count ? table[Int(c & 63)] : 61] {
                try meter.work(); try addMetadata(meter: &meter); try appendByte(byte, meter: &meter)
            }
            try meter.release(4)
            index += min(3, bytes.count - index)
        }
    }
}
