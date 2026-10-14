// SPDX-License-Identifier: Apache-2.0
import JSON

/// Type-directed exact overloads. Construction is invocation-owned and re-admitted;
/// strings and object keys are never normalized through Swift canonical equality.
package enum FilterOperators {
    package static func apply(_ op: String, _ a: JSON, _ b: JSON, context: inout CLIJobContext) throws -> FilterYield {
        if case .number(let lhs) = a, case .number(let rhs) = b {
            return try ExactDecimal.binary(op, lhs, rhs, context: &context)
        }
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        var owned: UInt64 = 0, collections: UInt64 = 0, transferred = false
        defer {
            try? context.meter.release(context.meter.used(.retainedBytes) - entry - owned)
            if !transferred { try? context.release(.collectionValues, collections) }
        }
        func collect(_ count: UInt64, context: inout CLIJobContext) throws {
            try context.charge(.collectionValues, count); collections += count
            try context.meter.require(.arrayItems, collections)
            try context.meter.retain(count * 16); try context.work(count)
        }
        var value: JSON
        switch (op, a, b) {
        case ("+", .null, _): value = b
        case ("+", _, .null): value = a
        case ("+", .string(let lhs), .string(let rhs)):
            var text = "", bytes: UInt64 = 0
            for source in [lhs, rhs] {
                for scalar in source.unicodeScalars {
                    let size = UInt64(scalar.utf8.count)
                    try context.work(size); try context.meter.require(.stringBytes, bytes + size); try context.meter.retain(size)
                    text.unicodeScalars.append(scalar); bytes += size
                }
            }
            value = .string(text)
        case ("+", .array(let lhs), .array(let rhs)):
            try collect(UInt64(lhs.count) + UInt64(rhs.count), context: &context)
            value = .array(lhs + rhs)
        case ("-", .array(let lhs), .array(let rhs)):
            var values: [JSON] = []
            for candidate in lhs {
                var excluded = false
                for match in rhs { try context.work(); if try FilterValues.equals(candidate, match, context: &context) { excluded = true; break } }
                if !excluded { try collect(1, context: &context); values.append(candidate) }
            }
            value = .array(values)
        case ("+", .object(let lhs), .object(let rhs)), ("*", .object(let lhs), .object(let rhs)):
            value = try merge(lhs, rhs, recursive: op == "*", context: &context)
        case ("*", .string(let text), .number(let count)), ("*", .number(let count), .string(let text)):
            guard count.isInteger, !count.isNegative else { throw FilterLanguageFailure("invalidRepeatCount") }
            // Check the host index before narrowing a count; no hidden iteration limit.
            let repeats: Int
            do { repeats = try count.integer(as: Int.self, meter: &context.meter) }
            catch let failure as JSONFailure where failure.category == .conversion { throw CLIError(.resource, "counterOverflow", metric: "stringBytes") }
            var bytes: UInt64 = 0
            for _ in text.utf8 { try context.work(); bytes += 1 }
            let (total, overflow) = bytes.multipliedReportingOverflow(by: UInt64(repeats))
            guard !overflow else { throw CLIError(.resource, "counterOverflow", metric: "stringBytes") }
            try context.meter.require(.stringBytes, total); try context.meter.retain(total)
            var output = ""
            for _ in 0..<repeats { try context.work(); for scalar in text.unicodeScalars { try context.work(UInt64(scalar.utf8.count)); output.unicodeScalars.append(scalar) } }
            value = .string(output)
        case ("/", .string(let text), .string(let separator)):
            value = .array(try split(text, separator: separator, context: &context, collectionCount: &collections))
        default: throw FilterLanguageFailure("arithmeticTypeMismatch")
        }
        let result = try FilterValues.produced(value, collections: collections, context: &context)
        owned = result.lease?.retained ?? 0; transferred = true
        return result
    }
    private struct MergeFrame {
        var members: [JSONMember]
        var index: JSONExactKeyIndex
        let right: JSONObject
        var position = 0
        let parentPosition: Int?
    }
    private static func merge(_ left: JSONObject, _ right: JSONObject, recursive: Bool, context: inout CLIJobContext) throws -> JSON {
        func frame(_ left: JSONObject, _ right: JSONObject, parent: Int?, context: inout CLIJobContext) throws -> MergeFrame {
            try context.meter.require(.objectMembers, UInt64(left.count)); try context.meter.retain(80 + UInt64(left.count) * 24); try context.work(UInt64(left.count))
            var index = JSONExactKeyIndex()
            for position in left.members.indices { _ = try index.insert(left.members[position].key, position: position, meter: &context.meter) }
            return .init(members: left.members, index: index, right: right, parentPosition: parent)
        }
        try context.require(.runtimeFrames, context.used(.runtimeFrames) + 1)
        var stack = [try frame(left, right, parent: nil, context: &context)]
        while !stack.isEmpty {
            try context.work(); try context.require(.runtimeFrames, context.used(.runtimeFrames) + UInt64(stack.count))
            var current = stack.removeLast()
            if current.position == current.right.count {
                let result = JSON.object(JSONObject(admitted: current.members, index: current.index))
                if let parent = current.parentPosition { stack[stack.count-1].members[parent] = .init(stack[stack.count-1].members[parent].key, value: result) }
                else { return result }
                continue
            }
            let member = current.right.members[current.position]; current.position += 1
            if let position = try current.index.find(member.key, meter: &context.meter) {
                if recursive, case .object(let a) = current.members[position].value, case .object(let b) = member.value {
                    try context.require(.runtimeFrames, context.used(.runtimeFrames) + UInt64(stack.count) + 2)
                    stack.append(current); stack.append(try frame(a, b, parent: position, context: &context)); continue
                }
                current.members[position] = .init(current.members[position].key, value: member.value)
            } else {
                try context.meter.require(.objectMembers, UInt64(current.members.count) + 1); try context.meter.retain(24)
                _ = try current.index.insert(member.key, position: current.members.count, meter: &context.meter)
                current.members.append(member)
            }
            stack.append(current)
        }
        throw CLIError(.resource, "mergeInvariant")
    }
    package static func split(_ text: String, separator: String, context: inout CLIJobContext, collectionCount: inout UInt64) throws -> [JSON] {
        var pattern: [Unicode.Scalar] = [], scalars: [Unicode.Scalar] = []
        for scalar in separator.unicodeScalars { try context.work(); try context.meter.retain(4); pattern.append(scalar) }
        for scalar in text.unicodeScalars { try context.work(); try context.meter.retain(4); scalars.append(scalar) }
        var results: [JSON] = [], part = "", position = 0
        func append(_ text: String, context: inout CLIJobContext) throws {
            try context.charge(.collectionValues); collectionCount += 1
            try context.meter.require(.arrayItems, collectionCount); try context.meter.retain(16)
            results.append(.string(text))
        }
        while position < scalars.count {
            try context.work()
            if pattern.isEmpty { try context.meter.retain(UInt64(scalars[position].utf8.count)); try append(String(scalars[position]), context: &context); position += 1; continue }
            var matches = position + pattern.count <= scalars.count
            if matches { for offset in pattern.indices { try context.work(); if scalars[position+offset].value != pattern[offset].value { matches = false; break } } }
            if matches { try append(part, context: &context); part = ""; position += pattern.count }
            else { let scalar = scalars[position]; try context.meter.retain(UInt64(scalar.utf8.count)); part.unicodeScalars.append(scalar); position += 1 }
        }
        if !pattern.isEmpty { try append(part, context: &context) }
        return results
    }
}
