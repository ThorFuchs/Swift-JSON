// SPDX-License-Identifier: Apache-2.0
import JSON
public enum JSONPatchOperation: Sendable, Equatable {
    case add(path: JSONPointer, value: JSON), remove(path: JSONPointer), replace(path: JSONPointer, value: JSON)
    case move(from: JSONPointer, path: JSONPointer), copy(from: JSONPointer, path: JSONPointer), test(path: JSONPointer, value: JSON)
    public var path: JSONPointer {
        switch self {
        case .add(let p, _), .remove(let p), .replace(let p, _), .move(_, let p), .copy(_, let p), .test(let p, _): return p
        }
    }
}
