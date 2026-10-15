// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONNavigation

private func navigationFailure(_ body: () throws -> Void) -> JSONFailure? {
    do { try body(); Issue.record("Expected a structured core failure"); return nil }
    catch let error as JSONFailure { return error }
    catch let error as JSONAccessFailure { return error.cause }
    catch { Issue.record("Unexpected failure type: \(type(of: error))"); return nil }
}

@Test func navigationAllScalarAndEmptyContainerRoots() throws {
    for value: JSON in [.null, .boolean(true), .number(1), .string(""), .array([]), .object(try JSONObject())] {
        let walk = JSONTraversal(document: .init(root: value))
        let report = try walk.collect()
        #expect(report.result.nodes.count == 1 && report.result.nodes[0].absoluteLocation.isEmpty)
        #expect(report.result.summary.completion == .complete)
        #expect(try walk.collect(options: .init(includeScopeRoot: false)).result.nodes.isEmpty)
    }
}

@Test func navigationDepthZeroChildrenOnlyAndLeafCoverage() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":{"b":1},"c":2}"#)))
    let zero = try walk.collect(options: .init(depthLimit: 0))
    #expect(zero.result.nodes.count == 1 && zero.result.summary.depthLimitedSubtrees == 1)
    #expect(zero.result.summary.completion == .restricted)
    let children = try walk.collect(options: .init(depthLimit: 1, includeScopeRoot: false))
    #expect(children.result.nodes.map(\.absoluteLocation) == [[.key("a")], [.key("c")]])
    let leaf = try walk.visit(scope: .subtree(at: [.key("c")]), options: .init(depthLimit: 0)) { _, _ in .skipDescendants }
    #expect(leaf.result.completion == .complete && leaf.result.prunedSubtrees == 0)
}

@Test func navigationStrictFailureCategoriesAndNoCallbacks() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":[null]}"#)))
    let cases: [([JSONLocationComponent], JSONFailure.Category, JSONFailure.Code)] = [
        ([.key("missing")], .missingValue, .missingMember),
        ([.index(0)], .typeMismatch, .wrongKind),
        ([.key("a"), .key("0")], .typeMismatch, .wrongKind),
        ([.key("a"), .index(-1)], .configuration, .invalidIndex),
        ([.key("a"), .index(1)], .missingValue, .missingTarget),
        ([.key("a"), .index(0), .key("x")], .typeMismatch, .wrongKind)
    ]
    for (path, category, code) in cases {
        var calls = 0
        let failure = navigationFailure { _ = try walk.visit(scope: .subtree(at: path)) { _, _ in calls += 1; return .continue } }
        #expect(failure?.category == category && failure?.code == code && calls == 0)
    }
}

@Test func navigationEmptyEmissionIsCompleteAndNotMissing() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"a":[1,null]}"#)))
    let report = try walk.collect(options: .init(emitKinds: []), maximumRecords: 0)
    #expect(report.result.nodes.isEmpty && report.result.summary.visitedCount == 4)
    #expect(report.result.summary.completion == .complete)
    #expect(navigationFailure { _ = try walk.collect(scope: .subtree(at: [.key("missing")]), options: .init(emitKinds: [])) }?.category == .missingValue)
}

@Test func navigationInsertionOrderIsIndependentOfValueEquality() throws {
    let first = try JSON.parse(#"{"z":1,"a":2}"#), second = try JSON.parse(#"{"a":2,"z":1}"#)
    #expect(first == second)
    let a = try JSONTraversal(document: .init(root: first)).collect().result.nodes.map(\.absoluteLocation)
    let b = try JSONTraversal(document: .init(root: second)).collect().result.nodes.map(\.absoluteLocation)
    #expect(a == [[], [.key("z")], [.key("a")]])
    #expect(b == [[], [.key("a")], [.key("z")]])
}

@Test func navigationPreservesExactDecimalsAndText() throws {
    let root = try JSON.parse(#"[9007199254740993,0.1,1,1.0,1e0,"é","e\u0301"]"#)
    var values: [JSON] = []
    _ = try JSONTraversal(document: .init(root: root)).visit(options: .init(includeScopeRoot: false)) { _, value in values.append(value); return .continue }
    #expect(values[0].numberValue == (try JSONNumber(parsing: "9007199254740993")))
    #expect(values[1].numberValue == (try JSONNumber(parsing: "0.1")))
    #expect(values[2] == values[3] && values[3] == values[4])
    #expect(values[3].numberValue?.originalLexeme == "1.0")
    #expect(values[4].numberValue?.originalLexeme == "1e0")
    #expect(values[5] != values[6])
}

@Test func navigationSubtreeMetamorphismAndDeterminism() throws {
    let root = try JSON.parse(#"{"x":[{"":"a","a/b":[]},{"~":{},".[]":0}],"y":1}"#)
    let walk = JSONTraversal(document: .init(root: root))
    let all = try walk.collect().result.nodes
    for path: [JSONLocationComponent] in [[], [.key("x")], [.key("x"), .index(0)], [.key("x"), .index(1), .key("~")]] {
        let subset = try walk.collect(scope: .subtree(at: path)).result.nodes
        let expected = all.filter { $0.absoluteLocation.starts(with: path) }.map(\.absoluteLocation)
        #expect(subset.map(\.absoluteLocation) == expected)
        #expect(subset.map(\.relativeDepth) == subset.map { $0.absoluteLocation.count - path.count })
        #expect(try walk.collect(scope: .subtree(at: path)).result.nodes == subset)
    }
}

@Test func navigationMappedAndReplacedSourceCoherence() throws {
    let source = try JSONParser().parseDocument(Data(#"{"a/b": [1.0, null], "é":2,"e\u0301":3}"#.utf8), source: "synthetic")
    let original = JSONTraversal(document: source)
    let mapped = try original.collect(options: .init(includeSourceSpans: true))
    for hit in mapped.result.nodes {
        #expect(hit.sourceSpan == (try source.sourceMap?.span(at: hit.absoluteLocation)))
        #expect(hit.sourceSpan != nil)
    }
    let rewritten = source.replacingRoot(.array([.null]))
    let new = try JSONTraversal(document: rewritten).collect(options: .init(includeSourceSpans: true))
    #expect(new.result.nodes.allSatisfy { $0.sourceSpan == nil })
    #expect(original.document.root == source.root && original.document.sourceBytes != nil)
    #expect(rewritten.sourceMap == nil && rewritten.sourceBytes == nil && rewritten.source == nil)
    #expect(try original.collect(options: .init(includeSourceSpans: true)).result.nodes == mapped.result.nodes)
}

@Test func navigationDeepIterativeWalkAndFullAdmission() throws {
    var value = JSON.null
    for _ in 0..<200 { value = .array([value]) }
    var limits = JSONLimits.balanced; limits[.maxDepth] = 256; limits[.pointerTokens] = 256
    let report = try JSONTraversal(document: .init(root: value), limits: limits).collect()
    #expect(report.result.nodes.count == 201 && report.result.summary.maximumDepthVisited == 200)
    let failure = navigationFailure { _ = try JSONTraversal(document: .init(root: value)).collect(options: .init(depthLimit: 0)) }
    #expect(failure?.resource?.metric == .maxDepth)
}

@Test func navigationWideObjectDoesNotSortOrLoseKeys() throws {
    let members = (0..<1000).map { JSONMember(JSONKey("k\(999 - $0)"), value: .number(JSONNumber(integer: $0))) }
    let root = JSON.object(try JSONObject(members: members))
    let report = try JSONTraversal(document: .init(root: root)).collect()
    #expect(report.result.nodes.dropFirst().map(\.absoluteLocation) == members.map { [.key($0.key)] })
    #expect(report.result.summary.visitedCount == 1001 && report.statistics[.nodes] == 1001)
}

@Test func navigationCallerErrorsPropagateAndCopiesAreCallerOwned() throws {
    enum Caller: Error { case witness }
    let walk = JSONTraversal(document: .init(root: .array([1,2])))
    #expect(throws: Caller.witness) { try walk.visit { _, _ in throw Caller.witness } }
    var retained: [JSONTraversalHit] = []
    let report = try walk.visit { hit, _ in retained.append(hit); return .continue }
    #expect(retained.count == 3 && report.statistics[.retainedBytes] == 0)
}

@Test func navigationCollectionBoundaryAndInvalidPolicies() throws {
    let walk = JSONTraversal(document: .init(root: .array([1,2])))
    #expect(try walk.collect(maximumRecords: 3).result.nodes.count == 3)
    #expect(throws: JSONTraversalFailure.collectionLimitExceeded(limit: 2)) { try walk.collect(maximumRecords: 2) }
    #expect(throws: JSONTraversalFailure.collectionLimitExceeded(limit: 0)) { try walk.collect(maximumRecords: 0) }
    #expect(navigationFailure { _ = try walk.collect(maximumRecords: -1) }?.category == .configuration)
    #expect(navigationFailure { _ = try walk.collect(options: .init(depthLimit: -1)) }?.category == .configuration)
}

@Test func navigationRetainedOutputAndInclusivePeak() throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"long/key":[1,2]}"#)))
    let report = try walk.collect()
    let expected: UInt64 = report.result.nodes.reduce(0) { total, hit in
        total + 64 + hit.absoluteLocation.reduce(UInt64(0)) { n, part in
            switch part { case .key(let key): return n + 32 + UInt64(key.string.utf8.count); case .index: return n + 32 }
        }
    }
    #expect(report.statistics[.retainedBytes] == expected)
    var limits = JSONLimits.balanced; limits[.retainedBytes] = report.statistics.peakLogicalRetainedBytes
    #expect(try JSONTraversal(document: walk.document, limits: limits).collect().statistics.peakLogicalRetainedBytes == limits[.retainedBytes])
    limits[.retainedBytes] -= 1
    #expect(navigationFailure { _ = try JSONTraversal(document: walk.document, limits: limits).collect() }?.resource?.metric == .retainedBytes)
}

@Test func navigationCorePathNodeAndWorkBounds() throws {
    let document = JSONDocument(root: .array([.null]))
    var limits = JSONLimits.balanced; limits[.pointerTokens] = 0
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect() }?.resource?.metric == .pointerTokens)
    #expect(try JSONTraversal(document: document, limits: limits).collect(options: .init(depthLimit: 0)).result.nodes.count == 1)
    limits = .balanced; limits[.pointerBytes] = 1
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect() }?.resource?.metric == .pointerBytes)
    limits = .balanced; limits[.nodes] = 1
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect(options: .init(depthLimit: 0)) }?.resource?.metric == .nodes)
    limits = .balanced; limits[.workUnits] = 0
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect() }?.resource?.metric == .workUnits)
}

@Test func navigationCancellationBeforeAdmission() async {
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try JSONTraversal(document: .init(root: .null)).collect()
    }
    do { _ = try await task.value; Issue.record("Cancelled admission succeeded") }
    catch { #expect(error is CancellationError) }
}

@Test func navigationCancellationAfterVisitorCannotBecomeStop() async {
    let task = Task {
        try JSONTraversal(document: .init(root: .array([1,2]))).visit { _, _ in
            withUnsafeCurrentTask { $0?.cancel() }
            return .stop
        }
    }
    do { _ = try await task.value; Issue.record("Cancellation became successful stop") }
    catch { #expect(error is CancellationError) }
}

@Test func navigationCancellationInsideOwnedFilteredLoop() async throws {
    let document = JSONDocument(root: .array(Array(repeating: .null, count: 1000)))
    let admitted = try document.readWithReport { _ in () }.statistics[.workUnits]
    let task = Task {
        var walk = JSONTraversal(document: document)
        walk.checkpointObserver = { work in
            if work >= admitted + 100 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        return try walk.collect(options: .init(emitKinds: []))
    }
    do { _ = try await task.value; Issue.record("Owned filtered loop ignored cancellation") }
    catch { #expect(error is CancellationError) }
}

@Test func navigationSharedImmutableRootIndependentInvocations() async throws {
    let walk = JSONTraversal(document: .init(root: try JSON.parse(#"{"é":[1,2],"e\u0301":[3]}"#)))
    let expected = try walk.collect().result.nodes
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<12 {
            group.addTask { () async throws -> Void in
                let actual = try walk.collect().result.nodes
                #expect(actual == expected)
            }
        }
        try await group.waitForAll()
    }
}

@Test func navigationDocumentSourceAndSpanWorkAreCumulative() throws {
    let document = try JSONParser().parseDocument(Data(#"{"a":[1,2]}"#.utf8))
    let basic = try JSONTraversal(document: document).collect()
    let mapped = try JSONTraversal(document: document).collect(options: .init(includeSourceSpans: true))
    #expect(mapped.statistics[.workUnits] > basic.statistics[.workUnits])
    var limits = JSONLimits.balanced; limits[.inputBytes] = UInt64(document.sourceBytes!.count)
    #expect(try JSONTraversal(document: document, limits: limits).collect().result.nodes.count == 4)
    limits[.inputBytes] -= 1
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect() }?.resource?.metric == .inputBytes)
    limits = .balanced; limits[.workUnits] = basic.statistics[.workUnits]
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect(options: .init(includeSourceSpans: true)) }?.resource?.metric == .workUnits)
}

@Test func navigationFailedInvocationDoesNotPoisonFreshWork() throws {
    let document = JSONDocument(root: .array([1,2]))
    var limits = JSONLimits.balanced; limits[.workUnits] = 1
    #expect(navigationFailure { _ = try JSONTraversal(document: document, limits: limits).collect() }?.category == .resource)
    #expect(try JSONTraversal(document: document).collect().result.summary.completion == .complete)
}
