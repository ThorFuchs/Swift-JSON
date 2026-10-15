// SPDX-License-Identifier: Apache-2.0
import JSON

public extension BinaryInteger {
    /// Constructs the exact decimal value of a trusted Swift integer.
    ///
    /// Delegates to `JSONNumber.init(integer:)` without an operation meter.
    /// Conversion work and storage grow with the decimal digit count; arbitrary
    /// user-defined integers are trusted input, not bounded untrusted admission.
    /// - Returns: An exact integer with no original JSON token spelling.
    func jsonNumber() -> JSONNumber { JSONNumber(integer: self) }
}

public extension FixedWidthInteger {
    /// Projects an exact decimal into this integer type with checked range and sign.
    ///
    /// Delegates once to `JSONNumber.integer(as:limits:)`; fractions and overflow
    /// throw instead of truncating, defaulting or wrapping.
    /// - Parameters:
    ///   - jsonNumber: The mathematical decimal to project.
    ///   - limits: Finite conversion limits forwarded unchanged.
    /// - Throws: Inexact conversion, resource or configuration failure, or cancellation.
    init(jsonNumber: JSONNumber, limits: JSONLimits = .balanced) throws {
        self = try jsonNumber.integer(as: Self.self, limits: limits)
    }
}
