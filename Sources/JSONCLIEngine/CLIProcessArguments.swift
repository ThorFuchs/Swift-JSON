// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSONFilterRuntime

/// Decode process-owned argv only after finite admission. CommandLine.arguments
/// would replace invalid UTF-8 before the strict CLI could inspect it.
package enum CLIProcessArguments {
    package static func read(context: inout CLIJobContext) throws -> [String] {
        let argc = CommandLine.argc
        guard argc >= 1 else { throw CLIError(.usage, "invalidArgv") }
        try context.require(.argvBytes, UInt64(argc-1))
        var result: [String] = []
        for index in 1..<Int(argc) {
            try context.work(); try context.meter.retain(8)
            guard let argument = unsafe CommandLine.unsafeArgv[index] else { throw CLIError(.usage, "invalidArgv") }
            var bytes: [UInt8] = [], offset = 0
            while true {
                try context.charge(.argvBytes); try context.work()
                let byte = unsafe UInt8(bitPattern: argument[offset])
                if byte == 0 { break }
                try context.meter.retain(1); bytes.append(byte); offset += 1
            }
            try context.work(UInt64(bytes.count)); try context.meter.retain(UInt64(bytes.count))
            guard let text = String(bytes: bytes, encoding: .utf8) else { throw CLIError(.usage, "invalidArgvUTF8") }
            try context.meter.release(UInt64(bytes.count))
            result.append(text)
        }
        return result
    }
    package static func preferences(_ arguments: [String], context: inout CLIJobContext) throws -> (json: Bool, report: Bool) {
        var json = false, report = false, index = 1
        while index < arguments.count {
            try context.work(UInt64(arguments[index].utf8.count)+1)
            let argument = arguments[index]; index += 1
            if ["--", "--args", "--jsonargs"].contains(argument) { break }
            if argument == "--diagnostics=json" { json = true }
            if argument == "--report=json" { report = true }
            if ["--diagnostics", "--report"].contains(argument), index < arguments.count {
                if argument == "--diagnostics" { json = arguments[index] == "json" }
                else { report = arguments[index] == "json" }
                index += 1
            }
        }
        return (json, report)
    }
}
