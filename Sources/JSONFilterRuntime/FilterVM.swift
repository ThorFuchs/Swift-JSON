// SPDX-License-Identifier: Apache-2.0
import JSON

package protocol FilterInput {
    mutating func next(context: inout CLIJobContext) throws -> FilterYield?
}
/// Explicit, demand-driven continuations. The arena reuses slots; no language
/// recursion becomes Swift call-stack recursion. Only immutable plans are shared.
package struct FilterVM {
    private enum Event { case value(FilterYield), end, failure(FilterLanguageFailure) }
    private enum Action { case pull(Int), emit(Event) }
    private struct ObjectChoice { let key: JSONKey; let value: FilterYield; let keySource: FilterYield }
    private struct Frame {
        let node: Int
        let input: FilterYield
        var bindings: [String: FilterYield]
        var phase = 0
        var children: [Int] = []
        var event: Event?
        var values: [FilterYield] = []
        var members: [(JSONKey, FilterYield)] = []
        var slots: UInt64 = 0
        var collectionSlots: UInt64 = 0
        var bindingSlots: UInt64 = 0
        var scopeBytes: UInt64 = 0
        var index = 0
        var range: FilterRangeState?
        var current: FilterYield?
        var flag = false
        var groups: [[FilterYield]] = []
        var choices: [[ObjectChoice]] = []
        var selections: [Int] = []
    }
    private let program: FilterProgram
    private var frames: [Frame?] = []
    private var available: [Int] = []
    private var root = 0
    private var finished = false
    package init(program: FilterProgram, input: FilterYield, bindings: [String: FilterYield] = [:], context: inout CLIJobContext) throws {
        self.program = program
        root = try create(program.root, input: input, bindings: bindings, context: &context)
    }
    private mutating func create(_ node: Int, input: FilterYield, bindings: [String: FilterYield], context: inout CLIJobContext) throws -> Int {
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        try context.charge(.runtimeFrames)
        var complete = false
        defer {
            if !complete {
                try? context.release(.runtimeFrames, 1)
                try? context.meter.release(context.meter.used(.retainedBytes) - entry)
            }
        }
        try context.work(4) // includes finite terminal cleanup
        try context.meter.retain(256)
        let frame = Frame(node: node, input: input, bindings: bindings)
        if let id = available.popLast() { frames[id] = frame; complete = true; return id }
        try context.meter.retain(64); frames.append(frame); complete = true; return frames.count - 1
    }
    private mutating func dispose(_ id: Int, context: inout CLIJobContext) throws {
        // Cleanup work and its bounded integer stack are prepaid at frame creation.
        var pending = [id]
        while let id = pending.popLast() {
            guard let frame = frames[id] else { continue }
            pending.append(contentsOf: frame.children)
            try context.meter.release(256 + frame.slots + frame.scopeBytes)
            try context.release(.runtimeFrames, 1)
            try context.release(.collectionValues, frame.collectionSlots)
            try context.release(.bindings, frame.bindingSlots)
            frames[id] = nil; available.append(id)
        }
        try context.reclaimValueLeases()
    }
    package mutating func close(context: inout CLIJobContext) throws {
        if !finished { try dispose(root, context: &context) }
        try context.meter.release(UInt64(frames.count) * 64)
        frames = []; available = []; finished = true
        try context.reclaimValueLeases()
    }
    package mutating func next<Input: FilterInput>(input: inout Input, context: inout CLIJobContext) throws -> FilterYield? {
        if finished { return nil }
        var demands: [Int] = [], current = root
        defer { try? context.meter.release(UInt64(demands.count) * 8) }
        while true {
            try context.work()
            let action: Action
            do { action = try step(current, input: &input, context: &context) }
            catch let failure as FilterLanguageFailure { action = .emit(.failure(failure)) }
            switch action {
            case .pull(let child):
                try context.meter.retain(8); demands.append(current); current = child
            case .emit(let event):
                if let parent = demands.popLast() {
                    try context.meter.release(8); frames[parent]!.event = event; current = parent
                } else {
                    switch event {
                    case .value(let value): return value
                    case .end: try close(context: &context); return nil
                    case .failure(let failure): throw failure
                    }
                }
            }
        }
    }
    private mutating func child(_ node: Int, frame: inout Frame, value: FilterYield? = nil, bindings: [String: FilterYield]? = nil, context: inout CLIJobContext) throws -> Int {
        let id = try create(node, input: value ?? frame.input, bindings: bindings ?? frame.bindings, context: &context)
        frame.children.append(id); return id
    }
    private func event(_ frame: inout Frame) -> Event? { let event = frame.event; frame.event = nil; return event }
    private func capture(_ value: FilterYield, frame: inout Frame, context: inout CLIJobContext) throws {
        try context.charge(.collectionValues); frame.collectionSlots += 1
        try context.meter.retain(24); frame.slots += 24
        frame.values.append(value)
    }
    private func releaseCache(_ frame: inout Frame, context: inout CLIJobContext, transferring: UInt64 = 0) throws {
        frame.values = []; frame.members = []
        try context.meter.release(frame.slots); frame.slots = 0
        guard transferring <= frame.collectionSlots else { throw CLIError(.usage, "invalidCollectionTransfer") }
        try context.release(.collectionValues, frame.collectionSlots - transferring); frame.collectionSlots = 0
        try context.reclaimValueLeases()
    }
    private mutating func step<Input: FilterInput>(_ id: Int, input: inout Input, context: inout CLIJobContext) throws -> Action {
        var frame = frames[id]!
        frames[id] = nil // Unique mutation of the frame's COW buffers.
        defer { frames[id] = frame }
        let incoming = event(&frame), node = program.nodes[frame.node]
        if case .failure(let failure) = incoming {
            switch node {
            case .optional: frame.phase = 99; return .emit(.end)
            case .attempt(_, let handler) where frame.phase == 1:
                if let handler {
                    let value = try FilterValues.produced(.string(failure.message), context: &context)
                    for child in frame.children { try dispose(child, context: &context) }; frame.children = []
                    frame.phase = 2; return .pull(try child(handler, frame: &frame, value: value, context: &context))
                }
                frame.phase = 99; return .emit(.end)
            default: return .emit(.failure(failure))
            }
        }
        if frame.phase == 99 { return .emit(.end) }
        switch node {
        case .pending: throw FilterCompileFailure("incompleteIR", at: 0)
        case .identity, .literal, .variable, .recursive:
            if case .recursive = node {
                if frame.phase == 0 { try capture(frame.input, frame: &frame, context: &context); frame.phase = 1 }
                guard let value = frame.values.popLast() else { return .emit(.end) }
                frame.collectionSlots -= 1; frame.slots -= 24
                try context.release(.collectionValues, 1); try context.meter.release(24)
                switch value.value {
                case .array(let values): for child in values.reversed() { try capture(value.selecting(child), frame: &frame, context: &context) }
                case .object(let object): for member in object.reversed() { try capture(value.selecting(member.value), frame: &frame, context: &context) }
                default: break
                }
                return .emit(.value(value))
            }
            guard frame.phase == 0 else { return .emit(.end) }; frame.phase = 1
            switch node {
            case .identity: return .emit(.value(frame.input))
            case .literal(let value): return .emit(.value(.init(value: value)))
            case .variable(let name): guard let value = frame.bindings[name] else { throw FilterLanguageFailure("unboundVariable") }; return .emit(.value(value))
            default: throw FilterLanguageFailure("invalidNode")
            }
        case .comma(let a, let b):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(a, frame: &frame, context: &context)) }
            if let incoming {
                if case .end = incoming {
                    if frame.phase == 2 { return .emit(.end) }
                    try dispose(frame.children.removeLast(), context: &context); frame.phase = 2
                    return .pull(try child(b, frame: &frame, context: &context))
                }
                return .emit(incoming)
            }
            return .pull(frame.children.last!)
        case .pipe(let a, let b), .bind(let a, _, let b):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(a, frame: &frame, context: &context)) }
            if let incoming {
                if frame.phase == 1 {
                    switch incoming {
                    case .end: return .emit(.end)
                    case .value(let value):
                        frame.phase = 2
                        if case .bind(_, let name, _) = node {
                            try context.charge(.bindings); frame.bindingSlots += 1
                            var bytes = UInt64(frame.bindings.count + 1) * 32 + UInt64(name.utf8.count)
                            for key in frame.bindings.keys { try context.work(UInt64(key.utf8.count) + 1); bytes += UInt64(key.utf8.count) }
                            try context.meter.retain(bytes); frame.scopeBytes += bytes
                            var bindings = frame.bindings; bindings[name] = value
                            let target = try child(b, frame: &frame, bindings: bindings, context: &context)
                            frames[target]!.scopeBytes += bytes; frames[target]!.bindingSlots = 1
                            frame.scopeBytes -= bytes; frame.bindingSlots -= 1
                            return .pull(target)
                        }
                        return .pull(try child(b, frame: &frame, value: value, context: &context))
                    case .failure(let failure): throw failure
                    }
                }
                if case .end = incoming { try dispose(frame.children.removeLast(), context: &context); frame.phase = 1; return .pull(frame.children[0]) }
                return .emit(incoming)
            }
            return .pull(frame.children.last!)
        case .array(let body):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(body, frame: &frame, context: &context)) }
            if let incoming {
                switch incoming {
                case .value(let value): try capture(value, frame: &frame, context: &context); return .pull(frame.children[0])
                case .end:
                    let count = UInt64(frame.values.count), bytes = count * 16
                    try context.meter.retain(bytes); frame.slots += bytes; try context.work(count)
                    let values = frame.values.map(\.value)
                    let result = try FilterValues.array(values, admittedCollectionCount: true, context: &context)
                    try context.meter.release(bytes); frame.slots -= bytes
                    try releaseCache(&frame, context: &context, transferring: count)
                    frame.phase = 99; return .emit(.value(result))
                case .failure(let failure): throw failure
                }
            }
            return .pull(frame.children[0])
        case .optional(let body), .attempt(let body, _):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(body, frame: &frame, context: &context)) }
            if let incoming { return .emit(incoming) }
            return .pull(frame.children.last!)
        case .fallback(let a, let b):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(a, frame: &frame, context: &context)) }
            if let incoming {
                if frame.phase == 2 { return .emit(incoming) }
                switch incoming {
                case .value(let value): if FilterTruth.test(value.value) { frame.flag = true; return .emit(.value(value)) }; return .pull(frame.children[0])
                case .end:
                    if frame.flag { return .emit(.end) }
                    try dispose(frame.children.removeLast(), context: &context); frame.phase = 2
                    return .pull(try child(b, frame: &frame, context: &context))
                case .failure(let failure): throw failure
                }
            }
            return .pull(frame.children.last!)
        case .conditional(let condition, let yes, let no):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(condition, frame: &frame, context: &context)) }
            if let incoming {
                if frame.phase == 1 {
                    switch incoming {
                    case .end: return .emit(.end)
                    case .value(let value): frame.phase = 2; return .pull(try child(FilterTruth.test(value.value) ? yes : no, frame: &frame, context: &context))
                    case .failure(let failure): throw failure
                    }
                }
                if case .end = incoming { try dispose(frame.children.removeLast(), context: &context); frame.phase = 1; return .pull(frame.children[0]) }
                return .emit(incoming)
            }
            return .pull(frame.children.last!)
        case .iterate(let base):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(base, frame: &frame, context: &context)) }
            if let incoming {
                switch incoming {
                case .end: return .emit(.end)
                case .value(let value): frame.current = value; frame.index = 0; frame.phase = 2
                case .failure(let failure): throw failure
                }
            }
            if frame.phase == 2 {
                let source = frame.current!, count: Int
                switch source.value { case .array(let a): count = a.count; case .object(let o): count = o.count; default: throw FilterLanguageFailure("cannotIterate") }
                if frame.index < count {
                    let value: JSON
                    switch source.value { case .array(let a): value = a[frame.index]; case .object(let o): value = o.members[frame.index].value; default: throw FilterLanguageFailure("cannotIterate") }
                    frame.index += 1; return .emit(.value(source.selecting(value)))
                }
                frame.current = nil; frame.phase = 1
            }
            return .pull(frame.children[0])
        case .unary(let op, let body):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(body, frame: &frame, context: &context)) }
            if let incoming {
                switch incoming {
                case .end: return .emit(.end)
                case .value(let value):
                    guard case .number(let n) = value.value else { throw FilterLanguageFailure("expectedNumber") }
                    return .emit(.value(try ExactDecimal.unary(op == "-" ? "negate" : "positive", n, context: &context)))
                case .failure(let failure): throw failure
                }
            }
            return .pull(frame.children[0])
        case .binary(let op, let a, let b) where op == "and" || op == "or":
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(a, frame: &frame, context: &context)) }
            if let incoming {
                if case .end = incoming {
                    if frame.phase == 1 { return .emit(.end) }
                    try dispose(frame.children.removeLast(), context: &context); frame.phase = 1; return .pull(frame.children[0])
                }
                if case .value(let value) = incoming {
                    let truth = FilterTruth.test(value.value)
                    if frame.phase == 1 {
                        if op == "and" && !truth || op == "or" && truth { return .emit(.value(try FilterValues.produced(.boolean(truth), context: &context))) }
                        frame.phase = 2; return .pull(try child(b, frame: &frame, context: &context))
                    }
                    return .emit(.value(try FilterValues.produced(.boolean(truth), context: &context)))
                }
            }
            return .pull(frame.children.last!)
        case .index(let a, let b), .binary(_, let a, let b):
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(b, frame: &frame, context: &context)) }
            if let incoming {
                if frame.phase == 1 {
                    switch incoming {
                    case .end: return .emit(.end)
                    case .value(let value):
                        frame.current = value; frame.index = 0
                        if !frame.flag { frame.phase = 2; return .pull(try child(a, frame: &frame, context: &context)) }
                        frame.phase = 3
                    case .failure(let failure): throw failure
                    }
                } else if frame.phase == 2 {
                    switch incoming {
                    case .value(let value): try capture(value, frame: &frame, context: &context); return .pull(frame.children[1])
                    case .end: try dispose(frame.children.removeLast(), context: &context); frame.phase = 3; frame.flag = true
                    case .failure(let failure): throw failure
                    }
                }
            }
            if frame.phase == 3 {
                if frame.index < frame.values.count {
                    let lhs = frame.values[frame.index], rhs = frame.current!; frame.index += 1
                    if case .index = node { return .emit(.value(lhs.selecting(try FilterValues.index(lhs.value, key: rhs.value, context: &context)))) }
                    guard case .binary(let op, _, _) = node else { throw FilterLanguageFailure("invalidState") }
                    if ["+","-","*","/","%"].contains(op) { return .emit(.value(try FilterOperators.apply(op, lhs.value, rhs.value, context: &context))) }
                    let result: Bool
                    if op == "==" || op == "!=" { let equal = try FilterValues.equals(lhs.value, rhs.value, context: &context); result = op == "==" ? equal : !equal }
                    else {
                        let order = try FilterValues.compare(lhs.value, rhs.value, context: &context)
                        switch op { case "<": result = order < 0; case ">": result = order > 0; case "<=": result = order <= 0; case ">=": result = order >= 0; default: throw FilterCompileFailure("arithmeticNotYetQualified", at: program.sourceRanges[frame.node].lowerBound) }
                    }
                    return .emit(.value(try FilterValues.produced(.boolean(result), context: &context)))
                }
                frame.current = nil; frame.phase = 1
            }
            return .pull(frame.children[0])
        case .call(let name, let arguments): return try call(name, arguments: arguments, frame: &frame, incoming: incoming, input: &input, context: &context)
        case .slice(let base, let lower, let upper):
            return try slice(base, lower: lower, upper: upper, frame: &frame, incoming: incoming, context: &context)
        case .object(let fields):
            return try object(fields, frame: &frame, incoming: incoming, context: &context)
        }
    }
    private func captureGroup(_ value: FilterYield, group: Int, frame: inout Frame, context: inout CLIJobContext) throws {
        try context.charge(.collectionValues); frame.collectionSlots += 1
        try context.meter.retain(24); frame.slots += 24
        frame.groups[group].append(value)
    }
    private func advance(_ selections: inout [Int], counts: [Int], context: inout CLIJobContext) throws -> Bool {
        for offset in selections.indices.reversed() {
            try context.work(); selections[offset] += 1
            if selections[offset] < counts[offset] { return true }
            selections[offset] = 0
        }
        return false
    }
    private mutating func slice(_ base: Int, lower: Int?, upper: Int?, frame: inout Frame, incoming: Event?, context: inout CLIJobContext) throws -> Action {
        let nodes = [base, lower, upper]
        if frame.phase == 0 {
            try context.meter.retain(120); frame.slots += 120
            frame.groups = [[], [], []]; frame.selections = [0, 0, 0]; frame.phase = 1; frame.index = 0
        }
        if let incoming {
            switch incoming {
            case .value(let value): try captureGroup(value, group: frame.index, frame: &frame, context: &context); return .pull(frame.children.last!)
            case .end: try dispose(frame.children.removeLast(), context: &context); frame.index += 1
            case .failure(let failure): throw failure
            }
        }
        if frame.phase == 1 {
            while frame.index < 3 {
                try context.work()
                if let node = nodes[frame.index] { return .pull(try child(node, frame: &frame, context: &context)) }
                try captureGroup(.init(value: .null), group: frame.index, frame: &frame, context: &context); frame.index += 1
            }
            if frame.groups.contains(where: { $0.isEmpty }) { frame.phase = 99; return .emit(.end) }
            frame.phase = 2
        }
        if frame.flag { frame.phase = 99; return .emit(.end) }
        let input = frame.groups[0][frame.selections[0]]
        let result = try FilterValues.slice(input.value, start: lower == nil ? Optional<JSON>.none : frame.groups[1][frame.selections[1]].value,
                                            end: upper == nil ? Optional<JSON>.none : frame.groups[2][frame.selections[2]].value, context: &context)
        frame.flag = try !advance(&frame.selections, counts: frame.groups.map(\.count), context: &context)
        return .emit(.value(result))
    }
    private mutating func object(_ fields: [(Int, Int)], frame: inout Frame, incoming: Event?, context: inout CLIJobContext) throws -> Action {
        if frame.phase == 0 {
            try context.meter.retain(UInt64(fields.count) * 40 + 48); frame.slots += UInt64(fields.count) * 40 + 48
            frame.groups = [[], []]; frame.index = 0; frame.phase = 1
        }
        if let incoming {
            let group = frame.phase == 1 ? 0 : 1
            switch incoming {
            case .value(let value):
                if group == 0, case .string = value.value {} else if group == 0 { throw FilterLanguageFailure("objectKeyMustBeString") }
                try captureGroup(value, group: group, frame: &frame, context: &context); return .pull(frame.children.last!)
            case .end:
                try dispose(frame.children.removeLast(), context: &context)
                if frame.phase == 1 {
                    if frame.groups[0].isEmpty { frame.phase = 99; return .emit(.end) }
                    frame.phase = 2; return .pull(try child(fields[frame.index].1, frame: &frame, context: &context))
                }
                if frame.groups[1].isEmpty { frame.phase = 99; return .emit(.end) }
                var choices: [ObjectChoice] = []
                for key in frame.groups[0] {
                    guard case .string(let text) = key.value else { throw FilterLanguageFailure("objectKeyMustBeString") }
                    for value in frame.groups[1] {
                        try context.work(); try context.charge(.collectionValues); frame.collectionSlots += 1
                        try context.meter.retain(64); frame.slots += 64
                        choices.append(.init(key: try JSONKey(text, meter: &context.meter), value: value, keySource: key))
                    }
                }
                // Temporary key/value result lists are no longer held. Choice slots
                // keep the exact sources alive, and work is never refunded.
                let records = UInt64(frame.groups[0].count + frame.groups[1].count)
                try context.release(.collectionValues, records); frame.collectionSlots -= records
                try context.meter.release(records * 24); frame.slots -= records * 24
                frame.groups = [[], []]; frame.choices.append(choices); frame.index += 1; frame.phase = 1
            case .failure(let failure): throw failure
            }
        }
        if frame.phase == 1, frame.index < fields.count { return .pull(try child(fields[frame.index].0, frame: &frame, context: &context)) }
        if frame.phase == 1 {
            frame.selections = Array(repeating: 0, count: fields.count); frame.phase = 3
        }
        if frame.flag { frame.phase = 99; return .emit(.end) }
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        var scratch: UInt64 = 0
        var building = true
        defer { try? context.meter.release(building ? context.meter.used(.retainedBytes) - entry : scratch) }
        var members: [JSONMember] = [], index = JSONExactKeyIndex()
        for field in fields.indices {
            try context.work(); let selected = frame.choices[field][frame.selections[field]]
            if let position = try index.find(selected.key, meter: &context.meter) {
                members[position] = JSONMember(members[position].key, value: selected.value.value)
            } else {
                try context.meter.require(.objectMembers, UInt64(members.count) + 1)
                try context.meter.retain(24)
                _ = try index.insert(selected.key, position: members.count, meter: &context.meter)
                members.append(.init(selected.key, value: selected.value.value))
            }
        }
        scratch = context.meter.used(.retainedBytes) - entry
        building = false
        let result = try FilterValues.produced(.object(JSONObject(admitted: members, index: index)), context: &context)
        frame.flag = try !advance(&frame.selections, counts: frame.choices.map(\.count), context: &context)
        return .emit(.value(result))
    }
    private mutating func call<Input: FilterInput>(_ name: String, arguments: [Int], frame: inout Frame, incoming: Event?, input: inout Input, context: inout CLIJobContext) throws -> Action {
        if name == "range" { return try range(arguments, frame: &frame, incoming: incoming, context: &context) }
        if name == "input" || name == "inputs" {
            if name == "input" && frame.phase > 0 { return .emit(.end) }
            frame.phase += 1
            if let value = try input.next(context: &context) { return .emit(.value(value)) }
            if name == "input" { throw FilterLanguageFailure("endOfInput") }
            return .emit(.end)
        }
        if arguments.isEmpty {
            if frame.phase > 0 { return .emit(.end) }; frame.phase = 1
            if ["abs","floor","ceil","trunc","round"].contains(name) {
                guard case .number(let number) = frame.input.value else { throw FilterLanguageFailure("expectedNumber") }
                return .emit(.value(try ExactDecimal.unary(name, number, context: &context)))
            }
            if name == "add" {
                guard case .array(let values) = frame.input.value else { throw FilterLanguageFailure("expectedArray") }
                var result = FilterYield(value: .null)
                for value in values { try context.work(); result = try FilterOperators.apply("+", result.value, value, context: &context) }
                return .emit(.value(result))
            }
            if name == "error" { throw try languageError(frame.input.value, frame: &frame, context: &context) }
            if let value = try FilterPrimitiveBuiltins.apply(name, value: frame.input.value, context: &context) {
                // Selectors borrow the original input's lifetime; constructed values
                // already have their own complete admission lease.
                return .emit(.value(value.lease == nil ? frame.input.selecting(value.value) : value))
            }
            return .emit(.end)
        }
        if name == "select" || name == "has" || name == "error" {
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(arguments[0], frame: &frame, context: &context)) }
            if let incoming {
                switch incoming {
                case .end: return .emit(.end)
                case .value(let value):
                    if name == "error" { throw try languageError(value.value, frame: &frame, context: &context) }
                    if name == "select" {
                        if FilterTruth.test(value.value) { return .emit(.value(frame.input)) }
                        return .pull(frame.children[0])
                    }
                    let result = try FilterPrimitiveBuiltins.apply(name, value: frame.input.value, argument: value.value, context: &context)
                    return .emit(result.map(Event.value) ?? .end)
                case .failure(let failure): throw failure
                }
            }
            return .pull(frame.children[0])
        }
        if name == "map" || name == "map_values" {
            let count: Int
            switch frame.input.value { case .array(let a): count = a.count; case .object(let o): count = o.count; default: throw FilterLanguageFailure("expectedContainer") }
            if let incoming {
                switch incoming {
                case .value(let value):
                    if name == "map_values", case .object(let object) = frame.input.value {
                        try context.charge(.collectionValues); frame.collectionSlots += 1
                        try context.meter.retain(40); frame.slots += 40
                        frame.members.append((object.members[frame.index].key, value))
                    } else { try capture(value, frame: &frame, context: &context) }
                    if name == "map_values" { try dispose(frame.children.removeLast(), context: &context); frame.index += 1; frame.phase = 0 }
                    else { return .pull(frame.children.last!) }
                case .end: try dispose(frame.children.removeLast(), context: &context); frame.index += 1; frame.phase = 0
                case .failure(let failure): throw failure
                }
            }
            if frame.index == count {
                let result: FilterYield, transfer = frame.collectionSlots
                if name == "map_values", case .object = frame.input.value {
                    let bytes = UInt64(frame.members.count) * 24
                    try context.meter.retain(bytes); frame.slots += bytes; try context.work(UInt64(frame.members.count))
                    let members = frame.members.map { JSONMember($0.0, value: $0.1.value) }
                    let entry = context.meter.used(.retainedBytes)
                    let object: JSONObject
                    do { object = try JSONObject.indexed(admitted: members, meter: &context.meter) }
                    catch { frame.slots += context.meter.used(.retainedBytes) - entry; throw error }
                    let indexBytes = context.meter.used(.retainedBytes) - entry
                    frame.slots += indexBytes
                    result = try FilterValues.produced(.object(object), collections: transfer, context: &context)
                    try context.meter.release(indexBytes); frame.slots -= indexBytes
                    try context.meter.release(bytes); frame.slots -= bytes
                } else {
                    let bytes = UInt64(frame.values.count) * 16
                    try context.meter.retain(bytes); frame.slots += bytes; try context.work(UInt64(frame.values.count))
                    let values = frame.values.map(\.value)
                    result = try FilterValues.array(values, admittedCollectionCount: true, context: &context)
                    try context.meter.release(bytes); frame.slots -= bytes
                }
                try releaseCache(&frame, context: &context, transferring: transfer)
                frame.phase = 99; return .emit(.value(result))
            }
            if frame.phase == 0 {
                let value: JSON
                switch frame.input.value { case .array(let a): value = a[frame.index]; case .object(let o): value = o.members[frame.index].value; default: throw FilterLanguageFailure("expectedContainer") }
                frame.phase = 1
                return .pull(try child(arguments[0], frame: &frame, value: frame.input.selecting(value), context: &context))
            }
            return .pull(frame.children.last!)
        }
        throw FilterCompileFailure("unsupportedBuiltin", at: program.sourceRanges[frame.node].lowerBound)
    }
    private mutating func range(_ arguments: [Int], frame: inout Frame, incoming: Event?, context: inout CLIJobContext) throws -> Action {
        if frame.phase == 0 {
            let bytes = UInt64(arguments.count) * 32
            try context.meter.retain(bytes); frame.slots += bytes
            frame.groups = Array(repeating: [], count: arguments.count)
            frame.selections = Array(repeating: 0, count: arguments.count); frame.phase = 1
        }
        if let incoming {
            switch incoming {
            case .value(let value): try captureGroup(value, group: frame.index, frame: &frame, context: &context); return .pull(frame.children.last!)
            case .end: try dispose(frame.children.removeLast(), context: &context); frame.index += 1
            case .failure(let failure): throw failure
            }
        }
        if frame.phase == 1 {
            if frame.index < arguments.count { return .pull(try child(arguments[frame.index], frame: &frame, context: &context)) }
            if frame.groups.contains(where: { $0.isEmpty }) { frame.phase = 99; return .emit(.end) }
            frame.phase = 2
        }
        while true {
            try context.work()
            if frame.range == nil {
                if frame.flag { frame.phase = 99; return .emit(.end) }
                func number(_ index: Int) throws -> JSONNumber {
                    guard case .number(let n) = frame.groups[index][frame.selections[index]].value else { throw FilterLanguageFailure("expectedNumber") }; return n
                }
                let start = arguments.count == 1 ? JSONNumber(integer: 0) : try number(0)
                let end = try number(arguments.count == 1 ? 0 : 1)
                let step = arguments.count == 3 ? try number(2) : JSONNumber(integer: 1)
                frame.range = try FilterRangeState(start: start, end: end, step: step, context: &context)
            }
            if let value = try frame.range!.next(context: &context) { return .emit(.value(value)) }
            frame.range = nil
            frame.flag = try !advance(&frame.selections, counts: frame.groups.map(\.count), context: &context)
        }
    }
    private func languageError(_ value: JSON, frame: inout Frame, context: inout CLIJobContext) throws -> FilterLanguageFailure {
        try context.checkpoint()
        let entry = context.meter.used(.retainedBytes)
        var building = true, scratch: UInt64 = 0
        defer { try? context.meter.release(building ? context.meter.used(.retainedBytes) - entry : scratch) }
        let text: String
        if case .string(let source) = value { text = source }
        else {
            try context.meter.resetValueBounds()
            let bytes = try JSONWriter(options: .init(limits: context.meter.limits, numberStyle: .preserved)).write(value, meter: &context.meter)
            try context.work(UInt64(bytes.count)); try context.meter.retain(UInt64(bytes.count))
            text = String(decoding: bytes, as: UTF8.self)
        }
        try context.require(.diagnosticBytes, UInt64(text.utf8.count))
        scratch = context.meter.used(.retainedBytes) - entry; building = false
        // Keep the admitted message live until propagation consumes this frame.
        // A catch handler admits its own copy before disposing the failing body.
        frame.current = try FilterValues.produced(.string(text), context: &context)
        return .init("explicitError", message: text)
    }
}
