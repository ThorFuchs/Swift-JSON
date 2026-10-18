// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
@testable import JSONInspection

private func p2Document(_ text: String) throws -> JSONDocument {
    try JSONParser(options: .init(limits: .offline)).parseDocument(Data(text.utf8))
}
private func p2Fixture(_ name: String) throws -> JSONDocument {
    let root = try #require(Bundle.module.resourceURL)
    return try JSONParser(options: .init(limits: .offline)).parseDocument(
        Data(contentsOf: URL(fileURLWithPath: root.path + "/P2Fixtures/" + name + ".json")))
}
private func p2Set(_ text: String) throws -> JSONStructuralSetProjection {
    try JSONStructuralSetProjection.build(document: p2Document(text)).result
}
private func p2Matrix(_ text: String) throws -> JSONNumericMatrixProjection {
    try JSONNumericMatrixProjection.build(document: p2Document(text)).result
}
private func p2Failure(_ operation: () throws -> Void) -> JSONFailure? {
    do { try operation(); Issue.record("Expected refusal, never partial success") }
    catch let error as JSONFailure { return error }
    catch { Issue.record("Unexpected error: \(error)") }
    return nil
}
private func p2Access(_ path: [JSONLocationComponent], _ operation: () throws -> Void) {
    do { try operation(); Issue.record("Expected typed access failure") }
    catch let error as JSONAccessFailure { #expect(error.path == path) }
    catch { Issue.record("Unexpected error: \(error)") }
}
private func p2Admitted(_ document: JSONDocument) throws -> (nodes: UInt64, maps: UInt64, retained: UInt64) {
    let scope = try JSONReadScope(document, limits: .offline)
    defer { scope.invalidate() }
    let state = try scope.check()
    return (state.meter.used(.nodes), state.meter.used(.sourceMapEntries), state.meter.used(.retainedBytes))
}
private func p2SameStatistics(_ a: JSONOperationStatistics, _ b: JSONOperationStatistics) {
    for metric in JSONResourceMetric.allCases { #expect(a[metric] == b[metric]) }
    #expect(a.peakLogicalRetainedBytes == b.peakLogicalRetainedBytes)
}

@Test func p2SetSSET01EmptyIsCompleteAndHasNoMember() throws {
    let view = try JSONStructuralSetProjection.build(document: p2Fixture("set-empty"), maximumUniqueItems: 0).result
    #expect(view.inputCount == 0 && view.uniqueCount == 0 && view.representativeIndices.isEmpty)
    #expect(view.traversal.visitedCount == 1)
    #expect(throws: JSONP2ProjectionFailure.memberOutOfBounds(0)) { _ = try view.member(at: 0) }
}
@Test func p2SetSSET02NullIsFirstRealRepresentative() throws {
    let view = try JSONStructuralSetProjection.build(document: p2Fixture("set-nulls")).result
    #expect(view.representativeIndices == [0])
    #expect(try view.member(at: 0).result == .null)
}
@Test func p2SetSSET03DecimalEqualityPreservesFirstLexeme() throws {
    let view = try p2Set("[0.1,0.10]")
    #expect(view.representativeIndices == [0])
    guard case .number(let number) = try view.member(at: 0).result else { Issue.record("Number required"); return }
    #expect(number.originalLexeme == "0.1")
    #expect(try view.document.root.read { try $0[1].requiredNumber() }.originalLexeme == "0.10")
}
@Test func p2SetSSET04IntegersBeyondBinaryPrecisionStayDistinct() throws {
    let view = try p2Set("[9007199254740993,9007199254740992]")
    #expect(view.representativeIndices == [0,1])
    #expect(try view.member(at: 0).result != view.member(at: 1).result)
}
@Test func p2SetSSET05UnicodeScalarsDoNotNormalize() throws {
    let view = try p2Set(#"["é","e\u0301"]"#)
    #expect(view.uniqueCount == 2)
    #expect(try view.member(at: 0).result != view.member(at: 1).result)
}
@Test func p2SetSSET06EmptyObjectsDeduplicate() throws {
    #expect(try p2Set("[{},{}]").representativeIndices == [0])
}
@Test func p2SetSSET07ObjectMemberOrderDoesNotChangeEquality() throws {
    let view = try p2Set(#"[{"a":1,"b":2},{"b":2,"a":1}]"#)
    #expect(view.representativeIndices == [0])
    let original = try view.member(at: 0).result.read { try $0.requiredObject() }
    #expect(original[0].key == JSONKey("a") && original[1].key == JSONKey("b"))
}
@Test func p2SetSSET08ArrayOrderRemainsSignificant() throws {
    #expect(try JSONStructuralSetProjection.build(document: p2Fixture("set-arrays")).result.representativeIndices == [0,1])
}
@Test func p2SetSSET09ExactObjectKeysStayDistinct() throws {
    #expect(try p2Set(#"[{"é":1},{"e\u0301":1}]"#).representativeIndices == [0,1])
}
@Test func p2SetSSET10NonarrayRefusesAtCompleteTypedLocation() throws {
    let document = try p2Document(#"{"a":{"0":null}}"#), path: [JSONLocationComponent] = [.key("a"),.key("0")]
    do { _ = try JSONStructuralSetProjection.build(document: document, at: path); Issue.record("Expected wrong-kind") }
    catch let error as JSONAccessFailure { #expect(error.path == path && error.cause.code == .wrongKind) }
    p2Access([]) { _ = try JSONStructuralSetProjection.build(document: p2Document("false")) }
}
@Test func p2SetSSET11MissingNumericKeyIndexAndEmptyKeyStayDistinct() throws {
    let document = try p2Document(#"{"0":[null],"":[]}"#)
    #expect(try JSONStructuralSetProjection.build(document: document, at: [.key("0")]).result.uniqueCount == 1)
    #expect(try JSONStructuralSetProjection.build(document: document, at: [.key("")]).result.uniqueCount == 0)
    p2Access([.index(0)]) { _ = try JSONStructuralSetProjection.build(document: document, at: [.index(0)]) }
    p2Access([.key("missing"),.key("deep")]) { _ = try JSONStructuralSetProjection.build(document: document, at: [.key("missing"),.key("deep")]) }
}
@Test func p2SetSSET12FirstOccurrencePositionsArePhysical() throws {
    let view = try p2Set("[1,1,2,1,2,3,3]")
    #expect(view.inputCount == 7 && view.representativeIndices == [0,2,5])
    for (position,index) in view.representativeIndices.enumerated() {
        #expect(try view.member(at: position).result == JSONPointer(tokens: [String(index)]).resolve(in: view.document.root))
    }
}
@Test func p2SetSSET13UniqueCapIsInclusiveAndDuplicatesStillChecked() throws {
    let document = try p2Document("[1,2,1,2]")
    #expect(try JSONStructuralSetProjection.build(document: document, maximumUniqueItems: 2).result.uniqueCount == 2)
    #expect(throws: JSONP2ProjectionFailure.uniqueItemLimitExceeded(limit: 1)) {
        _ = try JSONStructuralSetProjection.build(document: document, maximumUniqueItems: 1)
    }
    #expect(p2Failure { _ = try JSONStructuralSetProjection.build(document: document, maximumUniqueItems: -1) }?.code == .invalidLimits)
}
@Test func p2SetSSET14WideComparisonIsFiniteAndCumulative() throws {
    for count in [1,16,128] {
        for unique in [false,true] {
            let text = "[" + (0..<count).map { unique ? String($0) : "0" }.joined(separator: ",") + "]"
            let document = try p2Document(text)
            let baseline = try JSONStructuralSetProjection.build(document: document, limits: .offline)
            #expect(baseline.result.uniqueCount == (unique ? count : 1))
            var limits = JSONLimits.offline; limits[.workUnits] = baseline.statistics[.workUnits]
            #expect(try JSONStructuralSetProjection.build(document: document, limits: limits).result.uniqueCount == baseline.result.uniqueCount)
            limits[.workUnits] -= 1
            #expect(p2Failure { _ = try JSONStructuralSetProjection.build(document: document, limits: limits) }?.resource?.metric == .workUnits)
            print("P2_SET_RESOURCE count=\(count) unique=\(unique) work=\(baseline.statistics[.workUnits]) retained=\(baseline.statistics[.retainedBytes]) peak=\(baseline.statistics.peakLogicalRetainedBytes)")
        }
    }
}
private struct P2CaughtComparison: JSONTraversalOwnedReducer {
    mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        do { _ = try context.equalArrayElements(at: [], lhs: 0, rhs: 0) } catch { }
        return .stop
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> Int { 99 }
}
@Test func p2SetSSET15CaughtOwnedTypeFailureCannotPublish() throws {
    var reducer = P2CaughtComparison()
    p2Access([]) { _ = try JSONTraversal(document: p2Document("null")).inspectOwned(reducer: &reducer) }
}

private final class P2PhaseTrace: Sendable {
    struct State { var active = false; var calls = 0 }
    let state = Mutex(State())
    func activate() { state.withLock { $0.active = true; $0.calls = 0 } }
    func deactivate() { state.withLock { $0.active = false } }
    func step() -> Bool { state.withLock { value in
        guard value.active else { return false }
        value.calls += 1; return value.calls >= 32
    } }
}
private struct P2PhaseProbe<Inner: JSONTraversalOwnedReducer>: JSONTraversalOwnedReducer {
    var inner: Inner
    let trace: P2PhaseTrace
    let targetDepth: Int
    let targetIndex: Int
    mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        let active = hit.relativeDepth == targetDepth && hit.absoluteLocation.last == .index(targetIndex)
        if active { trace.activate() }
        defer { if active { trace.deactivate() } }
        return try inner.observe(hit, value: value, context: &context)
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> Inner.Result {
        try inner.finish(summary, context: &context)
    }
}
@Test func p2SetSSET16CancellationInsideComparatorReleasesScope() async throws {
    let text = "[\"" + String(repeating: "a", count: 8192) + "\",\"" + String(repeating: "a", count: 8192) + "\"]"
    let document = try p2Document(text), trace = P2PhaseTrace(), cleared = Mutex(false)
    let task = Task {
        var limits = JSONLimits.offline; limits[.cancellationQuantum] = 1
        var walk = JSONTraversal(document: document, limits: limits)
        walk.checkpointObserver = { _ in if trace.step() { withUnsafeCurrentTask { $0?.cancel() } } }
        walk.lifetimeObserver = { rootGone,stateGone in cleared.withLock { $0 = rootGone && stateGone } }
        var reducer = P2PhaseProbe(inner: StructuralSetReducer(maximumUniqueItems: 2, limits: limits), trace: trace, targetDepth: 1, targetIndex: 1)
        return try walk.inspectOwned(options: .init(depthLimit: 1), reducer: &reducer)
    }
    do { _ = try await task.value; Issue.record("Cancellation must throw") } catch is CancellationError { }
    #expect(trace.state.withLock { $0.calls >= 32 })
    #expect(cleared.withLock { $0 })
}
@Test func p2SetSSET17CapturedMappingIsCoherentAcrossReplacement() throws {
    let document = try p2Document("[0.10,0.1]"), view = try JSONStructuralSetProjection.build(document: document).result
    let replaced = document.replacingRoot([2,2]), changed = try JSONStructuralSetProjection.build(document: replaced).result
    #expect(view.document.sourceBytes == document.sourceBytes && view.document.sourceMap != nil)
    #expect(changed.document.sourceMap == nil && changed.document.sourceBytes == nil)
    #expect(try view.member(at: 0).result.read { try $0.requiredNumber() }.originalLexeme == "0.10")
    #expect(try changed.member(at: 0).result == 2)
}
@Test func p2SetSSET18SharedImmutableViewsHaveIndependentLedgers() async throws {
    let document = try p2Fixture("set-equality")
    let baseline = try JSONStructuralSetProjection.build(document: document)
    try await withThrowingTaskGroup(of: JSONOperationStatistics.self) { group in
        for _ in 0..<8 { group.addTask { try JSONStructuralSetProjection.build(document: document).statistics } }
        for try await statistics in group { p2SameStatistics(statistics, baseline.statistics) }
    }
    let view = baseline.result
    let healthy = try view.member(at: 0)
    var none = JSONLimits.balanced; none[.nodes] = 0
    #expect(p2Failure { _ = try view.member(at: 0, limits: none) }?.resource?.metric == .nodes)
    p2SameStatistics(healthy.statistics, try view.member(at: 0).statistics)
}

@Test func p2MatrixMAT01EmptyRootHasExplicitZeroShape() throws {
    let view = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-0x0"), maximumRows: 0, maximumColumns: 0, maximumElements: 0).result
    #expect(view.rowCount == 0 && view.columnCount == 0 && view.elementCount == 0)
    #expect(view.transposed().rowCount == 0 && view.transposed().columnCount == 0)
}
@Test func p2MatrixMAT02ZeroWidthTransposePreservesIndependentDimension() throws {
    let view = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-2x0")).result
    #expect(view.rowCount == 2 && view.columnCount == 0)
    #expect(view.transposed().rowCount == 0 && view.transposed().columnCount == 2)
    #expect(view.transposed().transposed().rowCount == 2 && !view.transposed().transposed().isTransposed)
}
@Test func p2MatrixMAT03ExactTransposeAndDoubleTranspose() throws {
    let view = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-2x2")).result
    #expect(view.rowCount == 2 && view.columnCount == 2 && view.elementCount == 4)
    for r in 0..<2 { for c in 0..<2 {
        #expect(try view.element(row: r, column: c).result == view.transposed().element(row: c, column: r).result)
        #expect(try view.element(row: r, column: c).result == view.transposed().transposed().element(row: r, column: c).result)
    } }
}
@Test func p2MatrixMAT04ExactNumbersKeepOriginalTokens() throws {
    let view = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-exact")).result
    for (r,row) in [["0.1","9007199254740993"],["-0.5","0.0100"]].enumerated() {
        for (c,token) in row.enumerated() {
            let number = try view.element(row: r, column: c).result
            #expect(try number.originalLexeme == token && number == JSONNumber(parsing: token))
        }
    }
}
@Test func p2MatrixMAT05RaggedRowIsRefusedWithoutPadding() throws {
    #expect(throws: JSONP2ProjectionFailure.raggedRow(at: [.index(1)], expected: 2, actual: 1)) {
        _ = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-ragged"))
    }
}
@Test func p2MatrixMAT06StringCellIsTypedRefusal() throws {
    #expect(throws: JSONP2ProjectionFailure.nonNumericCell(at: [.index(0),.index(1)], kind: .string)) {
        _ = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-string-cell"))
    }
    for text in ["[[null]]","[[true]]","[[{}]]","[[[]]]"] {
        #expect(throws: JSONP2ProjectionFailure.self) { _ = try p2Matrix(text) }
    }
}
@Test func p2MatrixMAT07NonarrayRowIsRefused() throws {
    #expect(throws: JSONP2ProjectionFailure.nonArrayRow(at: [.index(0)], kind: .number)) {
        _ = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-nonarray-row"))
    }
    p2Access([]) { _ = try p2Matrix("null") }
}
@Test func p2MatrixMAT08NumericObjectKeyIsNotArrayPosition() throws {
    let document = try p2Fixture("matrix-root-numeric-object-key")
    #expect(try JSONNumericMatrixProjection.build(document: document, at: [.key("0")]).result.rowCount == 1)
    p2Access([.index(0)]) { _ = try JSONNumericMatrixProjection.build(document: document, at: [.index(0)]) }
}
@Test func p2MatrixMAT09ColumnTransposeKeepsSourceAndExactPositions() throws {
    let view = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-3x1")).result
    #expect(view.rowCount == 3 && view.columnCount == 1 && view.transposed().rowCount == 1 && view.transposed().columnCount == 3)
    for r in 0..<3 {
        #expect(try view.transposed().element(row: 0, column: r).result == JSONNumber(integer: r + 1))
    }
    #expect(view.document.root == view.transposed().document.root)
}
@Test func p2MatrixMAT10SingleEmptyRowTransposesToZeroByOne() throws {
    let view = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-1x0")).result
    #expect(view.rowCount == 1 && view.columnCount == 0 && view.transposed().rowCount == 0 && view.transposed().columnCount == 1)
    #expect(throws: JSONP2ProjectionFailure.columnOutOfBounds(0)) { _ = try view.element(row: 0, column: 0) }
}
@Test func p2MatrixMAT11BoundsNeverBecomeNullOrZero() throws {
    let view = try p2Matrix("[[1,2]]")
    for row in [-1,1,Int.max] {
        #expect(throws: JSONP2ProjectionFailure.rowOutOfBounds(row)) { _ = try view.element(row: row, column: 0) }
    }
    for column in [-1,2,Int.max] {
        #expect(throws: JSONP2ProjectionFailure.columnOutOfBounds(column)) { _ = try view.element(row: 0, column: column) }
    }
}
@Test func p2MatrixMAT12EmptySelectionStillAdmitsWholeSource() throws {
    let document = try p2Document("{\"selected\":[],\"rest\":[" + Array(repeating: "1", count: 512).joined(separator: ",") + "]}")
    let baseline = try JSONNumericMatrixProjection.build(document: document, at: [.key("selected")])
    let admitted = try p2Admitted(document)
    #expect(baseline.result.rowCount == 0 && baseline.statistics[.nodes] == admitted.nodes && admitted.nodes == 515)
    var limits = JSONLimits.offline; limits[.nodes] = admitted.nodes - 1
    #expect(p2Failure { _ = try JSONNumericMatrixProjection.build(document: document, at: [.key("selected")], limits: limits) }?.resource?.metric == .nodes)
}
@Test func p2MatrixMAT13ShapeMultiplicationIsCheckedBeforeAllocation() throws {
    #expect(try P2Accounting.product(Int.max, 0, limits: .balanced) == 0)
    #expect(try P2Accounting.product(Int.max, 1, limits: .balanced) == Int.max)
    let error = p2Failure { _ = try P2Accounting.product(Int.max, 2, limits: .balanced) }
    #expect(error?.code == .counterOverflow && error?.resource?.overflow == true && error?.resource?.attemptedUsage == nil)
}
@Test func p2MatrixMAT14EveryCapacityIsInclusiveAndFinite() throws {
    let document = try p2Document("[[1,2],[3,4]]")
    #expect(try JSONNumericMatrixProjection.build(document: document, maximumRows: 2, maximumColumns: 2, maximumElements: 4).result.elementCount == 4)
    #expect(throws: JSONP2ProjectionFailure.rowLimitExceeded(limit: 1)) { _ = try JSONNumericMatrixProjection.build(document: document, maximumRows: 1) }
    #expect(throws: JSONP2ProjectionFailure.columnLimitExceeded(limit: 1)) { _ = try JSONNumericMatrixProjection.build(document: document, maximumColumns: 1) }
    #expect(throws: JSONP2ProjectionFailure.elementLimitExceeded(limit: 3)) { _ = try JSONNumericMatrixProjection.build(document: document, maximumElements: 3) }
    for bounds in [(-1,2,4),(2,-1,4),(2,2,-1)] {
        #expect(p2Failure { _ = try JSONNumericMatrixProjection.build(document: document, maximumRows: bounds.0, maximumColumns: bounds.1, maximumElements: bounds.2) }?.code == .invalidLimits)
    }
}
@Test func p2MatrixMAT15InnerValidationCancellationIsTerminal() async throws {
    let document = try p2Document("[[" + Array(repeating: "1", count: 128).joined(separator: ",") + "]]"), trace = P2PhaseTrace(), cleared = Mutex(false)
    let task = Task {
        var limits = JSONLimits.offline; limits[.cancellationQuantum] = 1
        var walk = JSONTraversal(document: document, limits: limits)
        // Activate during the first cell, and keep counting the following cell loop.
        walk.checkpointObserver = { _ in
            if trace.step() { withUnsafeCurrentTask { $0?.cancel() } }
        }
        walk.lifetimeObserver = { rootGone,stateGone in cleared.withLock { $0 = rootGone && stateGone } }
        var reducer = P2MatrixCellProbe(inner: NumericMatrixReducer(maximumRows: 1, maximumColumns: 128, maximumElements: 128, limits: limits), trace: trace)
        return try walk.inspectOwned(options: .init(depthLimit: 2), reducer: &reducer)
    }
    do { _ = try await task.value; Issue.record("Cancellation must throw") } catch is CancellationError { }
    #expect(trace.state.withLock { $0.calls >= 32 })
    #expect(cleared.withLock { $0 })
}
private struct P2MatrixCellProbe: JSONTraversalOwnedReducer {
    var inner: NumericMatrixReducer
    let trace: P2PhaseTrace
    mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        if hit.relativeDepth == 2 && hit.absoluteLocation.last == .index(0) { trace.activate() }
        return try inner.observe(hit, value: value, context: &context)
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> JSONNumericMatrixProjection {
        try inner.finish(summary, context: &context)
    }
}
@Test func p2MatrixMAT16ReplacementCannotRebindOrPreserveStaleMap() throws {
    let document = try p2Document("[[0.10]]"), view = try JSONNumericMatrixProjection.build(document: document).result
    let changed = try JSONNumericMatrixProjection.build(document: document.replacingRoot([[2]])).result
    #expect(view.document.sourceMap != nil && view.document.sourceBytes == document.sourceBytes)
    #expect(changed.document.sourceMap == nil && changed.document.sourceBytes == nil)
    #expect(try view.transposed().element(row: 0, column: 0).result.originalLexeme == "0.10")
    #expect(try changed.element(row: 0, column: 0).result == JSONNumber(integer: 2))
}
@Test func p2MatrixMAT17ElementReadIsNewExplicitFullAdmission() throws {
    let document = try p2Document(#"{"0":[[0.10,9007199254740993]],"rest":[1,2,3]}"#)
    let built = try JSONNumericMatrixProjection.build(document: document, at: [.key("0")]), view = built.result
    let read = try view.element(row: 0, column: 1), admitted = try p2Admitted(document)
    #expect(read.result.originalLexeme == "9007199254740993")
    #expect(read.statistics[.nodes] == admitted.nodes && read.statistics[.nodes] == built.statistics[.nodes])
    #expect(read.statistics[.sourceMapEntries] == admitted.maps && read.statistics[.retainedBytes] == 0)
    for metric in [JSONResourceMetric.workUnits,.retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .workUnits ? read.statistics[metric] : read.statistics.peakLogicalRetainedBytes
        #expect(try view.element(row: 0, column: 1, limits: limits).result == read.result)
        limits[metric] -= 1
        #expect(p2Failure { _ = try view.element(row: 0, column: 1, limits: limits) }?.resource?.metric == metric)
    }
}
@Test func p2MatrixMAT18SharedTransposesHaveIndependentReads() async throws {
    let view = try p2Matrix("[[1,2],[3,4]]"), transposed = view.transposed()
    let baseline = try transposed.element(row: 1, column: 0)
    try await withThrowingTaskGroup(of: JSONOperationStatistics.self) { group in
        for _ in 0..<8 { group.addTask {
            let report = try transposed.element(row: 1, column: 0)
            #expect(report.result == JSONNumber(integer: 2)); return report.statistics
        } }
        for try await statistics in group { p2SameStatistics(statistics, baseline.statistics) }
    }
    #expect(view.rowCount == 2 && !view.isTransposed)
}

@Test func p2Core01ExistingNavigationInspectionAndP1StayEquivalent() throws {
    let document = try p2Document(#"{"set":[{"x":null},{"x":null},{}],"matrix":[[1,2]],"empty":[]}"#)
    let walk = JSONTraversal(document: document)
    let before = try walk.collect(), shape = try JSONShapeInspector(document: document).inspectArray(at: [.key("set")])
    let table = try JSONSparseTableProjection.build(document: document, at: [.key("set")]).result
    let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
    let tree = try JSONTreeProjection.build(snapshot: snapshot).result
    _ = try JSONStructuralSetProjection.build(document: document, at: [.key("set")])
    _ = try JSONNumericMatrixProjection.build(document: document, at: [.key("matrix")])
    p2SameStatistics(before.statistics, try walk.collect().statistics)
    p2SameStatistics(shape.statistics, try JSONShapeInspector(document: document).inspectArray(at: [.key("set")]).statistics)
    #expect(try table.cell(row: 0, column: 0).result == .null && table.cell(row: 2, column: 0).result == .absent)
    #expect(try tree.value(for: 0).result == document.root)
    #expect(try JSONPointer(parsing: "/empty").resolve(in: document.root) == [])
}
@Test func p2Core02OneAdmissionAndExactLogicalRetainedOutput() throws {
    let document = try p2Document(#"{"s":[1,1,2],"m":[[1,2],[3,4]]}"#), admitted = try p2Admitted(document)
    let set = try JSONStructuralSetProjection.build(document: document, at: [.key("s")])
    let matrix = try JSONNumericMatrixProjection.build(document: document, at: [.key("m")])
    for stats in [set.statistics,matrix.statistics] {
        #expect(stats[.nodes] == admitted.nodes && stats[.sourceMapEntries] == admitted.maps)
    }
    let selection = JSONLogicalWeights.indexSlot + 1 // one exact ASCII key
    #expect(set.statistics[.retainedBytes] == admitted.retained + 128 + selection + 16)
    #expect(matrix.statistics[.retainedBytes] == admitted.retained + 128 + selection)
    #expect(try JSONTraversal(document: document).visit { _,_ in .continue }.statistics[.retainedBytes] == 0)
}
@Test func p2Core03RepresentativeAndCellDifferentialUseCoreAuthorities() throws {
    let document = try p2Fixture("set-equality"), set = try JSONStructuralSetProjection.build(document: document).result
    #expect(set.representativeIndices == [0,2,3,4,6,7,8,10,11,12,13])
    let values = try document.root.read { try $0.requiredArray() }
    var oracle: [Int] = []
    for i in values.indices {
        var duplicate = false
        for first in oracle { if try JSONComparison.equals(values[first], values[i]) { duplicate = true; break } }
        if !duplicate { oracle.append(i) }
    }
    #expect(set.representativeIndices == oracle)
    let matrix = try JSONNumericMatrixProjection.build(document: p2Fixture("matrix-exact")).result
    for r in 0..<matrix.rowCount { for c in 0..<matrix.columnCount {
        let number = try matrix.document.root.read { try $0[r][c].requiredNumber() }
        #expect(try matrix.element(row: r, column: c).result == number)
    } }
}
@Test func p2Core04SignedAndUnsignedAccountingOverflowAreRefusals() throws {
    #expect(p2Failure { _ = try P2Accounting.product(-1, 0, limits: .balanced) }?.code == .invalidLimits)
    #expect(p2Failure { _ = try ProjectionAccounting.next(Int.max, limits: .balanced) }?.code == .counterOverflow)
    #expect(p2Failure { _ = try ProjectionAccounting.bytes(2, unit: UInt64.max, limits: .balanced) }?.resource?.overflow == true)
    #expect(try P2Accounting.product(0, Int.max, limits: .balanced) == 0)
    #expect(try ProjectionAccounting.bytes(Int.max, unit: 1, limits: .balanced) == UInt64(Int.max))
}
private enum P2LateError: Error { case caller }
private struct P2LateProbe<Inner: JSONTraversalOwnedReducer>: JSONTraversalOwnedReducer {
    enum Mode: Sendable { case work, cancelled, twice, caller }
    var inner: Inner
    let mode: Mode
    mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        try inner.observe(hit, value: value, context: &context)
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> Inner.Result {
        let result = try inner.finish(summary, context: &context)
        switch mode {
        case .work: do { try context.work(64_000_000) } catch { }; throw P2LateError.caller
        case .cancelled: withUnsafeCurrentTask { $0?.cancel() }; do { try context.checkpoint() } catch { }
        case .twice: do { _ = try context.transferDocumentOwnership() } catch { }
        case .caller: throw P2LateError.caller
        }
        return result
    }
}
private func p2Late<Inner: JSONTraversalOwnedReducer & Sendable>(document: JSONDocument, inner: Inner, depth: Int) async throws
    where Inner.Result: Sendable {
    for mode in [P2LateProbe<Inner>.Mode.work,.cancelled,.twice,.caller] {
        let cleared = Mutex(false)
        let task = Task {
            var walk = JSONTraversal(document: document)
            walk.lifetimeObserver = { rootGone,stateGone in cleared.withLock { $0 = rootGone && stateGone } }
            var reducer = P2LateProbe(inner: inner, mode: mode)
            return try walk.inspectOwned(options: .init(depthLimit: depth), reducer: &reducer)
        }
        do { _ = try await task.value; Issue.record("No successful artifact after terminal/final failure") }
        catch let error as JSONFailure {
            if mode == .twice { #expect(error.code == .invalidOperation) }
            else { #expect(mode == .work && error.resource?.metric == .workUnits) }
        } catch is CancellationError { #expect(mode == .cancelled) }
        catch is P2LateError { #expect(mode == .caller) }
        #expect(cleared.withLock { $0 })
    }
}
@Test func p2Core05LateFailureAndCancellationNeverReturnArtifact() async throws {
    try await p2Late(document: p2Document("[1,1,2]"), inner: StructuralSetReducer(maximumUniqueItems: 2, limits: .balanced), depth: 1)
    try await p2Late(document: p2Document("[[1,2],[3,4]]"), inner: NumericMatrixReducer(maximumRows: 2, maximumColumns: 2, maximumElements: 4, limits: .balanced), depth: 2)
}
@Test func p2Core06CopiesCaptureOriginalPhysicalSourceAndLexemes() throws {
    let document = try p2Document(#"{"a/b~":[[0.10]],"s":[0.10,0.1]}"#)
    let matrix = try JSONNumericMatrixProjection.build(document: document, at: [.key("a/b~")]).result
    let set = try JSONStructuralSetProjection.build(document: document, at: [.key("s")]).result
    let copy = matrix.transposed(), copiedSet = set
    #expect(copy.selectedArrayPath == [.key("a/b~")] && copy.document.sourceBytes == document.sourceBytes)
    #expect(try copy.element(row: 0, column: 0).result.originalLexeme == "0.10")
    #expect(copiedSet.representativeIndices == [0] && copiedSet.document.sourceMap != nil)
    let modified = document.replacingRoot(.null)
    #expect(modified.sourceMap == nil && modified.sourceBytes == nil)
    #expect(try JSONPointer(parsing: "/a~1b~0/0/0").resolve(in: copy.document.root) == .number(copy.element(row: 0, column: 0).result))
}
private struct P2CaughtQuota: JSONTraversalOwnedReducer {
    mutating func observe(_ hit: JSONTraversalHit, value: JSON, context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        do { try context.work(UInt64.max) } catch { }
        return .stop
    }
    mutating func finish(_ summary: JSONTraversalSummary, context: inout JSONTraversalContext) throws -> Int { 99 }
}
@Test func p2Core07ExclusiveContextCannotClearCaughtTerminalHealth() throws {
    // Full ownership codegen is a separate required script: this is runtime parity.
    var reducer = P2CaughtQuota()
    let error = p2Failure { _ = try JSONTraversal(document: p2Document("[]")).inspectOwned(reducer: &reducer) }
    #expect(error?.category == .resource && error?.resource?.overflow == true)
}
@Test func p2Core08PortableEdgeValuesRemainExactWithoutBinaryCoercion() throws {
    let set = try p2Set(#"[-0,0.00,1e1000,1e1000,"0",false,null]"#)
    #expect(set.representativeIndices == [0,2,4,5,6])
    let matrix = try p2Matrix("[[-0,1e1000],[0.0100,9007199254740993]]")
    #expect(try matrix.transposed().element(row: 1, column: 0).result.originalLexeme == "1e1000")
    #expect(try matrix.element(row: 0, column: 0).result == JSONNumber(integer: 0))
}
@Test func p2Core09DeterministicLogicalReportsAndInclusivePeakCaps() throws {
    let document = try p2Document("[[1,2],[3,4]]")
    let baseline = try JSONNumericMatrixProjection.build(document: document)
    p2SameStatistics(baseline.statistics, try JSONNumericMatrixProjection.build(document: document).statistics)
    for metric in [JSONResourceMetric.workUnits,.retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] = metric == .workUnits ? baseline.statistics[metric] : baseline.statistics.peakLogicalRetainedBytes
        #expect(try JSONNumericMatrixProjection.build(document: document, limits: limits).result.elementCount == 4)
        limits[metric] -= 1
        #expect(p2Failure { _ = try JSONNumericMatrixProjection.build(document: document, limits: limits) }?.resource?.metric == metric)
    }
    let set = try JSONStructuralSetProjection.build(document: document)
    var limits = JSONLimits.balanced; limits[.retainedBytes] = set.statistics.peakLogicalRetainedBytes
    #expect(try JSONStructuralSetProjection.build(document: document, limits: limits).result.uniqueCount == 2)
    limits[.retainedBytes] -= 1
    #expect(p2Failure { _ = try JSONStructuralSetProjection.build(document: document, limits: limits) }?.resource?.metric == .retainedBytes)
    print("P2_MATRIX_RESOURCE rows=2 columns=2 work=\(baseline.statistics[.workUnits]) retained=\(baseline.statistics[.retainedBytes]) peak=\(baseline.statistics.peakLogicalRetainedBytes)")
}
@Test func p2Core10CoreProfilesAndExplicitPrototypeCapsStayFinite() throws {
    #expect(JSONResourceMetric.allCases.count == 49)
    for profile in [JSONLimits.balanced,.offline] {
        for metric in JSONResourceMetric.allCases { #expect(profile[metric] < UInt64.max) }
    }
    #expect(throws: JSONP2ProjectionFailure.uniqueItemLimitExceeded(limit: 0)) {
        _ = try JSONStructuralSetProjection.build(document: p2Document("[null]"), maximumUniqueItems: 0)
    }
    #expect(throws: JSONP2ProjectionFailure.rowLimitExceeded(limit: 0)) {
        _ = try JSONNumericMatrixProjection.build(document: p2Document("[[]]"), maximumRows: 0)
    }
    #expect(throws: JSONP2ProjectionFailure.columnLimitExceeded(limit: 0)) {
        _ = try JSONNumericMatrixProjection.build(document: p2Document("[[0]]"), maximumColumns: 0)
    }
}
