// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

/// Finite codec policy, independent of compilation and execution policies.
/// Native work, traversal, text, cancellation and live logical storage limits also apply.
public struct JSONTransformDefinitionLimits: Sendable {
    /// Native cumulative quotas for one prepare, decode or encode operation.
    public var json: JSONLimits = .balanced
    /// Maximum UTF-8 bytes in query source; default one MiB.
    public var maximumSourceBytes: UInt64 = 1_048_576
    /// Maximum declared names, including every supplied occurrence before duplicate detection.
    public var maximumVariableNames: UInt64 = 128
    /// Maximum UTF-8 bytes in one ASCII variable name.
    public var maximumNameBytes: UInt64 = 128
    /// Maximum total UTF-8 bytes in all supplied variable names.
    public var maximumTotalNameBytes: UInt64 = 8_192
    /// Inclusive input/output wire-byte ceiling, additionally bounded by native quotas.
    public var maximumEncodedBytes: UInt64 = 2_097_152
    var checkpointObserver: (@Sendable (UInt64) -> Void)?
    /// Creates the finite balanced codec policy; zero capacities remain valid.
    public init() {}

    func effective() throws -> JSONLimits {
        for cap in [maximumSourceBytes, maximumVariableNames, maximumNameBytes,
                    maximumTotalNameBytes, maximumEncodedBytes] {
            guard cap < UInt64.max else { throw JSONFailure(.configuration, code: .invalidLimits) }
        }
        var result = json
        result[.inputBytes] = min(result[.inputBytes], maximumEncodedBytes)
        result[.outputBytes] = min(result[.outputBytes], maximumEncodedBytes)
        try result.validate()
        return result
    }
    func meter() throws -> JSONWorkMeter {
        var result = try JSONWorkMeter(limits: effective(), domain: .core)
        result.checkpointObserver = checkpointObserver
        return result
    }
}

/// Closed-definition refusals; native JSON syntax/resource errors and cancellation stay distinct.
public enum JSONTransformDefinitionFailure: Error, Sendable, Equatable {
    /// Wrong root, fields, field types or format identifier.
    case invalidDefinition
    /// A definition revision other than mathematical integer one.
    case unsupportedDefinitionRevision
    /// A query dialect other than swift-json-query-v1.
    case unsupportedDialectRevision
    /// A name outside the compiler's ASCII identifier grammar.
    case invalidVariableName
    /// Two identical names were supplied; no Set conversion silently removed one.
    case duplicateVariableName
    /// An inclusive codec-specific capacity was exceeded.
    /// - Parameters:
    ///   - metric: Fixed codec policy identifier, without rejected payloads.
    ///   - limit: Configured finite maximum.
    ///   - attempted: Observed usage at refusal.
    case limitExceeded(metric: String, limit: UInt64, attempted: UInt64)
}

/// Immutable source definition, separate from compiled VM plans and effective policies.
/// Source scalar spelling is preserved. Names are unique ASCII identifiers in UTF-8
/// order. No synthesized String equality, source rewriting or bytecode serialization is used.
public struct JSONTransformProgramDefinition: Sendable {
    /// Exact decoded query source, including whitespace and scalar spelling.
    public let source: String
    /// Unique declared variable names in exact ascending UTF-8 order.
    public let variableNames: [String]
    /// Known wire definition revision; independent of implementation identity.
    public var definitionRevision: UInt32 { 1 }
    /// Known query-language revision; independent of limits and the CLI source digest.
    public var dialectRevision: String { "swift-json-query-v1" }

    private init(validatedSource: String, canonicalNames: [String]) {
        source = validatedSource; variableNames = canonicalNames
    }

    /// Validates authored source metadata using one finite ledger; query compilation is explicit.
    /// - Parameters:
    ///   - source: Exact query source; syntax is checked only by compile.
    ///   - variables: Names before sorting; exact duplicates are rejected.
    ///   - limits: Finite text, sort, traversal and retention policy.
    /// - Returns: The immutable definition and actual successful validation accounting.
    /// - Throws: Definition/name/capacity, native resource/configuration errors or cancellation.
    public static func prepare(source: String, variables: [String] = [],
                               limits: JSONTransformDefinitionLimits = .init()) throws -> JSONOperationReport<Self> {
        var meter = try limits.meter()
        let result = try make(source: source, variables: variables, limits: limits, meter: &meter)
        return .init(result: result, statistics: meter.statistics())
    }

    /// Decodes one strict native JSON document with an exact closed V1 field set.
    /// Field order, whitespace and equivalent JSON escapes may differ; encoding
    /// produces canonical bytes. Duplicate fields/names and unknown fields fail.
    /// - Parameters:
    ///   - bytes: Caller-owned UTF-8 input; no ambient I/O or byte-copy prepass.
    ///   - limits: One cumulative policy for parsing, field checks and canonical names.
    /// - Returns: The decoded definition and actual successful cumulative accounting.
    /// - Throws: Native JSON syntax/resource errors, definition failures or cancellation.
    public static func decode(_ bytes: [UInt8], limits: JSONTransformDefinitionLimits = .init()) throws -> JSONOperationReport<Self> {
        var meter = try limits.meter()
        var root = try JSONParser().parse(bytes, meter: &meter)
        guard case .object(let object) = root, object.count == 5 else { throw JSONTransformDefinitionFailure.invalidDefinition }
        try meter.retain(80)
        var fields: [JSON?] = Array(repeating: nil, count: 5)
        for member in object {
            var found = false
            for (index, key) in ["definition", "version", "dialect", "source", "variables"].enumerated() {
                if try JSONComparison.textEquals(member.key.string, key, meter: &meter) {
                    fields[index] = member.value; found = true; break
                }
            }
            guard found else { throw JSONTransformDefinitionFailure.invalidDefinition }
        }
        guard case .string(let tag) = fields[0],
              try JSONComparison.textEquals(tag, "swift-json-transform-source", meter: &meter),
              case .number(let revision) = fields[1], case .string(let dialect) = fields[2],
              case .string(let source) = fields[3], case .array(let names) = fields[4] else {
            throw JSONTransformDefinitionFailure.invalidDefinition
        }
        guard try revision.compare(to: JSONNumber(integer: 1), meter: &meter) == .orderedSame else {
            throw JSONTransformDefinitionFailure.unsupportedDefinitionRevision
        }
        guard try JSONComparison.textEquals(dialect, "swift-json-query-v1", meter: &meter) else {
            throw JSONTransformDefinitionFailure.unsupportedDialectRevision
        }
        try require(UInt64(names.count), limits.maximumVariableNames, "variableNames", meter: &meter)
        var strings: [String] = []
        for name in names {
            try meter.work()
            guard case .string(let text) = name else { throw JSONTransformDefinitionFailure.invalidDefinition }
            try meter.retain(16); strings.append(text)
        }
        let baseline = meter.used(.retainedBytes)
        let result = try make(source: source, variables: strings, limits: limits, meter: &meter)
        let resultBytes = meter.used(.retainedBytes) - baseline
        root = .null; fields = []; strings = []
        // Parsed tree and extraction aliases are temporary; result strings were
        // independently reserved by make. Work is never refunded or restarted.
        try meter.checkpoint(); try meter.release(meter.used(.retainedBytes) - resultBytes)
        return .init(result: result, statistics: meter.statistics())
    }

    /// Encodes canonical compact UTF-8 with fixed metadata order and native escaping.
    /// The ordered fields are definition, version, dialect, source, variables.
    /// - Parameter limits: One finite ledger for admission, metadata, sorting and output.
    /// - Returns: Canonical bytes without a trailing newline and successful accounting.
    /// - Throws: Codec/native capacity or configuration errors, or cancellation.
    public func encode(limits: JSONTransformDefinitionLimits = .init()) throws -> JSONOperationReport<[UInt8]> {
        var meter = try limits.meter()
        let admitted = try Self.make(source: source, variables: variableNames, limits: limits, meter: &meter)
        var names: [JSON] = []
        for name in admitted.variableNames { try meter.work(); try meter.retain(16); names.append(.string(name)) }
        try meter.retain(5 * JSONLogicalWeights.member)
        let members: [JSONMember] = [
            .init("definition", value: .string("swift-json-transform-source")),
            .init("version", value: .number(JSONNumber(integer: 1))),
            .init("dialect", value: .string(dialectRevision)),
            .init("source", value: .string(admitted.source)),
            .init("variables", value: .array(names))]
        let object = try JSONObject.checked(members: members, meter: &meter)
        let bytes = try JSONWriter().write(.object(object), meter: &meter)
        try meter.checkpoint(); try meter.release(meter.used(.retainedBytes) - UInt64(bytes.count))
        return .init(result: bytes, statistics: meter.statistics())
    }

    /// Compiles this definition using the existing compiler and one compilation context.
    /// The source definition and codec policy are not captured by the compiled plan.
    /// - Parameter limits: Explicit finite compilation policy, independent of codec policy.
    /// - Returns: The native compiled program and actual successful compilation work.
    /// - Throws: The existing typed compiler/configuration/resource/cancellation failures.
    public func compile(limits: JSONTransformLimits = .init()) throws -> JSONOperationReport<JSONTransformProgram> {
        do {
            var context = try TransformRuntimeContext(limits: limits.runtime)
            var names: Set<String> = []
            for name in variableNames {
                // Admit hashing/scan work before constructing an owned Set entry.
                for _ in name.utf8 { try context.work() }
                try context.meter.retain(32)
                names.insert(name)
                try context.checkpoint()
            }
            let result = try JSONTransformProgram.compileValidated(source, variables: names, context: &context)
            return .init(result: result, statistics: context.meter.statistics())
        } catch { throw JSONTransformFailure.classify(error) }
    }

    private static func require(_ attempted: UInt64, _ limit: UInt64, _ metric: String,
                                meter: inout JSONWorkMeter) throws {
        try meter.checkpoint()
        guard attempted <= limit else {
            throw JSONTransformDefinitionFailure.limitExceeded(metric: metric, limit: limit, attempted: attempted)
        }
    }
    private static func scanned(_ text: String, maximum: UInt64, metric: String,
                                meter: inout JSONWorkMeter) throws -> UInt64 {
        var count: UInt64 = 0
        for _ in text.utf8 {
            try meter.work(); count = try meter.adding(.aggregateTextBytes, count, 1)
            try require(count, maximum, metric, meter: &meter)
        }
        return count
    }
    private static func make(source: String, variables: [String], limits: JSONTransformDefinitionLimits,
                             meter: inout JSONWorkMeter) throws -> Self {
        try meter.retain(64)
        _ = try scanned(source, maximum: limits.maximumSourceBytes, metric: "sourceBytes", meter: &meter)
        try JSONAdmission.text(source, meter: &meter, owned: true)
        try require(UInt64(variables.count), limits.maximumVariableNames, "variableNames", meter: &meter)
        var names: [String] = [], total: UInt64 = 0
        try meter.retain(32)
        for name in variables {
            let size = try scanned(name, maximum: limits.maximumNameBytes, metric: "nameBytes", meter: &meter)
            total = try meter.adding(.aggregateTextBytes, total, size)
            try require(total, limits.maximumTotalNameBytes, "totalNameBytes", meter: &meter)
            var first = true
            for byte in name.utf8 {
                try meter.work()
                let letter = byte == 95 || (65...90).contains(byte) || (97...122).contains(byte)
                guard letter || (!first && (48...57).contains(byte)) else { throw JSONTransformDefinitionFailure.invalidVariableName }
                first = false
            }
            guard !first else { throw JSONTransformDefinitionFailure.invalidVariableName }
            try JSONAdmission.text(name, key: true, meter: &meter, owned: true)
            try meter.retain(16); names.append(name)
        }
        var scratch: [String] = []
        for name in names { try meter.work(); try meter.retain(16); scratch.append(name) }
        var width = 1
        while width < names.count {
            var start = 0
            while start < names.count {
                let middle = start + min(width, names.count - start)
                let end = middle + min(width, names.count - middle)
                var a = start, b = middle
                for target in start..<end {
                    try meter.work()
                    if try b == end || (a < middle && !less(names[b], names[a], meter: &meter)) {
                        scratch[target] = names[a]; a += 1
                    } else { scratch[target] = names[b]; b += 1 }
                }
                start = end
            }
            swap(&names, &scratch)
            if width > names.count / 2 { break }; width *= 2
        }
        if names.count > 1 {
            for index in 1..<names.count {
                if try JSONComparison.textEquals(names[index-1], names[index], meter: &meter) {
                    throw JSONTransformDefinitionFailure.duplicateVariableName
                }
            }
        }
        scratch = []; try meter.release(UInt64(names.count) * 16)
        return .init(validatedSource: source, canonicalNames: names)
    }
    private static func less(_ lhs: String, _ rhs: String, meter: inout JSONWorkMeter) throws -> Bool {
        var a = lhs.utf8.makeIterator(), b = rhs.utf8.makeIterator()
        while true {
            try meter.work(); let x = a.next(), y = b.next()
            if x != y { if let x, let y { return x < y }; return x == nil }
            if x == nil { return false }
        }
    }
}
