// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Explicit physical arrays and direct string fields for a source-bound directed simple graph.
///
/// Paths use exact typed components; roles are never guessed. Explicit field reuse is valid.
public struct JSONGraphProfile: Sendable {
    /// Absolute typed location of the complete node array.
    public let nodesAt: [JSONLocationComponent]
    /// Absolute typed location of the complete edge array, disjoint from the node array.
    public let edgesAt: [JSONLocationComponent]
    /// Exact direct key of each node’s required string identifier.
    public let nodeIDKey: JSONKey
    /// Exact direct key of each edge’s required source string identifier.
    public let edgeSourceKey: JSONKey
    /// Exact direct key of each edge’s required target string identifier.
    public let edgeTargetKey: JSONKey
    /// Defines roles without interpreting path strings, normalizing keys or validating a source.
    /// - Parameters:
    ///   - nodesAt: Absolute typed node-array location.
    ///   - edgesAt: Absolute typed edge-array location; build rejects overlap.
    ///   - nodeIDKey: Direct required string ID key in node rows.
    ///   - edgeSourceKey: Direct required string source ID key in edge rows.
    ///   - edgeTargetKey: Direct required string target ID key in edge rows.
    public init(nodesAt: [JSONLocationComponent], edgesAt: [JSONLocationComponent],
                 nodeIDKey: JSONKey, edgeSourceKey: JSONKey, edgeTargetKey: JSONKey) {
        self.nodesAt = nodesAt; self.edgesAt = edgesAt; self.nodeIDKey = nodeIDKey
        self.edgeSourceKey = edgeSourceKey; self.edgeTargetKey = edgeTargetKey
    }
}

/// Graph semantic refusals retain exact original locations, never normalized IDs.
public enum JSONGraphFailure: Error, Sendable, Equatable {
    /// The node array exceeds the explicit inclusive node cap.
    case nodeLimitExceeded(limit: Int)
    /// The edge array exceeds the explicit inclusive edge cap.
    case edgeLimitExceeded(limit: Int)
    /// An original node or edge row is not an object.
    case rowNotObject(at: [JSONLocationComponent], kind: JSONTraversalKind)
    /// A required direct ID or endpoint field is absent.
    case idMissing(at: [JSONLocationComponent])
    /// A required direct ID or endpoint field is explicitly null.
    case idNull(at: [JSONLocationComponent])
    /// A required direct ID or endpoint field is not a string.
    case idWrongKind(at: [JSONLocationComponent], kind: JSONTraversalKind)
    /// Two node IDs have identical decoded scalar sequences; both row paths are retained.
    case duplicateNodeID(first: [JSONLocationComponent], second: [JSONLocationComponent])
    /// An edge endpoint has no exact matching node ID; its field path is retained.
    case danglingEndpoint(at: [JSONLocationComponent])
    /// Two original edge rows have the same ordered endpoint pair.
    case duplicateDirectedEdge(first: [JSONLocationComponent], second: [JSONLocationComponent])
    /// The requested node ordinal is outside this captured graph.
    case nodeOutOfBounds(Int)
    /// The requested edge ordinal is outside this captured graph.
    case edgeOutOfBounds(Int)
    /// BFS would exceed its live pending-node frontier cap.
    case frontierLimitExceeded(limit: Int)
    /// BFS would exceed its total visited-node cap.
    case visitedLimitExceeded(limit: Int)
    /// A query would exceed its complete-result cap.
    case resultLimitExceeded(limit: Int)
}

/// Trusted row ordinals in this captured source, not durable graph identifiers.
package struct JSONGraphEdgeRecord: Sendable, Equatable {
    package let row: Int
    package let source: Int
    package let target: Int
}
