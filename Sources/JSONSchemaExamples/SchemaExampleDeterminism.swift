// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

enum SchemaExampleVersion {
    static let generator = "s3-candidates-v4"
    static let rng = "splitmix64-v1"
    static let snapshot = "swift-json-schema-snapshot-v1"
    static let corpus = "swift-json-example-corpus-v1"
    static let policy = "swift-json-example-policy-v1"
    static let trace = "swift-json-example-trace-v2"
    static let referencePushOrder: [JSONSchemaPlan.Keyword] = [.ref, .dynamicRef]
    static let keywords: [(String, JSONSchemaPlan.Keyword)] = [("const", .const), ("default", .default), ("enum", .enum), ("examples", .examples)]
}

// No Sendable conformance: mutable state belongs to one synchronous invocation.
struct SchemaExampleRandom: ~Copyable {
    private var state: UInt64
    private(set) var draws: UInt64 = 0
    init(seed: UInt64) { state = seed }

    mutating func next(meter: inout JSONWorkMeter) throws -> UInt64 {
        for _ in 0..<10 { try meter.work() }
        draws = try meter.adding(.workUnits, draws, 1)
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    mutating func uniform(upperBound: UInt64, trace: inout SchemaExampleTrace,
                          meter: inout JSONWorkMeter) throws -> UInt64 {
        try meter.checkpoint()
        guard upperBound > 0 else {
            let failure = JSONFailure(.configuration, code: .invalidOperation)
            meter.recordFailure(failure); throw failure
        }
        for _ in 0..<3 { try meter.work() }
        let threshold = (UInt64(0) &- upperBound) % upperBound
        while true {
            let candidate = try next(meter: &meter)
            try trace.event(3, candidate, upperBound, meter: &meter)
            for _ in 0..<2 { try meter.work() }
            if candidate >= threshold { return candidate % upperBound }
        }
    }
}

// A finite transport buffer; trace bytes share the native diagnostic byte quota.
struct SchemaExampleTransport: ~Copyable {
    private(set) var bytes: [UInt8] = []
    let isTrace: Bool
    init(header: String, isTrace: Bool = false, meter: inout JSONWorkMeter) throws {
        self.isTrace = isTrace
        for byte in header.utf8 { try append(byte, meter: &meter) }
    }
    mutating func append(_ byte: UInt8, meter: inout JSONWorkMeter) throws {
        try meter.work()
        try meter.require(.inputBytes, UInt64(bytes.count) + 1)
        if isTrace { try meter.charge(.diagnosticBytes) }
        try meter.retain(1); bytes.append(byte)
    }
    mutating func integer(_ value: UInt64, meter: inout JSONWorkMeter) throws {
        for shift in stride(from: 56, through: 0, by: -8) {
            try append(UInt8(truncatingIfNeeded: value >> shift), meter: &meter)
        }
    }
    mutating func field<C: Collection>(_ value: C, meter: inout JSONWorkMeter) throws where C.Element == UInt8 {
        var length: UInt64 = 0
        for _ in value { try meter.work(); length = try meter.adding(.inputBytes, length, 1) }
        try integer(length, meter: &meter)
        for byte in value { try append(byte, meter: &meter) }
    }
    mutating func digest(meter: inout JSONWorkMeter) throws -> String {
        let hash = try JSONSHA256Core.hexadecimal(bytes, accounting: &meter)
        try meter.release(UInt64(bytes.count))
        bytes = []
        return hash
    }
}

struct SchemaExampleTrace: ~Copyable {
    private var transport: SchemaExampleTransport
    private(set) var events: UInt64 = 0
    private var finished = false
    var retainedByteCount: UInt64 { UInt64(transport.bytes.count) }
    init(snapshot: String, corpus: String, policy: String, seed: UInt64,
         profile: JSONSchemaExampleProfile, meter: inout JSONWorkMeter) throws {
        var transport = try SchemaExampleTransport(header: "SwiftJSON-example-trace-v2\n", isTrace: true, meter: &meter)
        try meter.retain(JSONLogicalWeights.arraySlot * 4)
        for text in [SchemaExampleVersion.generator, snapshot, corpus, policy] {
            try transport.field(text.utf8, meter: &meter)
        }
        try meter.release(JSONLogicalWeights.arraySlot * 4)
        try transport.integer(seed, meter: &meter)
        try transport.append(profile == .minimal ? 0 : 1, meter: &meter)
        self.transport = consume transport
    }
    mutating func event(_ code: UInt8, _ a: UInt64, _ b: UInt64, meter: inout JSONWorkMeter) throws {
        guard !finished else {
            let failure = JSONFailure(.configuration, code: .invalidOperation)
            meter.recordFailure(failure); throw failure
        }
        try transport.append(code, meter: &meter)
        try transport.integer(a, meter: &meter); try transport.integer(b, meter: &meter)
        events = try meter.adding(.workUnits, events, 1)
    }
    mutating func digest(meter: inout JSONWorkMeter) throws -> String {
        guard !finished else {
            let failure = JSONFailure(.configuration, code: .invalidOperation)
            meter.recordFailure(failure); throw failure
        }
        finished = true
        // The transport owns exactly its bytes. There is no array-slot
        // reservation here to refund; SHA-256 retains its 64-byte hex result.
        return try transport.digest(meter: &meter)
    }
}

enum SchemaExampleExact {
    static func bytes(_ value: JSON, meter: inout JSONWorkMeter) throws -> [UInt8] {
        try meter.resetValueBounds()
        return try JSONWriter(options: .init(keyOrder: .scalar, numberStyle: .normalized)).write(value, meter: &meter)
    }
    static func construct(_ value: JSON, meter: inout JSONWorkMeter) throws -> JSON {
        let encoded = try bytes(value, meter: &meter)
        try meter.resetValueBounds()
        let normalized = try JSONParser().parse(encoded, meter: &meter)
        try meter.release(UInt64(encoded.count))
        return normalized
    }
}

enum SchemaExampleDigests {
    static func snapshot(document: JSONSchemaDocument, registry: JSONSchemaRegistry,
                         meter: inout JSONWorkMeter) throws -> String {
        var transport = try SchemaExampleTransport(header: "SwiftJSON-schema-snapshot-v1\n", meter: &meter)
        let count = try meter.adding(.schemaDocuments, UInt64(registry.documents.count), 1)
        try transport.integer(count, meter: &meter)
        for index in 0..<Int(count) {
            try meter.work()
            let entry = index == 0 ? document : registry.documents[index - 1]
            try transport.append(entry.retrievalURI == nil ? 0 : 1, meter: &meter)
            try transport.field((entry.retrievalURI?.string ?? "").utf8, meter: &meter)
            let encoded = try SchemaExampleExact.bytes(entry.raw, meter: &meter)
            try transport.field(encoded, meter: &meter)
            try meter.release(UInt64(encoded.count))
        }
        return try transport.digest(meter: &meter)
    }
    static func corpus(_ values: [JSON], meter: inout JSONWorkMeter) throws -> String {
        var transport = try SchemaExampleTransport(header: "SwiftJSON-example-corpus-v1\n", meter: &meter)
        let encoded = try SchemaExampleExact.bytes(.array(values), meter: &meter)
        try transport.field(encoded, meter: &meter); try meter.release(UInt64(encoded.count))
        return try transport.digest(meter: &meter)
    }
    static func policy(_ options: JSONSchemaExampleOptions, meter: inout JSONWorkMeter) throws -> String {
        var transport = try SchemaExampleTransport(header: "SwiftJSON-example-policy-v1\n", meter: &meter)
        try transport.integer(options.maximumAttempts, meter: &meter)
        try meter.retain(JSONLogicalWeights.arraySlot * 3)
        for limits in [options.limits, options.compilationOptions.limits, options.validationOptions.limits] {
            try transport.integer(UInt64(JSONResourceMetric.allCases.count), meter: &meter)
            for metric in JSONResourceMetric.allCases {
                try transport.field(metric.rawValue.utf8, meter: &meter)
                try transport.integer(limits[metric], meter: &meter)
            }
        }
        try meter.release(JSONLogicalWeights.arraySlot * 3)
        try meter.retain(JSONLogicalWeights.arraySlot * 2)
        for policy in [options.compilationOptions, options.validationOptions] {
            try transport.append(policy.formatAssertion ? 1 : 0, meter: &meter)
            try transport.append(policy.output == .flag ? 0 : 1, meter: &meter)
            try transport.append(policy.diagnosticPolicy == .complete ? 0 : 1, meter: &meter)
            try transport.append(policy.collectAnnotations ? 1 : 0, meter: &meter)
        }
        try meter.release(JSONLogicalWeights.arraySlot * 2)
        return try transport.digest(meter: &meter)
    }
}

// Swift infers Sendable for internal value types with Sendable storage. Explicit
// unavailable conformances opt invocation-only mutable helpers out, with compiler
// rejection fixtures; immutable preparation remains checked Sendable.
@available(*, unavailable)
extension SchemaExampleRandom: Sendable {}
@available(*, unavailable)
extension SchemaExampleTrace: Sendable {}
@available(*, unavailable)
extension SchemaExampleTransport: Sendable {}
