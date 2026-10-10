// SPDX-License-Identifier: Apache-2.0
/// Resource and presentation choices for strict JSON output.
public struct JSONWritingOptions: Sendable {
    /// The member order chosen for output.
    public enum KeyOrder: Sendable {
        /// Preserve member insertion order.
        case insertion
        /// Sort by exact decoded Unicode scalar key order; no signature canonicalization is implied.
        case scalar
    }
    /// Finite capacities and work quotas applied to library-owned operations.
    public var limits: JSONLimits
    /// Spaces per nesting level, from 0 through 8; nil selects compact output.
    public var indentation: Int?
    /// Insertion order or ascending decoded-scalar key order.
    public var keyOrder: KeyOrder
    /// Normalized decimal spelling or original lexemes when available.
    public var numberStyle: JSONNumberTextStyle
    /// Creates the value configuration; finite limits are checked at operation entry.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    ///   - indentation: Spaces per level, 0...8, or nil for compact output.
    ///   - keyOrder: Insertion or scalar key order.
    ///   - numberStyle: Normalized or preserved numeric spelling.
    public init(limits: JSONLimits = .balanced, indentation: Int? = nil,
                keyOrder: KeyOrder = .insertion, numberStyle: JSONNumberTextStyle = .normalized) {
        self.limits = limits; self.indentation = indentation; self.keyOrder = keyOrder; self.numberStyle = numberStyle
    }
}
