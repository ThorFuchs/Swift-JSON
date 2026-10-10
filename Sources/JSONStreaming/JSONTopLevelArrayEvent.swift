// SPDX-License-Identifier: Apache-2.0
import JSON
/// A provisional root-array element or certified document completion.
public enum JSONTopLevelArrayEvent: Sendable {
    /// A zero-based indexed element; the enclosing array document remains provisional.
    case element(index: UInt64, value: JSON)
    /// The outer array, trailing whitespace and EOF have been certified.
    case documentCompleted(JSONStreamSummary)
}
