// SPDX-License-Identifier: Apache-2.0
import JSON

// Owned, actor-independent generation. The strict writer owns JSON syntax and UTF-8;
// this adapter maps its classified bytes to RTF without Foundation text conversion.
package enum JSONRTFWriter {
    package static func write(_ value: JSON, options: JSONExportOptions,
                              meter: inout JSONWorkMeter) throws -> [UInt8] {
        var output = JSONExportBuffer(limit: options.limits.maxRepresentationBytes)
        // RTF is deterministic light rich text; browser automatic/dark themes apply
        // only to HTML. Fixed local font/color tables contain no external resources.
        try output.append(#"{\rtf1\ansi\deff0\uc1{\fonttbl{\f0\fmodern Menlo;}}{\colortbl;\red35\green40\blue48;\red33\green75\blue110;\red35\green111\blue59;\red143\green59\blue16;\red106\green58\blue156;\red100\green100\blue100;}\pard\deftab"#.utf8, meter: &meter)
        // Menlo 11 advances approximately 6.6 points per cell. Each paragraph
        // receives explicit stops for its actual indentation; native decoders may
        // ignore deftab. No depth-sized stop array or preliminary traversal exists.
        let tabTwips = UInt64(options.tabWidth * 132)
        try output.append(String(tabTwips).utf8, meter: &meter)
        try output.append(#"\f0\fs22 "#.utf8, meter: &meter)
        var tabPosition: UInt64 = 0
        var cursor = JSONWritingCursor(value: value, options: .init(limits: options.limits.core,
            indentation: options.indentation, numberStyle: .preserved, indentationUnit: options.indentationUnit))
        var previousColor: Int? = nil
        var runs: UInt64 = 0, units: UInt64 = 0
        // A scalar occupies at most four strict UTF-8 bytes. Fixed-width scalar
        // state avoids a token-sized buffer or native attributed-string allocation.
        var scalar: UInt32 = 0, remaining: Int = 0, minimum: UInt32 = 0
        while let token = try cursor.nextToken(meter: &meter) {
            try meter.work()
            let color: Int
            switch token.kind {
            case .key: color = 2
            case .string: color = 3
            case .number: color = 4
            case .boolean: color = 5
            case .null: color = 6
            case .punctuation, .whitespace: color = 1
            }
            if color != previousColor {
                guard remaining == 0 else { throw JSONExportFailure.invalidConfiguration }
                runs = try JSONExportBuffer.adding(.rtfStyleRuns, runs, 1, options.limits.maxRTFStyleRuns)
                try output.append(("\\cf" + String(color) + " ").utf8, meter: &meter)
                previousColor = color
            }
            let byte = token.byte
            if remaining > 0 {
                guard byte & 0xc0 == 0x80 else { throw JSONExportFailure.invalidConfiguration }
                scalar = (scalar << 6) | UInt32(byte & 0x3f); remaining -= 1
                if remaining > 0 { continue }
                guard scalar >= minimum, scalar <= 0x10ffff, !(0xd800...0xdfff).contains(scalar) else {
                    throw JSONExportFailure.invalidConfiguration
                }
            } else if byte >= 0x80 {
                switch byte {
                case 0xc2...0xdf: scalar = UInt32(byte & 0x1f); remaining = 1; minimum = 0x80
                case 0xe0...0xef: scalar = UInt32(byte & 0x0f); remaining = 2; minimum = 0x800
                case 0xf0...0xf4: scalar = UInt32(byte & 0x07); remaining = 3; minimum = 0x10000
                default: throw JSONExportFailure.invalidConfiguration
                }
                continue
            } else { scalar = UInt32(byte) }
            units = try JSONExportBuffer.adding(.rtfUTF16Units, units, scalar > 0xffff ? 2 : 1,
                                               options.limits.maxRTFUTF16Units)
            if scalar < 0x80 {
                switch scalar {
                case 10:
                    try output.append("\\par\n\\pard\\f0\\fs22 ".utf8, meter: &meter)
                    tabPosition = 0
                case 9:
                    tabPosition = try JSONExportBuffer.adding(.rtfTabPosition, tabPosition, tabTwips, UInt64(Int32.max))
                    try output.append(("\\tx" + String(tabPosition) + "\\tab ").utf8, meter: &meter)
                case 92, 123, 125:
                    try output.append(92, meter: &meter); try output.append(UInt8(scalar), meter: &meter)
                case 32...126: try output.append(UInt8(scalar), meter: &meter)
                default: throw JSONExportFailure.invalidConfiguration
                }
            } else if scalar <= 0xffff {
                try unicode(UInt16(scalar), output: &output, meter: &meter)
            } else {
                let supplementary = scalar - 0x10000
                try unicode(UInt16(0xd800 + (supplementary >> 10)), output: &output, meter: &meter)
                try unicode(UInt16(0xdc00 + (supplementary & 0x3ff)), output: &output, meter: &meter)
            }
        }
        guard remaining == 0 else { throw JSONExportFailure.invalidConfiguration }
        try output.append(125, meter: &meter)
        try meter.checkpoint()
        return output.bytes
    }

    private static func unicode(_ unit: UInt16, output: inout JSONExportBuffer,
                                meter: inout JSONWorkMeter) throws {
        try meter.work()
        try output.append(("\\u" + String(Int16(bitPattern: unit)) + "?").utf8, meter: &meter)
    }
}
