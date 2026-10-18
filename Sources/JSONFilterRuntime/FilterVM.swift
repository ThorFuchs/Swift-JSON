// SPDX-License-Identifier: Apache-2.0
import JSON

package protocol FilterInput {
    mutating func next(context: inout TransformRuntimeContext) throws -> FilterYield?
}
/// Explicit, demand-driven continuations. The arena reuses slots; no language
/// recursion becomes Swift call-stack recursion. Only immutable plans are shared.
package struct FilterVM {
    private enum Event { case value(FilterYield), end, failure(FilterLanguageFailure) }
    private enum Action { case pull(Int), emit(Event) }
    private struct ObjectChoice { let key: JSONKey; let value: FilterYield; let keySource: FilterYield }
    private final class FunctionClosure {
        let bindings:[String:FilterYield]
        let functions:[Int:FunctionClosure]
        let parameters:[String:FilterThunk]
        init(bindings:[String:FilterYield],functions:[Int:FunctionClosure],parameters:[String:FilterThunk]){self.bindings=bindings;self.functions=functions;self.parameters=parameters}
    }
    private struct FilterThunk {
        let node:Int
        let bindings:[String:FilterYield]
        let functions:[Int:FunctionClosure]
        let parameters:[String:FilterThunk]
    }
    private struct Frame {
        let node: Int
        let input: FilterYield
        var bindings: [String: FilterYield]
        var functions:[Int:FunctionClosure] = [:]
        var parameters:[String:FilterThunk] = [:]
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
        var paths:[[JSON]]=[]
        var changes:[FilterYield?]=[]
        var pathRoot:FilterLocationRoot?
        var ordinal: UInt64 = 0
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
    package init(program: FilterProgram, input: FilterYield, bindings: [String: FilterYield] = [:], context: inout TransformRuntimeContext) throws {
        self.program = program
        root = try create(program.root, input: input, bindings: bindings, context: &context)
    }
    private mutating func create(_ node: Int, input: FilterYield, bindings: [String: FilterYield], functions:[Int:FunctionClosure]=[:],parameters:[String:FilterThunk]=[:], context: inout TransformRuntimeContext) throws -> Int {
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
        let frame = Frame(node: node, input: input, bindings: bindings,functions:functions,parameters:parameters)
        if let id = available.popLast() { frames[id] = frame; complete = true; return id }
        try context.meter.retain(64); frames.append(frame); complete = true; return frames.count - 1
    }
    private mutating func dispose(_ id: Int, context: inout TransformRuntimeContext) throws {
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
    package mutating func close(context: inout TransformRuntimeContext) throws {
        if !finished { try dispose(root, context: &context) }
        try context.meter.release(UInt64(frames.count) * 64)
        frames = []; available = []; finished = true
        try context.reclaimValueLeases()
    }
    package mutating func next<Input: FilterInput>(input: inout Input, context: inout TransformRuntimeContext) throws -> FilterYield? {
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
    private mutating func child(_ node: Int, frame: inout Frame, value: FilterYield? = nil, bindings: [String: FilterYield]? = nil,functions:[Int:FunctionClosure]?=nil,parameters:[String:FilterThunk]?=nil, context: inout TransformRuntimeContext) throws -> Int {
        let id = try create(node, input: value ?? frame.input, bindings: bindings ?? frame.bindings,functions:functions ?? frame.functions,parameters:parameters ?? frame.parameters, context: &context)
        frame.children.append(id); return id
    }
    private func event(_ frame: inout Frame) -> Event? { let event = frame.event; frame.event = nil; return event }
    private func capture(_ value: FilterYield, frame: inout Frame, context: inout TransformRuntimeContext) throws {
        try context.charge(.collectionValues); frame.collectionSlots += 1
        try context.meter.retain(24); frame.slots += 24
        frame.values.append(value)
    }
    private func releaseCache(_ frame: inout Frame, context: inout TransformRuntimeContext, transferring: UInt64 = 0) throws {
        frame.values = []; frame.members = []
        try context.meter.release(frame.slots); frame.slots = 0
        guard transferring <= frame.collectionSlots else { throw TransformRuntimeFailure(.usage, "invalidCollectionTransfer") }
        try context.release(.collectionValues, frame.collectionSlots - transferring); frame.collectionSlots = 0
        try context.reclaimValueLeases()
    }
    private mutating func step<Input: FilterInput>(_ id: Int, input: inout Input, context: inout TransformRuntimeContext) throws -> Action {
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
                    var result=source.selecting(value)
                    if let location=source.location{
                        let segment:JSON
                        if case .object(let object)=source.value{segment = .string(object.members[frame.index].key.string)}else{segment = .number(JSONNumber(integer:frame.index))}
                        result.location=try location.appending(segment,context:&context)
                    }
                    frame.index += 1; return .emit(.value(result))
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
                    if case .index = node {
                        var result=lhs.selecting(try FilterValues.index(lhs.value,key:rhs.value,context:&context))
                        if let location=lhs.location{
                            var segment=rhs.value
                            if case .array(let values)=lhs.value,case .number(let n)=segment,n.isNegative,
                               try n.compare(to:JSONNumber(integer:-values.count),meter:&context.meter) != .orderedAscending {
                                segment = .number(JSONNumber(integer:values.count + (try n.integer(as:Int.self,meter:&context.meter))))
                            }
                            result.location=try location.appending(segment,context:&context)
                        }
                        return .emit(.value(result))
                    }
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
        case .destructure(let source,let pattern,let after):
            return try destructure(source,pattern:program.patterns[pattern],after:after,frame:&frame,incoming:incoming,context:&context)
        case .assignment(let op,let targets,let update):
            return try assignment(op,targets:targets,update:update,frame:&frame,incoming:incoming,context:&context)
        case .interpolation(let parts,let format):
            return try interpolate(parts,format:format,frame:&frame,incoming:incoming,context:&context)
        case .definition(let function,let after):
            if frame.phase==0{
                let bytes=UInt64(frame.functions.count+1)*32+96
                try context.charge(.bindings);frame.bindingSlots += 1
                try context.meter.retain(bytes);frame.scopeBytes += bytes;try context.work(UInt64(frame.functions.count)+1)
                let closure=FunctionClosure(bindings:frame.bindings,functions:frame.functions,parameters:frame.parameters)
                frame.functions[function]=closure;frame.phase=1
                return .pull(try child(after,frame:&frame,context:&context))
            }
            if let incoming{return .emit(incoming)};return .pull(frame.children[0])
        case .parameter(let name):
            if frame.phase==0{
                guard let thunk=frame.parameters[name] else{throw FilterLanguageFailure("unboundFilterParameter")}
                frame.phase=1
                return .pull(try child(thunk.node,frame:&frame,value:frame.input,bindings:thunk.bindings,functions:thunk.functions,parameters:thunk.parameters,context:&context))
            }
            if let incoming{return .emit(incoming)};return .pull(frame.children[0])
        case .invoke(let function,let arguments):
            if frame.phase==0{
                guard let closure=frame.functions[function] else{throw FilterLanguageFailure("unboundFunction")}
                let definition=program.functions[function]
                let slots=UInt64(definition.parameters.count)+1
                try context.charge(.bindings,slots);frame.bindingSlots += slots
                let bytes=UInt64(closure.functions.count+1)*32+UInt64(closure.parameters.count+arguments.count)*64
                try context.meter.retain(bytes);frame.scopeBytes += bytes;try context.work(UInt64(arguments.count)+UInt64(closure.functions.count)+1)
                var functions=closure.functions;functions[function]=closure
                var parameters=closure.parameters
                for index in arguments.indices{parameters[definition.parameters[index]]=FilterThunk(node:arguments[index],bindings:frame.bindings,functions:frame.functions,parameters:frame.parameters)}
                frame.phase=1
                let target=try child(definition.body,frame:&frame,bindings:closure.bindings,functions:functions,parameters:parameters,context:&context)
                frames[target]!.bindingSlots += slots;frames[target]!.scopeBytes += bytes
                frame.bindingSlots -= slots;frame.scopeBytes -= bytes
                return .pull(target)
            }
            if let incoming{return .emit(incoming)};return .pull(frame.children[0])
        case .reduction(let source,let name,let initial,let update,let extract,let foreach):
            return try reduction(source,name:name,initial:initial,update:update,extract:extract,foreach:foreach,frame:&frame,incoming:incoming,context:&context)
        case .call(let name, let arguments): return try call(name, arguments: arguments, frame: &frame, incoming: incoming, input: &input, context: &context)
        case .slice(let base, let lower, let upper):
            return try slice(base, lower: lower, upper: upper, frame: &frame, incoming: incoming, context: &context)
        case .object(let fields):
            return try object(fields, frame: &frame, incoming: incoming, context: &context)
        }
    }
    private func captureGroup(_ value: FilterYield, group: Int, frame: inout Frame, context: inout TransformRuntimeContext) throws {
        try context.charge(.collectionValues); frame.collectionSlots += 1
        try context.meter.retain(24); frame.slots += 24
        frame.groups[group].append(value)
    }
    private func advance(_ selections: inout [Int], counts: [Int], context: inout TransformRuntimeContext) throws -> Bool {
        for offset in selections.indices.reversed() {
            try context.work(); selections[offset] += 1
            if selections[offset] < counts[offset] { return true }
            selections[offset] = 0
        }
        return false
    }
    private mutating func slice(_ base: Int, lower: Int?, upper: Int?, frame: inout Frame, incoming: Event?, context: inout TransformRuntimeContext) throws -> Action {
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
    private mutating func object(_ fields: [(Int, Int)], frame: inout Frame, incoming: Event?, context: inout TransformRuntimeContext) throws -> Action {
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
    private mutating func call<Input: FilterInput>(_ name: String, arguments: [Int], frame: inout Frame, incoming: Event?, input: inout Input, context: inout TransformRuntimeContext) throws -> Action {
        if name == "paths" { return try paths(arguments.first,frame:&frame,incoming:incoming,context:&context) }
        if name == "setpath" { return try setpath(arguments,frame:&frame,incoming:incoming,context:&context) }
        if name == "del" { return try deleteExpression(arguments[0],frame:&frame,incoming:incoming,context:&context) }
        if name == "path" { return try path(arguments[0],frame:&frame,incoming:incoming,context:&context) }
        if name == "walk" { return try walk(arguments[0],frame:&frame,incoming:incoming,context:&context) }
        if name == "while" || name == "until" { return try loop(name,arguments:arguments,frame:&frame,incoming:incoming,context:&context) }
        if name == "recurse" { return try recurse(arguments,frame:&frame,incoming:incoming,context:&context) }
        if name == "any" || name == "all" { return try truthReduction(name,arguments:arguments,frame:&frame,incoming:incoming,context:&context) }
        if name == "nth" { return try nth(arguments,frame:&frame,incoming:incoming,context:&context) }
        if ["sort_by","group_by","unique_by","min_by","max_by"].contains(name) { return try keyed(name,argument:arguments[0],frame:&frame,incoming:incoming,context:&context) }
        if !arguments.isEmpty && (name == "first" || name == "last") { return try terminalSelection(name,argument:arguments[0],frame:&frame,incoming:incoming,context:&context) }
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
            if name.hasPrefix("@") { return .emit(.value(try FilterFormats.apply(String(name.dropFirst()),value:frame.input.value,context:&context))) }
            if FilterStringBuiltins.arities[name] != nil { return .emit(.value(try FilterStringBuiltins.apply(name,value:frame.input.value,context:&context))) }
            if name == "sort" || name == "unique" || name == "min" || name == "max" {
                guard case .array(let values) = frame.input.value else { throw FilterLanguageFailure("expectedArray") }
                let entry = context.meter.used(.retainedBytes)
                try context.meter.retain(UInt64(values.count)*48);try context.work(UInt64(values.count))
                let keyed = values.map { FilterCollectionBuiltins.Keyed(value:$0,keys:[$0]) }
                let scratch = context.meter.used(.retainedBytes)-entry
                defer { try? context.meter.release(scratch) }
                return .emit(.value(try FilterCollectionBuiltins.keyed(name,values:keyed,context:&context)))
            }
            if name == "first" || name == "last" {
                guard case .array(let values)=frame.input.value else{throw FilterLanguageFailure("expectedArray")}
                let value = name == "first" ? values.first:values.last
                return value.map { .emit(.value(frame.input.selecting($0))) } ?? .emit(.end)
            }
            if name == "flatten" { return .emit(.value(try FilterCollectionBuiltins.flattened(frame.input.value,depth:nil,context:&context))) }
            if name == "reverse" {
                guard case .array(let values) = frame.input.value else { throw FilterLanguageFailure("expectedArray") }
                let bytes=UInt64(values.count)*16
                try context.meter.retain(bytes);defer { try? context.meter.release(bytes) };try context.work(UInt64(values.count))
                return .emit(.value(try FilterValues.array(Array(values.reversed()),context:&context)))
            }
            if name == "error" { throw try languageError(frame.input.value, frame: &frame, context: &context) }
            if let value = try FilterPrimitiveBuiltins.apply(name, value: frame.input.value, context: &context) {
                // Selectors borrow the original input's lifetime; constructed values
                // already have their own complete admission lease.
                return .emit(.value(value.lease == nil ? frame.input.selecting(value.value) : value))
            }
            return .emit(.end)
        }
        if name == "select" || name == "has" || name == "error" || FilterStringBuiltins.arities[name]?.contains(1) == true || name == "flatten" || name == "getpath" || name == "delpaths" {
            if frame.phase == 0 { frame.phase = 1; return .pull(try child(arguments[0], frame: &frame, context: &context)) }
            if let incoming {
                switch incoming {
                case .end: return .emit(.end)
                case .value(let value):
                    if name == "error" { throw try languageError(value.value, frame: &frame, context: &context) }
                    if name=="getpath"{
                        let path=try FilterPaths.segments(value.value,context:&context)
                        var result=frame.input.selecting(try FilterPaths.get(frame.input.value,path:path,context:&context))
                        if var location=frame.input.location{for segment in path{location=try location.appending(segment,context:&context)};result.location=location}
                        return .emit(.value(result))
                    }
                    if name=="delpaths"{return try deletePaths(value.value,frame:&frame,context:&context)}
                    if FilterStringBuiltins.arities[name] != nil { return .emit(.value(try FilterStringBuiltins.apply(name,value:frame.input.value,argument:value.value,context:&context))) }
                    if name == "flatten" {
                        guard case .number(let n) = value.value,n.isInteger,!n.isNegative else { throw FilterLanguageFailure("invalidFlattenDepth") }
                        let depth:Int
                        do { depth=try n.integer(as:Int.self,meter:&context.meter) }
                        catch let error as JSONFailure where error.category == .conversion { throw FilterLanguageFailure("invalidFlattenDepth") }
                        return .emit(.value(try FilterCollectionBuiltins.flattened(frame.input.value,depth:depth,context:&context)))
                    }
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
    private mutating func destructure(_ source:Int,pattern:FilterBindingPattern,after:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{frame.phase=1;return .pull(try child(source,frame:&frame,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{
                    for shape in pattern.shapes{
                        try context.work();let selected=try FilterPaths.get(value.value,path:shape.path,context:&context)
                        switch selected{case .null:break;case .object where shape.object:break;case .array where !shape.object:break;default:throw FilterLanguageFailure("wrongBindingShape")}
                    }
                    let count=UInt64(pattern.bindings.count),bytes=UInt64(frame.bindings.count+pattern.bindings.count)*32
                    try context.charge(.bindings,count);frame.bindingSlots += count
                    try context.meter.retain(bytes);frame.scopeBytes += bytes
                    var environment=frame.bindings
                    for binding in pattern.bindings{try context.work();environment[binding.name]=value.selecting(try FilterPaths.get(value.value,path:binding.path,context:&context))}
                    let target=try child(after,frame:&frame,bindings:environment,context:&context)
                    frames[target]!.scopeBytes += bytes;frames[target]!.bindingSlots += count
                    frame.scopeBytes -= bytes;frame.bindingSlots -= count;frame.phase=2;return .pull(target)
                }
                return .emit(.value(value))
            case .end:
                if frame.phase==1{return .emit(.end)}
                try dispose(frame.children.removeLast(),context:&context);frame.phase=1;return .pull(frame.children[0])
            case .failure(let error):throw error
            }
        }
        return .pull(frame.children.last!)
    }
    private func pathChildren(_ value:FilterYield,frame:inout Frame,context:inout TransformRuntimeContext)throws {
        guard let location=value.location else{throw FilterLanguageFailure("invalidPath")}
        switch value.value{
        case .array(let values):
            for index in values.indices.reversed(){try context.work();var child=value.selecting(values[index]);child.location=try location.appending(.number(JSONNumber(integer:index)),context:&context);try capture(child,frame:&frame,context:&context)}
        case .object(let object):
            for member in object.reversed(){try context.work();var child=value.selecting(member.value);child.location=try location.appending(.string(member.key.string),context:&context);try capture(child,frame:&frame,context:&context)}
        default:break
        }
    }
    private mutating func paths(_ predicate:Int?,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{let root=try FilterLocationRoot(context:&context);frame.pathRoot=root;var value=frame.input;value.location = .init(root:root);try pathChildren(value,frame:&frame,context:&context);frame.phase=1}
        if let incoming{
            switch incoming{
            case .value(let value):
                if FilterTruth.test(value.value){guard let location=frame.current?.location else{throw FilterLanguageFailure("invalidPath")};return .emit(.value(try FilterValues.array(location.segments,context:&context)))}
                return .pull(frame.children[0])
            case .end:try dispose(frame.children.removeLast(),context:&context);frame.phase=1
            case .failure(let error):throw error
            }
        }
        if frame.phase==2{return .pull(frame.children[0])}
        if let value=frame.current{try pathChildren(value,frame:&frame,context:&context);frame.current=nil}
        guard let value=frame.values.popLast() else{frame.phase=99;return .emit(.end)}
        try context.release(.collectionValues,1);frame.collectionSlots -= 1;try context.meter.release(24);frame.slots -= 24
        frame.current=value
        if let predicate{frame.phase=2;return .pull(try child(predicate,frame:&frame,value:value,context:&context))}
        guard let location=value.location else{throw FilterLanguageFailure("invalidPath")}
        return .emit(.value(try FilterValues.array(location.segments,context:&context)))
    }
    private mutating func setpath(_ arguments:[Int],frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{frame.phase=1;return .pull(try child(arguments[0],frame:&frame,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{let path=try FilterPaths.segments(value.value,context:&context);try context.meter.retain(UInt64(path.count)*16);frame.slots += UInt64(path.count)*16;frame.paths=[path];frame.current=value;frame.phase=2;return .pull(try child(arguments[1],frame:&frame,context:&context))}
                if let result=try FilterPaths.set(frame.input.value,path:frame.paths[0],replacement:value.value,context:&context){return .emit(.value(result))};return .pull(frame.children[1])
            case .end:
                if frame.phase==1{return .emit(.end)}
                try dispose(frame.children.removeLast(),context:&context);frame.paths=[];frame.current=nil;try context.meter.release(frame.slots);frame.slots=0;frame.phase=1;return .pull(frame.children[0])
            case .failure(let error):throw error
            }
        }
        return .pull(frame.children.last!)
    }
    private mutating func deletePaths(_ value:JSON,frame:inout Frame,context:inout TransformRuntimeContext)throws->Action {
        guard case .array(let values)=value else{throw FilterLanguageFailure("expectedPathList")}
        let entry=context.meter.used(.retainedBytes);var scratch:UInt64=0,ready=false
        defer{try? context.meter.release(ready ? scratch:context.meter.used(.retainedBytes)-entry)}
        var raw:[[JSON]]=[]
        for value in values{try context.work();let path=try FilterPaths.segments(value,context:&context);try context.meter.retain(24);raw.append(path)}
        let paths=try FilterPaths.targets(frame.input.value,paths:raw,context:&context),order=try FilterPaths.deletionOrder(paths,context:&context)
        scratch=context.meter.used(.retainedBytes)-entry;ready=true
        var candidate=frame.input
        for index in order{
            try context.work()
            guard let next=try FilterPaths.set(candidate.value,path:paths[index],replacement:Optional<JSON>.none,context:&context) else{return .pull(frame.children[0])}
            candidate=next
        }
        return .emit(.value(candidate))
    }
    private mutating func deleteExpression(_ expression:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{let root=try FilterLocationRoot(context:&context);frame.pathRoot=root;var value=frame.input;value.location = .init(root:root);frame.phase=1;return .pull(try child(expression,frame:&frame,value:value,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):guard let location=value.location,location.root === frame.pathRoot else{throw FilterLanguageFailure("invalidPath")};let path=try FilterValues.array(location.segments,context:&context);try capture(path,frame:&frame,context:&context);return .pull(frame.children[0])
            case .end:
                let bytes=UInt64(frame.values.count)*16;try context.meter.retain(bytes);frame.slots += bytes;try context.work(UInt64(frame.values.count));let value=JSON.array(frame.values.map(\.value));frame.phase=99;return try deletePaths(value,frame:&frame,context:&context)
            case .failure(let error):throw error
            }
        }
        return .pull(frame.children[0])
    }
    private mutating func assignment(_ op:String,targets:Int,update:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{let root=try FilterLocationRoot(context:&context);frame.pathRoot=root;var value=frame.input;value.location = .init(root:root);frame.phase=1;return .pull(try child(targets,frame:&frame,value:value,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{guard let location=value.location,location.root === frame.pathRoot else{throw FilterLanguageFailure("invalidPath")};let path=try FilterValues.array(location.segments,context:&context);try capture(path,frame:&frame,context:&context);return .pull(frame.children[0])}
                if op=="="{
                    var candidate=frame.input
                    for path in frame.paths{guard let next=try FilterPaths.set(candidate.value,path:path,replacement:value.value,context:&context) else{throw FilterLanguageFailure("invalidAssignment")};candidate=next}
                    return .emit(.value(candidate))
                }
                let old=try FilterPaths.get(frame.input.value,path:frame.paths[frame.index],context:&context)
                let change:FilterYield
                if op=="|=" || op=="//="{change=value}else{change=try FilterOperators.apply(String(op.dropLast()),old,value.value,context:&context)}
                frame.changes.append(change);try dispose(frame.children.removeLast(),context:&context);frame.index += 1;frame.phase=3
            case .end:
                if frame.phase==1{
                    try dispose(frame.children.removeLast(),context:&context)
                    let rawBytes=UInt64(frame.values.count)*24;try context.meter.retain(rawBytes);frame.slots += rawBytes;try context.work(UInt64(frame.values.count))
                    let entry=context.meter.used(.retainedBytes)
                    let raw=frame.values.map{value->[JSON] in if case .array(let path)=value.value{return path};return []}
                    do{frame.paths=try FilterPaths.targets(frame.input.value,paths:raw,context:&context)}catch{frame.slots += context.meter.used(.retainedBytes)-entry;throw error}
                    frame.slots += context.meter.used(.retainedBytes)-entry
                    if op=="="{frame.phase=2;return .pull(try child(update,frame:&frame,context:&context))}
                    let count=UInt64(frame.paths.count);try context.charge(.collectionValues,count);frame.collectionSlots += count;try context.meter.retain(count*24);frame.slots += count*24;frame.phase=3
                }else if op=="="{return .emit(.end)}
                else{frame.changes.append(nil);try dispose(frame.children.removeLast(),context:&context);frame.index += 1;frame.phase=3}
            case .failure(let error):throw error
            }
        }
        if frame.phase==3{
            while frame.index<frame.paths.count{
                try context.work();let old=try FilterPaths.get(frame.input.value,path:frame.paths[frame.index],context:&context)
                if op=="//=",FilterTruth.test(old){frame.changes.append(frame.input.selecting(old));frame.index += 1;continue}
                frame.phase=2;return .pull(try child(update,frame:&frame,value:frame.input.selecting(old),context:&context))
            }
            var candidate=frame.input
            for index in frame.paths.indices{if let change=frame.changes[index]{guard let next=try FilterPaths.set(candidate.value,path:frame.paths[index],replacement:change.value,context:&context) else{throw FilterLanguageFailure("invalidAssignment")};candidate=next}}
            let entry=context.meter.used(.retainedBytes)
            var deleted:[[JSON]]=[];for index in frame.paths.indices where frame.changes[index]==nil{try context.work();try context.meter.retain(24);deleted.append(frame.paths[index])}
            let order=try FilterPaths.deletionOrder(deleted,context:&context),scratch=context.meter.used(.retainedBytes)-entry
            defer{try? context.meter.release(scratch)}
            for index in order{guard let next=try FilterPaths.set(candidate.value,path:deleted[index],replacement:Optional<JSON>.none,context:&context) else{frame.phase=99;return .emit(.end)};candidate=next}
            frame.phase=99;return .emit(.value(candidate))
        }
        return .pull(frame.children.last!)
    }
    private mutating func path(_ expression:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{
            let root=try FilterLocationRoot(context:&context);frame.pathRoot=root
            var value=frame.input;value.location = .init(root:root);frame.phase=1
            return .pull(try child(expression,frame:&frame,value:value,context:&context))
        }
        if let incoming{
            switch incoming{
            case .value(let value):guard let location=value.location,location.root === frame.pathRoot else{throw FilterLanguageFailure("invalidPath")};return .emit(.value(try FilterValues.array(location.segments,context:&context)))
            case .end:return .emit(.end)
            case .failure(let error):throw error
            }
        }
        return .pull(frame.children[0])
    }
    private mutating func interpolate(_ parts:[Int],format:String?,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{let bytes=UInt64(parts.count)*32;try context.meter.retain(bytes);frame.slots += bytes;frame.groups=Array(repeating:[],count:parts.count);frame.selections=Array(repeating:0,count:parts.count);frame.phase=1}
        if let incoming{
            switch incoming{case .value(let value):try captureGroup(value,group:frame.index,frame:&frame,context:&context);return .pull(frame.children[0]);case .end:try dispose(frame.children.removeLast(),context:&context);frame.index += 1;case .failure(let error):throw error}
        }
        if frame.phase==1{
            if frame.index<parts.count{return .pull(try child(parts[frame.index],frame:&frame,context:&context))}
            if frame.groups.contains(where:{$0.isEmpty}){frame.phase=99;return .emit(.end)};frame.phase=2
        }
        if frame.flag{frame.phase=99;return .emit(.end)}
        var output="",bytes:UInt64=0
        defer{try? context.meter.release(bytes)}
        func append(_ text:String,context:inout TransformRuntimeContext)throws{
            for scalar in text.unicodeScalars{let size=UInt64(scalar.utf8.count);try context.work(size);try context.meter.require(.stringBytes,bytes+size);try context.meter.retain(size);output.unicodeScalars.append(scalar);bytes += size}
        }
        for index in parts.indices{
            let value=frame.groups[index][frame.selections[index]].value
            if index%2==1,let format{
                var formatted=try FilterFormats.apply(format,value:value,context:&context)
                guard case .string(let source)=formatted.value else{throw FilterLanguageFailure("invalidFormattedString")}
                try append(source,context:&context);try formatted.release(context:&context)
            }else{try FilterStringBuiltins.usingText(value,context:&context){text,context in try append(text,context:&context)}}
        }
        let result=try FilterValues.produced(.string(output),context:&context)
        frame.flag=try !advance(&frame.selections,counts:frame.groups.map(\.count),context:&context)
        return .emit(.value(result))
    }
    private mutating func walk(_ filter:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        let count:Int,object:JSONObject?
        switch frame.input.value{case .array(let values):count=values.count;object=nil;case .object(let value):count=value.count;object=value;default:
            if frame.phase==0{frame.phase=3;return .pull(try child(filter,frame:&frame,context:&context))}
            if let incoming{return .emit(incoming)};return .pull(frame.children[0])
        }
        if frame.phase==3 {
            if let incoming{return .emit(incoming)}
            return .pull(frame.children.last!)
        }
        if frame.phase==0{frame.phase=1}
        if let incoming{
            switch incoming{
            case .value(let value):
                if let object{
                    try context.charge(.collectionValues);frame.collectionSlots += 1
                    try context.meter.retain(40);frame.slots += 40
                    frame.members.append((object.members[frame.index].key,value));try dispose(frame.children.removeLast(),context:&context);frame.index += 1
                }else{try capture(value,frame:&frame,context:&context);return .pull(frame.children[0])}
            case .end:try dispose(frame.children.removeLast(),context:&context);frame.index += 1
            case .failure(let failure):throw failure
            }
        }
        if frame.index<count{
            let value:JSON
            if let object{value=object.members[frame.index].value}else if case .array(let values)=frame.input.value{value=values[frame.index]}else{throw FilterLanguageFailure("invalidWalkState")}
            return .pull(try child(frame.node,frame:&frame,value:frame.input.selecting(value),context:&context))
        }
        let result:FilterYield,transfer=frame.collectionSlots
        if object != nil{
            let bytes=UInt64(frame.members.count)*24;try context.meter.retain(bytes);frame.slots += bytes;try context.work(UInt64(frame.members.count))
            let members=frame.members.map{JSONMember($0.0,value:$0.1.value)}
            let entry=context.meter.used(.retainedBytes)
            let indexed:JSONObject
            do{indexed=try JSONObject.indexed(admitted:members,meter:&context.meter)}catch{frame.slots += context.meter.used(.retainedBytes)-entry;throw error}
            let indexBytes=context.meter.used(.retainedBytes)-entry;frame.slots += indexBytes
            result=try FilterValues.produced(.object(indexed),collections:transfer,context:&context)
            try context.meter.release(bytes+indexBytes);frame.slots -= bytes+indexBytes
        }else{
            let bytes=UInt64(frame.values.count)*16;try context.meter.retain(bytes);frame.slots += bytes;try context.work(UInt64(frame.values.count))
            result=try FilterValues.array(frame.values.map(\.value),admittedCollectionCount:true,context:&context)
            try context.meter.release(bytes);frame.slots -= bytes
        }
        try releaseCache(&frame,context:&context,transferring:transfer)
        frame.current=result;frame.phase=3;return .pull(try child(filter,frame:&frame,value:result,context:&context))
    }
    private mutating func loop(_ name:String,arguments:[Int],frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{frame.phase=1;return .pull(try child(arguments[0],frame:&frame,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{
                    let truth=FilterTruth.test(value.value)
                    if name=="until" && truth{return .emit(.value(frame.input))}
                    if name=="while" && !truth{return .pull(frame.children[0])}
                    frame.phase=2
                    if name=="while"{return .emit(.value(frame.input))}
                }else if frame.phase==3{frame.phase=4;return .pull(try child(frame.node,frame:&frame,value:value,context:&context))}
                else{return .emit(.value(value))}
            case .end:
                if frame.phase==1{return .emit(.end)}
                if frame.phase==3{try dispose(frame.children.removeLast(),context:&context);frame.phase=1;return .pull(frame.children[0])}
                try dispose(frame.children.removeLast(),context:&context);frame.phase=3;return .pull(frame.children[1])
            case .failure(let failure):throw failure
            }
        }
        if frame.phase==2{frame.phase=3;return .pull(try child(arguments[1],frame:&frame,context:&context))}
        return .pull(frame.children.last!)
    }
    private mutating func recurse(_ arguments:[Int],frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{frame.phase=1;return .emit(.value(frame.input))}
        if frame.phase==1{frame.phase=2;return .pull(try child(arguments[0],frame:&frame,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==2{
                    if arguments.count==2{frame.current=value;frame.phase=4;return .pull(try child(arguments[1],frame:&frame,value:value,context:&context))}
                    frame.phase=3;return .pull(try child(frame.node,frame:&frame,value:value,context:&context))
                }
                if frame.phase==4{
                    if FilterTruth.test(value.value){frame.phase=5;return .pull(try child(frame.node,frame:&frame,value:frame.current,context:&context))}
                    return .pull(frame.children[1])
                }
                return .emit(.value(value))
            case .end:
                if frame.phase==2{return .emit(.end)}
                try dispose(frame.children.removeLast(),context:&context)
                if frame.phase==5{frame.phase=4;return .pull(frame.children[1])}
                frame.phase=2;frame.current=nil;return .pull(frame.children[0])
            case .failure(let failure):throw failure
            }
        }
        return .pull(frame.children.last!)
    }
    private mutating func reduction(_ source:Int,name:String,initial:Int,update:Int,extract:Int?,foreach:Bool,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{frame.phase=1;return .pull(try child(initial,frame:&frame,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{frame.current=value;frame.phase=2;return .pull(try child(source,frame:&frame,context:&context))}
                if frame.phase==2{
                    try context.charge(.bindings);frame.bindingSlots += 1
                    let bytes=UInt64(frame.bindings.count+1)*32+UInt64(name.utf8.count)
                    try context.meter.retain(bytes);frame.scopeBytes += bytes
                    var environment=frame.bindings;environment[name]=value
                    let target=try child(update,frame:&frame,value:frame.current ?? .init(value:.null),bindings:environment,context:&context)
                    frames[target]!.scopeBytes += bytes;frames[target]!.bindingSlots += 1
                    frame.scopeBytes -= bytes;frame.bindingSlots -= 1;frame.phase=3;frame.flag=false;return .pull(target)
                }
                if frame.phase==3{
                    frame.current=value;frame.flag=true
                    if foreach{
                        if let extract{frame.phase=4;return .pull(try child(extract,frame:&frame,value:value,bindings:frames[frame.children[2]]!.bindings,context:&context))}
                        return .emit(.value(value))
                    }
                    return .pull(frame.children[2])
                }
                return .emit(.value(value))
            case .end:
                if frame.phase==1{return .emit(.end)}
                if frame.phase==2{
                    try dispose(frame.children.removeLast(),context:&context);frame.phase=1
                    if foreach{frame.current=nil;return .pull(frame.children[0])}
                    let result=frame.current ?? .init(value:.null);frame.current=nil;return .emit(.value(result))
                }
                if frame.phase==3{
                    if !frame.flag{frame.current = .init(value:.null)}
                    try dispose(frame.children.removeLast(),context:&context);frame.phase=2;return .pull(frame.children[1])
                }
                try dispose(frame.children.removeLast(),context:&context);frame.phase=3;return .pull(frame.children[2])
            case .failure(let failure):throw failure
            }
        }
        return .pull(frame.children.last!)
    }
    private mutating func truthReduction(_ name:String,arguments:[Int],frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        let identity=name=="all"
        func verdict(_ truth:Bool,context:inout TransformRuntimeContext)throws->Action{try .emit(.value(FilterValues.produced(.boolean(truth),context:&context)))}
        if arguments.isEmpty{
            if frame.phase>0{return .emit(.end)};frame.phase=99
            guard case .array(let values)=frame.input.value else{throw FilterLanguageFailure("expectedArray")}
            for value in values{try context.work();let truth=FilterTruth.test(value);if truth != identity{return try verdict(truth,context:&context)}}
            return try verdict(identity,context:&context)
        }
        if arguments.count==1{
            guard case .array(let values)=frame.input.value else{throw FilterLanguageFailure("expectedArray")}
            if let incoming{
                switch incoming{
                case .value(let value):let truth=FilterTruth.test(value.value);if truth != identity{try dispose(frame.children.removeLast(),context:&context);frame.phase=99;return try verdict(truth,context:&context)};return .pull(frame.children[0])
                case .end:try dispose(frame.children.removeLast(),context:&context);frame.index += 1
                case .failure(let failure):throw failure
                }
            }
            if frame.index==values.count{frame.phase=99;return try verdict(identity,context:&context)}
            return .pull(try child(arguments[0],frame:&frame,value:frame.input.selecting(values[frame.index]),context:&context))
        }
        if frame.phase==0{frame.phase=1;return .pull(try child(arguments[0],frame:&frame,context:&context))}
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{frame.phase=2;return .pull(try child(arguments[1],frame:&frame,value:value,context:&context))}
                let truth=FilterTruth.test(value.value)
                if truth != identity{for child in frame.children{try dispose(child,context:&context)};frame.children=[];frame.phase=99;return try verdict(truth,context:&context)}
                return .pull(frame.children[1])
            case .end:
                if frame.phase==1{frame.phase=99;return try verdict(identity,context:&context)}
                try dispose(frame.children.removeLast(),context:&context);frame.phase=1;return .pull(frame.children[0])
            case .failure(let failure):throw failure
            }
        }
        return .pull(frame.children.last!)
    }
    private mutating func nth(_ arguments:[Int],frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{
            if arguments.count==1 { guard case .array=frame.input.value else{throw FilterLanguageFailure("expectedArray")} }
            try context.meter.retain(48);frame.slots += 48;frame.groups=[[],[]];frame.phase=1;return .pull(try child(arguments[0],frame:&frame,context:&context))
        }
        if let incoming{
            switch incoming{
            case .value(let value):
                if frame.phase==1{
                    guard case .number(let n)=value.value,n.isInteger,!n.isNegative else{throw FilterLanguageFailure("invalidNthIndex")}
                    try captureGroup(value,group:0,frame:&frame,context:&context);return .pull(frame.children[0])
                }
                let index=JSONNumber(integer:frame.ordinal)
                var allPassed=true
                for position in frame.groups[0].indices{
                    guard case .number(let n)=frame.groups[0][position].value else{throw FilterLanguageFailure("invalidNthIndex")}
                    let order=try n.compare(to:index,meter:&context.meter)
                    if order == .orderedSame{frame.groups[1][position]=value;frame.selections[position]=1}
                    if order == .orderedDescending{allPassed=false}
                }
                if allPassed{try dispose(frame.children.removeLast(),context:&context);frame.phase=3}
                else{let (next,overflow)=frame.ordinal.addingReportingOverflow(1);guard !overflow else{throw TransformRuntimeFailure(.resource,"counterOverflow",metric:"totalWorkUnits",overflow:true)};frame.ordinal=next;return .pull(frame.children[0])}
            case .end:
                try dispose(frame.children.removeLast(),context:&context)
                if frame.phase==1{
                    if arguments.count==1{
                        guard case .array(let values)=frame.input.value else{throw FilterLanguageFailure("expectedArray")}
                        for value in frame.groups[0]{
                            guard case .number(let n)=value.value else{throw FilterLanguageFailure("invalidNthIndex")}
                            if try n.compare(to:JSONNumber(integer:values.count),meter:&context.meter) == .orderedAscending{
                                let index=try n.integer(as:Int.self,meter:&context.meter)
                                try captureGroup(frame.input.selecting(values[index]),group:1,frame:&frame,context:&context)
                            }
                        }
                        frame.phase=4;frame.index=0
                    }else{
                        if frame.groups[0].isEmpty{frame.phase=99;return .emit(.end)}
                        let count=UInt64(frame.groups[0].count),bytes=count*32
                        try context.charge(.collectionValues,count);frame.collectionSlots += count
                        try context.meter.retain(bytes);frame.slots += bytes
                        frame.groups[1]=Array(repeating:.init(value:.null),count:Int(count));frame.selections=Array(repeating:0,count:Int(count));frame.phase=2
                        return .pull(try child(arguments[1],frame:&frame,context:&context))
                    }
                }else{frame.phase=3;frame.index=0}
            case .failure(let failure):throw failure
            }
        }
        if frame.phase==3 || frame.phase==4{
            while frame.index<frame.groups[1].count{try context.work();let index=frame.index;frame.index += 1;if frame.phase==4 || frame.selections[index]==1{return .emit(.value(frame.groups[1][index]))}}
            frame.phase=99;return .emit(.end)
        }
        return .pull(frame.children[0])
    }
    private mutating func terminalSelection(_ name:String,argument:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        if frame.phase==0{frame.phase=1;return .pull(try child(argument,frame:&frame,context:&context))}
        if let incoming {
            switch incoming{
            case .value(let value):
                if name=="first"{try dispose(frame.children.removeLast(),context:&context);frame.phase=99;return .emit(.value(value))}
                frame.current=value;return .pull(frame.children[0])
            case .end:
                frame.phase=99
                if let value=frame.current{frame.current=nil;return .emit(.value(value))};return .emit(.end)
            case .failure(let failure):throw failure
            }
        }
        return .pull(frame.children[0])
    }
    private mutating func keyed(_ name:String,argument:Int,frame:inout Frame,incoming:Event?,context:inout TransformRuntimeContext)throws->Action {
        guard case .array(let values)=frame.input.value else{throw FilterLanguageFailure("expectedArray")}
        if frame.phase==0 {
            let bytes=UInt64(values.count)*24
            try context.meter.retain(bytes);frame.slots += bytes
            frame.groups=Array(repeating:[],count:values.count);frame.phase=1
        }
        if let incoming {
            switch incoming{
            case .value(let value):try captureGroup(value,group:frame.index,frame:&frame,context:&context);return .pull(frame.children[0])
            case .end:try dispose(frame.children.removeLast(),context:&context);frame.index += 1
            case .failure(let failure):throw failure
            }
        }
        if frame.index<values.count{return .pull(try child(argument,frame:&frame,value:frame.input.selecting(values[frame.index]),context:&context))}
        let bytes=UInt64(values.count)*32+frame.collectionSlots*16
        try context.meter.retain(bytes);frame.slots += bytes;try context.work(UInt64(values.count)+frame.collectionSlots)
        var keyed:[FilterCollectionBuiltins.Keyed]=[]
        for index in values.indices{keyed.append(.init(value:values[index],keys:frame.groups[index].map(\.value)))}
        let result=try FilterCollectionBuiltins.keyed(name,values:keyed,context:&context)
        frame.phase=99;return .emit(.value(result))
    }
    private mutating func range(_ arguments: [Int], frame: inout Frame, incoming: Event?, context: inout TransformRuntimeContext) throws -> Action {
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
    private func languageError(_ value: JSON, frame: inout Frame, context: inout TransformRuntimeContext) throws -> FilterLanguageFailure {
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
