// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

package enum CLIQueryOutput {
    package static func emit(_ value: JSON, arguments: CLIArguments, output: CLIOutput, context: inout CLIJobContext) throws {
        try context.domain(.writing); try context.meter.resetValueBounds()
        let retainedAtEntry = context.meter.used(.retainedBytes)
        defer {
            let retained = context.meter.used(.retainedBytes)
            if retained >= retainedAtEntry { try? context.meter.release(retained - retainedAtEntry) }
            else { context.latch(CLIError(.usage, "invalidOutputOwnership")) }
        }
        let raw = arguments.options["raw-output"] != nil || arguments.options["raw-output0"] != nil || arguments.options["join-output"] != nil
        var bytes: [UInt8] = []
        func append(_ byte: UInt8, context: inout CLIJobContext) throws {
            try context.work(); try context.meter.charge(.outputBytes); try context.meter.retain(1)
            bytes.append(byte)
        }
        if raw, case .string(let text) = value {
            // Validate the entire string before handing off any bytes of this record.
            if arguments.options["raw-output0"] != nil {
                for byte in text.utf8 { try context.work(); if byte == 0 { throw CLIError(.language, "nulInRawOutput") } }
            }
            for byte in text.utf8 { try append(byte, context: &context) }
        } else {
            try JSONAdmission.value(value, meter: &context.meter)
            var cursor = JSONWritingCursor(value: value, options: arguments.writingOptions(limits: context.meter.limits))
            let ascii = arguments.options["ascii-output"] != nil
            let hex: [UInt8] = Array("0123456789abcdef".utf8)
            func escape(_ unit: UInt32, context: inout CLIJobContext) throws {
                try append(92, context: &context); try append(117, context: &context)
                for shift in [12,8,4,0] { try append(hex[Int((unit >> shift) & 15)], context: &context) }
            }
            while let byte = try cursor.next(meter: &context.meter) {
                if !ascii || byte < 128 { try append(byte, context: &context); continue }
                let count: Int, initial: UInt32
                if byte < 224 { count = 2; initial = UInt32(byte & 31) }
                else if byte < 240 { count = 3; initial = UInt32(byte & 15) }
                else { count = 4; initial = UInt32(byte & 7) }
                var scalar = initial
                for _ in 1..<count {
                    guard let continuation = try cursor.next(meter: &context.meter), continuation & 192 == 128 else { throw JSONFailure(.syntax, code: .invalidUTF8) }
                    scalar = (scalar << 6) | UInt32(continuation & 63)
                }
                if scalar <= 65535 { try escape(scalar, context: &context) }
                else {
                    let remainder = scalar - 65536
                    try escape(55296 + (remainder >> 10), context: &context)
                    try escape(56320 + (remainder & 1023), context: &context)
                }
            }
        }
        if arguments.options["join-output"] == nil { try append(arguments.options["raw-output0"] == nil ? 10 : 0, context: &context) }
        try context.charge(.totalResults)
        try output.write(bytes, context: &context); output.resultAccepted(context: &context)
    }
}
