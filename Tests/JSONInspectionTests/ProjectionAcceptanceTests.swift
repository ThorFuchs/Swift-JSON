// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
@testable import JSONInspection

private func projectionFixture(_ name: String) throws -> Data {
    // WASI Foundation's named-resource search can truncate the extension.
    // Match the existing JSONHTML fixture loader using the exact copied path.
    let root = try #require(Bundle.module.resourceURL)
    let url = URL(fileURLWithPath: root.path + "/ProjectionFixtures/" + name + ".json")
    return try Data(contentsOf: url)
}
private func projectionDocument(_ text: String) throws -> JSONDocument {
    try JSONParser().parseDocument(Data(text.utf8))
}
private func projectionInput(_ name: String) throws -> JSONDocument {
    try JSONParser(options: .init(limits: .offline)).parseDocument(projectionFixture(name))
}
private func projectionTree(_ document: JSONDocument, root: Int = 0) throws -> JSONTreeProjection {
    let snapshot = try JSONStructuralSnapshotBuilder(document: document, limits: .offline).build().result
    return try JSONTreeProjection.build(snapshot: snapshot, rootOrdinal: root, limits: .offline).result
}
private func projectionResource(_ body: () throws -> Void) -> JSONFailure? {
    do { try body(); Issue.record("Expected an operational resource refusal") }
    catch let failure as JSONFailure { return failure }
    catch { Issue.record("Wrong failure: \(error)") }
    return nil
}
private func projectionPresence(_ value: JSON?) -> JSONPresence<JSON> {
    guard let value else { return .absent }
    if case .null = value { return .null }
    return .value(value)
}
private func projectionTokens(_ path: [JSONLocationComponent]) -> [String] {
    path.map { switch $0 { case .key(let key): key.string; case .index(let index): String(index) } }
}

@Test func projectionP01ScalarRootIsOneExactLeaf() throws {
    for text in ["null", "false", "9007199254740993", #""exact""#] {
        let document = try projectionDocument(text), view = try projectionTree(document)
        #expect(view.rootOrdinal == 0 && view.endExclusive == 1)
        #expect(try view.children(of: 0, maximumRecords: 0).result.isEmpty)
        #expect(try view.subtreeOrdinals(of: 0, maximumRecords: 1).result == [0])
        #expect(try view.value(for: 0).result == document.root)
    }
}
@Test func projectionP02EmptyContainerKindsStayDifferent() throws {
    let view = try projectionTree(projectionDocument("[{},[]]"))
    #expect(try view.record(at: 1).kind == .object)
    #expect(try view.record(at: 2).kind == .array)
    for ordinal in [1,2] { #expect(try view.children(of: ordinal).result.isEmpty) }
}
@Test func projectionP03RootAndEmptyKeyHaveDifferentLocations() throws {
    let document = try projectionInput("root-keys"), view = try projectionTree(document)
    #expect(try view.location(for: 0).result == [])
    #expect(try view.location(for: 1).result == [.key("")])
    #expect(try JSONPointer(parsing: "").resolve(in: document.root) == view.value(for: 0).result)
    #expect(try JSONPointer(parsing: "/").resolve(in: document.root) == view.value(for: 1).result)
}
@Test func projectionP04NumericKeysAndIndicesAreNotAliases() throws {
    let view = try projectionTree(projectionDocument(#"{"0":[{"0":1}]}"#))
    #expect(try view.location(for: 1).result == [.key("0")])
    #expect(try view.location(for: 2).result == [.key("0"),.index(0)])
    #expect(try view.location(for: 3).result == [.key("0"),.index(0),.key("0")])
    #expect(throws: JSONAccessFailure.self) {
        _ = try JSONTraversal(document: view.snapshot.document).collect(scope: .subtree(at: [.index(0)]))
    }
}
@Test func projectionP05ScalarExactUnicodeKeysNeverNormalize() throws {
    let view = try projectionTree(projectionDocument(#"{"é":1,"e\u0301":2}"#))
    #expect("é" == "e\u{301}") // Swift's canonical equivalence is not JSON identity.
    #expect(JSONKey("é") != JSONKey("e\u{301}"))
    #expect(try view.location(for: 1).result == [.key("é")])
    #expect(try view.location(for: 2).result == [.key("e\u{301}")])
}
@Test func projectionP06ChildrenJumpOverGrandchildren() throws {
    let view = try projectionTree(projectionInput("tree-nested"))
    #expect(try view.children(of: 0).result == [1,8])
    #expect(try view.children(of: 1).result == [2,4])
    #expect(try view.children(of: 4).result == [5,6])
    #expect(try view.subtreeOrdinals(of: 1).result == Array(1..<8))
}
@Test func projectionP07SourceInsertionAndArrayOrderAreCanonical() throws {
    let view = try projectionTree(projectionDocument(#"{"z":[2,1],"a":0}"#))
    #expect(try view.children(of: 0).result == [1,4])
    #expect(try view.record(at: 1).componentFromParent == .key("z"))
    #expect(try view.record(at: 4).componentFromParent == .key("a"))
    #expect(try view.children(of: 1).result == [2,3])
    #expect(try view.value(for: 2).result == 2 && view.value(for: 3).result == 1)
}
@Test func projectionP08EveryRangeMatchesIndependentPacketOracleAndCore() throws {
    // Hand-computed packet topology, independently verified by Python's pair-preserving oracle.
    let view = try projectionTree(projectionInput("tree-nested"))
    let parents: [Int?] = [nil,0,1,2,1,4,4,6,0]
    let depths = [0,1,2,3,2,3,3,4,1], ends = [9,8,4,4,8,6,8,8,9]
    let counts = [2,2,1,0,2,0,1,0,0]
    for ordinal in 0..<9 {
        let record = try view.record(at: ordinal)
        #expect(record.parentOrdinal == parents[ordinal] && record.depth == depths[ordinal])
        #expect(record.subtreeEndExclusive == ends[ordinal] && record.childCount == counts[ordinal])
        let path = try view.location(for: ordinal).result
        let core = try JSONPointer(tokens: projectionTokens(path)).resolve(in: view.snapshot.document.root)
        #expect(try view.value(for: ordinal).result == core)
    }
}
@Test func projectionP09EqualSiblingsKeepDistinctPhysicalPositions() throws {
    let view = try projectionTree(projectionDocument("[1,1]"))
    #expect(try view.children(of: 0).result == [1,2])
    #expect(try view.value(for: 1).result == view.value(for: 2).result)
    #expect(try view.location(for: 1).result != view.location(for: 2).result)
}
@Test func projectionP10SelectedSubtreeKeepsOriginalRootAndParent() throws {
    let document = try projectionInput("tree-nested"), view = try projectionTree(document, root: 1)
    #expect(view.rootOrdinal == 1 && view.endExclusive == 8)
    #expect(try view.record(at: 1).parentOrdinal == 0 && view.record(at: 1).depth == 1)
    #expect(view.snapshot.document.root == document.root)
    #expect(throws: JSONProjectionFailure.outsideSelectedSubtree(ordinal: 8)) { _ = try view.value(for: 8) }
    #expect(throws: JSONProjectionFailure.outsideSelectedSubtree(ordinal: 0)) { _ = try view.record(at: 0) }
}
@Test func projectionP11ReplacementCannotRebindAViewOrGivePortableOrdinals() throws {
    let old = try projectionDocument(#"{"a":1}"#), changed = old.replacingRoot(try JSON.parse(#"{"b":2}"#))
    let first = try projectionTree(old), second = try projectionTree(changed)
    #expect(try first.location(for: 1).result == [.key("a")])
    #expect(try second.location(for: 1).result == [.key("b")])
    #expect(try first.value(for: 1).result == 1 && second.value(for: 1).result == 2)
    // The same bare Int is a local position, not an identity carrying a replacement source.
}
@Test func projectionP12OnlyCapturedCoherentSourceSuppliesSpans() throws {
    let old = try projectionDocument(#"{"a":1}"#), first = try projectionTree(old)
    let changed = old.replacingRoot(try JSON.parse(#"{"a":2}"#)), second = try projectionTree(changed)
    #expect(try first.sourceSpan(for: 1).result != nil)
    #expect(try second.sourceSpan(for: 1).result == nil)
    #expect(try first.sourceSpan(for: 1).result != nil)
}
@Test func projectionP13InclusiveCatalogueCapsNeverReturnTruncation() throws {
    let view = try projectionTree(projectionInput("tree-nested"))
    #expect(try view.children(of: 0, maximumRecords: 2).result == [1,8])
    #expect(throws: JSONProjectionFailure.recordLimitExceeded(limit: 1)) { _ = try view.children(of: 0, maximumRecords: 1) }
    #expect(throws: JSONProjectionFailure.recordLimitExceeded(limit: 0)) { _ = try view.subtreeOrdinals(of: 3, maximumRecords: 0) }
    #expect(try view.subtreeOrdinals(of: 3, maximumRecords: 1).result == [3])
    #expect(throws: JSONFailure.self) { _ = try view.children(of: 0, maximumRecords: -1) }
}
@Test func projectionP14TreeWorkRetentionKeysAndCancellationAreBounded() async throws {
    let view = try projectionTree(projectionInput("tree-nested")), baseline = try view.children(of: 0)
    let built = try JSONTreeProjection.build(snapshot: view.snapshot)
    #expect(built.statistics[.nodes] == 9)
    let admission = try JSONReadScope(view.snapshot.document, limits: .balanced)
    let rootBytes = try admission.check().meter.used(.retainedBytes); admission.invalidate()
    // Six exact edge keys: tree/left/leaf/right/leaf/empty =26 UTF8 bytes.
    #expect(built.statistics[.retainedBytes] == rootBytes + 192 + 96 * 9 + 26)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .workUnits ? built.statistics[metric] : built.statistics.peakLogicalRetainedBytes
        #expect(try JSONTreeProjection.build(snapshot: view.snapshot, limits: limits).result.rootOrdinal == 0)
        limits[metric] -= 1
        #expect(projectionResource { _ = try JSONTreeProjection.build(snapshot: view.snapshot, limits: limits) }?.resource?.metric == metric)
    }
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .workUnits ? baseline.statistics[metric] : baseline.statistics.peakLogicalRetainedBytes
        #expect(try view.children(of: 0, limits: limits).result == baseline.result)
        limits[metric] -= 1
        #expect(projectionResource { _ = try view.children(of: 0, limits: limits) }?.resource?.metric == metric)
    }
    var keys = JSONLimits.balanced; keys[.keyBytes] = 1
    #expect(projectionResource { _ = try view.children(of: 0, limits: keys) }?.resource?.metric == .keyBytes)
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var walk = JSONTraversal(document: view.snapshot.document, limits: limits)
        walk.checkpointObserver = { if $0 >= baseline.statistics[.workUnits] - 1 { withUnsafeCurrentTask { $0?.cancel() } } }
        var reducer = TreeCatalogueReducer(view: view, ordinal: 0, childrenOnly: true, maximumRecords: 2)
        return try walk.inspectOwned(options: .init(depthLimit: 0), reducer: &reducer)
    }
    do { _ = try await task.value; Issue.record("Late tree cancellation must not return a catalogue") }
    catch is CancellationError { }
}
@Test func projectionP15DeepAndWideCataloguesRemainIterativeAndFinite() throws {
    for depth in [16,64,256] {
        let document = try projectionInput("deep-\(depth)"), view = try projectionTree(document)
        #expect(try view.subtreeOrdinals(of: 0, maximumRecords: depth + 1, limits: .offline).result.count == depth + 1)
        var shallow = JSONLimits.offline; shallow[.maxDepth] = 8
        #expect(projectionResource { _ = try view.children(of: depth, limits: shallow) }?.resource?.metric == .maxDepth)
    }
    let wide = try projectionTree(projectionInput("wide-1024"))
    #expect(try wide.children(of: 0, maximumRecords: 1024, limits: .offline).result == Array(1...1024))
}
@Test func projectionP16SharedViewsHaveIndependentHealthAndLegacyStatistics() async throws {
    let document = try projectionInput("tree-nested")
    let initial = try JSONStructuralSnapshotBuilder(document: document).build()
    let view = try JSONTreeProjection.build(snapshot: initial.result).result
    let baseline = try view.children(of: 0)
    let table = try JSONSparseTableProjection.build(document: projectionDocument(#"[{"x":1},{}]"#)).result
    try await withThrowingTaskGroup(of: UInt64.self) { group in
        for index in 0..<16 { group.addTask {
            if index.isMultiple(of: 2) {
                var limits = JSONLimits.balanced; limits[.nodes] = 0
                #expect(projectionResource { _ = try view.children(of: 0, limits: limits) }?.resource?.metric == .nodes)
            }
            let report = try view.children(of: 0)
            #expect(report.result == [1,8]); #expect(try view.value(for: 3).result == 1)
            if index.isMultiple(of: 2) {
                var limits = JSONLimits.balanced; limits[.nodes] = 0
                #expect(projectionResource { _ = try table.cell(row: 0, column: 0, limits: limits) }?.resource?.metric == .nodes)
            }
            #expect(try table.cell(row: 0, column: 0).result == .value(1))
            #expect(try table.cell(row: 1, column: 0).result == .absent)
            return report.statistics[.workUnits]
        } }
        for try await work in group { #expect(work == baseline.statistics[.workUnits]) }
    }
    let after = try JSONStructuralSnapshotBuilder(document: document).build()
    for metric in JSONResourceMetric.allCases { #expect(initial.statistics[metric] == after.statistics[metric]) }
}

@Test func projectionP17EmptyArrayIsExplicitCompleteZeroByZero() throws {
    let document = try projectionInput("table-empty")
    let table = try JSONSparseTableProjection.build(document: document).result
    #expect(table.rowCount == 0 && table.columns.isEmpty && table.presentMembers.isEmpty && table.rowOffsets == [0])
    #expect(try JSONShapeInspector(document: document).inspectArray().result.observedAllObjects == nil)
}
@Test func projectionP18EmptyObjectRowsNeverDisappear() throws {
    let table = try JSONSparseTableProjection.build(document: projectionInput("table-empty-objects"),
        maximumRows: 2, maximumColumns: 0, maximumPresentCells: 0).result
    #expect(table.rowCount == 2 && table.columns.isEmpty && table.rowOffsets == [0,0,0])
    #expect(throws: JSONProjectionFailure.rowOutOfBounds(2)) { _ = try table.cell(row: 2, column: 0) }
}
@Test func projectionP19EveryNonObjectRowFailsAtItsPhysicalPath() throws {
    for (text, row, kind) in [("[null]",0,JSONTraversalKind.null),("[{},false]",1,.boolean),("[{},{},0]",2,.number),("[[]]",0,.array)] {
        let document = try projectionDocument("{\"\":" + text + "}")
        #expect(throws: JSONProjectionFailure.nonObjectRow(at: [.key(""),.index(row)], kind: kind)) {
            _ = try JSONSparseTableProjection.build(document: document, at: [.key("")])
        }
    }
}
@Test func projectionP20PositivePrefixCannotAdmitLateBadTable() throws {
    let document = try projectionInput("table-late-invalid")
    let prefix = try JSONShapeInspector(document: document).inspectArray(sampling: .prefix(maximumRows: 2)).result
    #expect(prefix.observedAllObjects == true && prefix.rowCoverage == .prefix(examined: 2, total: 3))
    #expect(throws: JSONProjectionFailure.nonObjectRow(at: [.index(2)], kind: .boolean)) {
        _ = try JSONSparseTableProjection.build(document: document)
    }
}
@Test func projectionP21ColumnsFollowFirstEncounterAcrossPermutations() throws {
    let first = try JSONSparseTableProjection.build(document: projectionDocument(#"[{"z":1,"a":2},{"q":3}]"#)).result
    let permuted = try JSONSparseTableProjection.build(document: projectionDocument(#"[{"q":3},{"a":2,"z":1}]"#)).result
    #expect(first.columns == [JSONKey("z"),JSONKey("a"),JSONKey("q")])
    #expect(permuted.columns == [JSONKey("q"),JSONKey("a"),JSONKey("z")])
    #expect(try first.cell(row: 0, column: 1).result == .value(2))
    #expect(try permuted.cell(row: 1, column: 1).result == .value(2))
}
@Test func projectionP22UnicodeColumnsHaveExactSeparatePresence() throws {
    let table = try JSONSparseTableProjection.build(document: projectionInput("table-unicode")).result
    #expect(table.columns == [JSONKey("é"),JSONKey("e\u{301}")])
    #expect(try table.cell(row: 0, column: 0).result == .null)
    #expect(try table.cell(row: 1, column: 0).result == .absent)
    #expect(try table.cell(row: 1, column: 1).result == .value(2))
}
@Test func projectionP23EqualRowsRemainSeparatePhysicalRows() throws {
    let table = try JSONSparseTableProjection.build(document: projectionInput("table-equal-rows")).result
    #expect(table.rowCount == 2 && table.rowOffsets == [0,1,2] && table.presentMembers.count == 2)
    #expect(try table.cell(row: 0, column: 0).result == table.cell(row: 1, column: 0).result)
    #expect(table.presentMembers.map(\.memberOrdinal) == [0,0])
}
@Test func projectionP24CellPresenceHasThreeCanonicalStates() throws {
    let table = try JSONSparseTableProjection.build(document: projectionDocument(#"[{"a":null},{},{"a":false}]"#)).result
    #expect(try table.cell(row: 0, column: 0).result == .null)
    #expect(try table.cell(row: 1, column: 0).result == .absent)
    #expect(try table.cell(row: 2, column: 0).result == .value(false))
}
@Test func projectionP25MissingCountsUseEveryAdmittedObjectRow() throws {
    let document = try projectionDocument(#"[{"x":null},{"y":1},{}]"#)
    let table = try JSONSparseTableProjection.build(document: document).result
    let evidence = try JSONShapeInspector(document: document).inspectArray().result
    for column in table.columns.indices {
        var missing: UInt64 = 0, nulls: UInt64 = 0
        for row in 0..<table.rowCount {
            switch try table.cell(row: row, column: column).result {
            case .absent: missing += 1
            case .null: nulls += 1
            case .value: break
            }
        }
        #expect(evidence.firstSeenColumns[column].missing == missing)
        #expect(evidence.firstSeenColumns[column].explicitNull == nulls)
    }
}
@Test func projectionP26NestedValuesAndExactNumbersRemainAtSource() throws {
    let document = try projectionInput("table-complete"), table = try JSONSparseTableProjection.build(document: document).result
    #expect(table.columns == [JSONKey("n"),JSONKey("price"),JSONKey("é"),JSONKey("e\u{301}"),JSONKey("nest")])
    for row in 0..<table.rowCount {
        for column in table.columns.indices {
            let source = try JSONPointer(tokens: [String(row)]).resolve(in: document.root)
            let expected = source.objectValue?.presence(of: table.columns[column])
            #expect(try table.cell(row: row, column: column).result == expected)
        }
    }
    if case .value(let number) = try table.cell(row: 0, column: 0).result {
        #expect(try number.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
    } else { Issue.record("Exact integer is present") }
    if case .value(let number) = try table.cell(row: 0, column: 1).result {
        #expect(number.numberValue?.originalLexeme == "0.0100")
    } else { Issue.record("Original decimal lexeme is present") }
    #expect(try table.cell(row: 2, column: 0).result == .value(.number(JSONNumber(parsing: "0.1"))))
    let nested = try JSONSparseTableProjection.build(document: projectionInput("table-nested")).result
    #expect(try nested.cell(row: 0, column: 0).result == .value(.array([1,2])))
    #expect(try nested.cell(row: 0, column: 1).result == .value(JSON.parse(#"{"0":"key"}"#)))
}
@Test func projectionP27SparsePrefixesAndMemberOrdinalsMatchOracle() throws {
    let table = try JSONSparseTableProjection.build(document: projectionInput("table-complete")).result
    #expect(table.rowOffsets == [0,3,5,7])
    #expect(table.presentMembers.map(\.memberOrdinal) == [0,1,2,0,1,0,1])
    #expect(table.presentMembers.map(\.columnOrdinal) == [0,1,2,3,0,0,4])
    #expect(table.presentMembers.count == 7 && table.presentMembers.count < table.rowCount * table.columns.count)
    #expect(try JSONSparseTableProjection.build(document: projectionInput("table-empty-objects")).result.rowOffsets == [0,0,0])
}
@Test func projectionP28BadBoundsKindsConfigurationPathsAndDuplicatesThrow() throws {
    let table = try JSONSparseTableProjection.build(document: projectionInput("table-numeric-keys")).result
    #expect(table.columns == [JSONKey("0")])
    #expect(try table.cell(row: 1, column: 0).result == .value(2))
    for row in [-1,2] { #expect(throws: JSONProjectionFailure.rowOutOfBounds(row)) { _ = try table.cell(row: row, column: 0) } }
    for column in [-1,1] { #expect(throws: JSONProjectionFailure.columnOutOfBounds(column)) { _ = try table.cell(row: 0, column: column) } }
    #expect(throws: JSONAccessFailure.self) { _ = try JSONSparseTableProjection.build(document: projectionDocument("{}")) }
    #expect(throws: JSONAccessFailure.self) { _ = try JSONSparseTableProjection.build(document: table.document, at: [.key("0")]) }
    #expect(throws: JSONAccessFailure.self) { _ = try JSONSparseTableProjection.build(document: table.document, at: [.index(-1)]) }
    #expect(projectionResource { _ = try JSONSparseTableProjection.build(document: table.document, maximumRows: -1) }?.code == .invalidLimits)
    #expect(projectionResource { _ = try JSONSparseTableProjection.build(document: table.document, maximumColumns: -1) }?.code == .invalidLimits)
    #expect(projectionResource { _ = try JSONSparseTableProjection.build(document: table.document, maximumPresentCells: -1) }?.code == .invalidLimits)
    #expect(throws: JSONFailure.self) { _ = try JSONParser().parseDocument(projectionFixture("table-duplicate-keys")) }
}
@Test func projectionP29ScaleCapsAndCheckedProductsPrecedeGrowth() throws {
    for count in [1,16,1024,10000] {
        let document = try projectionInput("sparse-\(count)")
        let report = try JSONSparseTableProjection.build(document: document, limits: .offline,
            maximumRows: count, maximumColumns: min(count,16), maximumPresentCells: count)
        let table = report.result
        #expect(table.rowCount == count && table.columns.count == min(count,16))
        #expect(table.rowOffsets == Array(0...count) && table.presentMembers.count == count)
        #expect(table.presentMembers.allSatisfy { $0.memberOrdinal == 0 })
        #expect(table.presentMembers.map(\.columnOrdinal) == (0..<count).map { $0 % 16 })
        #expect(report.statistics[.nodes] == UInt64(2 * count + 1))
        #expect(throws: JSONProjectionFailure.rowLimitExceeded(limit: count - 1)) {
            _ = try JSONSparseTableProjection.build(document: document, limits: .offline, maximumRows: count - 1)
        }
        #expect(throws: JSONProjectionFailure.presentCellLimitExceeded(limit: count - 1)) {
            _ = try JSONSparseTableProjection.build(document: document, limits: .offline, maximumPresentCells: count - 1)
        }
        print("PROJECTION_RESOURCE rows=\(count) columns=\(table.columns.count) members=\(count) work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes)")
    }
    let small = try projectionDocument(#"[{"a":1,"b":2}]"#)
    #expect(throws: JSONProjectionFailure.columnLimitExceeded(limit: 1)) { _ = try JSONSparseTableProjection.build(document: small, maximumColumns: 1) }
    #expect(projectionResource { _ = try ProjectionAccounting.bytes(2, unit: UInt64.max, limits: .balanced) }?.code == .counterOverflow)
    #expect(projectionResource { _ = try ProjectionAccounting.next(Int.max, limits: .balanced) }?.code == .counterOverflow)
}
@Test func projectionP30ConstructionHasOneAdmissionAndRetainsExactSparseOutput() throws {
    let document = try projectionInput("table-complete")
    let scope = try JSONReadScope(document, limits: .balanced)
    let state = try scope.check(), admitted = state.meter.used(.retainedBytes)
    let nodes = state.meter.used(.nodes), maps = state.meter.used(.sourceMapEntries); scope.invalidate()
    let before = try JSONShapeInspector(document: document).inspectArray()
    let report = try JSONSparseTableProjection.build(document: document), table = report.result
    let keys = table.columns.reduce(UInt64(0)) { $0 + UInt64($1.string.utf8.count) }
    let expected = admitted + 256 + 8 * UInt64(table.rowCount + 1) + 64 * UInt64(table.columns.count) + keys + 16 * UInt64(table.presentMembers.count)
    #expect(report.statistics[.nodes] == nodes && report.statistics[.sourceMapEntries] == maps)
    #expect(report.statistics[.retainedBytes] == expected)
    #expect(table.document.root == document.root && table.traversal.visitedCount == 4)
    let after = try JSONShapeInspector(document: document).inspectArray()
    for metric in JSONResourceMetric.allCases { #expect(before.statistics[metric] == after.statistics[metric]) }
    #expect(try JSONTraversal(document: document).visit { _,_ in .continue }.statistics[.retainedBytes] == 0)
}
@Test func projectionP31CellLookupIsIndependentFullSourceAdmission() throws {
    let document = try projectionDocument(#"{"0":[{"0":null},{},{"0":9007199254740993}],"outside":[1,2,3]}"#)
    let built = try JSONSparseTableProjection.build(document: document, at: [.key("0")]), table = built.result
    let baseline = try table.cell(row: 2, column: 0)
    #expect(baseline.statistics[.nodes] == built.statistics[.nodes])
    #expect(baseline.statistics[.sourceMapEntries] == built.statistics[.sourceMapEntries])
    #expect(try table.cell(row: 1, column: 0).result == .absent)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .workUnits ? baseline.statistics[metric] : baseline.statistics.peakLogicalRetainedBytes
        #expect(try table.cell(row: 2, column: 0, limits: limits).result == baseline.result)
        limits[metric] -= 1
        #expect(projectionResource { _ = try table.cell(row: 2, column: 0, limits: limits) }?.resource?.metric == metric)
    }
    var none = JSONLimits.balanced; none[.nodes] = 0
    #expect(projectionResource { _ = try table.cell(row: 1, column: 0, limits: none) }?.resource?.metric == .nodes)
    #expect(try table.cell(row: 2, column: 0).result == baseline.result)
}

private enum ProjectionAfterFinish: Error { case replacement }
private struct ProjectionLateProbe<Inner: JSONTraversalOwnedReducer>: JSONTraversalOwnedReducer {
    enum Mode: Sendable { case work, cancellation, twice, caller }
    var inner: Inner
    let mode: Mode
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try inner.observe(hit, value: value, context: &context)
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> Inner.Result {
        let result = try inner.finish(summary, context: &context)
        switch mode {
        case .work:
            do { try context.work(64_000_000) } catch { }
            throw ProjectionAfterFinish.replacement
        case .cancellation:
            withUnsafeCurrentTask { $0?.cancel() }
            do { try context.checkpoint() } catch { }
        case .twice:
            do { _ = try context.transferDocumentOwnership() } catch { }
        case .caller: throw ProjectionAfterFinish.replacement
        }
        return result
    }
}
@Test func projectionP32FinalizationFailureCancellationAndScopeTeardownAreTerminal() async throws {
    let document = try projectionDocument(#"[{"x":1},{"y":null}]"#)
    let baseline = try JSONSparseTableProjection.build(document: document)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .workUnits ? baseline.statistics[metric] : baseline.statistics.peakLogicalRetainedBytes
        #expect(try JSONSparseTableProjection.build(document: document, limits: limits).result.rowCount == 2)
        limits[metric] -= 1
        #expect(projectionResource { _ = try JSONSparseTableProjection.build(document: document, limits: limits) }?.resource?.metric == metric)
    }
    typealias Probe = ProjectionLateProbe<SparseTableReducer>
    for mode in [Probe.Mode.work,.cancellation,.twice,.caller] {
        let cleared = Mutex(false)
        let task = Task {
            var walk = JSONTraversal(document: document)
            walk.lifetimeObserver = { rootGone,stateGone in cleared.withLock { $0 = rootGone && stateGone } }
            var reducer = Probe(inner: SparseTableReducer(maximumRows: 2, maximumColumns: 2,
                maximumPresentCells: 2, limits: .balanced), mode: mode)
            return try walk.inspectOwned(options: .init(depthLimit: 1), reducer: &reducer)
        }
        do { _ = try await task.value; Issue.record("No finalized projection may mask terminal failure") }
        catch let failure as JSONFailure {
            if mode == .twice { #expect(failure.code == .invalidOperation) }
            else { #expect(mode == .work && failure.resource?.metric == .workUnits) }
        }
        catch is CancellationError { #expect(mode == .cancellation) }
        catch is ProjectionAfterFinish { #expect(mode == .caller) }
        #expect(cleared.withLock { $0 })
    }

    let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
    typealias TreeProbe = ProjectionLateProbe<TreeViewReducer>
    for mode in [TreeProbe.Mode.work,.cancellation,.twice,.caller] {
        let cleared = Mutex(false)
        let task = Task {
            var walk = JSONTraversal(document: document)
            walk.lifetimeObserver = { rootGone,stateGone in cleared.withLock { $0 = rootGone && stateGone } }
            var reducer = TreeProbe(inner: TreeViewReducer(snapshot: snapshot, rootOrdinal: 0, limits: .balanced), mode: mode)
            return try walk.inspectOwned(options: .init(depthLimit: 0), reducer: &reducer)
        }
        do { _ = try await task.value; Issue.record("No source-owning tree may mask final failure") }
        catch let failure as JSONFailure {
            if mode == .twice { #expect(failure.code == .invalidOperation) }
            else { #expect(mode == .work && failure.resource?.metric == .workUnits) }
        }
        catch is CancellationError { #expect(mode == .cancellation) }
        catch is ProjectionAfterFinish { #expect(mode == .caller) }
        #expect(cleared.withLock { $0 })
    }
    // Cancel inside a long owned key scan, and inside the offset-finalization scan.
    for finish in [false,true] {
        let trace = ProjectionPhaseTrace()
        let text = finish ? "[" + Array(repeating: #"{"x":1}"#, count: 40).joined(separator: ",") + "]"
            : "[{\"" + String(repeating: "a", count: 128) + "A\":1},{\"" + String(repeating: "a", count: 128) + "B\":2}]"
        let input = try projectionDocument(text)
        let cleared = Mutex(false)
        let task = Task {
            var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
            var walk = JSONTraversal(document: input, limits: limits)
            walk.checkpointObserver = { _ in if trace.step() { withUnsafeCurrentTask { $0?.cancel() } } }
            walk.lifetimeObserver = { rootGone,stateGone in cleared.withLock { $0 = rootGone && stateGone } }
            var reducer = ProjectionPhaseProbe(inner: SparseTableReducer(maximumRows: 100,
                maximumColumns: 100, maximumPresentCells: 100, limits: limits), trace: trace, finishing: finish)
            return try walk.inspectOwned(options: .init(depthLimit: 1), reducer: &reducer)
        }
        do { _ = try await task.value; Issue.record("Inner projection scan must observe cancellation") }
        catch is CancellationError { }
        #expect(trace.state.withLock { $0.calls >= 32 })
        #expect(cleared.withLock { $0 })
    }
}

private final class ProjectionPhaseTrace: Sendable {
    struct State { var active = false; var calls = 0 }
    let state = Mutex(State())
    func activate() { state.withLock { $0.active = true; $0.calls = 0 } }
    func deactivate() { state.withLock { $0.active = false } }
    func step() -> Bool { state.withLock { value in
        guard value.active else { return false }
        value.calls += 1; return value.calls >= 32
    } }
}
private struct ProjectionPhaseProbe: JSONTraversalOwnedReducer {
    var inner: SparseTableReducer
    let trace: ProjectionPhaseTrace
    let finishing: Bool
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        let activate = !finishing && hit.relativeDepth == 1 && hit.absoluteLocation.last == .index(1)
        if activate { trace.activate() }
        defer { if activate { trace.deactivate() } }
        return try inner.observe(hit, value: value, context: &context)
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONSparseTableProjection {
        if finishing { trace.activate() }
        defer { trace.deactivate() }
        return try inner.finish(summary, context: &context)
    }
}
