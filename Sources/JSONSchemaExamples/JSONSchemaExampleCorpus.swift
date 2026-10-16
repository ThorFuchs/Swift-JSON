// SPDX-License-Identifier: Apache-2.0
import JSON

/// Immutable ordered synthetic candidates, admitted when a generator is prepared.
///
/// Tokens never override schema semantics. The demonstration profile uses them
/// for true/empty schemas and conservative string proposals. Corpus order and
/// exact admitted contents contribute to deterministic identity. Preparation
/// checks all tokens with its finite policy; storing the corpus alone is unmetered.
public struct JSONSchemaExampleCorpus: Sendable {
    /// Exact ordered values; order contributes to corpus identity and seeded choices.
    public let values: [JSON]
    /// Stores caller-authored values without admission or implicit numeric conversion.
    /// - Parameter values: A nonempty corpus checked under preparation limits later.
    public init(values: [JSON]) { self.values = values }
    /// Version 1 synthetic corpus: null, false, zero, "example", empty array and empty object.
    /// Materializes values for the caller's lifetime instead of retaining JSON payloads globally.
    /// As with caller-authored corpora, preparation performs the checked admission later.
    public static var synthetic: Self {
        Self(values: [.null, .boolean(false), 0, .string("example"), .array([]), .object(.init(empty: ()))])
    }
}
