// SPDX-License-Identifier: Apache-2.0
import JSON
/// A Patch document state that distinguishes root removal from JSON null.
public enum JSONPatchResult: Sendable, Equatable {
    /// A present root, including JSON null.
    case document(JSON)
    /// No root document exists; this differs from a document containing JSON null.
    case removed
}
