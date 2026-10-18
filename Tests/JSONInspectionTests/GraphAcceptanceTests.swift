// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
@testable import JSONInspection

private let graphProfile = JSONGraphProfile(nodesAt: [.key("nodes")], edgesAt: [.key("edges")],
    nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
private func graphDocument(_ name: String) throws -> JSONDocument {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "GraphFixtures"))
    return try JSONParser().parseDocument(Data(contentsOf: url))
}
private func graphBuild(_ name: String, profile: JSONGraphProfile = graphProfile) throws -> JSONOperationReport<JSONGraphProjection> {
    try JSONGraphProjection.build(document: graphDocument(name), profile: profile)
}
private func graphFailure(_ body: () throws -> Void) -> JSONGraphFailure? {
    do { try body(); Issue.record("Expected graph refusal"); return nil }
    catch let error as JSONGraphFailure { return error }
    catch { Issue.record("Unexpected error: \(error)"); return nil }
}
private func graphCore(_ body: () throws -> Void) -> JSONFailure? {
    do { try body(); Issue.record("Expected core refusal"); return nil }
    catch let error as JSONFailure { return error }
    catch let error as JSONAccessFailure { return error.cause }
    catch { Issue.record("Unexpected error: \(error)"); return nil }
}
@Test func graphG01EmptySourceAndNoValidStart() throws {
    let graph = try graphBuild("g01-empty").result
    #expect(graph.nodeCount == 0 && graph.edgeCount == 0 && graph.offsets == [0])
    #expect(graph.document.sourceBytes != nil)
    #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0) } == .nodeOutOfBounds(0))
}
@Test func graphG02IndependentOracleAndSourceOrder() throws {
    struct Oracle: Decodable { let cases: [Case] }
    struct Case: Decodable { let name: String; let expected: Expected }
    struct Expected: Decodable {
        let kind: String; let ids_codepoints: [[UInt32]]?; let edge_pairs: [[Int]]?
        let outgoing_edge_ordinals: [[Int]]?; let bfs_from_node0: [Int]?
    }
    let url = try #require(Bundle.module.url(forResource: "GRAPH-FIXTURE-ORACLE", withExtension: "json", subdirectory: "GraphFixtures"))
    let oracle = try JSONValueDecoder().decode(Oracle.self, from: JSON.parse(Data(contentsOf: url)))
    var evaluated = 0
    for entry in oracle.cases where entry.expected.kind == "valid" {
        let profile = entry.name == "g23-numeric-object-key" ? JSONGraphProfile(
            nodesAt: [.key("0"), .key("nodes")], edgesAt: [.key("0"), .key("edges")],
            nodeIDKey: "key/id", edgeSourceKey: "src~", edgeTargetKey: "dst") : graphProfile
        let graph = try graphBuild(entry.name, profile: profile).result
        #expect(graph.nodeIDs.map { $0.unicodeScalars.map(\.value) } == entry.expected.ids_codepoints)
        #expect(graph.edges.map { [$0.source, $0.target] } == entry.expected.edge_pairs)
        var outgoing: [[Int]] = []
        for node in 0..<graph.nodeCount { outgoing.append(try graph.outgoingEdges(of: node).result) }
        #expect(outgoing == entry.expected.outgoing_edge_ordinals)
        if graph.nodeCount > 0 { #expect(try graph.breadthFirst(fromNode: 0).result == entry.expected.bfs_from_node0) }
        let document = graph.document
        #expect(try JSONGraphProjection.build(document: document, profile: profile, maximumNodes: graph.nodeCount, maximumEdges: graph.edgeCount).result.edges == graph.edges)
        if graph.nodeCount > 0 {
            #expect(graphFailure { _ = try JSONGraphProjection.build(document: document, profile: profile, maximumNodes: graph.nodeCount - 1) } == .nodeLimitExceeded(limit: graph.nodeCount - 1))
            let reached = try #require(entry.expected.bfs_from_node0)
            var seen = Set<Int>([0]), queue = [0], head = 0, peak = 1
            while head < queue.count {
                let node = queue[head]; head += 1
                for pair in try #require(entry.expected.edge_pairs) where pair[0] == node {
                    if seen.insert(pair[1]).inserted { queue.append(pair[1]); peak = max(peak, queue.count - head) }
                }
            }
            #expect(queue == reached)
            #expect(try graph.breadthFirst(fromNode: 0, maximumFrontier: peak, maximumVisited: reached.count, maximumResults: reached.count).result == reached)
            #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumFrontier: peak - 1) } == .frontierLimitExceeded(limit: peak - 1))
            #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumVisited: reached.count - 1) } == .visitedLimitExceeded(limit: reached.count - 1))
            #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumResults: reached.count - 1) } == .resultLimitExceeded(limit: reached.count - 1))
        }
        if graph.edgeCount > 0 {
            #expect(graphFailure { _ = try JSONGraphProjection.build(document: document, profile: profile, maximumEdges: graph.edgeCount - 1) } == .edgeLimitExceeded(limit: graph.edgeCount - 1))
        }
        evaluated += 1
    }
    #expect(evaluated == 12)
    var refused = 0
    for entry in oracle.cases where entry.expected.kind != "valid" {
        if entry.expected.kind == "overlap" {
            let profile = JSONGraphProfile(nodesAt: [.key("data")], edgesAt: [.key("data")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
            #expect(throws: JSONTraversalFailure.ambiguousRoots(first: 0, second: 1)) { _ = try graphBuild(entry.name, profile: profile) }
        } else if entry.expected.kind.hasSuffix("not_array") {
            #expect(graphCore { _ = try graphBuild(entry.name) }?.code == .wrongKind)
        } else {
            let failure = graphFailure { _ = try graphBuild(entry.name) }
            switch (entry.expected.kind, failure) {
            case ("duplicate_node_id", .duplicateNodeID), ("node_id_missing", .idMissing),
                 ("edge_source_missing", .idMissing), ("node_id_null", .idNull),
                 ("edge_target_null", .idNull), ("node_id_wrong_kind", .idWrongKind),
                 ("edge_target_wrong_kind", .idWrongKind), ("node_row_wrong_kind", .rowNotObject),
                 ("edge_row_wrong_kind", .rowNotObject), ("dangling_endpoint", .danglingEndpoint),
                 ("duplicate_directed_edge", .duplicateDirectedEdge): break
            default: Issue.record("Independent refusal mismatch: \(entry.name) \(String(describing: failure))")
            }
        }
        refused += 1
    }
    #expect(refused == 15)
    print("GRAPH_ORACLE passed valid=12 refused=15")

}
@Test func graphG03ScalarDistinctIDs() throws {
    let graph = try graphBuild("g03-unicode-scalars").result
    #expect(graph.nodeCount == 2 && graph.edges[0].target == 1)
    #expect(graph.nodeIDs[0] == graph.nodeIDs[1]) // Swift canonical equivalence is intentionally different.
    #expect(Array(graph.nodeIDs[0].utf8) != Array(graph.nodeIDs[1].utf8))
}
@Test func graphG04SpecialIDsAreNotPaths() throws {
    let graph = try graphBuild("g04-empty-and-special-ids").result
    #expect(graph.nodeIDs.contains("")); #expect(graph.nodeCount == 3)
    for node in 0..<graph.nodeCount { #expect(try graph.nodeValue(at: node).result.objectValue?["id"]?.stringValue == graph.nodeIDs[node]) }
}
@Test func graphG05DuplicateNodeLocations() throws {
    #expect(graphFailure { _ = try graphBuild("g05-duplicate-id") } == .duplicateNodeID(
        first: [.key("nodes"), .index(0)], second: [.key("nodes"), .index(1)]))
}
@Test func graphG06EqualPayloadsPreserveRows() throws {
    let graph = try graphBuild("g06-equal-payload-distinct-id").result
    #expect(graph.nodeCount == 2 && graph.nodeIDs == ["A", "B"])
    #expect(try graph.nodeValue(at: 0).result.objectValue?["payload"] == graph.nodeValue(at: 1).result.objectValue?["payload"])
}
@Test func graphG07MissingNodeID() throws {
    #expect(graphFailure { _ = try graphBuild("g07-node-id-missing") } == .idMissing(at: [.key("nodes"), .index(0), .key("id")]))
}
@Test func graphG08NullNodeID() throws {
    #expect(graphFailure { _ = try graphBuild("g08-node-id-null") } == .idNull(at: [.key("nodes"), .index(0), .key("id")]))
}
@Test func graphG09WrongNodeIDKinds() throws {
    for value in ["0", "false", "{}", "[]"] {
        let document = JSONDocument(root: try JSON.parse("{\"nodes\":[{\"id\":\(value)}],\"edges\":[]}"))
        guard case .idWrongKind(let path, _)? = graphFailure({ _ = try JSONGraphProjection.build(document: document, profile: graphProfile) }) else { Issue.record("Wrong-kind ID was accepted"); continue }
        #expect(path == [.key("nodes"), .index(0), .key("id")])
    }
}
@Test func graphG10NonobjectNode() throws {
    #expect(graphFailure { _ = try graphBuild("g10-node-row-not-object") } == .rowNotObject(at: [.key("nodes"), .index(0)], kind: .string))
}
@Test func graphG11MissingEdgeSource() throws {
    #expect(graphFailure { _ = try graphBuild("g11-edge-source-missing") } == .idMissing(at: [.key("edges"), .index(0), .key("from")]))
}
@Test func graphG12NullEdgeTarget() throws {
    #expect(graphFailure { _ = try graphBuild("g12-edge-target-null") } == .idNull(at: [.key("edges"), .index(0), .key("to")]))
}
@Test func graphG13WrongEndpointKind() throws {
    #expect(graphFailure { _ = try graphBuild("g13-edge-target-number") } == .idWrongKind(at: [.key("edges"), .index(0), .key("to")], kind: .number))
}
@Test func graphG14NonobjectEdge() throws {
    #expect(graphFailure { _ = try graphBuild("g14-edge-row-not-object") } == .rowNotObject(at: [.key("edges"), .index(0)], kind: .number))
}
@Test func graphG15DanglingAndEmpty() throws {
    for name in ["g15-dangling", "g15b-dangling-empty"] {
        guard case .danglingEndpoint(let path)? = graphFailure({ _ = try graphBuild(name) }) else { Issue.record("Expected dangling endpoint"); continue }
        #expect(path.prefix(2) == [.key("edges"), .index(0)])
    }
}
@Test func graphG16DuplicateOrderedEdge() throws {
    #expect(graphFailure { _ = try graphBuild("g16-duplicate-edge") } == .duplicateDirectedEdge(first: [.key("edges"), .index(0)], second: [.key("edges"), .index(1)]))
}
@Test func graphG17ReverseEdgesAreDistinct() throws {
    let graph = try graphBuild("g17-reverse-edges").result
    #expect(graph.edgeCount == 2); #expect(try graph.outgoingEdges(of: 1).result == [1])
}
@Test func graphG18SelfEdgeIsVisitedOnce() throws {
    let graph = try graphBuild("g18-self-edge").result
    #expect(try graph.outgoingEdges(of: 0).result == [0]); #expect(try graph.breadthFirst(fromNode: 0).result == [0])
}
@Test func graphG19CycleTerminates() throws {
    #expect(try graphBuild("g19-cycle").result.breadthFirst(fromNode: 0).result == [0, 1, 2])
}
@Test func graphG20IsolatesRemainSourceNodes() throws {
    let graph = try graphBuild("g20-isolate").result
    #expect(graph.nodeCount == 3); #expect(try graph.breadthFirst(fromNode: 0).result == [0, 1])
    #expect(try graph.breadthFirst(fromNode: 2).result == [2])
}
@Test func graphG21SourceEdgeNeighborOrder() throws {
    #expect(try graphBuild("g21-bfs-source-edge-order").result.breadthFirst(fromNode: 0).result == [0, 3, 1, 2])
}
@Test func graphG22DiamondEnqueuesOnce() throws {
    #expect(try graphBuild("g22-diamond").result.breadthFirst(fromNode: 0).result == [0, 1, 2, 3])
}
@Test func graphG23TypedPathsAndPointerDifferential() throws {
    let profile = JSONGraphProfile(nodesAt: [.key("0"), .key("nodes")], edgesAt: [.key("0"), .key("edges")], nodeIDKey: "key/id", edgeSourceKey: "src~", edgeTargetKey: "dst")
    let graph = try graphBuild("g23-numeric-object-key", profile: profile).result
    #expect(try graph.nodeValue(at: 0).result == JSONPointer(parsing: "/0/nodes/0").resolve(in: graph.document.root))
    let wrong = JSONGraphProfile(nodesAt: [.index(0), .key("nodes")], edgesAt: profile.edgesAt, nodeIDKey: profile.nodeIDKey, edgeSourceKey: profile.edgeSourceKey, edgeTargetKey: profile.edgeTargetKey)
    #expect(graphCore { _ = try JSONGraphProjection.build(document: graph.document, profile: wrong) }?.code == .wrongKind)
}
@Test func graphG24OverlapAndDuplicateRootsFailBeforeRows() throws {
    for paths in [([], [.key("nodes")]), ([.key("nodes")], [.key("nodes")])] as [([JSONLocationComponent], [JSONLocationComponent])] {
        let profile = JSONGraphProfile(nodesAt: paths.0, edgesAt: paths.1, nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
        #expect(throws: JSONTraversalFailure.ambiguousRoots(first: 0, second: 1)) { _ = try JSONGraphProjection.build(document: graphDocument("g01-empty"), profile: profile) }
    }
}
@Test func graphG25WholeSourceAdmissionAndFreshQueries() throws {
    for count in [0, 16, 128] {
        let root = try JSON.parse("{\"nodes\":[{\"id\":\"A\"}],\"edges\":[],\"other\":[" + Array(repeating: "null", count: count).joined(separator: ",") + "]}")
        let doc = JSONDocument(root: root)
        let report = try JSONGraphProjection.build(document: doc, profile: graphProfile)
        let baseline = try JSONTraversal(document: doc).visit { _, _ in .continue }
        #expect(report.statistics[.nodes] == baseline.statistics[.nodes])
        let query = try report.result.breadthFirst(fromNode: 0)
        #expect(query.statistics[.nodes] == baseline.statistics[.nodes])
        print("GRAPH_RESOURCE siblings=\(count) nodes=\(report.statistics[.nodes]) build=\(report.statistics[.workUnits]) bfs=\(query.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes)")
        var limits = JSONLimits.balanced; limits[.nodes] = baseline.statistics[.nodes] - 1
        #expect(graphCore { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile, limits: limits) }?.resource?.metric == .nodes)
    }
    for depth in [16, 64, 256] {
        var root = try JSON.parse(#"{"nodes":[{"id":"A"}],"edges":[]}"#)
        for _ in 0..<depth { root = .array([root]) }
        let prefix = Array(repeating: JSONLocationComponent.index(0), count: depth)
        let profile = JSONGraphProfile(nodesAt: prefix + [.key("nodes")], edgesAt: prefix + [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
        var limits = JSONLimits.offline; limits[.maxDepth] = 512; limits[.pointerTokens] = 512
        let report = try JSONGraphProjection.build(document: .init(root: root), profile: profile, limits: limits)
        #expect(report.result.nodeCount == 1)
        #expect(try report.result.breadthFirst(fromNode: 0, limits: limits).result == [0])
        print("GRAPH_DEPTH levels=\(depth) work=\(report.statistics[.workUnits]) peak=\(report.statistics.peakLogicalRetainedBytes)")
    }
    for count in [1, 32, 1024] {
        let nodes = (0..<count).map { "{\"id\":\"n\($0)\"}" }.joined(separator: ",")
        let edges = (0..<count).map { "{\"from\":\"n\($0)\",\"to\":\"n\(($0 + 1) % count)\"}" }.joined(separator: ",")
        let document = JSONDocument(root: try JSON.parse("{\"nodes\":[" + nodes + "],\"edges\":[" + edges + "]}"))
        let report = try JSONGraphProjection.build(document: document, profile: graphProfile, maximumNodes: count, maximumEdges: count)
        #expect(report.result.nodeCount == count && report.result.edgeCount == count)
        #expect(try report.result.breadthFirst(fromNode: 0, maximumFrontier: 1, maximumVisited: count, maximumResults: count).result == Array(0..<count))
        print("GRAPH_SCALE nodes=\(count) edges=\(count) work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes)")
    }

}
@Test func graphG26InclusiveWorkAndRetention() throws {
    let doc = try graphDocument("g02-simple")
    let baseline = try JSONGraphProjection.build(document: doc, profile: graphProfile)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .retainedBytes ? baseline.statistics.peakLogicalRetainedBytes : baseline.statistics[metric]
        #expect(try JSONGraphProjection.build(document: doc, profile: graphProfile, limits: limits).statistics[.workUnits] == baseline.statistics[.workUnits])
        limits[metric] -= 1
        #expect(graphCore { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile, limits: limits) }?.resource?.metric == metric)
        let bfs = try baseline.result.breadthFirst(fromNode: 0)
        limits = .balanced; limits[metric] = metric == .retainedBytes ? bfs.statistics.peakLogicalRetainedBytes : bfs.statistics[metric]
        #expect(try baseline.result.breadthFirst(fromNode: 0, limits: limits).result == [0, 1, 2])
        limits[metric] -= 1
        #expect(graphCore { _ = try baseline.result.breadthFirst(fromNode: 0, limits: limits) }?.resource?.metric == metric)
    }
}
@Test func graphG27EveryCapacityAndCheckedOverflow() throws {
    let doc = try graphDocument("g02-simple")
    let graph = try JSONGraphProjection.build(document: doc, profile: graphProfile, maximumNodes: 3, maximumEdges: 3).result
    #expect(graphFailure { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile, maximumNodes: 2) } == .nodeLimitExceeded(limit: 2))
    #expect(graphFailure { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile, maximumEdges: 2) } == .edgeLimitExceeded(limit: 2))
    #expect(try graph.breadthFirst(fromNode: 0, maximumFrontier: 2, maximumVisited: 3, maximumResults: 3).result == [0, 1, 2])
    #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumFrontier: 1) } == .frontierLimitExceeded(limit: 1))
    #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumVisited: 2) } == .visitedLimitExceeded(limit: 2))
    #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumResults: 2) } == .resultLimitExceeded(limit: 2))
    #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumFrontier: 0) } == .frontierLimitExceeded(limit: 0))
    #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumVisited: 0) } == .visitedLimitExceeded(limit: 0))
    #expect(graphFailure { _ = try graph.outgoingEdges(of: 0, maximumResults: 1) } == .resultLimitExceeded(limit: 1))
    let empty = try graphDocument("g01-empty")
    let hugeKey = JSONGraphProfile(nodesAt: graphProfile.nodesAt, edgesAt: graphProfile.edgesAt,
        nodeIDKey: "unused-but-owned", edgeSourceKey: "from", edgeTargetKey: "to")
    var keyLimits = JSONLimits.balanced; keyLimits[.keyBytes] = 5
    #expect(graphCore { _ = try JSONGraphProjection.build(document: empty, profile: hugeKey, limits: keyLimits) }?.resource?.metric == .keyBytes)
    #expect(graphCore { _ = try ProjectionAccounting.next(Int.max, limits: .balanced) }?.code == .counterOverflow)
    #expect(graphCore { _ = try ProjectionAccounting.bytes(Int.max, unit: 256, limits: .balanced) }?.code == .counterOverflow)
}
@Test func graphG28CancellationStopsBuildAndBFS() async throws {
    let doc = try graphDocument("g22-diamond"), graph = try graphBuild("g22-diamond").result
    // Phase markers arm cancellation; the checkpoint count crosses inside an
    // exact-ID loop, adjacency scan or BFS edge scan, after source admission.
    let prefix = String(repeating: "x", count: 128)
    let nodes = (0..<12).map { "{\"id\":\"\(prefix)\($0)\"}" }.joined(separator: ",")
    let edges = (1..<12).map { "{\"from\":\"\(prefix)0\",\"to\":\"\(prefix)\($0)\"}" }.joined(separator: ",")
    let large = JSONDocument(root: try JSON.parse("{\"nodes\":[" + nodes + "],\"edges\":[" + edges + "]}"))
    for phase in [GraphWorkStage.nodeIdentity, .endpointIdentity, .edgePair, .adjacency, .breadthFirst] {
        let fired = Mutex(false), armed = Mutex(false), ticks = Mutex(0), cleared = Mutex(false)
        let job = Task {
            var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
            var walk = JSONTraversal(document: large, limits: limits)
            walk.lifetimeObserver = { root, state in cleared.withLock { $0 = root && state } }
            walk.checkpointObserver = { _ in
                if armed.withLock({ $0 }) {
                    let n = ticks.withLock { $0 += 1; return $0 }
                    if n >= 6 { fired.withLock { $0 = true }; withUnsafeCurrentTask { $0?.cancel() } }
                }
            }
            let observer: @Sendable (GraphWorkStage) -> Void = { current in
                if current == phase { armed.withLock { $0 = true } }
            }
            if phase == .breadthFirst {
                let captured = try JSONGraphProjection.build(document: large, profile: graphProfile).result
                var query = GraphQuery(workObserver: observer, graph: captured, query: .breadthFirst(0), limits: limits,
                    maximumFrontier: 12, maximumVisited: 12, maximumResults: 12)
                #expect(throws: CancellationError.self) { _ = try walk.inspectOwned(options: .init(depthLimit: 0), reducer: &query) }
            } else {
                var reducer = GraphBuilder(workObserver: observer, profile: graphProfile, limits: limits, maximumNodes: 12, maximumEdges: 11)
                #expect(throws: CancellationError.self) {
                    _ = try walk.inspectOwned(scope: .virtual(roots: [graphProfile.nodesAt, graphProfile.edgesAt], overlap: .rejectAmbiguous), options: .init(depthLimit: 1), reducer: &reducer)
                }
            }
        }
        try await job.value
        #expect(fired.withLock { $0 } && cleared.withLock { $0 })
        print("GRAPH_CANCELLATION phase=\(phase) checkpoints=\(ticks.withLock { $0 }) root-and-state-released=true")
    }
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        #expect(throws: CancellationError.self) { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile) }
        #expect(throws: CancellationError.self) { _ = try graph.breadthFirst(fromNode: 0) }
    }
    await task.value
    #expect(try graph.breadthFirst(fromNode: 0).result == [0, 1, 2, 3])
}
@Test func graphG29FailurePrecedenceAndTerminalLatch() throws {
    let doc = JSONDocument(root: try JSON.parse(#"{"nodes":[false,{"id":"A"},{"id":"A"}],"edges":[{"from":"X","to":"Y"}]}"#))
    #expect(graphCore { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile, maximumNodes: -1) }?.code == .invalidLimits)
    #expect(graphFailure { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile) } == .rowNotObject(at: [.key("nodes"), .index(0)], kind: .boolean))
    var limits = JSONLimits.balanced; limits[.workUnits] = 0
    #expect(graphCore { _ = try JSONGraphProjection.build(document: doc, profile: graphProfile, limits: limits) }?.category == .resource)
    struct Catcher: JSONTraversalOwnedReducer {
        enum Replacement: Error { case caller }
        mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
            do { try context.work(UInt64.max) } catch {}
            throw Replacement.caller
        }
        mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> Bool { true }
    }
    var reducer = Catcher()
    #expect(graphCore { _ = try JSONTraversal(document: doc).inspectOwned(reducer: &reducer) }?.category == .resource)
}
@Test func graphG30ConcurrentViewsHaveIndependentHealth() async throws {
    let doc = try graphDocument("g22-diamond")
    let graph = try JSONGraphProjection.build(document: doc, profile: graphProfile).result
    try await withThrowingTaskGroup(of: [Int].self) { group in
        for _ in 0..<12 {
            group.addTask {
                #expect(graphFailure { _ = try graph.breadthFirst(fromNode: 0, maximumResults: 1) } == .resultLimitExceeded(limit: 1))
                return try JSONGraphProjection.build(document: doc, profile: graphProfile).result.breadthFirst(fromNode: 0).result
            }
        }
        for try await result in group { #expect(result == [0, 1, 2, 3]) }
    }
}
@Test func graphG31CapturedRootAndSourceMapCoherence() throws {
    let original = try graphDocument("g02-simple"), graph = try JSONGraphProjection.build(document: original, profile: graphProfile).result
    let replaced = original.replacingRoot(try JSON.parse(#"{"nodes":[{"id":"NEW"}],"edges":[]}"#))
    let new = try JSONGraphProjection.build(document: replaced, profile: graphProfile).result
    #expect(try graph.nodeSpan(at: 0).result != nil && new.nodeSpan(at: 0).result == nil)
    #expect(graph.nodeIDs == ["A", "B", "C"] && new.nodeIDs == ["NEW"])
    #expect(graph.document.sourceBytes == original.sourceBytes)
}
@Test func graphG32CheckedMetadataAndExistingPublicSemantics() throws {
    let graph = try graphBuild("g02-simple").result
    #expect(graphFailure { _ = try graph.nodeValue(at: -1) } == .nodeOutOfBounds(-1))
    #expect(graphFailure { _ = try graph.edgeValue(at: graph.edgeCount) } == .edgeOutOfBounds(graph.edgeCount))
    #expect(try graph.edgeValue(at: 0).result == JSONPointer(parsing: "/edges/0").resolve(in: graph.document.root))
    #expect(try JSONTraversal(document: graph.document).visit { _, _ in .continue }.statistics[.retainedBytes] == 0)
    #expect(try JSONShapeInspector(document: graph.document).inspectArray(at: [.key("nodes")]).result.totalRows == 3)
}
