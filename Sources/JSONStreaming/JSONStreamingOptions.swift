// SPDX-License-Identifier: Apache-2.0
import JSON
/// Finite iterator-lifetime limits and strict value framing.
public struct JSONStreamingOptions: Sendable {
    /// Finite capacities and work quotas applied to library-owned operations.
    public var limits: JSONLimits
    /// The strict boundary policy; the root-array reader always uses one array document.
    public var framing: JSONFraming
    /// Creates the value configuration; finite limits are checked at operation entry.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    ///   - framing: Strict single-document or whitespace-separated value framing.
    public init(limits: JSONLimits = .balanced, framing: JSONFraming = .singleDocument) {
        self.limits = limits; self.framing = framing
    }
}
