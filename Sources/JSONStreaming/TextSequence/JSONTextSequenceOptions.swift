// SPDX-License-Identifier: Apache-2.0
import JSON
/// Finite limits and the malformed-text policy for RFC 7464 JSON text sequences.
public struct JSONTextSequenceOptions: Sendable {
    /// What a reader does with a text that is not one complete JSON value.
    public enum MalformedTexts: Sendable, Equatable {
        /// Throw the syntax failure and end the sequence (the default).
        case fail
        /// Skip the text and continue with the next record separator, as RFC 7464
        /// recommends. Resource failures, cancellation and source errors still end
        /// the sequence. The iterator counts skipped texts.
        case skip
    }
    /// Finite capacities and work quotas applied to library-owned operations.
    public var limits: JSONLimits
    /// The policy for texts that fail to parse or are possibly truncated.
    public var malformedTexts: MalformedTexts
    /// Creates the configuration; finite limits are checked at operation entry.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas, per text and for the iterator lifetime.
    ///   - malformedTexts: Whether malformed texts end the sequence or are skipped.
    public init(limits: JSONLimits = .balanced, malformedTexts: MalformedTexts = .fail) {
        self.limits = limits; self.malformedTexts = malformedTexts
    }
}
