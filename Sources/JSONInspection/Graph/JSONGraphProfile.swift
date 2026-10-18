// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Experimental explicit direct-field profile; all locations are absolute/typed.
package struct JSONGraphProfile: Sendable {
    package let nodesAt: [JSONLocationComponent]
    package let edgesAt: [JSONLocationComponent]
    package let nodeIDKey: JSONKey
    package let edgeSourceKey: JSONKey
    package let edgeTargetKey: JSONKey
    package init(nodesAt: [JSONLocationComponent], edgesAt: [JSONLocationComponent],
                 nodeIDKey: JSONKey, edgeSourceKey: JSONKey, edgeTargetKey: JSONKey) {
        self.nodesAt = nodesAt; self.edgesAt = edgesAt; self.nodeIDKey = nodeIDKey
        self.edgeSourceKey = edgeSourceKey; self.edgeTargetKey = edgeTargetKey
    }
}

/// Graph semantic refusals retain exact original locations, never normalized IDs.
package enum JSONGraphFailure: Error, Sendable, Equatable {
    case nodeLimitExceeded(limit: Int)
    case edgeLimitExceeded(limit: Int)
    case rowNotObject(at: [JSONLocationComponent], kind: JSONTraversalKind)
    case idMissing(at: [JSONLocationComponent])
    case idNull(at: [JSONLocationComponent])
    case idWrongKind(at: [JSONLocationComponent], kind: JSONTraversalKind)
    case duplicateNodeID(first: [JSONLocationComponent], second: [JSONLocationComponent])
    case danglingEndpoint(at: [JSONLocationComponent])
    case duplicateDirectedEdge(first: [JSONLocationComponent], second: [JSONLocationComponent])
    case nodeOutOfBounds(Int)
    case edgeOutOfBounds(Int)
    case frontierLimitExceeded(limit: Int)
    case visitedLimitExceeded(limit: Int)
    case resultLimitExceeded(limit: Int)
}

/// Trusted row ordinals in this captured source, not durable graph identifiers.
package struct JSONGraphEdgeRecord: Sendable, Equatable {
    package let row: Int
    package let source: Int
    package let target: Int
}
