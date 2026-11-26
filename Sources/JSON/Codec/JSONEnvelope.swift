// SPDX-License-Identifier: Apache-2.0
// Original versioned, digest-checked envelope over RFC 8785 canonical JSON.
import Foundation

/// A versioned, self-checking record of one JSON payload, written as RFC 8785 canonical JSON.
///
/// An envelope names what its payload is (``type``) and which schema version of
/// that type it follows (``version``), so a store can migrate old records. Its
/// wire form is one canonical object with six members:
///
/// ```json
/// {"digest":"sha256:…","format":"swift-json-envelope","formatVersion":1,"payload":{…},"type":"mcp.task","version":3}
/// ```
///
/// `digest` is the SHA-256 of the payload's canonical bytes. Decoding recomputes
/// it, so a damaged payload is detected, and equal payloads always have equal
/// digests, so the digest can serve as a content address. Because the whole
/// envelope is canonical, equal envelopes encode to equal bytes.
///
/// Format version 1 is fixed: the member names, the marker and the digest
/// algorithm do not change. A later format would use a new `formatVersion`.
public struct JSONEnvelope: Sendable, Equatable {
    /// The format marker, `swift-json-envelope`.
    public static let format = "swift-json-envelope"
    /// The format version this type reads and writes, `1`.
    public static let formatVersion = 1
    /// The largest accepted ``type`` length in UTF-8 bytes.
    public static let maximumTypeBytes = 256
    /// The accepted ``version`` range: 1 through 2^53 − 1, independent of platform word size.
    public static let versions: ClosedRange<Int64> = 1...9_007_199_254_740_991

    /// The caller's name for the kind of payload, such as `mcp.task`.
    public let type: String
    /// The schema version of ``type`` that the payload follows, stored as a platform-independent integer.
    public let version: Int64
    /// The enveloped value.
    public let payload: JSON

    /// Creates an envelope after checking its type and version.
    ///
    /// - Throws: ``JSONEnvelopeFailure/invalidType`` for an empty type or one longer
    ///   than ``maximumTypeBytes``; ``JSONEnvelopeFailure/invalidVersion`` for a version
    ///   outside ``versions``.
    ///
    /// - Parameters:
    ///   - type: A non-empty name for the kind of payload, at most 256 UTF-8 bytes.
    ///   - version: The payload's schema version, from 1 through 2^53 − 1.
    ///   - payload: The value to envelope.
    public init(type: String, version: Int64, payload: JSON) throws {
        guard !type.isEmpty, type.utf8.count <= Self.maximumTypeBytes else { throw JSONEnvelopeFailure.invalidType }
        guard Self.versions.contains(version) else { throw JSONEnvelopeFailure.invalidVersion }
        self.type = type; self.version = version; self.payload = payload
    }

    /// Writes the envelope's canonical bytes and returns them with the payload digest.
    ///
    /// - Returns: The canonical envelope bytes and the `sha256:` digest of the payload.
    /// - Throws: Inexact conversion for a number the policy refuses, resource failure or cancellation.
    ///
    /// - Parameters:
    ///   - options: Limits and the canonical number policy.
    public func encode(options: JSONEnvelopeOptions = .init()) throws -> JSONEnvelopeEncoding {
        try encodeWithReport(options: options).result
    }
    /// Writes the envelope with one cumulative work ledger.
    ///
    /// - Returns: The encoding and the ledger's charged counts.
    /// - Throws: Inexact conversion for a number the policy refuses, resource failure or cancellation.
    ///
    /// - Parameters:
    ///   - options: Limits and the canonical number policy.
    public func encodeWithReport(options: JSONEnvelopeOptions = .init()) throws -> JSONOperationReport<JSONEnvelopeEncoding> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .writing)
        let writer = JSONCanonicalWriter(limits: options.limits, numberPolicy: options.numberPolicy)
        let payloadBytes = try writer.write(payload, meter: &meter)
        let digest = try Self.digest(of: payloadBytes, meter: &meter)
        try meter.resetValueBounds(); let typeBytes = try writer.write(.string(type), meter: &meter)
        try meter.resetValueBounds(); let versionBytes = try writer.write(.number(JSONNumber(integer: version)), meter: &meter)
        // Members in RFC 8785 order; every name is ASCII, so UTF-16 order is byte order.
        var bytes: [UInt8] = []
        func append<C: Collection>(_ part: C, meter: inout JSONWorkMeter) throws where C.Element == UInt8 {
            for byte in part { try meter.work(); try meter.retain(1); bytes.append(byte) }
        }
        func literal(_ text: String, meter: inout JSONWorkMeter) throws {
            try meter.charge(.outputBytes, UInt64(text.utf8.count)); try append(text.utf8, meter: &meter)
        }
        try literal("{\"digest\":\"\(digest)\",\"format\":\"\(Self.format)\",\"formatVersion\":\(Self.formatVersion),\"payload\":", meter: &meter)
        try append(payloadBytes, meter: &meter)
        try literal(",\"type\":", meter: &meter); try append(typeBytes, meter: &meter)
        try literal(",\"version\":", meter: &meter); try append(versionBytes, meter: &meter)
        try literal("}", meter: &meter)
        try meter.checkpoint()
        return .init(result: .init(data: Data(bytes), digest: digest), statistics: meter.statistics())
    }

    /// Reads an envelope and verifies its format, fields and payload digest.
    ///
    /// The input may be any strict JSON spelling of the envelope object; canonical
    /// bytes are not required. Use the same number policy that encoded it.
    ///
    /// - Returns: The checked envelope.
    /// - Throws: ``JSONEnvelopeFailure`` for a well-formed JSON value that is not a
    ///   valid version 1 envelope or whose digest does not match; `JSONFailure` for
    ///   syntax, a refused number, resource failure; or cancellation.
    ///
    /// - Parameters:
    ///   - data: The envelope bytes.
    ///   - options: Limits and the canonical number policy used for the digest.
    public static func decode(_ data: Data, options: JSONEnvelopeOptions = .init()) throws -> JSONEnvelope {
        try decodeWithReport(data, options: options).result
    }
    /// Reads and verifies an envelope with one cumulative work ledger.
    ///
    /// See ``decode(_:options:)``.
    ///
    /// - Returns: The checked envelope and the ledger's charged counts.
    /// - Throws: ``JSONEnvelopeFailure``, `JSONFailure` or cancellation, as for ``decode(_:options:)``.
    ///
    /// - Parameters:
    ///   - data: The envelope bytes.
    ///   - options: Limits and the canonical number policy used for the digest.
    public static func decodeWithReport(_ data: Data, options: JSONEnvelopeOptions = .init()) throws -> JSONOperationReport<JSONEnvelope> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .core)
        try meter.require(.inputBytes, UInt64(data.count))
        var input: [UInt8] = []
        for byte in data { try meter.work(); try meter.retain(1); input.append(byte) }
        let root = try JSONParser().parse(input, meter: &meter)
        try meter.release(UInt64(input.count)); input = []

        guard case .object(let object) = root, object.count == 6 else { throw JSONEnvelopeFailure.invalidFormat }
        func member(_ name: String, meter: inout JSONWorkMeter) throws -> JSON {
            guard let value = try object.lookup(name, meter: &meter) else { throw JSONEnvelopeFailure.invalidFormat }
            return value
        }
        guard case .string(format) = try member("format", meter: &meter) else { throw JSONEnvelopeFailure.invalidFormat }
        guard case .number(let formatVersion) = try member("formatVersion", meter: &meter) else { throw JSONEnvelopeFailure.invalidFormat }
        guard try integer(formatVersion, meter: &meter) == Int64(Self.formatVersion) else {
            throw JSONEnvelopeFailure.unsupportedFormatVersion
        }
        guard case .string(let type) = try member("type", meter: &meter) else { throw JSONEnvelopeFailure.invalidType }
        guard case .number(let versionNumber) = try member("version", meter: &meter),
              let version = try integer(versionNumber, meter: &meter) else { throw JSONEnvelopeFailure.invalidVersion }
        guard case .string(let digest) = try member("digest", meter: &meter), isDigest(digest) else { throw JSONEnvelopeFailure.invalidDigest }
        let payload = try member("payload", meter: &meter)
        let envelope = try JSONEnvelope(type: type, version: version, payload: payload)

        try meter.resetValueBounds()
        let writer = JSONCanonicalWriter(limits: options.limits, numberPolicy: options.numberPolicy)
        let payloadBytes = try writer.write(payload, meter: &meter)
        guard try Self.digest(of: payloadBytes, meter: &meter) == digest else { throw JSONEnvelopeFailure.digestMismatch }
        try meter.checkpoint()
        return .init(result: envelope, statistics: meter.statistics())
    }

    /// The exact integer value, or nil when it does not fit `Int64`.
    private static func integer(_ number: JSONNumber, meter: inout JSONWorkMeter) throws -> Int64? {
        do { return try number.integer(as: Int64.self, meter: &meter) }
        catch let failure as JSONFailure where failure.category == .conversion { return nil }
    }
    private static func digest(of bytes: [UInt8], meter: inout JSONWorkMeter) throws -> String {
        "sha256:" + (try JSONSHA256Core.hexadecimal(bytes, accounting: &meter))
    }
    private static func isDigest(_ text: String) -> Bool {
        let bytes = Array(text.utf8)
        guard bytes.count == 71, bytes.starts(with: Array("sha256:".utf8)) else { return false }
        return bytes.dropFirst(7).allSatisfy { (0x30...0x39).contains($0) || (0x61...0x66).contains($0) }
    }
}

/// Limits and the number policy for encoding and decoding a ``JSONEnvelope``.
public struct JSONEnvelopeOptions: Sendable {
    /// Finite capacities and work quotas applied to each call.
    public var limits: JSONLimits
    /// The canonical number policy for the payload; decoding must use the policy that encoded it.
    public var numberPolicy: JSONCanonicalWriter.NumberPolicy
    /// Creates the configuration; finite limits are checked when an operation begins.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas for each call.
    ///   - numberPolicy: Refuse (the default) or round numbers that binary64 cannot represent exactly.
    public init(limits: JSONLimits = .balanced, numberPolicy: JSONCanonicalWriter.NumberPolicy = .preserving) {
        self.limits = limits; self.numberPolicy = numberPolicy
    }
}

/// The canonical bytes of a ``JSONEnvelope`` and the digest of its payload.
public struct JSONEnvelopeEncoding: Sendable, Equatable {
    /// The canonical envelope bytes.
    public let data: Data
    /// The payload digest, `sha256:` followed by 64 lowercase hexadecimal digits.
    public let digest: String
}

/// Why a well-formed JSON value is not a valid version 1 ``JSONEnvelope``.
///
/// Syntax, resource and number-conversion failures are reported as `JSONFailure`.
/// No case carries input text.
public enum JSONEnvelopeFailure: Error, Sendable, Equatable {
    /// The root is not an object with exactly the six envelope members, or the format marker is wrong.
    case invalidFormat
    /// The format version is not 1.
    case unsupportedFormatVersion
    /// The type is not a non-empty string of at most 256 UTF-8 bytes.
    case invalidType
    /// The version is not an integer from 1 through 2^53 − 1.
    case invalidVersion
    /// The digest is not `sha256:` followed by 64 lowercase hexadecimal digits.
    case invalidDigest
    /// The payload's canonical digest differs from the recorded digest.
    case digestMismatch
}
