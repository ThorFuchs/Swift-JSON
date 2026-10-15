// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

struct SchemaExampleObjectFrame {
    let constraints: [SchemaExampleConstraint]
    let keys: [JSONKey]
    let depth: UInt64
    let variation: UInt64
    var position = 0
    var members: [JSONMember] = []
    var awaiting = false
}
struct SchemaExampleArrayFrame {
    let constraints: [SchemaExampleConstraint]
    let count: UInt64
    let depth: UInt64
    let variation: UInt64
    let unique: Bool
    var values: [JSON] = []
    var awaiting = false
}
enum SchemaExampleFrame {
    case value([JSONSchemaQualifiedNode], UInt64, UInt64)
    case object(SchemaExampleObjectFrame)
    case array(SchemaExampleArrayFrame)
}
@available(*, unavailable)
extension SchemaExampleFrame: Sendable {}
@available(*, unavailable)
extension SchemaExampleObjectFrame: Sendable {}
@available(*, unavailable)
extension SchemaExampleArrayFrame: Sendable {}

enum SchemaExampleConstructor {
    static let alternatives: [JSONSchemaPlan.Keyword] = [.allOf, .anyOf, .oneOf]
    static func integerText(_ value: UInt64, meter: inout JSONWorkMeter) throws -> String {
        // UInt64 decimal formatting is bounded by twenty ASCII digits. It must
        // remain positional text (index 10 is "10", not normalized JSON "1e1").
        try meter.retain(40)
        for _ in 0..<20 { try meter.work(subsystem: .numericWorkUnits) }
        return String(value)
    }
    static func appendNodes(_ input: [JSONSchemaQualifiedNode], to output: inout [JSONSchemaQualifiedNode],
                            meter: inout JSONWorkMeter) throws {
        for node in input { try meter.work(); try meter.retain(JSONLogicalWeights.indexSlot); output.append(node) }
    }
    static func propertyNodes(_ constraints: [SchemaExampleConstraint], key: JSONKey,
                              meter: inout JSONWorkMeter) throws -> [JSONSchemaQualifiedNode] {
        var result: [JSONSchemaQualifiedNode] = []
        for c in constraints {
            let declared = try c.value(.properties, meter: &meter)?.objectValue?.lookup(key.string, meter: &meter)
            let nodes = try c.children(declared == nil ? .additionalProperties : .properties,
                                       token: declared == nil ? nil : key.string, meter: &meter)
            try appendNodes(nodes, to: &result, meter: &meter)
        }
        return result
    }
    static func textLess(_ a: String, _ b: String, meter: inout JSONWorkMeter) throws -> Bool {
        var a = a.utf8.makeIterator(), b = b.utf8.makeIterator()
        while true {
            try meter.work(); let x = a.next(), y = b.next()
            if x != y { if let x, let y { return x < y }; return x == nil }
            if x == nil { return false }
        }
    }
    static func insert(_ spelling: String, into keys: inout [JSONKey], meter: inout JSONWorkMeter) throws {
        var position = keys.count
        for (i, key) in keys.enumerated() {
            if try JSONComparison.textEquals(key.string, spelling, meter: &meter) { return }
            if try textLess(spelling, key.string, meter: &meter) { position = i; break }
        }
        try meter.require(.objectMembers, UInt64(keys.count) + 1)
        try JSONAdmission.text(spelling, key: true, meter: &meter, owned: true)
        let key = try JSONKey(spelling, meter: &meter)
        try meter.retain(JSONLogicalWeights.indexSlot)
        for _ in position..<keys.count { try meter.work() }
        keys.insert(key, at: position)
    }
    static func objectKeys(_ constraints: [SchemaExampleConstraint], meter: inout JSONWorkMeter) throws -> [JSONKey]? {
        guard let bounds = try SchemaExamplePrimitives.size(constraints, minimum: .minProperties, maximum: .maxProperties,
                                                             capacity: .objectMembers, meter: &meter) else { return nil }
        var keys: [JSONKey] = []
        for c in constraints {
            if let required = try c.value(.required, meter: &meter)?.arrayValue {
                for value in required {
                    try meter.work()
                    guard let spelling = value.stringValue else { throw JSONFailure(.configuration, code: .invalidOperation) }
                    try insert(spelling, into: &keys, meter: &meter)
                }
            }
        }
        if UInt64(keys.count) > bounds.maximum { return nil }
        var declared: [JSONKey] = []
        for c in constraints {
            if let properties = try c.value(.properties, meter: &meter)?.objectValue {
                for member in properties {
                    try meter.work()
                    if member.value.booleanValue != false { try insert(member.key.string, into: &declared, meter: &meter) }
                }
            }
        }
        for key in declared {
            if UInt64(keys.count) >= bounds.minimum { break }
            try insert(key.string, into: &keys, meter: &meter)
        }
        var ordinal: UInt64 = 0
        while UInt64(keys.count) < bounds.minimum {
            try meter.work()
            let suffix = try integerText(ordinal, meter: &meter)
            try meter.retain(UInt64(suffix.utf8.count) + 1)
            for _ in suffix.utf8 { try meter.work() }
            try insert("p" + suffix, into: &keys, meter: &meter)
            ordinal = try meter.adding(.workUnits, ordinal, 1)
        }
        return keys
    }
    static func typeMask(_ constraints: [SchemaExampleConstraint], meter: inout JSONWorkMeter) throws -> UInt8 {
        var mask: UInt8 = 127
        for c in constraints {
            if c.view.raw.booleanValue == false { return 0 }
            guard let type = try c.value(.type, meter: &meter) else { continue }
            let values: [JSON]
            if type.stringValue != nil { try meter.retain(JSONLogicalWeights.arraySlot); values = [type] }
            else if let array = type.arrayValue { values = array }
            else { throw JSONFailure(.configuration, code: .invalidOperation) }
            var accepted: UInt8 = 0
            for value in values {
                try meter.work()
                guard let name = value.stringValue else { throw JSONFailure(.configuration, code: .invalidOperation) }
                // Only the compiler's seven ASCII type names can reach this mapping.
                for (spelling, bits) in typeNames where try JSONComparison.textEquals(name, spelling, meter: &meter) { accepted |= bits }
            }
            mask &= accepted
        }
        return mask
    }
    static let typeNames: [(String, UInt8)] = [("null",1),("boolean",2),("integer",4),("number",12),("string",16),("array",32),("object",64)]
    static let hints: [JSONSchemaPlan.Keyword] = [.type,.minimum,.maximum,.exclusiveMinimum,.exclusiveMaximum,.multipleOf,.minLength,.maxLength,.pattern,.format,.required,.properties,.minProperties,.maxProperties,.items,.prefixItems,.minItems,.maxItems]
    static func construct(nodes: [JSONSchemaQualifiedNode], variation: UInt64,
                          profile: JSONSchemaExampleProfile, corpus: [JSON], assertion: Bool,
                          random: inout SchemaExampleRandom, trace: inout SchemaExampleTrace,
                          meter: inout JSONWorkMeter) throws -> JSON? {
        var frames: [SchemaExampleFrame] = [], completed: JSON?
        func push(_ frame: SchemaExampleFrame, meter: inout JSONWorkMeter) throws {
            try meter.require(.evaluationFrames, UInt64(frames.count) + 1)
            try meter.retain(JSONLogicalWeights.frame); frames.append(frame)
        }
        try push(.value(nodes, 0, variation), meter: &meter)
        while let frame = frames.popLast() {
            try meter.work(); try meter.release(JSONLogicalWeights.frame)
            switch frame {
            case .value(let nodes, let depth, let ordinal):
                try trace.event(6, depth, ordinal, meter: &meter)
                let constraints = try SchemaExampleConjunction.gather(nodes, meter: &meter)
                var declared: JSON?, hasHint = nodes.isEmpty
                for c in constraints {
                    if c.view.raw.booleanValue == false { return nil }
                    if let value = try c.value(.const, meter: &meter) { declared = value; break }
                    if let values = try c.value(.enum, meter: &meter)?.arrayValue, !values.isEmpty {
                        declared = values[Int(ordinal % UInt64(values.count))]; break
                    }
                    for hint in hints { if try c.value(hint, meter: &meter) != nil { hasHint = true; break } }
                    if c.view.raw.booleanValue == true || c.view.raw.objectValue?.isEmpty == true { hasHint = true }
                }
                // Whole-instance const/enum candidates were already tried by discovery.
                if depth == 0 && declared != nil { return nil }
                if let declared {
                    try JSONAdmission.value(declared, meter: &meter, owned: true, depth: depth)
                    completed = declared; continue
                }
                guard hasHint else { return nil }
                try meter.charge(.nodes); try meter.retain(JSONLogicalWeights.node)
                let mask = try typeMask(constraints, meter: &meter)
                var kinds: [UInt8] = []
                for kind: UInt8 in [1,2,4,16,32,64] {
                    if mask & kind != 0 { try meter.retain(1); kinds.append(kind) }
                }
                guard !kinds.isEmpty else { return nil }
                let kind = kinds[Int(ordinal % UInt64(kinds.count))]
                switch kind {
                case 1: completed = .null
                case 2: completed = .boolean(ordinal % 2 != 0)
                case 4:
                    guard let number = try SchemaExamplePrimitives.number(constraints, integral: mask & 8 == 0, variation: ordinal, meter: &meter) else { return nil }
                    completed = .number(number)
                case 16:
                    guard let text = try SchemaExamplePrimitives.string(constraints, variation: ordinal, profile: profile, corpus: corpus,
                                                                        assertion: assertion, random: &random, trace: &trace, meter: &meter) else { return nil }
                    completed = .string(text)
                case 32:
                    let container = try meter.adding(.maxDepth, depth, 1)
                    guard let bounds = try SchemaExamplePrimitives.size(constraints, minimum: .minItems, maximum: .maxItems,
                                                                         capacity: .arrayItems, meter: &meter) else { return nil }
                    var unique = false
                    for c in constraints { if try c.value(.uniqueItems, meter: &meter)?.booleanValue == true { unique = true } }
                    try push(.array(.init(constraints: constraints, count: bounds.minimum, depth: container, variation: ordinal, unique: unique)), meter: &meter)
                default:
                    let container = try meter.adding(.maxDepth, depth, 1)
                    guard let keys = try objectKeys(constraints, meter: &meter) else { return nil }
                    try push(.object(.init(constraints: constraints, keys: keys, depth: container, variation: ordinal)), meter: &meter)
                }
            case .object(var state):
                if state.awaiting {
                    guard let value = completed else { throw JSONFailure(.configuration, code: .invalidOperation) }
                    try meter.retain(JSONLogicalWeights.member)
                    state.members.append(.init(state.keys[state.position - 1], value: value)); completed = nil; state.awaiting = false
                }
                if state.position == state.keys.count {
                    completed = .object(try JSONObject.indexed(admitted: state.members, meter: &meter)); continue
                }
                let nodes = try propertyNodes(state.constraints, key: state.keys[state.position], meter: &meter)
                state.position += 1; state.awaiting = true
                let depth = state.depth, ordinal = state.variation
                try push(.object(state), meter: &meter); try push(.value(nodes, depth, ordinal), meter: &meter)
            case .array(var state):
                if state.awaiting {
                    guard let value = completed else { throw JSONFailure(.configuration, code: .invalidOperation) }
                    try meter.retain(JSONLogicalWeights.arraySlot); state.values.append(value); completed = nil; state.awaiting = false
                }
                let index = UInt64(state.values.count)
                if index == state.count { completed = .array(state.values); continue }
                var nodes: [JSONSchemaQualifiedNode] = []
                let token = try integerText(index, meter: &meter)
                for c in state.constraints {
                    let prefix = try c.value(.prefixItems, meter: &meter)?.arrayValue
                    let kind: JSONSchemaPlan.Keyword = index < UInt64(prefix?.count ?? 0) ? .prefixItems : .items
                    try appendNodes(c.children(kind, token: kind == .prefixItems ? token : nil, meter: &meter), to: &nodes, meter: &meter)
                }
                let ordinal = try meter.adding(.workUnits, state.variation, state.unique ? index : 0)
                let depth = state.depth; state.awaiting = true
                try push(.array(state), meter: &meter); try push(.value(nodes, depth, ordinal), meter: &meter)
            }
        }
        return completed
    }
}
