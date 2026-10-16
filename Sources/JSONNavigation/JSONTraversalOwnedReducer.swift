// SPDX-License-Identifier: Apache-2.0
import JSON

/// Experimental package-only strategy. The executor owns the one original scope.
/// Reducers remain Copyable; their ordinary data cannot own a noncopyable capability.
/// No reference to the native scope or meter is available through this interface.
package protocol JSONTraversalOwnedReducer {
    associatedtype Result
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> Result
}
