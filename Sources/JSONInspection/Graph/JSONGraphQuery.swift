// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

internal struct GraphQuery: JSONTraversalOwnedReducer {
    var workObserver: (@Sendable (GraphWorkStage) -> Void)? = nil
    enum Query { case outgoing(Int), breadthFirst(Int) }
    let graph: JSONGraphProjection
    let query: Query
    let limits: JSONLimits
    let maximumFrontier: Int
    let maximumVisited: Int
    let maximumResults: Int
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work(); return .skipDescendants
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> [Int] {
        let aliases = try retainAliases(context: &context)
        var result: [Int] = []
        switch query {
        case .outgoing(let node):
            for position in graph.offsets[node]..<graph.offsets[node + 1] {
                try context.work()
                guard result.count < maximumResults else { throw JSONGraphFailure.resultLimitExceeded(limit: maximumResults) }
                _ = try ProjectionAccounting.next(result.count, limits: limits)
                try context.retain(8); result.append(graph.adjacency[position])
            }
        case .breadthFirst(let start):
            var visited: [Bool] = []
            for _ in 0..<graph.nodeCount { try context.work(); try context.retain(1); visited.append(false) }
            var head = 0
            func enqueue(_ node: Int, context: inout JSONTraversalContext) throws {
                try context.work()
                guard result.count - head < maximumFrontier else { throw JSONGraphFailure.frontierLimitExceeded(limit: maximumFrontier) }
                guard result.count < maximumVisited else { throw JSONGraphFailure.visitedLimitExceeded(limit: maximumVisited) }
                guard result.count < maximumResults else { throw JSONGraphFailure.resultLimitExceeded(limit: maximumResults) }
                _ = try ProjectionAccounting.next(result.count, limits: limits)
                try context.retain(8); visited[node] = true; result.append(node)
            }
            try enqueue(start, context: &context)
            while head < result.count {
                try context.work()
                let node = result[head]; head += 1
                for position in graph.offsets[node]..<graph.offsets[node + 1] {
                    try context.work()
                    workObserver?(.breadthFirst)
                    let target = graph.edges[graph.adjacency[position]].target
                    if !visited[target] { try enqueue(target, context: &context) }
                }
            }
            let flags = visited.count; visited.removeAll(keepingCapacity: false)
            try context.release(UInt64(flags))
        }
        try context.work(); try context.release(aliases)
        return result
    }
    /// Additional owned aliases of the immutable graph are accounted separately
    /// from the one complete source admission, and relinquished before handoff.
    private func retainAliases(context: inout JSONTraversalContext) throws -> UInt64 {
        var total: UInt64 = 0
        func retain(_ bytes: UInt64, context: inout JSONTraversalContext) throws {
            try context.retain(bytes)
            // Each successful retain is bounded below UInt64.max by the core.
            total += bytes
        }
        try context.work(); try retain(256, context: &context)
        for path in [graph.profile.nodesAt, graph.profile.edgesAt] {
            for part in path {
                try context.work(); try retain(32, context: &context)
                if case .key(let key) = part {
                    for _ in key.string.utf8 { try context.work(); try retain(1, context: &context) }
                }
            }
        }
        for key in [graph.profile.nodeIDKey, graph.profile.edgeSourceKey, graph.profile.edgeTargetKey] {
            try context.work(); try retain(32, context: &context)
            for _ in key.string.utf8 { try context.work(); try retain(1, context: &context) }
        }
        for id in graph.nodeIDs {
            try context.work(); try retain(48, context: &context)
            for _ in id.utf8 { try context.work(); try retain(1, context: &context) }
        }
        for _ in graph.edges { try context.work(); try retain(24, context: &context) }
        for _ in graph.offsets { try context.work(); try retain(8, context: &context) }
        for _ in graph.adjacency { try context.work(); try retain(8, context: &context) }
        return total
    }
}
