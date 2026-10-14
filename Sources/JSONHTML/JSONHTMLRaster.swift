// SPDX-License-Identifier: Apache-2.0
import JSON

package struct JSONHTMLRaster {
    package let type: JSONHTMLRasterMediaType
    package let bytes: [UInt8]
    package let width: UInt32, height: UInt32
    package let progressive: Bool
    package var reservation: UInt64 { UInt64(bytes.count) }
    package func emit(
        alt: String? = nil, output: inout JSONHTMLDocumentBuffer, meter: inout JSONWorkMeter
    ) throws {
        try output.addDOM(6, meter: &meter)
        try output.append("<figure class=\"image-preview\"><img alt=\"", meter: &meter)
        try JSONHTMLDisplay.text(
            alt ?? "Declared embedded raster preview; original source follows", quoted: false,
            output: &output, meter: &meter)
        try output.append("\" width=\"", meter: &meter)
        try output.decimal(UInt64(width), meter: &meter)
        try output.append("\" height=\"", meter: &meter)
        try output.decimal(UInt64(height), meter: &meter)
        try output.append("\" src=\"data:", meter: &meter)
        try output.append(type.rawValue, meter: &meter)
        try output.append(";base64,", meter: &meter)
        try output.base64(bytes, meter: &meter)
        try output.append("\"><figcaption>", meter: &meter)
        try output.append(type.rawValue, meter: &meter)
        try output.append(" · ", meter: &meter)
        try output.decimal(UInt64(width), meter: &meter)
        try output.append(" × ", meter: &meter)
        try output.decimal(UInt64(height), meter: &meter)
        try output.append(
            " pixels · native header admitted; raster decoding is browser work</figcaption></figure>",
            meter: &meter)
    }
}
package struct JSONHTMLMediaLedger {
    package var bytes: UInt64 = 0
    package var images: UInt64 = 0
}
package enum JSONHTMLRasterAdmission {
    private static let pngDepths: [UInt8: [UInt8]] = [
        0: [1, 2, 4, 8, 16], 2: [8, 16], 3: [1, 2, 4, 8], 4: [8, 16], 6: [8, 16],
    ]
    package static func decode(
        _ source: String, type: JSONHTMLRasterMediaType?, policy: JSONHTMLPreviewPolicy,
        ledger: inout JSONHTMLMediaLedger, meter: inout JSONWorkMeter
    ) throws -> JSONHTMLRaster? {
        let retained = meter.used(.retainedBytes)
        do {
            var iterator = source.utf8.makeIterator()
            var declared = type
            var encoded: [UInt8] = []
            if declared == nil {
                var header: [UInt8] = []
                while let b = iterator.next() {
                    try meter.work()
                    guard header.count < 32 else { throw JSONHTMLPreviewRejection.syntax }
                    try meter.retain(1)
                    header.append(b)
                    if b == 44 { break }
                }
                if header == Array("data:image/png;base64,".utf8) {
                    declared = .png
                } else if header == Array("data:image/jpeg;base64,".utf8) {
                    declared = .jpeg
                } else {
                    throw JSONHTMLPreviewRejection.syntax
                }
                try meter.release(UInt64(header.count))
            }
            while let b = iterator.next() {
                try meter.work()
                guard UInt64(encoded.count) < policy.maxEncodedImageBytes else {
                    throw JSONHTMLPreviewRejection.eligibility
                }
                try meter.retain(1)
                encoded.append(b)
            }
            guard !encoded.isEmpty, encoded.count % 4 == 0, ledger.images < policy.maxImagePreviews
            else {
                throw JSONHTMLPreviewRejection.eligibility
            }
            let padding = encoded.last == 61 ? (encoded[encoded.count - 2] == 61 ? 2 : 1) : 0
            let size = UInt64(encoded.count / 4) * 3 - UInt64(padding)
            guard size <= policy.maxDecodedImageBytes,
                size <= policy.maxAggregateDecodedImageBytes - ledger.bytes
            else { throw JSONHTMLPreviewRejection.eligibility }
            let decoded = try canonical(encoded, maximum: size, meter: &meter)
            try meter.release(UInt64(encoded.count))
            let geometry = try dimensions(decoded, type: declared!, policy: policy, meter: &meter)
            let pixels = UInt64(geometry.0) * UInt64(geometry.1)
            guard geometry.0 > 0, geometry.1 > 0, UInt64(geometry.0) <= policy.maxImageWidth,
                UInt64(geometry.1) <= policy.maxImageHeight, pixels <= policy.maxImagePixels
            else { throw JSONHTMLPreviewRejection.eligibility }
            ledger.bytes += size
            ledger.images += 1
            return .init(
                type: declared!, bytes: decoded, width: geometry.0, height: geometry.1,
                progressive: geometry.2)
        } catch is JSONHTMLPreviewRejection {
            try meter.release(meter.used(.retainedBytes) - retained)
            return nil
        } catch { throw error }
    }
    package static func canonical(_ encoded: [UInt8], maximum: UInt64, meter: inout JSONWorkMeter)
        throws -> [UInt8]
    {
        guard encoded.count % 4 == 0 else { throw JSONHTMLPreviewRejection.syntax }
        func digit(_ b: UInt8) -> UInt32? {
            switch b {
            case 65...90: return UInt32(b - 65)
            case 97...122: return UInt32(b - 71)
            case 48...57: return UInt32(b + 4)
            case 43: return 62
            case 47: return 63
            default: return nil
            }
        }
        var bytes: [UInt8] = []
        var i = 0
        while i < encoded.count {
            try meter.work(4)
            guard let a = digit(encoded[i]), let b = digit(encoded[i + 1]) else {
                throw JSONHTMLPreviewRejection.syntax
            }
            let c = encoded[i + 2]
            let d = encoded[i + 3]
            let last = i + 4 == encoded.count
            var value = a << 18 | b << 12
            let emitted: Int
            if c == 61 {
                guard last, d == 61, b & 15 == 0 else { throw JSONHTMLPreviewRejection.syntax }
                emitted = 1
            } else {
                guard let cc = digit(c) else { throw JSONHTMLPreviewRejection.syntax }
                value |= cc << 6
                if d == 61 {
                    guard last, cc & 3 == 0 else { throw JSONHTMLPreviewRejection.syntax }
                    emitted = 2
                } else {
                    guard let dd = digit(d) else { throw JSONHTMLPreviewRejection.syntax }
                    value |= dd
                    emitted = 3
                }
            }
            for n in 0..<emitted {
                try meter.work()
                guard UInt64(bytes.count) < maximum else {
                    throw JSONHTMLPreviewRejection.eligibility
                }
                try meter.retain(1)
                bytes.append(UInt8(value >> UInt32(16 - 8 * n) & 255))
            }
            i += 4
        }
        return bytes
    }
    private static func dimensions(
        _ data: [UInt8], type: JSONHTMLRasterMediaType, policy: JSONHTMLPreviewPolicy,
        meter: inout JSONWorkMeter
    ) throws -> (UInt32, UInt32, Bool) {
        var scanned: UInt64 = 0
        func read(_ i: Int, _ m: inout JSONWorkMeter) throws -> UInt8 {
            try m.work()
            guard i >= 0, i < data.count, scanned < policy.maxImageHeaderBytes else {
                throw JSONHTMLPreviewRejection.eligibility
            }
            scanned += 1
            return data[i]
        }
        func u32(_ i: Int, _ m: inout JSONWorkMeter) throws -> UInt32 {
            var n: UInt32 = 0
            for x in i..<(i + 4) { n = n << 8 | UInt32(try read(x, &m)) }
            return n
        }
        if type == .png {
            guard data.count >= 45 else { throw JSONHTMLPreviewRejection.syntax }
            for (i, b) in [UInt8(137), 80, 78, 71, 13, 10, 26, 10].enumerated() {
                guard try read(i, &meter) == b else { throw JSONHTMLPreviewRejection.syntax }
            }
            guard try u32(8, &meter) == 13 else { throw JSONHTMLPreviewRejection.syntax }
            for (i, b) in Array("IHDR".utf8).enumerated() {
                guard try read(i + 12, &meter) == b else { throw JSONHTMLPreviewRejection.syntax }
            }
            let width = try u32(16, &meter)
            let height = try u32(20, &meter)
            let depth = try read(24, &meter)
            let color = try read(25, &meter)
            guard pngDepths[color]?.contains(depth) == true, try read(26, &meter) == 0,
                try read(27, &meter) == 0, try read(28, &meter) <= 1
            else { throw JSONHTMLPreviewRejection.syntax }
            // Owned IHDR CRC check; compressed raster validation is deliberately separate.
            var crc: UInt32 = 0xffff_ffff
            for i in 12..<29 {
                crc ^= UInt32(try read(i, &meter))
                for _ in 0..<8 {
                    try meter.work()
                    crc = crc & 1 == 1 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1
                }
            }
            guard crc ^ 0xffff_ffff == (try u32(29, &meter)) else {
                throw JSONHTMLPreviewRejection.syntax
            }
            var at = 33
            var seenIDAT = false
            var ended = false
            while at < data.count {
                guard data.count - at >= 12 else { throw JSONHTMLPreviewRejection.syntax }
                let length = UInt64(try u32(at, &meter))
                guard length <= UInt64(data.count - at) - 12 else {
                    throw JSONHTMLPreviewRejection.syntax
                }
                let tag = try u32(at + 4, &meter)
                if tag == 0x6163_544c { throw JSONHTMLPreviewRejection.syntax }  // acTL: no animation claim.
                if tag == 0x4948_4452 { throw JSONHTMLPreviewRejection.syntax }
                if tag == 0x4944_4154 { seenIDAT = true }
                if tag == 0x4945_4e44 {
                    guard length == 0, seenIDAT, at + 12 == data.count else {
                        throw JSONHTMLPreviewRejection.syntax
                    }
                    ended = true
                    break
                }
                at += Int(length) + 12
            }
            guard ended else { throw JSONHTMLPreviewRejection.syntax }
            return (width, height, false)
        }
        guard data.count >= 4, try read(0, &meter) == 255, try read(1, &meter) == 216,
            data[data.count - 2] == 255, data.last == 217
        else { throw JSONHTMLPreviewRejection.syntax }
        var at = 2
        while at < data.count {
            guard try read(at, &meter) == 255 else { throw JSONHTMLPreviewRejection.syntax }
            at += 1
            while try at < data.count && read(at, &meter) == 255 { at += 1 }
            let marker = try read(at, &meter)
            at += 1
            guard marker != 0, marker != 0xd9, marker != 0xda else {
                throw JSONHTMLPreviewRejection.syntax
            }
            if marker == 0x01 || (0xd0...0xd7).contains(marker) { continue }
            let length = Int(try read(at, &meter)) * 256 + Int(try read(at + 1, &meter))
            guard length >= 2, length <= data.count - at else {
                throw JSONHTMLPreviewRejection.syntax
            }
            if marker == 0xc0 || marker == 0xc2 {
                guard length >= 8, try read(at + 2, &meter) == 8 else {
                    throw JSONHTMLPreviewRejection.syntax
                }
                let height =
                    UInt32(try read(at + 3, &meter)) * 256 + UInt32(try read(at + 4, &meter))
                let width =
                    UInt32(try read(at + 5, &meter)) * 256 + UInt32(try read(at + 6, &meter))
                let components = Int(try read(at + 7, &meter))
                guard [1, 3, 4].contains(components), length == 8 + 3 * components else {
                    throw JSONHTMLPreviewRejection.syntax
                }
                for n in 0..<components {
                    let sampling = try read(at + 9 + n * 3, &meter)
                    guard (1...4).contains(sampling >> 4), (1...4).contains(sampling & 15),
                        try read(at + 10 + n * 3, &meter) <= 3
                    else { throw JSONHTMLPreviewRejection.syntax }
                }
                return (width, height, marker == 0xc2)
            }
            // Count skipped header bytes as scan work before advancing a bounded segment.
            guard UInt64(length) <= policy.maxImageHeaderBytes - scanned else {
                throw JSONHTMLPreviewRejection.eligibility
            }
            try meter.work(UInt64(length))
            scanned += UInt64(length)
            at += length
        }
        throw JSONHTMLPreviewRejection.syntax
    }
}
