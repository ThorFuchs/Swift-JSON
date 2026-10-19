// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONNavigation
import JSONInspection

// Shared scenario inputs are also executed by the distinct-package public consumer.
enum GraphPublicCases {
    enum CheckFailure: Error { case failed(Int) }
    static let profile = JSONGraphProfile(nodesAt: [.key("nodes")], edgesAt: [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
    static let text = #"{"nodes":[{"id":"A","n":9007199254740993},{"id":"B"},{"id":"C"},{"id":"isolate"}],"edges":[{"from":"A","to":"C"},{"from":"A","to":"B"},{"from":"C","to":"A"}]}"#
    static func check(_ value: Bool, _ id: Int) throws { if !value { throw CheckFailure.failed(id) } }
    static func doc(_ text: String = text) throws -> JSONDocument { try JSONParser().parseDocument(Data(text.utf8)) }
    static func build(_ text: String = text) throws -> JSONOperationReport<JSONGraphProjection> { try JSONGraphProjection.build(document: doc(text), profile: profile) }
    static func graphError(_ expected: JSONGraphFailure, _ body: () throws -> Void) throws {
        do { try body(); throw CheckFailure.failed(100) } catch let failure as JSONGraphFailure { try check(failure == expected, 101) }
    }
    static func resource(_ metric: JSONResourceMetric, _ body: () throws -> Void) throws {
        do { try body(); throw CheckFailure.failed(102) } catch let failure as JSONFailure { try check(failure.category == .resource && failure.resource?.metric == metric, 103) }
    }
    static func run(_ id: Int) async throws {
        switch id {
        case 1:
            let result = try build(); let graph: JSONGraphProjection = result.result
            try check(graph.nodeCount == 4 && graph.edgeCount == 3 && result.statistics[.workUnits] > 0, id)
        case 2:
            let document = try doc(#"{"":{"0":[{"id":"A"}]},"edges":[]}"#)
            let exact = JSONGraphProfile(nodesAt: [.key(""), .key("0")], edgesAt: [.key("edges")], nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
            let graph = try JSONGraphProjection.build(document: document, profile: exact).result
            try check(try graph.nodeValue(at: 0).result == JSONPointer(parsing: "//0/0").resolve(in: document.root), id)
            let indexed = JSONGraphProfile(nodesAt: [.index(0)], edgesAt: exact.edgesAt, nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "to")
            do { _ = try JSONGraphProjection.build(document: document, profile: indexed); throw CheckFailure.failed(id) }
            catch let failure as JSONAccessFailure { try check(failure.cause.code == .wrongKind, id) }
        case 3:
            let graph = try build().result
            try check(try graph.breadthFirst(fromNode: 0).result == [0,2,1], id)
            try check(try graph.outgoingEdges(of: 0).result == [0,1], id)
            try check(try graph.breadthFirst(fromNode: 3).result == [3], id)
        case 4:
            let graph = try build(#"{"nodes":[{"id":"A"},{"id":"B"}],"edges":[{"from":"A","to":"A"},{"from":"A","to":"B"},{"from":"B","to":"A"}]}"#).result
            try check(try graph.breadthFirst(fromNode: 0).result == [0,1], id)
            let explicitReuse = JSONGraphProfile(nodesAt: profile.nodesAt, edgesAt: profile.edgesAt, nodeIDKey: "id", edgeSourceKey: "from", edgeTargetKey: "from")
            let reused = try JSONGraphProjection.build(document: doc(#"{"nodes":[{"id":"A"}],"edges":[{"from":"A"}]}"#), profile: explicitReuse).result
            try check(try reused.breadthFirst(fromNode: 0).result == [0], id)
        case 5:
            try graphError(.duplicateNodeID(first: [.key("nodes"),.index(0)], second: [.key("nodes"),.index(1)])) {
                _ = try build(#"{"nodes":[{"id":"A"},{"id":"A"}],"edges":[]}"#)
            }
        case 6:
            let graph = try build(#"{"nodes":[{"id":"é"},{"id":"e\u0301"}],"edges":[{"from":"é","to":"e\u0301"}]}"#).result
            let a = try graph.nodeValue(at: 0).result.requiredMember("id"), b = try graph.nodeValue(at: 1).result.requiredMember("id")
            try check(a != b && graph.nodeCount == 2, id)
            try check(try graph.breadthFirst(fromNode: 0).result == [0,1], id)
        case 7:
            try graphError(.duplicateDirectedEdge(first: [.key("edges"),.index(0)], second: [.key("edges"),.index(1)])) {
                _ = try build(#"{"nodes":[{"id":"A"}],"edges":[{"from":"A","to":"A"},{"from":"A","to":"A"}]}"#)
            }
            let reverse = try build(#"{"nodes":[{"id":"A"},{"id":"B"}],"edges":[{"from":"A","to":"B"},{"from":"B","to":"A"}]}"#).result
            try check(reverse.edgeCount == 2, id)
        case 8:
            try graphError(.danglingEndpoint(at: [.key("edges"),.index(0),.key("to")])) {
                _ = try build(#"{"nodes":[{"id":"A"}],"edges":[{"from":"A","to":"missing"}]}"#)
            }
        case 9:
            let path: [JSONLocationComponent] = [.key("nodes"),.index(0),.key("id")]
            for (row,error) in [("{}", JSONGraphFailure.idMissing(at: path)), (#"{"id":null}"#, .idNull(at: path)), (#"{"id":1}"#, .idWrongKind(at: path, kind: .number)), ("false", .rowNotObject(at: [.key("nodes"),.index(0)], kind: .boolean))] {
                try graphError(error) { _ = try build("{\"nodes\":[" + row + "],\"edges\":[]}") }
            }
            try graphError(.idNull(at: [.key("edges"),.index(0),.key("to")])) { _ = try build(#"{"nodes":[{"id":"A"}],"edges":[{"from":"A","to":null}]}"#) }
        case 10:
            let graph = try build().result
            try graphError(.nodeOutOfBounds(-1)) { _ = try graph.nodeValue(at: -1) }
            try graphError(.edgeOutOfBounds(3)) { _ = try graph.edgeValue(at: 3) }
            try graphError(.frontierLimitExceeded(limit: 0)) { _ = try graph.breadthFirst(fromNode: 0, maximumFrontier: 0) }
            try graphError(.resultLimitExceeded(limit: 0)) { _ = try graph.outgoingEdges(of: 0, maximumResults: 0) }
            let empty = try JSONGraphProjection.build(document: doc(#"{"nodes":[],"edges":[]}"#), profile: profile, maximumNodes: 0, maximumEdges: 0).result
            try check(empty.nodeCount == 0 && empty.edgeCount == 0, id)
            do { _ = try graph.breadthFirst(fromNode: 0, maximumResults: -1); throw CheckFailure.failed(id) }
            catch let failure as JSONFailure { try check(failure.code == .invalidLimits, id) }
        case 11:
            let graph = try build().result, baseline = try graph.breadthFirst(fromNode: 0)
            var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
            try check(try graph.breadthFirst(fromNode: 0, limits: limits).statistics[.workUnits] == baseline.statistics[.workUnits], id)
            limits[.workUnits] -= 1
            try resource(.workUnits) { _ = try graph.breadthFirst(fromNode: 0, limits: limits) }
            try check(try graph.breadthFirst(fromNode: 0).result == [0,2,1], id)
        case 12:
            let result = try build(), graph = result.result, row = try graph.nodeValue(at: 0)
            try check(graph.document.sourceBytes == doc().sourceBytes && result.statistics[.retainedBytes] > 0 && row.statistics[.retainedBytes] > 0, id)
            let number = try row.result.requiredMember("n").numberValue
            try check(try number?.integer(as: UInt64.self) == 9_007_199_254_740_993, id)
            try check(try graph.edgeValue(at: 0).result == JSONPointer(parsing: "/edges/0").resolve(in: graph.document.root), id)
        case 13:
            let graph = try build().result
            let task = Task {
                withUnsafeCurrentTask { $0?.cancel() }
                do { _ = try graph.breadthFirst(fromNode: 0); throw CheckFailure.failed(id) } catch is CancellationError {}
                do { _ = try build(); throw CheckFailure.failed(id) } catch is CancellationError {}
            }
            try await task.value
            try check(try graph.breadthFirst(fromNode: 0).result == [0,2,1], id)
        case 14:
            let graph = try build().result
            try await withThrowingTaskGroup(of: [Int].self) { group in
                for _ in 0..<8 { group.addTask {
                    try graphError(.resultLimitExceeded(limit: 1)) { _ = try graph.breadthFirst(fromNode: 0, maximumResults: 1) }
                    return try graph.breadthFirst(fromNode: 0).result
                } }
                for try await result in group { try check(result == [0,2,1], id) }
            }
        case 15:
            let original = try doc(), graph = try JSONGraphProjection.build(document: original, profile: profile).result
            let replacement = original.replacingRoot(try JSON.parse(#"{"nodes":[{"id":"new"}],"edges":[]}"#))
            let next = try JSONGraphProjection.build(document: replacement, profile: profile).result
            try check(try graph.nodeSpan(at: 0).result != nil && next.nodeSpan(at: 0).result == nil, id)
            try check(graph.nodeCount == 4 && next.nodeCount == 1 && graph.document.root == original.root, id)
        case 16:
            // The selected graph is tiny, but an unselected subtree still undergoes core admission.
            let invalid = JSONDocument(root: .object(try JSONObject(members: [JSONMember("nodes", value: .array([])),JSONMember("edges", value: .array([])),JSONMember("unselected", value: .string(String(repeating: "x", count: 32)))])))
            var limits = JSONLimits.balanced; limits[.stringBytes] = 16
            try resource(.stringBytes) { _ = try JSONGraphProjection.build(document: invalid, profile: profile, limits: limits) }
        default: throw CheckFailure.failed(id)
        }
    }
}

@main struct GraphPublicConsumer {
    static func main() async throws {
        for id in 1...16 {
            try await GraphPublicCases.run(id)
            print("GRAPH_PUBLIC_CHECK GP\(String(format: "%02d", id)) passed")
        }
        let report = try GraphPublicCases.build()
        print("GRAPH_PUBLIC_RESOURCE work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes) nodes=\(report.statistics[.nodes])")
        print("GRAPH_PUBLIC_CONSUMER passed cases=16")
    }
}
