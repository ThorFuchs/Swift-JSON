// SPDX-License-Identifier: Apache-2.0
import JSON

/// RFC 3986 section 5.2 component resolution over already admitted encoded bytes.
/// Scratch admission belongs to JSONSchemaURI.parse's invocation-owned meter.
package enum JSONSchemaURIResolution {
    private struct Parts {
        var scheme: Range<Int>?
        var authority: Range<Int>?
        var path: Range<Int> = 0..<0
        var query: Range<Int>?
        var fragment: Range<Int>?
    }

    private static func parts(_ bytes: [UInt8], meter: inout JSONWorkMeter) throws -> Parts {
        var result = Parts(), index = 0
        while index < bytes.count && ![47, 63, 35].contains(bytes[index]) {
            try meter.work()
            if bytes[index] == 58 { result.scheme = 0..<index; index += 1; break }
            index += 1
        }
        if result.scheme == nil { index = 0 }
        if index + 1 < bytes.count && bytes[index] == 47 && bytes[index + 1] == 47 {
            index += 2
            let start = index
            while index < bytes.count && ![47, 63, 35].contains(bytes[index]) { try meter.work(); index += 1 }
            result.authority = start..<index
        }
        let path = index
        while index < bytes.count && bytes[index] != 63 && bytes[index] != 35 { try meter.work(); index += 1 }
        result.path = path..<index
        if index < bytes.count && bytes[index] == 63 {
            index += 1
            let query = index
            while index < bytes.count && bytes[index] != 35 { try meter.work(); index += 1 }
            result.query = query..<index
        }
        if index < bytes.count { result.fragment = (index + 1)..<bytes.count }
        return result
    }

    package static func resolve(_ text: String, relativeTo base: String?, meter: inout JSONWorkMeter) throws -> String {
        guard let base else { return text } // Native format admission already requires an absolute scheme.
        var reference: [UInt8] = [], origin: [UInt8] = []
        for byte in text.utf8 { try meter.work(); reference.append(byte) }
        for byte in base.utf8 { try meter.work(); origin.append(byte) }
        let r = try parts(reference, meter: &meter)
        if r.scheme != nil { return text }
        let b = try parts(origin, meter: &meter)
        guard let scheme = b.scheme else { throw JSONSchemaCompilationFailure(.identifier) }
        var output: [UInt8] = []
        func byte(_ value: UInt8) throws {
            try meter.work(); try meter.require(.stringBytes, UInt64(output.count) + 1)
            output.append(value)
        }
        func append(_ buffer: [UInt8], _ range: Range<Int>) throws {
            for index in range { try byte(buffer[index]) }
        }
        try append(origin, scheme); try byte(58)
        if let authority = r.authority {
            try byte(47); try byte(47); try append(reference, authority)
            try append(reference, r.path)
            if let query = r.query { try byte(63); try append(reference, query) }
        } else {
            if let authority = b.authority { try byte(47); try byte(47); try append(origin, authority) }
            if r.path.isEmpty {
                try append(origin, b.path)
                if let query = r.query { try byte(63); try append(reference, query) }
                else if let query = b.query { try byte(63); try append(origin, query) }
            } else {
                if reference[r.path.lowerBound] != 47 {
                    if b.authority != nil && b.path.isEmpty { try byte(47) }
                    else {
                        var end = b.path.lowerBound
                        for index in b.path { try meter.work(); if origin[index] == 47 { end = index + 1 } }
                        try append(origin, b.path.lowerBound..<end)
                    }
                }
                try append(reference, r.path)
                if let query = r.query { try byte(63); try append(reference, query) }
            }
        }
        if let fragment = r.fragment { try byte(35); try append(reference, fragment) }
        // Existing syntax normalization removes dot segments and normalizes
        // encoded scalar identity after this bounded component merge.
        for _ in output { try meter.work() }
        return String(decoding: output, as: UTF8.self)
    }
}
