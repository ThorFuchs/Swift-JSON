// SPDX-License-Identifier: Apache-2.0
import JSON
/// One RFC 6902 operation using exact values and strict JSON Pointers.
public enum JSONPatchOperation: Sendable, Equatable {
    /// Insert or replace at the path; a final array - appends and an empty path adds the root.
    case add(path: JSONPointer, value: JSON)
    /// Remove an existing target; removing the root produces a removed document state.
    case remove(path: JSONPointer)
    /// Replace an existing target; an absent target fails.
    case replace(path: JSONPointer, value: JSON)
    /// Remove the source before resolving the destination; moving into a descendant fails.
    case move(from: JSONPointer, path: JSONPointer)
    /// Copy an existing source to the destination with charged payload and editing work.
    case copy(from: JSONPointer, path: JSONPointer)
    /// Require exact scalar/decimal, order-independent object equality; mismatch fails the patch.
    case test(path: JSONPointer, value: JSON)
    /// The destination or tested/removed path for this operation.
    public var path: JSONPointer {
        switch self {
        case .add(let p, _), .remove(let p), .replace(let p, _), .move(_, let p), .copy(_, let p), .test(let p, _): return p
        }
    }
}
