// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

public extension Decimal {
    /// Projects an exact JSON decimal into Foundation's finite-precision Decimal.
    ///
    /// Delegates once to `JSONNumber.decimalValue(policy:limits:)`. Exact policy
    /// verifies mathematical equality; rounded policy still enforces target range
    /// and precision admission. No reverse Decimal-to-JSON conversion is implied.
    /// - Parameters:
    ///   - jsonNumber: The exact decimal value to project.
    ///   - policy: Require equality or allow the delegate's finite rounding policy.
    ///   - limits: Finite conversion limits forwarded unchanged.
    /// - Throws: Precision/range failure, resource or configuration failure, or cancellation.
    init(jsonNumber: JSONNumber, policy: JSONNumberConversionPolicy = .exact, limits: JSONLimits = .balanced) throws {
        self = try jsonNumber.decimalValue(policy: policy, limits: limits)
    }
}
