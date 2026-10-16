// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
import JSONInspection

private func snapshot(_ text: String) throws -> JSONStructuralSnapshot {
    try JSONStructuralSnapshotBuilder(document: JSONParser().parseDocument(Data(text.utf8))).build().result
}
private func snapshotFailure(_ body: () throws -> Void) -> JSONFailure? {
    do { try body(); Issue.record("Expected resource failure") }
    catch let error as JSONFailure { return error }
    catch { Issue.record("Unexpected failure: \(error)") }
    return nil
}

@Test func snapshotS01ScalarAndEmptyRootsAreRealRecords() throws {
    for text in ["null", "false", "1", #""s""#, "[]", "{}"] {
        let result = try snapshot(text), root = try result.record(at: 0)
        #expect(result.recordCount == 1 && root.parentOrdinal == nil && root.componentFromParent == nil)
        #expect(root.ordinal == 0 && root.depth == 0 && root.childCount == 0 && root.subtreeEndExclusive == 1)
        #expect(try result.location(for: 0).result.isEmpty)
        #expect(try result.value(for: 0).result == result.document.root)
    }
}

@Test func snapshotS02RootEmptyAndNumericKeysRemainDistinct() throws {
    let result = try snapshot(#"{"":1,"0":2}"#)
    #expect(try result.location(for: 0).result == [])
    #expect(try result.location(for: 1).result == [.key("")])
    #expect(try result.location(for: 2).result == [.key("0")])
    #expect(try result.record(at: 2).componentFromParent != .index(0))
}

@Test func snapshotS03NestedArrayPositionsIncreaseFromZero() throws {
    let result = try snapshot("[[null,false],[]]")
    let paths = try (0..<result.recordCount).map { try result.location(for: $0).result }
    #expect(paths == [[], [.index(0)], [.index(0),.index(0)], [.index(0),.index(1)], [.index(1)]])
}

@Test func snapshotS04ScalarDistinctKeysKeepSeparateEdges() throws {
    let result = try snapshot(#"{"é":1,"e\u0301":2}"#)
    #expect(result.recordCount == 3)
    #expect(try result.location(for: 1).result == [.key("é")])
    #expect(try result.location(for: 2).result == [.key("e\u{301}")])
    #expect(try result.record(at: 1).componentFromParent != result.record(at: 2).componentFromParent)
}

@Test func snapshotS05NumbersRemainInCanonicalSource() throws {
    let result = try snapshot("[9007199254740993,0.1,0.0100]")
    #expect(try result.value(for: 1).result.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
    #expect(try result.value(for: 2).result.numberValue == JSONNumber(parsing: "0.1"))
    #expect(try result.value(for: 3).result.numberValue?.originalLexeme == "0.0100")
}

@Test func snapshotS06DecodedDuplicateKeysFailBeforeBuild() throws {
    #expect(throws: JSONFailure.self) { _ = try snapshot(#"{"a":1,"\u0061":2}"#) }
    #expect(try snapshot(#"{"é":1,"e\u0301":2}"#).recordCount == 3)
}

@Test func snapshotS07ParentAndDepthInvariants() throws {
    let result = try snapshot(#"{"a":[{"b":[]},null],"c":{}}"#)
    for ordinal in 1..<result.recordCount {
        let record = try result.record(at: ordinal), parent = try #require(record.parentOrdinal)
        #expect(parent < ordinal)
        #expect(try result.record(at: parent).depth + 1 == record.depth)
        #expect(record.componentFromParent != nil)
    }
}

@Test func snapshotS08PreorderIsReproducible() throws {
    let text = #"{"z":[1,2],"a":{"x":null}}"#
    let first = try snapshot(text), second = try snapshot(text)
    let expected: [[JSONLocationComponent]] = [[], [.key("z")], [.key("z"),.index(0)], [.key("z"),.index(1)], [.key("a")], [.key("a"),.key("x")]]
    for ordinal in expected.indices {
        #expect(try first.record(at: ordinal).ordinal == ordinal)
        #expect(try first.location(for: ordinal).result == expected[ordinal])
        #expect(try second.location(for: ordinal).result == expected[ordinal])
    }
}

@Test func snapshotS09RangesCloseAtTheNextSibling() throws {
    let result = try snapshot(#"{"a":[1,{"x":2}],"b":[],"c":[3]}"#)
    #expect(try (0..<result.recordCount).map { try result.record(at: $0).subtreeEndExclusive } == [8,5,3,5,5,6,8,8])
    #expect(try (0..<result.recordCount).map { try result.record(at: $0).childCount } == [3,2,0,1,0,0,1,0])
}

@Test func snapshotS10EveryHitResolvesThroughCorePointer() throws {
    let result = try snapshot(#"{"/":{"~":[0,{"":false}]},"0":null}"#)
    for ordinal in 0..<result.recordCount {
        let path = try result.location(for: ordinal).result
        let pointer = try JSONPointer(tokens: path.map {
            switch $0 { case .key(let key): key.string; case .index(let i): String(i) }
        })
        #expect(try pointer.resolve(in: result.document.root) == result.value(for: ordinal).result)
    }
}

@Test func snapshotS11MappedSpansUseCapturedSource() throws {
    let result = try snapshot(" [ 1 , {\"a\" : null} ] ")
    for ordinal in 0..<result.recordCount {
        let path = try result.location(for: ordinal).result
        #expect(try result.sourceSpan(for: ordinal).result == result.document.sourceMap?.span(at: path))
        #expect(try result.sourceSpan(for: ordinal).result != nil)
    }
}

@Test func snapshotS12ReplacementHasNoHistoricalMap() throws {
    let original = try snapshot("[1,2]")
    let replacement = try JSONStructuralSnapshotBuilder(document: original.document.replacingRoot(.null)).build().result
    #expect(replacement.recordCount == 1 && replacement.document.sourceBytes == nil)
    #expect(try replacement.sourceSpan(for: 0).result == nil)
    #expect(try original.sourceSpan(for: 1).result != nil)
}

@Test func snapshotS13OldSnapshotRetainsItsExactRoot() throws {
    let old = try snapshot(#"{"n":9007199254740993}"#)
    let fresh = try JSONStructuralSnapshotBuilder(document: old.document.replacingRoot(.array([.null]))).build().result
    #expect(try old.location(for: 1).result == [.key("n")])
    #expect(try old.value(for: 1).result.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
    #expect(try fresh.location(for: 1).result == [.index(0)])
    #expect(try fresh.value(for: 1).result == .null)
}

@Test func snapshotS14OrdinalsAreInstanceLocalAndBoundsChecked() throws {
    let first = try snapshot("[1]"), second = try snapshot("[2]")
    // These are local array positions, not detached handles; no lookup accepts a document.
    #expect(try first.value(for: 1).result != second.value(for: 1).result)
    for invalid in [-1, 2, Int.max] {
        #expect(throws: JSONStructuralSnapshotFailure.ordinalOutOfBounds(invalid)) { _ = try first.record(at: invalid) }
        #expect(throws: JSONStructuralSnapshotFailure.ordinalOutOfBounds(invalid)) { _ = try first.location(for: invalid) }
        #expect(throws: JSONStructuralSnapshotFailure.ordinalOutOfBounds(invalid)) { _ = try first.value(for: invalid) }
    }
}

@Test func snapshotS15CompactOutputChargesSourceOnceAndEdgesOnly() throws {
    let document = try JSONParser().parseDocument(Data(#"{"long-key":[null,null]}"#.utf8))
    let admitted = try JSONReadScope(document, limits: .balanced)
    let sourceBytes = try admitted.check().meter.used(.retainedBytes); admitted.invalidate()
    let report = try JSONStructuralSnapshotBuilder(document: document).build()
    #expect(report.result.recordCount == 4)
    #expect(report.statistics[.retainedBytes] == sourceBytes + 128 + 4 * 96 + 8)
    #expect(report.statistics[.nodes] == 4)
}

@Test func snapshotS16EveryPhysicalNodeIsAlwaysIncluded() throws {
    let result = try snapshot(#"[{},[],null,{"a":[true,false]}]"#)
    #expect(result.recordCount == 8)
    #expect(try result.record(at: 0).subtreeEndExclusive == result.recordCount)
    #expect(try result.record(at: 0).childCount == 4)
    // Builder exposes no selection/filter/depth/prefix policy that could hide a node.
}

@Test func snapshotS17CapacityAndConfigurationNeverReturnPartial() throws {
    let document = JSONDocument(root: .array([.null,.null]))
    #expect(try JSONStructuralSnapshotBuilder(document: document).build(maximumRecords: 3).result.recordCount == 3)
    for bound in [0, 2] {
        #expect(throws: JSONStructuralSnapshotFailure.recordLimitExceeded(limit: bound)) {
            _ = try JSONStructuralSnapshotBuilder(document: document).build(maximumRecords: bound)
        }
    }
    var limits = JSONLimits.balanced; limits[.nodes] = 0
    #expect(snapshotFailure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build(maximumRecords: -1) }?.category == .configuration)
    #expect(snapshotFailure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build() }?.resource?.metric == .nodes)
}

@Test func snapshotS18TraversalAndFinalizationCancellationAreTerminal() async throws {
    var root = JSON.null
    for _ in 0..<16 { root = .array([root]) }
    let document = JSONDocument(root: root)
    var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
    let source = try JSONReadScope(document, limits: limits)
    let admissionWork = try source.check().meter.used(.workUnits); source.invalidate()
    let baseline = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build()
    for threshold in [admissionWork + 10, baseline.statistics[.workUnits] - 5] {
        let observed = Mutex(false), invalidated = Mutex(false)
        let task = Task { @Sendable [document, limits, threshold] in
            var builder = JSONStructuralSnapshotBuilder(document: document, limits: limits)
            builder.checkpointObserver = { work in
                if work >= threshold { observed.withLock { $0 = true }; withUnsafeCurrentTask { $0?.cancel() } }
            }
            builder.lifetimeObserver = { rootGone, stateGone in invalidated.withLock { $0 = rootGone && stateGone } }
            return try builder.build()
        }
        do { _ = try await task.value; Issue.record("No artifact may escape cancellation") }
        catch is CancellationError { }
        #expect(observed.withLock { $0 } && invalidated.withLock { $0 })
    }
}

@Test func snapshotS19NavigationParityAndIndependentInvocations() async throws {
    let document = try JSONParser().parseDocument(Data(#"{"rows":[{"a":null},{"b":1}]}"#.utf8))
    let traversal = JSONTraversal(document: document)
    let before = try traversal.collect()
    let builder = JSONStructuralSnapshotBuilder(document: document)
    let baseline = try builder.build()
    try await withThrowingTaskGroup(of: UInt64.self) { group in
        for _ in 0..<4 { group.addTask { try builder.build().statistics[.workUnits] } }
        for try await work in group { #expect(work == baseline.statistics[.workUnits]) }
    }
    let after = try traversal.collect()
    #expect(before.result.nodes.map(\.absoluteLocation) == after.result.nodes.map(\.absoluteLocation))
    #expect(before.statistics[.workUnits] == after.statistics[.workUnits])
    #expect(before.statistics[.retainedBytes] == after.statistics[.retainedBytes])
    #expect(try JSONShapeInspector(document: document).inspectArray(at: [.key("rows")]).result.rowCoverage == .complete)
}

@Test func snapshotS20OneOriginalAdmissionAndScopeRelease() throws {
    let document = try JSONParser().parseDocument(Data(#"{"a":[1,2]}"#.utf8))
    let ordinary = try JSONTraversal(document: document).visit { _, _ in .continue }
    let invalidated = Mutex(false)
    var builder = JSONStructuralSnapshotBuilder(document: document)
    builder.lifetimeObserver = { rootGone, stateGone in invalidated.withLock { $0 = rootGone && stateGone } }
    let result = try builder.build()
    #expect(result.statistics[.nodes] == ordinary.statistics[.nodes])
    #expect(result.statistics[.sourceMapEntries] == ordinary.statistics[.sourceMapEntries])
    #expect(invalidated.withLock { $0 })
    #expect(try result.result.value(for: 3).result == JSONParser().parse("2"))
}

@Test func snapshotS21InclusiveWorkAndRetentionBudgets() throws {
    let document = JSONDocument(root: .array([.null,.boolean(false)]))
    let baseline = try JSONStructuralSnapshotBuilder(document: document).build()
    var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
    #expect(try JSONStructuralSnapshotBuilder(document: document, limits: limits).build().result.recordCount == 3)
    limits[.workUnits] -= 1
    #expect(snapshotFailure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build() }?.resource?.attemptedUsage == baseline.statistics[.workUnits])
    limits = .balanced; limits[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try JSONStructuralSnapshotBuilder(document: document, limits: limits).build().statistics.peakLogicalRetainedBytes == limits[.retainedBytes])
    limits[.retainedBytes] -= 1
    #expect(snapshotFailure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build() }?.resource?.metric == .retainedBytes)
}

@Test func snapshotS22IterativeDepthAndBreadthStayFinite() throws {
    var deep = JSON.null
    for _ in 0..<128 { deep = .array([deep]) }
    let depth = try JSONStructuralSnapshotBuilder(document: JSONDocument(root: deep)).build()
    let wide = try JSONStructuralSnapshotBuilder(document: JSONDocument(root: .array(Array(repeating: .null, count: 1000)))).build()
    #expect(depth.result.recordCount == 129 && wide.result.recordCount == 1001)
    #expect(try depth.result.location(for: 128).result.count == 128)
    #expect(try wide.result.location(for: 1000).result == [.index(999)])
    print("SNAPSHOT_RESOURCE depth=128 nodes=\(depth.result.recordCount) work=\(depth.statistics[.workUnits]) retained=\(depth.statistics[.retainedBytes]) peak=\(depth.statistics.peakLogicalRetainedBytes)")
    print("SNAPSHOT_RESOURCE width=1000 nodes=\(wide.result.recordCount) work=\(wide.statistics[.workUnits]) retained=\(wide.statistics[.retainedBytes]) peak=\(wide.statistics.peakLogicalRetainedBytes)")
}

@Test func snapshotS23SourceTransferIsOneShotAndOrdinaryReadsRefund() throws {
    let document = JSONDocument(root: .array([.null]))
    let scope = try JSONReadScope(document, limits: .balanced)
    let retained = try scope.check().meter.used(.retainedBytes)
    let source = try scope.transferDocumentOwnership()
    #expect(source.root == document.root)
    #expect(throws: JSONFailure.self) { _ = try scope.transferDocumentOwnership() }
    #expect(try scope.complete(source).statistics[.retainedBytes] == retained)
    #expect(scope.document == nil && scope.state == nil)
    #expect(try document.readWithReport { _ in true }.statistics[.retainedBytes] == 0)
}

@Test func snapshotS24LookupsAreSeparateBoundedOperations() throws {
    let result = try snapshot(#"{"a":[{"b":null}]}"#)
    let baseline = try result.location(for: 3)
    var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
    #expect(try result.location(for: 3, limits: limits).result == [.key("a"),.index(0),.key("b")])
    limits[.workUnits] -= 1
    #expect(snapshotFailure { _ = try result.location(for: 3, limits: limits) }?.resource?.metric == .workUnits)
    limits = .balanced; limits[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try result.location(for: 3, limits: limits).result.count == 3)
    limits[.retainedBytes] -= 1
    #expect(snapshotFailure { _ = try result.location(for: 3, limits: limits) }?.resource?.metric == .retainedBytes)
    limits = .balanced; limits[.pointerTokens] = 2
    let pathFailure = snapshotFailure { _ = try result.location(for: 3, limits: limits) }
    #expect(pathFailure?.resource?.metric == .pointerTokens && pathFailure?.resource?.attemptedUsage == 3)
    limits = .balanced; limits[.nodes] = 0
    #expect(snapshotFailure { _ = try result.value(for: 3, limits: limits) }?.resource?.metric == .nodes)
    #expect(try result.value(for: 3).result == .null) // Existing explicit null; no absent/default API.
    #expect(baseline.statistics[.retainedBytes] > 0)
}
