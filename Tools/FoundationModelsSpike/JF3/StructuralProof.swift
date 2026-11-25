// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// Evidence of a verified rewrite at an effective canonical schema position.
/// A local reference records the exact decoded root definition key; it is not
/// an instruction to mutate the original or the actual framework schema.
public struct JSONGenerationSchemaStructuralRewrite: Sendable, Equatable {
    public enum Kind: String, Sendable, Equatable {
        case localReference, requiredPermutation
    }
    public let kind: Kind
    public let path: [JSONLocationComponent]
    public let definition: JSONKey?
}

// Paired proof over the admitted canonical tree. Never construct an expanded
// tree or infer equivalence from instance samples. All caller inputs have
// already been admitted; the original has compiled and passed JF3SchemaProfile.
struct JF33StructuralProof {
    typealias Path = JF3SchemaProfile.Path
    private let definitions: JSONObject?
    private var used: [Bool]
    private var active: [Bool]
    private(set) var additions: [JSONGenerationSchemaAnnotationAddition] = []
    private(set) var rewrites: [JSONGenerationSchemaStructuralRewrite] = []

    static func verify(_ original: JSON, _ returned: JSON,
                       meter: inout JSONWorkMeter) throws -> Self {
        guard let root = returned.objectValue else { throw fail(.unsupportedShape, []) }
        let defsPath: Path = [.key(JSONKey("$defs"))]
        var defs: JSONObject?
        if let value = try root.lookup("$defs", meter: &meter) {
            guard let object = value.objectValue, !object.isEmpty, object.count <= 128 else {
                throw fail(.unsupportedShape, defsPath)
            }
            defs = object
            for member in object {
                try meter.work()
                guard !member.key.string.isEmpty else { throw fail(.invalidLocalReference, defsPath) }
            }
        }
        let count = defs?.count ?? 0
        try meter.retain(64 + UInt64(count) * 2)
        var proof = Self(definitions: defs, used: Array(repeating: false, count: count),
                         active: Array(repeating: false, count: count))
        try proof.node(original, returned, at: [], depth: 1, root: true, allowReference: false, meter: &meter)
        if let defs {
            for index in defs.indices {
                try meter.work()
                if !proof.used[index] {
                    throw fail(.unusedDefinition, try JF3SchemaProfile.path(defsPath, defs[index].key, meter: &meter))
                }
            }
        }
        try meter.checkpoint()
        return proof
    }

    private static func fail(_ issue: JSONGenerationSchemaIssue, _ path: Path) -> JSONGenerationSchemaFailure {
        .init(issue: issue, path: path)
    }

    private mutating func node(_ original: JSON, _ returned: JSON, at location: Path, depth: Int,
                               root: Bool = false, allowReference: Bool = true, meter: inout JSONWorkMeter) throws {
        try meter.checkpoint(); try meter.work(); try meter.retain(64)
        guard depth <= 16, let a = original.objectValue, let b = returned.objectValue else {
            throw Self.fail(.changedConstraint, location)
        }
        if let ref = try b.lookup("$ref", meter: &meter) {
            let field = try JF3SchemaProfile.path(location, JSONKey("$ref"), meter: &meter)
            guard allowReference, !root, b.count == 1, let text = ref.stringValue, let defs = definitions else {
                throw Self.fail(.invalidLocalReference, field)
            }
            let pointer: JSONPointer
            do { pointer = try JSONPointer.uriFragment(text, meter: &meter) }
            catch let error as JSONFailure where error.category == .pointer {
                throw Self.fail(.invalidLocalReference, field)
            }
            guard pointer.tokens.count == 2,
                  try JSONComparison.textEquals(pointer.tokens[0].string, "$defs", meter: &meter) else {
                throw Self.fail(.invalidLocalReference, field)
            }
            let key = pointer.tokens[1]
            var found: Int?
            for i in defs.indices {
                try meter.work()
                if try JSONComparison.textEquals(defs[i].key.string, key.string, meter: &meter) { found = i; break }
            }
            guard let index = found else { throw Self.fail(.invalidLocalReference, field) }
            guard !active[index] else { throw Self.fail(.cyclicLocalReference, field) }
            let target = defs[index].value
            // Only hoisted concrete object schemas, not chains of aliases or
            // arbitrary referenced scalar/array schemas. Nested uses may refer
            // to other definitions; check them per use, not only once per title.
            guard let targetObject = target.objectValue,
                  let type = try targetObject.lookup("type", meter: &meter)?.stringValue,
                  try JSONComparison.textEquals(type, "object", meter: &meter),
                  try targetObject.lookup("$ref", meter: &meter) == nil else {
                throw Self.fail(.invalidLocalReference, field)
            }
            used[index] = true; active[index] = true
            try chargeDiagnostic(location, definition: key, meter: &meter)
            rewrites.append(.init(kind: .localReference, path: location, definition: key))
            try node(original, target, at: location, depth: depth, allowReference: false, meter: &meter)
            active[index] = false
            return
        }

        for member in a {
            try meter.work()
            let key = member.key.string // canonical profile admits ASCII keywords
            let field = try JF3SchemaProfile.path(location, member.key, meter: &meter)
            let annotation = key == "title" || key == "description" || key == "x-order"
            guard let other = try b.lookup(key, meter: &meter) else {
                throw Self.fail(annotation ? .changedAnnotation : .changedConstraint, field)
            }
            switch key {
            case "properties":
                guard let props = member.value.objectValue, let actual = other.objectValue, props.count == actual.count else {
                    throw Self.fail(.changedConstraint, field)
                }
                for prop in props {
                    try meter.work()
                    let path = try JF3SchemaProfile.path(field, prop.key, meter: &meter)
                    guard let child = try actual.lookup(prop.key.string, meter: &meter) else {
                        throw Self.fail(.changedConstraint, path)
                    }
                    try node(prop.value, child, at: path, depth: depth + 1, meter: &meter)
                }
            case "items":
                try node(member.value, other, at: field, depth: depth + 1, meter: &meter)
            case "required":
                if try !JSONComparison.equals(member.value, other, meter: &meter) {
                    guard let expected = member.value.arrayValue, let actual = other.arrayValue,
                          try permutation(expected, actual, meter: &meter) else {
                        throw Self.fail(.changedConstraint, field)
                    }
                    try chargeDiagnostic(field, definition: nil, meter: &meter)
                    rewrites.append(.init(kind: .requiredPermutation, path: field, definition: nil))
                }
            default:
                if try !JSONComparison.equals(member.value, other, meter: &meter) {
                    throw Self.fail(annotation ? .changedAnnotation : .changedConstraint, field)
                }
            }
        }
        for member in b {
            try meter.work()
            if try a.lookup(member.key.string, meter: &meter) != nil { continue }
            let key = member.key.string
            let field = try JF3SchemaProfile.path(location, member.key, meter: &meter)
            guard try JF3SchemaProfile.ascii(key, meter: &meter) else { throw Self.fail(.unsupportedDeclaration, field) }
            if root && key == "$defs" { continue }
            switch key {
            case "title":
                guard member.value.stringValue != nil else { throw Self.fail(.unsupportedShape, field) }
            case "x-order":
                guard let props = try a.lookup("properties", meter: &meter)?.objectValue,
                      let values = member.value.arrayValue,
                      try order(values, properties: props, meter: &meter) else {
                    throw Self.fail(.unsupportedShape, field)
                }
            case "description": throw Self.fail(.changedAnnotation, field)
            default: throw Self.fail(.unsupportedDeclaration, field)
            }
            try chargeDiagnostic(field, definition: nil, meter: &meter)
            additions.append(.init(path: field))
        }
    }

    // Canonical required has already been checked to contain distinct names.
    // Mark each matched index exactly once, avoiding Swift String equivalence
    // and unmetered hashing or sorting.
    private func permutation(_ expected: [JSON], _ actual: [JSON], meter: inout JSONWorkMeter) throws -> Bool {
        guard expected.count == actual.count, expected.count <= 128 else { return false }
        try meter.retain(UInt64(expected.count))
        var matched = Array(repeating: false, count: expected.count)
        for value in actual {
            try meter.work()
            guard let text = value.stringValue else { return false }
            var found = false
            for i in expected.indices {
                try meter.work()
                guard let name = expected[i].stringValue else { return false }
                if try JSONComparison.textEquals(name, text, meter: &meter) {
                    guard !matched[i] else { return false }
                    matched[i] = true; found = true; break
                }
            }
            if !found { return false }
        }
        return true
    }

    private func order(_ values: [JSON], properties: JSONObject, meter: inout JSONWorkMeter) throws -> Bool {
        guard values.count == properties.count else { return false }
        try meter.retain(UInt64(values.count) * JSONLogicalWeights.arraySlot)
        var expected: [JSON] = []
        for prop in properties { try meter.work(); expected.append(.string(prop.key.string)) }
        return try permutation(expected, values, meter: &meter)
    }

    private func chargeDiagnostic(_ path: Path, definition: JSONKey?, meter: inout JSONWorkMeter) throws {
        try meter.charge(.issues); try meter.retain(64)
        for component in path {
            try meter.work(); try meter.charge(.diagnosticBytes, 16)
            if case .key(let key) = component {
                for _ in key.string.utf8 { try meter.work(); try meter.charge(.diagnosticBytes) }
            }
        }
        if let definition {
            for _ in definition.string.utf8 { try meter.work(); try meter.charge(.diagnosticBytes); try meter.retain(1) }
        }
    }
}
