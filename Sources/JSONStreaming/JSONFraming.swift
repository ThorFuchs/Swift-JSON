// SPDX-License-Identifier: Apache-2.0
/// Strict boundaries for one document or whitespace-separated values.
public enum JSONFraming: Sendable {
    /// Require one complete root followed by whitespace and EOF.
    case singleDocument
    /// Require actual whitespace between roots; adjacent JSON values fail.
    case whitespaceSeparatedValues
}
