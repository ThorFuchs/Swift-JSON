// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONNavigation

@Test func navigationVirtualRejectsAmbiguityBeforeCallbacks() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":{"b":1},"c":1}"#)))
    for roots: [[JSONLocationComponent]] in [[[.key("a")], [.key("a")]], [[.key("a")], [.key("a"), .key("b")]], [[], [.key("c")]]] {
        var calls = 0
        #expect(throws: JSONTraversalFailure.ambiguousRoots(first: 0, second: 1)) {
            try walk.visit(scope: .virtual(roots: roots)) { _, _ in calls += 1; return .continue }
        }
        #expect(calls == 0)
    }
}

@Test func navigationVirtualOrderedRepeatsRetainOriginAndDepth() throws {
    let document = JSONDocument(root: try JSON.parse(#"{"a":{"b":1},"c":1}"#))
    let report = try JSONTraversal(document: document).collect(scope: .virtual(roots: [[.key("a")], [.key("a"), .key("b")], [.key("a")]], overlap: .orderedOccurrences))
    #expect(report.result.nodes.map(\.scopeRootIndex) == [0,0,1,2,2])
    #expect(report.result.nodes.map(\.relativeDepth) == [0,1,0,0,1])
    #expect(report.result.nodes.map(\.occurrenceIndex) == [0,1,2,3,4])
    #expect(report.result.summary.visitedCount == 5 && report.result.summary.deduplicatedCount == 0)
    #expect(report.statistics[.nodes] == 4) // input admission is not restarted for each root
}

@Test func navigationVirtualUniqueUsesPathsRatherThanEqualValues() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":1,"b":1,"é":1,"e\u0301":1}"#)))
    let report = try walk.collect(scope: .virtual(roots: [[.key("a")], [], [.key("a")]], overlap: .uniquePhysicalNodes))
    #expect(report.result.nodes.map(\.absoluteLocation) == [[.key("a")], [], [.key("b")], [.key("é")], [.key("e\u{301}")]])
    #expect(report.result.nodes.map(\.scopeRootIndex) == [0,1,1,1,1])
    #expect(report.result.summary.deduplicatedCount == 2 && report.result.summary.visitedCount == 7)
    #expect(report.result.summary.completion == .complete)
}

@Test func navigationVirtualExactUnicodeAndSiblingRootsAreUnambiguous() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"é":1,"e\u0301":2,"0":3,"a":[4]}"#)))
    let report = try walk.collect(scope: .virtual(roots: [[.key("é")], [.key("e\u{301}")], [.key("0")], [.key("a"), .index(0)]]))
    #expect(report.result.nodes.count == 4 && report.result.summary.completion == .complete)
}

@Test func navigationVirtualValidatesEveryRootBeforeAnyCallback() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":1}"#)))
    for policy: JSONScopeOverlapPolicy in [.rejectAmbiguous, .orderedOccurrences, .uniquePhysicalNodes] {
        var calls = 0
        do {
            _ = try walk.visit(scope: .virtual(roots: [[.key("a")], [.key("missing")]], overlap: policy)) { _, _ in calls += 1; return .continue }
            Issue.record("Missing virtual root accepted")
        } catch let error as JSONAccessFailure { #expect(error.cause.category == .missingValue) }
        #expect(calls == 0)
    }
}

@Test func navigationVirtualEmptySelectionIsCompleteAfterAdmission() throws {
    let report = try JSONTraversal(document: .init(root: .array([1,2]))).collect(scope: .virtual(roots: []), maximumRecords: 0)
    #expect(report.result.nodes.isEmpty && report.result.summary.scopeRootCount == 0)
    #expect(report.result.summary.completion == .complete && report.statistics[.nodes] == 3)
}

@Test func navigationVirtualUniqueDoesNotPruneRevisitedFrontier() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":{"b":{"c":1}}}"#)))
    let report = try walk.collect(scope: .virtual(roots: [[], [.key("a")]], overlap: .uniquePhysicalNodes), options: .init(depthLimit: 2))
    #expect(report.result.nodes.map(\.absoluteLocation) == [[], [.key("a")], [.key("a"), .key("b")], [.key("a"), .key("b"), .key("c")]])
    #expect(report.result.nodes.last?.relativeDepth == 2 && report.result.nodes.last?.scopeRootIndex == 1)
    #expect(report.result.summary.depthLimitedSubtrees == 1 && report.result.summary.completion == .restricted)
}

@Test func navigationVirtualComparisonAndCollectionShareExactBudget() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":[1,2],"b":[3,4]}"#)))
    let selection = JSONTraversalScope.virtual(roots: [[.key("a")], [.key("b")]])
    let baseline = try walk.collect(scope: selection)
    var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
    #expect(try JSONTraversal(document: walk.document, limits: limits).collect(scope: selection).statistics == baseline.statistics)
    limits[.workUnits] -= 1
    do { _ = try JSONTraversal(document: walk.document, limits: limits).collect(scope: selection); Issue.record("Work quota reset") }
    catch let error as JSONFailure { #expect(error.resource?.metric == .workUnits) }
    #expect(try walk.collect(scope: selection).result.nodes == baseline.result.nodes)
}

@Test func navigationVirtualUniqueFilteredRootFirstOccurrenceWins() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":1}"#)))
    let report = try walk.collect(scope: .virtual(roots: [[.key("a")], []], overlap: .uniquePhysicalNodes), options: .init(includeScopeRoot: false))
    #expect(report.result.nodes.isEmpty && report.result.summary.deduplicatedCount == 1)
    #expect(report.result.summary.completion == .complete)
}

@Test func navigationVirtualOverlapComparisonCannotHideWork() throws {
    let keys = (0..<60).map { JSONKey(String(repeating: "x", count: 120) + String($0)) }
    let members = keys.map { JSONMember($0, value: .null) }
    let document = JSONDocument(root: .object(try JSONObject(members: members)))
    let roots = keys.map { [JSONLocationComponent.key($0)] }
    let options = JSONTraversalOptions(depthLimit: 0, emitKinds: [])
    let baseline = try JSONTraversal(document: document).collect(scope: .virtual(roots: roots, overlap: .orderedOccurrences), options: options)
    var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
    do {
        _ = try JSONTraversal(document: document, limits: limits).collect(scope: .virtual(roots: roots), options: options)
        Issue.record("Pairwise exact comparisons escaped the cumulative quota")
    } catch let error as JSONFailure { #expect(error.resource?.metric == .workUnits) }
}
