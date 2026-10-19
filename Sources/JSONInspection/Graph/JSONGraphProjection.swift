// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONNavigation

/// Experimental immutable source-attached directed simple graph. Not public API.
package struct JSONGraphProjection: Sendable {
    package let document: JSONDocument
    package let profile: JSONGraphProfile
    package let nodeIDs: [String]
    package let edges: [JSONGraphEdgeRecord]
    package let offsets: [Int]
    package let adjacency: [Int]
    package let traversal: JSONTraversalSummary
    package var nodeCount: Int { nodeIDs.count }
    package var edgeCount: Int { edges.count }
    fileprivate init(document: JSONDocument, profile: JSONGraphProfile, nodeIDs: [String],
                     edges: [JSONGraphEdgeRecord], offsets: [Int], adjacency: [Int],
                     traversal: JSONTraversalSummary) {
        self.document = document; self.profile = profile; self.nodeIDs = nodeIDs
        self.edges = edges; self.offsets = offsets; self.adjacency = adjacency; self.traversal = traversal
    }

    /// Complete source admission, nodes, edges and adjacency share one original meter.
    package static func build(document: JSONDocument, profile: JSONGraphProfile,
                              limits: JSONLimits = .balanced, maximumNodes: Int = 10_000,
                              maximumEdges: Int = 50_000) throws -> JSONOperationReport<Self> {
        guard maximumNodes >= 0, maximumEdges >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        var reducer = GraphBuilder(profile: profile, limits: limits, maximumNodes: maximumNodes, maximumEdges: maximumEdges)
        return try JSONTraversal(document: document, limits: limits).inspectOwned(
            scope: .virtual(roots: [profile.nodesAt, profile.edgesAt], overlap: .rejectAmbiguous),
            options: .init(depthLimit: 1), reducer: &reducer)
    }

    /// A new whole-source operation; returns original physical outgoing edge ordinals.
    package func outgoingEdges(of node: Int, limits: JSONLimits = .balanced, maximumResults: Int = 50_000)
        throws -> JSONOperationReport<[Int]> {
        guard maximumResults >= 0 else { throw JSONFailure(.configuration, code: .invalidLimits) }
        try checkNode(node)
        var reducer = GraphQuery(graph: self, query: .outgoing(node), limits: limits,
                                 maximumFrontier: 0, maximumVisited: 0, maximumResults: maximumResults)
        return try JSONTraversal(document: document, limits: limits)
            .inspectOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }

    /// Complete reachable component, including start; never a partial success.
    package func breadthFirst(fromNode node: Int, limits: JSONLimits = .balanced,
                              maximumFrontier: Int = 10_000, maximumVisited: Int = 10_000,
                              maximumResults: Int = 10_000) throws -> JSONOperationReport<[Int]> {
        guard maximumFrontier >= 0, maximumVisited >= 0, maximumResults >= 0 else {
            throw JSONFailure(.configuration, code: .invalidLimits)
        }
        try checkNode(node)
        var reducer = GraphQuery(graph: self, query: .breadthFirst(node), limits: limits,
                                 maximumFrontier: maximumFrontier, maximumVisited: maximumVisited,
                                 maximumResults: maximumResults)
        return try JSONTraversal(document: document, limits: limits)
            .inspectOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }

    package func nodeValue(at node: Int, limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSON> {
        try checkNode(node)
        return try value(at: profile.nodesAt, row: node, limits: limits)
    }
    package func edgeValue(at edge: Int, limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSON> {
        guard edge >= 0, edge < edgeCount else { throw JSONGraphFailure.edgeOutOfBounds(edge) }
        return try value(at: profile.edgesAt, row: edge, limits: limits)
    }
    /// Source-map lookup under a new explicit full-source admission.
    package func nodeSpan(at node: Int, limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSONSourceSpan?> {
        try checkNode(node)
        let scope = try JSONReadScope(document, limits: limits); defer { scope.invalidate() }
        let state = try scope.check(); let path = try rowPath(profile.nodesAt, row: node, scope: scope, state: state)
        let span = try document.sourceMap?.span(at: path.components, kind: .value, meter: &state.meter)
        return try scope.complete(span)
    }
    private func checkNode(_ node: Int) throws {
        guard node >= 0, node < nodeCount else { throw JSONGraphFailure.nodeOutOfBounds(node) }
    }
    private func value(at root: [JSONLocationComponent], row: Int, limits: JSONLimits) throws -> JSONOperationReport<JSON> {
        let scope = try JSONReadScope(document, limits: limits); defer { scope.invalidate() }
        let state = try scope.check(); let path = try rowPath(root, row: row, scope: scope, state: state)
        let value = try scope.run(path.components) { try scope.select(path.components, state: $0) }
        // A returned JSON alias remains owned through handoff, independently of input.
        try JSONAdmission.value(value, meter: &state.meter, owned: true)
        return try scope.complete(value)
    }
    private func rowPath(_ root: [JSONLocationComponent], row: Int, scope: JSONReadScope,
                         state: JSONCodingState) throws -> JSONReadPath {
        var path = JSONReadPath(scope: scope, components: [], bytes: 0)
        for part in root { try state.meter.work(); path = try scope.append(part, to: path.components, state: state) }
        return try scope.append(.index(row), to: path.components, state: state)
    }
}

internal enum GraphWorkStage: Sendable, Equatable { case nodeIdentity, endpointIdentity, edgePair, adjacency, breadthFirst }

internal struct GraphBuilder: JSONTraversalOwnedReducer {
    /// Qualification-only phase marker; no scope/capability is exposed.
    var workObserver: (@Sendable (GraphWorkStage) -> Void)? = nil
    let profile: JSONGraphProfile
    let limits: JSONLimits
    let maximumNodes: Int
    let maximumEdges: Int
    var ids: [String] = []
    var edges: [JSONGraphEdgeRecord] = []
    var nodeTotal = 0, edgeTotal = 0

    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try context.work()
        if hit.relativeDepth == 0 {
            let count = try context.arrayCount(value, at: hit.absoluteLocation)
            if hit.scopeRootIndex == 0 {
                guard count <= maximumNodes else { throw JSONGraphFailure.nodeLimitExceeded(limit: maximumNodes) }
                nodeTotal = count
                _ = try ProjectionAccounting.next(count, limits: limits)
                try context.retain(256)
                _ = try context.retainLocation(profile.nodesAt); _ = try context.retainLocation(profile.edgesAt)
                for key in [profile.nodeIDKey, profile.edgeSourceKey, profile.edgeTargetKey] {
                    try context.work(); try context.retain(32); try context.retainKey(key, admittingCallerInput: true)
                }
            } else {
                guard count <= maximumEdges else { throw JSONGraphFailure.edgeLimitExceeded(limit: maximumEdges) }
                edgeTotal = count
            }
            return .continue
        }
        guard case .object = value else { throw JSONGraphFailure.rowNotObject(at: try context.retainLocation(hit.absoluteLocation), kind: hit.kind) }
        if hit.scopeRootIndex == 0 {
            let id = try string(value, key: profile.nodeIDKey, at: hit.absoluteLocation, context: &context)
            for prior in ids.indices {
                try context.work()
                workObserver?(.nodeIdentity)
                if try context.equalStrings(ids[prior], id) {
                    throw JSONGraphFailure.duplicateNodeID(
                        first: try context.appending(.index(prior), to: profile.nodesAt),
                        second: try context.retainLocation(hit.absoluteLocation))
                }
            }
            _ = try ProjectionAccounting.next(ids.count, limits: limits)
            try context.retain(16); ids.append(id)
        } else {
            // Required fields are checked source then target before resolving either.
            let source = try string(value, key: profile.edgeSourceKey, at: hit.absoluteLocation, context: &context)
            let target = try string(value, key: profile.edgeTargetKey, at: hit.absoluteLocation, context: &context)
            let from = try resolve(source, key: profile.edgeSourceKey, at: hit.absoluteLocation, context: &context)
            let to = try resolve(target, key: profile.edgeTargetKey, at: hit.absoluteLocation, context: &context)
            for prior in edges.indices {
                try context.work()
                workObserver?(.edgePair)
                if edges[prior].source == from, edges[prior].target == to {
                    throw JSONGraphFailure.duplicateDirectedEdge(
                        first: try context.appending(.index(prior), to: profile.edgesAt),
                        second: try context.retainLocation(hit.absoluteLocation))
                }
            }
            _ = try ProjectionAccounting.next(edges.count, limits: limits)
            try context.retain(24); edges.append(.init(row: edges.count, source: from, target: to))
            try context.releaseStringAlias(source); try context.releaseStringAlias(target)
        }
        return .skipDescendants
    }
    private func string(_ value: JSON, key: JSONKey, at row: [JSONLocationComponent],
                        context: inout JSONTraversalContext) throws -> String {
        let member = try context.directStringMember(value, key: key, at: row)
        if let text = member.text { return text }
        let path = try context.appending(.key(key), to: row)
        guard let kind = member.kind else { throw JSONGraphFailure.idMissing(at: path) }
        if kind == .null { throw JSONGraphFailure.idNull(at: path) }
        throw JSONGraphFailure.idWrongKind(at: path, kind: kind)
    }
    private func resolve(_ text: String, key: JSONKey, at row: [JSONLocationComponent],
                         context: inout JSONTraversalContext) throws -> Int {
        for index in ids.indices {
            try context.work()
            workObserver?(.endpointIdentity)
            if try context.equalStrings(ids[index], text) { return index }
        }
        throw JSONGraphFailure.danglingEndpoint(at: try context.appending(.key(key), to: row))
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> JSONGraphProjection {
        guard ids.count == nodeTotal, edges.count == edgeTotal else { throw JSONFailure(.configuration, code: .invalidOperation) }
        var offsets: [Int] = [], adjacency: [Int] = []
        try context.work(); try context.retain(8); offsets.append(0)
        // Deterministic source-ordered CSR, deliberately bounded linear scans.
        for node in ids.indices {
            try context.work()
            for edge in edges.indices {
                workObserver?(.adjacency)
                try context.work()
                if edges[edge].source == node {
                    _ = try ProjectionAccounting.next(adjacency.count, limits: limits)
                    try context.retain(8); adjacency.append(edge)
                }
            }
            _ = try ProjectionAccounting.next(offsets.count, limits: limits)
            try context.retain(8); offsets.append(adjacency.count)
        }
        try context.work()
        let document = try context.transferDocumentOwnership()
        return .init(document: document, profile: profile, nodeIDs: ids, edges: edges,
                     offsets: offsets, adjacency: adjacency, traversal: summary)
    }
}
