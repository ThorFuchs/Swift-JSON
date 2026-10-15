// SPDX-License-Identifier: Apache-2.0
// Compiled as an external module by Scripts/qualify_navigation.py; no private imports.
import Foundation
import JSON
import JSONNavigation

@main struct NavigationConsumer {
    static func main() throws {
        var checks = 0
        func check(_ id: String, _ condition: Bool) {
            precondition(condition, id); checks += 1
            print("NAVIGATION_CHECK \(id) passed")
        }
        let text = #"{"":"empty","0":"key","items":[{"n":9007199254740993},null],"é":1,"e\u0301":2,"null":null}"#
        let root = try JSONParser().parse(text)
        // BEFORE: the core continues to own one-node lookup and native projection.
        let whole = try JSONPointer(parsing: "").resolve(in: root)
        let empty = try JSONPointer(parsing: "/").resolve(in: root)
        check("root-empty-key", whole == root && empty == .string("empty"))
        let keyPath: [JSONLocationComponent] = [.key("0")]
        let indexPath: [JSONLocationComponent] = [.index(0)]
        check("typed-key-index", keyPath != indexPath)
        let presence = try root.read { cursor in
            (try cursor.presence(of: "null"), try cursor.presence(of: "absent"))
        }
        check("presence", presence.0 == .null && presence.1 == .absent)
        check("scalar-keys", root.objectValue!.count == 6)
        let count = try root.read { try $0["items"][0]["n"].requiredInteger(as: UInt64.self) }
        check("native-exact", count == 9_007_199_254_740_993)

        // AFTER: one many-node operation, exact metadata and unchanged source values.
        let traversal = JSONTraversal(document: JSONDocument(root: root))
        var parity = true
        let visit = try traversal.visit { hit, value in
            let tokens = hit.absoluteLocation.map { part in
                switch part { case .key(let key): return key.string; case .index(let i): return String(i) }
            }
            let selected = try JSONPointer(tokens: tokens).resolve(in: root)
            parity = parity && selected == value
            return .continue
        }
        check("pointer-parity", parity && visit.result.visitedCount == 10)
        let collected = try traversal.collect()
        check("metadata-collection", collected.result.nodes.count == 10 && collected.result.summary.completion == .complete)
        let path: [JSONLocationComponent] = [.key("items"), .index(0)]
        let repeated = try traversal.collect(scope: .virtual(roots: [path,path], overlap: .orderedOccurrences))
        check("ordered-occurrences", repeated.result.nodes.map(\.scopeRootIndex) == [0,0,1,1])
        let unique = try traversal.collect(scope: .virtual(roots: [path,path], overlap: .uniquePhysicalNodes))
        check("unique-paths", unique.result.nodes.count == 2 && unique.result.summary.deduplicatedCount == 2)
        var ambiguous = false
        do { _ = try traversal.collect(scope: .virtual(roots: [path,path])) }
        catch JSONTraversalFailure.ambiguousRoots(first: 0, second: 1) { ambiguous = true }
        check("default-overlap-rejection", ambiguous)
        var missing = false
        do { _ = try traversal.collect(scope: .subtree(at: [.key("missing")])) }
        catch let error as JSONAccessFailure { missing = error.cause.category == .missingValue }
        check("typed-missing", missing)
        let filtered = try traversal.collect(options: .init(emitKinds: []), maximumRecords: 0)
        check("complete-empty-filter", filtered.result.nodes.isEmpty && filtered.result.summary.completion == .complete && filtered.result.summary.visitedCount == 10)
        var capacity = false
        do { _ = try traversal.collect(maximumRecords: 0) }
        catch JSONTraversalFailure.collectionLimitExceeded(limit: 0) { capacity = true }
        check("collection-limit", capacity)
        check("cumulative-report", collected.statistics[.nodes] == 10 && collected.statistics[.workUnits] > 0 && collected.statistics.domain == .core)
        let document = try JSONParser().parseDocument(Data(text.utf8))
        let spans = try JSONTraversal(document: document).collect(options: .init(includeSourceSpans: true))
        check("coherent-spans", spans.result.nodes.allSatisfy { $0.sourceSpan != nil })
        let replaced = try JSONTraversal(document: document.replacingRoot(.null)).collect(options: .init(includeSourceSpans: true))
        check("replacement-invalidates-spans", replaced.result.nodes[0].sourceSpan == nil)
        let stop = try traversal.visit { _, _ in .stop }
        check("intentional-stop", stop.result.completion == .visitorStopped && stop.result.visitedCount == 1)
        var limits = JSONLimits.balanced; limits[.workUnits] = collected.statistics[.workUnits] - 1
        var quota = false
        do { _ = try JSONTraversal(document: traversal.document, limits: limits).collect() }
        catch let error as JSONFailure { quota = error.resource?.metric == .workUnits }
        check("cumulative-quota", quota)
        print("NAVIGATION_RESOURCE work=\(collected.statistics[.workUnits]) retained=\(collected.statistics[.retainedBytes]) peak=\(collected.statistics.peakLogicalRetainedBytes) nodes=\(collected.statistics[.nodes])")
        print("NAVIGATION_CONSUMER passed cases=\(checks)")
    }
}
