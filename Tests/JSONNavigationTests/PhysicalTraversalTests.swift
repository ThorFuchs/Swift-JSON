// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONNavigation

@Test func navigationPhysicalPreorderAndTypedAuthority() throws {
    let root = try JSON.parse(#"{"":"empty","0":"key","items":[{"a/b":9007199254740993},null],"é":1,"e\u0301":2}"#)
    let walk = JSONTraversal(document: .init(root: root))
    var paths: [[JSONLocationComponent]] = []
    let report = try walk.visit { hit, value in
        paths.append(hit.absoluteLocation)
        let tokens = hit.absoluteLocation.map { part in
            switch part { case .key(let k): return k.string; case .index(let i): return String(i) }
        }
        #expect(try JSONPointer(tokens: tokens).resolve(in: root) == value)
        let read = try root.read { cursor in
            var selected = cursor
            for part in hit.absoluteLocation {
                switch part { case .key(let k): selected = try selected[k]; case .index(let i): selected = try selected[i] }
            }
            return try selected.requiredValue()
        }
        #expect(read == value)
        return .continue
    }
    #expect(paths == [[], [.key("")], [.key("0")], [.key("items")], [.key("items"), .index(0)], [.key("items"), .index(0), .key("a/b")], [.key("items"), .index(1)], [.key("é")], [.key("e\u{301}")]])
    #expect(report.result.completion == .complete)
    #expect(report.result.visitedCount == 9)
    #expect(report.statistics[.nodes] == 9) // exactly one root admission
    #expect(report.statistics[.retainedBytes] == 0)
}

@Test func navigationPhysicalScalarAndStrictFailures() throws {
    let scalar = JSONTraversal(document: .init(root: .null))
    #expect(try scalar.collect().result.nodes.count == 1)
    #expect(try scalar.collect(options: .init(includeScopeRoot: false)).result.nodes.isEmpty)
    let root = try JSON.parse(#"{"x":null,"a":[1]}"#)
    let walk = JSONTraversal(document: .init(root: root))
    #expect(try walk.collect(scope: .subtree(at: [.key("x")])).result.nodes.first?.kind == .null)
    for path: [JSONLocationComponent] in [[.key("missing")], [.key("a"), .key("0")], [.key("a"), .index(-1)], [.key("a"), .index(1)], [.key("x"), .key("z")]] {
        #expect(throws: (any Error).self) { try walk.collect(scope: .subtree(at: path)) }
    }
}

@Test func navigationPhysicalPoliciesDoNotConflateCoverage() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":[1,2],"b":3}"#)))
    let filtered = try walk.collect(options: .init(emitKinds: [.number]))
    #expect(filtered.result.summary.visitedCount == 5 && filtered.result.nodes.count == 3)
    #expect(filtered.result.summary.completion == .complete)
    let shallow = try walk.collect(options: .init(depthLimit: 1, includeScopeRoot: false))
    #expect(shallow.result.nodes.count == 2 && shallow.result.summary.completion == .restricted)
    let stopped = try walk.visit { _, _ in .stop }
    #expect(stopped.result.completion == .visitorStopped && stopped.result.visitedCount == 1)
    let pruned = try walk.visit { hit, _ in hit.absoluteLocation == [.key("a")] ? .skipDescendants : .continue }
    #expect(pruned.result.visitedCount == 3 && pruned.result.prunedSubtrees == 1)
}

@Test func navigationOneLedgerAdmissionSelectionAndCollection() throws {
    let root = try JSON.parse(#"{"a":[1,2]}"#)
    let full = try JSONTraversal(document: .init(root: root)).collect(scope: .subtree(at: [.key("a")]))
    let used = full.statistics[.workUnits]
    var exact = JSONLimits.balanced; exact[.workUnits] = used
    #expect(try JSONTraversal(document: .init(root: root), limits: exact).collect(scope: .subtree(at: [.key("a")])).statistics[.workUnits] == used)
    exact[.workUnits] = used - 1
    #expect(throws: JSONFailure.self) { try JSONTraversal(document: .init(root: root), limits: exact).collect(scope: .subtree(at: [.key("a")])) }
    #expect(throws: JSONTraversalFailure.collectionLimitExceeded(limit: 2)) { try JSONTraversal(document: .init(root: root)).collect(maximumRecords: 2) }
    #expect(full.statistics[.nodes] == 4 && full.statistics[.retainedBytes] > 0)
}
