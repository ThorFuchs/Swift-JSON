// SPDX-License-Identifier: Apache-2.0
import JSON

public extension Double {
    /// Adopts the exact decimal meaning of this finite value's Swift round-trip text.
    ///
    /// Delegates once to `JSONNumber.fromFiniteDouble(_:limits:)`. For binary64
    /// 0.1 this produces decimal 0.1, which differs from the exact binary rational.
    /// Negative zero has JSON's single mathematical zero identity. This method
    /// does not recover an earlier token or promise bit-pattern preservation.
    /// - Parameter limits: Finite decimal admission limits forwarded unchanged.
    /// - Returns: The admitted decimal rendering of this finite Double.
    /// - Throws: NaN/infinity rejection, resource or configuration failure, or cancellation.
    func jsonNumberFromRoundTripText(limits: JSONLimits = .balanced) throws -> JSONNumber {
        try JSONNumber.fromFiniteDouble(self, limits: limits)
    }

    /// Projects an exact decimal into finite binary64 with an explicit fidelity policy.
    ///
    /// Delegates once to `JSONNumber.doubleValue(policy:limits:)`. The default
    /// exact policy rejects decimal 0.1; rounded conversion requires caller opt-in.
    /// - Parameters:
    ///   - jsonNumber: The exact decimal value to project.
    ///   - policy: Require mathematical equality or allow finite rounding.
    ///   - limits: Finite conversion limits forwarded unchanged.
    /// - Throws: Inexact/overflowing conversion, resource or configuration failure, or cancellation.
    init(jsonNumber: JSONNumber, policy: JSONNumberConversionPolicy = .exact, limits: JSONLimits = .balanced) throws {
        self = try jsonNumber.doubleValue(policy: policy, limits: limits)
    }
}
