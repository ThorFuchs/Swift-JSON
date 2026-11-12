// SPDX-License-Identifier: Apache-2.0
// Original implementation of RFC 8785, JSON Canonicalization Scheme (JCS).
import Foundation

/// A writer for RFC 8785 canonical JSON, the JSON Canonicalization Scheme (JCS).
///
/// The output is compact UTF-8 with object members ordered by the UTF-16 code
/// units of their keys, strings using the short escapes `\b`, `\t`, `\n`, `\f`,
/// `\r`, `\"` and `\\` (and `\u00xx` for other control characters), and numbers
/// spelled as ECMAScript formats binary64 values. Equal values produce equal
/// bytes, so the result can be hashed, signed or used as a content address.
///
/// RFC 8785 treats every number as an IEEE 754 binary64 value. A ``JSONNumber``
/// is an exact decimal, so the ``NumberPolicy`` decides what happens when the
/// binary64 spelling would denote a different value. The default,
/// ``NumberPolicy/preserving``, refuses such a number instead of changing it.
///
/// This type produces bytes only. It performs no hashing or signing, and its key
/// order differs from ``JSONWritingOptions/KeyOrder/scalar`` for keys that mix
/// supplementary-plane characters with characters from U+E000 through U+FFFF.
public struct JSONCanonicalWriter: Sendable {
    /// How a number that binary64 cannot represent exactly is handled.
    public enum NumberPolicy: Sendable {
        /// Refuse a number whose canonical binary64 spelling would denote a
        /// different exact decimal, with an inexact-conversion failure.
        ///
        /// A short decimal such as `0.1` is accepted, because its canonical
        /// spelling `0.1` denotes the same exact value. `9007199254740993` and
        /// `0.10000000000000001` are refused.
        case preserving
        /// Round to the nearest binary64 value before formatting, as RFC 8785
        /// does for I-JSON input. Different exact decimals can then produce the
        /// same bytes. Values outside the finite binary64 range still fail.
        case rounding
    }
    /// Finite capacities and work quotas applied to each call.
    public let limits: JSONLimits
    /// The treatment of numbers that binary64 cannot represent exactly.
    public let numberPolicy: NumberPolicy
    /// Creates an immutable canonical writer. Limits are checked when writing begins.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas for each call.
    ///   - numberPolicy: Refuse (the default) or round numbers that binary64 cannot represent exactly.
    public init(limits: JSONLimits = .balanced, numberPolicy: NumberPolicy = .preserving) {
        self.limits = limits; self.numberPolicy = numberPolicy
    }
    /// Writes the RFC 8785 canonical bytes of a complete value.
    ///
    /// - Returns: Owned canonical UTF-8 bytes.
    /// - Throws: Inexact conversion for a number the policy refuses or for a value
    ///   outside the finite binary64 range; resource failure or cancellation.
    ///
    /// - Parameters:
    ///   - value: The exact root to admit and canonicalize.
    public func write(_ value: JSON) throws -> Data { try writeWithReport(value).result }
    /// Writes RFC 8785 canonical bytes with successful operation accounting.
    ///
    /// - Returns: Owned canonical bytes and counts; output bytes are charged before growth.
    /// - Throws: Inexact conversion for a number the policy refuses or for a value
    ///   outside the finite binary64 range; resource failure or cancellation.
    ///
    /// - Parameters:
    ///   - value: The exact root to admit and canonicalize.
    public func writeWithReport(_ value: JSON) throws -> JSONOperationReport<Data> {
        var meter = try JSONWorkMeter(limits: limits, domain: .writing)
        let bytes = try write(value, meter: &meter)
        for _ in bytes { try meter.work(); try meter.retain(1) }
        return .init(result: Data(bytes), statistics: meter.statistics())
    }
    package func write(_ value: JSON, meter: inout JSONWorkMeter) throws -> [UInt8] {
        try JSONAdmission.value(value, meter: &meter)
        var cursor = JSONWritingCursor(value: value, limits: limits, canonical: numberPolicy)
        var bytes: [UInt8] = []
        while let byte = try cursor.next(meter: &meter) {
            try meter.charge(.outputBytes); try meter.retain(1); bytes.append(byte)
        }
        return bytes
    }
}
