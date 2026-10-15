// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONFilterRuntime

package enum CLIQueryCommand {
    package static func run(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> Int32 {
        let source: String, files: [String]
        if let path = arguments.options["filter-file"] {
            source = try textFile(path, maximum: context.limits[.querySourceBytes], context: &context)
            files = arguments.positionals
        } else {
            guard let first = arguments.positionals.first else { throw CLIError(.usage, "missingFilter") }
            source = first; files = Array(arguments.positionals.dropFirst())
        }
        if let raw = arguments.options["division-scale"] {
            guard arguments.options["rounding"] == "half-even", !raw.isEmpty,
                  raw.utf8.allSatisfy({ (48...57).contains($0) }),
                  let scale = UInt64(raw), scale <= context.meter.limits[.numberDigits], scale < UInt64(Int.max) else { throw CLIError(.usage, "invalidDivisionPolicy") }
            context.divisionScale = Int(scale)
        }
        let inputFiles = files.isEmpty ? ["-"] : files
        let auxiliary = arguments.repeated.enumerated().compactMap { index, pair -> String? in
            guard pair.0 == "bindingValue", index > 0, ["rawfile","slurpfile"].contains(arguments.repeated[index-1].0) else { return nil }
            return pair.1
        } + [arguments.options["filter-file"], arguments.options["limits-file"]].compactMap { $0 }
        guard (inputFiles + auxiliary).filter({ $0 == "-" }).count <= 1 else { throw CLIError(.usage, "repeatedStdin") }
        let bindingEntry = context.used(.bindings)
        var bindings: [String: FilterYield] = [:]
        defer {
            bindings = [:]
            try? context.release(.bindings, context.used(.bindings) - bindingEntry)
            try? context.reclaimValueLeases()
        }
        bindings = try makeBindings(arguments, context: &context)
        let program = try FilterCompiler.compile(source, variables: Set(bindings.keys), context: &context)
        try context.domain(.core)
        let output = try CLIOutput(destination: arguments.options["output"], overwrite: arguments.overwrite, inputs: inputFiles + auxiliary, context: &context)
        let framing: CLIInputFraming
        if arguments.options["raw-input"] != nil { framing = arguments.options["slurp"] == nil ? .rawLines : .rawText }
        else {
            guard let selected = CLIInputFraming(rawValue: arguments.options["input-framing"] ?? "values"), [.values,.document,.ndjson].contains(selected) else { throw CLIError(.usage, "invalidInputFraming") }
            framing = selected
        }
        var cursor = CLIInputCursor(files: inputFiles, framing: framing)
        defer { try? cursor.close(context: &context) }
        var finalTruth: Bool?
        func evaluate(_ input: FilterYield, cursor: inout CLIInputCursor, context: inout CLIJobContext) throws {
            try context.domain(.core)
            var vm = try FilterVM(program: program, input: input, bindings: bindings, context: &context)
            defer { try? vm.close(context: &context) }
            while true {
                try context.domain(.core)
                guard var value = try vm.next(input: &cursor, context: &context) else { break }
                finalTruth = FilterTruth.test(value.value)
                try CLIQueryOutput.emit(value.value, arguments: arguments, output: output, context: &context)
                try value.release(context: &context)
            }
        }
        if arguments.options["null-input"] != nil {
            try evaluate(.init(value: .null), cursor: &cursor, context: &context)
        } else if arguments.options["slurp"] != nil {
            var collected: [FilterYield] = [], count: UInt64 = 0, scratch: UInt64 = 0
            defer { try? context.release(.collectionValues, count); try? context.meter.release(scratch) }
            while let value = try cursor.next(context: &context) {
                try context.charge(.collectionValues); count += 1; try context.meter.retain(24); scratch += 24; collected.append(value)
            }
            let input: FilterYield
            if framing == .rawText {
                var text = "", bytes: UInt64 = 0
                defer { try? context.meter.release(bytes) }
                for value in collected {
                    guard case .string(let part) = value.value else { throw CLIError(.input, "invalidRawSlurp") }
                    for scalar in part.unicodeScalars {
                        let amount = UInt64(scalar.utf8.count)
                        try context.work(amount); try context.meter.require(.stringBytes, bytes + amount); try context.meter.retain(amount)
                        text.unicodeScalars.append(scalar); bytes += amount
                    }
                }
                input = try FilterValues.produced(.string(text), context: &context)
            } else {
                try context.meter.retain(count * 16); scratch += count * 16; try context.work(count)
                input = try FilterValues.array(collected.map(\.value), admittedCollectionCount: true, context: &context)
                try context.meter.release(scratch); scratch = 0
                // The finished array lease adopts the collector's logical slots.
                count = 0
            }
            collected = []
            try evaluate(input, cursor: &cursor, context: &context)
        } else {
            while var value = try cursor.next(context: &context) {
                try evaluate(value, cursor: &cursor, context: &context)
                try value.release(context: &context)
            }
        }
        // first()/short-circuiting stops a filter, never the enclosing file's syntax.
        try cursor.drain(context: &context)
        try output.finish(inputs: inputFiles + auxiliary, context: &context)
        bindings = [:]; try context.reclaimValueLeases()
        if arguments.options["exit-status"] != nil { return finalTruth.map { $0 ? 0 : 1 } ?? 4 }
        return 0
    }
    private static func validName(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        guard let first = bytes.first, first == 95 || (65...90).contains(first) || (97...122).contains(first), text != "ARGS" else { return false }
        return bytes.allSatisfy { $0 == 95 || (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) }
    }
    private static func makeBindings(_ arguments: CLIArguments, context: inout CLIJobContext) throws -> [String: FilterYield] {
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        var owned: UInt64 = 0
        defer {
            let total = context.meter.used(.retainedBytes)
            if total >= entry + owned { try? context.meter.release(total - entry - owned) }
            else { context.latch(CLIError(.usage, "invalidBindingOwnership")) }
        }
        var bindings: [String: FilterYield] = [:], named: [JSONMember] = [], index = 0
        while index < arguments.repeated.count {
            let (mode, name) = arguments.repeated[index]; index += 1
            guard validName(name), bindings[name] == nil, index < arguments.repeated.count, arguments.repeated[index].0 == "bindingValue" else { throw CLIError(.usage, "invalidBinding") }
            let source = arguments.repeated[index].1; index += 1
            try context.charge(.bindings); try context.work(UInt64(name.utf8.count) + 1)
            let value: FilterYield
            switch mode {
            case "arg": value = try FilterValues.produced(.string(source), context: &context)
            case "argjson":
                try context.meter.resetValueBounds()
                let entry = context.meter.used(.retainedBytes)
                let json = try JSONParser().parse(Array(source.utf8), meter: &context.meter)
                value = .init(value: json, lease: try CLIValueLease(ownedRetained: context.meter.used(.retainedBytes) - entry, context: &context))
            case "rawfile": value = try FilterValues.produced(.string(textFile(source, maximum: context.meter.limits[.stringBytes], context: &context)), context: &context)
            case "slurpfile":
                var cursor = CLIInputCursor(files: [source]), values: [FilterYield] = [], slots: UInt64 = 0, scratch: UInt64 = 0
                defer {
                    try? cursor.close(context: &context)
                    try? context.release(.collectionValues, slots)
                    try? context.meter.release(scratch)
                }
                while let value = try cursor.next(context: &context) { try context.charge(.collectionValues); slots += 1; try context.meter.retain(24); scratch += 24; values.append(value) }
                try context.meter.retain(slots * 16); scratch += slots * 16; try context.work(slots)
                value = try FilterValues.array(values.map(\.value), admittedCollectionCount: true, context: &context)
                try context.meter.release(scratch); scratch = 0; slots = 0
            default: throw CLIError(.usage, "invalidBinding")
            }
            bindings[name] = value; owned += value.lease?.retained ?? 0
            try context.meter.retain(UInt64(name.utf8.count) + 32)
            try context.meter.retain(24); named.append(.init(try JSONKey(name, meter: &context.meter), value: value.value))
        }
        var positional: [JSON] = []
        if let captured = arguments.capturedArguments {
            for argument in captured {
                try context.charge(.collectionValues); try context.meter.retain(16); try context.work(UInt64(argument.utf8.count) + 1)
                if arguments.captureJSONArguments { try context.meter.resetValueBounds(); positional.append(try JSONParser().parse(Array(argument.utf8), meter: &context.meter)) }
                else { positional.append(.string(argument)) }
            }
        }
        let namedObject = try JSONObject.indexed(admitted: named, meter: &context.meter)
        let args = try CLIEngine.object([("named", .object(namedObject)), ("positional", .array(positional))], context: &context)
        try context.charge(.bindings)
        bindings["ARGS"] = try FilterValues.produced(args, collections: UInt64(positional.count), context: &context)
        owned += bindings["ARGS"]?.lease?.retained ?? 0
        return bindings
    }
    private static func textFile(_ path: String, maximum: UInt64, context: inout CLIJobContext) throws -> String {
        let source = try CLIInput(path: path)
        var bytes: [UInt8] = []
        defer { try? context.meter.release(UInt64(bytes.count)) }
        while let chunk = try source.next(context: &context) {
            guard UInt64(bytes.count) + UInt64(chunk.count) <= maximum else { throw CLIError(.resource, "limitExceeded", metric: "textSourceBytes") }
            try context.work(UInt64(chunk.count)); try context.meter.retain(UInt64(chunk.count))
            bytes.append(contentsOf: chunk); try context.meter.release(UInt64(chunk.count))
        }
        try context.work(UInt64(bytes.count)); try context.meter.retain(UInt64(bytes.count))
        guard let text = String(bytes: bytes, encoding: .utf8) else { throw CLIError(.input, "invalidUTF8") }
        return text
    }
}
