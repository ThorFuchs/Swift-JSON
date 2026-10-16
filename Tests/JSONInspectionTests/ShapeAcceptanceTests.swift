// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
import JSONInspection

private func inspector(_ text: String, limits: JSONLimits = .balanced) throws -> JSONShapeInspector {
    .init(document: .init(root: try JSON.parse(text)), limits: limits)
}
private func inspectionFailure(_ body: () throws -> Void) -> JSONFailure? {
    do { try body(); Issue.record("Expected an operational failure"); return nil }
    catch let error as JSONAccessFailure { return error.cause }
    catch let error as JSONFailure { return error }
    catch { Issue.record("Unexpected failure: \(error)"); return nil }
}

@Test func inspectionI01EmptyArrayHasNoPositiveTraits() throws {
    let result = try inspector("[]").inspectArray(maximumColumns: 0).result
    #expect(result.sourceAdmissionComplete && result.rowCoverage == .complete)
    #expect(result.totalRows == 0 && result.examinedRows == 0 && result.firstSeenColumns.isEmpty)
    #expect(JSONTraversalKind.allCases.allSatisfy { result.rowKinds[$0] == 0 })
    #expect(result.observedAllObjects == nil && result.observedUniformRowKind == nil)
    #expect(result.observedArrayLengthRange == nil && result.observedRectangularArrayWidth == nil)
}

@Test func inspectionI02WrongKindThrowsRatherThanEmptyEvidence() throws {
    for text in ["null", "false", "0", "{}", #""text""#] {
        let failure = inspectionFailure { _ = try inspector(text).inspectArray(sampling: .prefix(maximumRows: 0)) }
        #expect(failure?.category == .typeMismatch && failure?.code == .wrongKind)
    }
}

@Test func inspectionI03StrictMissingRootAndEmptyKey() throws {
    let source = try inspector(#"{"":[],"a":[0]}"#)
    #expect(try source.inspectArray(at: [.key("")]).result.totalRows == 0)
    #expect(inspectionFailure { _ = try source.inspectArray() }?.category == .typeMismatch)
    #expect(inspectionFailure { _ = try source.inspectArray(at: [.key("missing")]) }?.category == .missingValue)
    #expect(inspectionFailure { _ = try source.inspectArray(at: [.key("a"), .index(-1)]) }?.code == .invalidIndex)
    #expect(inspectionFailure { _ = try source.inspectArray(at: [.key("a"), .index(1)]) }?.code == .missingTarget)
}

@Test func inspectionI04CompleteObjectRowsRemainRowEvidence() throws {
    let evidence = try inspector(#"[{"id":1,"name":null},{"id":2,"name":"two"}]"#).inspectArray().result
    #expect(evidence.rowCoverage == .complete && evidence.examinedRows == 2)
    #expect(evidence.rowKinds.objects == 2 && evidence.observedObjectRows == 2)
    #expect(evidence.observedAllObjects == true && evidence.observedUniformRowKind == .object)
    #expect(evidence.firstSeenColumns.map(\.key) == [JSONKey("id"), JSONKey("name")])
    #expect(evidence.firstSeenColumns[0].present == 2 && evidence.firstSeenColumns[0].kinds.numbers == 2)
    #expect(evidence.firstSeenColumns[1].explicitNull == 1 && evidence.firstSeenColumns[1].missing == 0)
    #expect(evidence.traversal.completion == .restricted) // Cell subtrees were not traversed.
    #expect(evidence.traversal.visitedCount == 3)
}

@Test func inspectionI05HeterogeneousRowsKeepSixExactKinds() throws {
    let evidence = try inspector(#"[{"a":null},1,null,[],false,"s"]"#).inspectArray().result
    for kind in JSONTraversalKind.allCases { #expect(evidence.rowKinds[kind] == 1) }
    #expect(evidence.observedObjectRows == 1 && evidence.observedNonObjectRows == 5)
    #expect(evidence.firstSeenColumns[0].missing == 0 && evidence.firstSeenColumns[0].explicitNull == 1)
    #expect(evidence.observedAllObjects == false && evidence.observedUniformRowKind == nil)
    #expect(evidence.observedArrayLengthRange == 0...0 && evidence.observedRectangularArrayWidth == nil)
}

@Test func inspectionI06LateCounterexampleCannotBecomePrefixCertification() throws {
    let source = try inspector(#"[{"a":0},{"a":1},false]"#)
    let prefix = try source.inspectArray(sampling: .prefix(maximumRows: 2)).result
    #expect(prefix.rowCoverage == .prefix(examined: 2, total: 3))
    #expect(prefix.observedAllObjects == true && prefix.observedUniformRowKind == .object)
    #expect(prefix.traversal.completion == .visitorStopped)
    let complete = try source.inspectArray().result
    #expect(complete.rowCoverage == .complete && complete.observedAllObjects == false)
    #expect(complete.rowKinds.booleans == 1)
    #expect(try source.inspectArray(sampling: .prefix(maximumRows: 10)).result.rowCoverage == .complete)
}

@Test func inspectionI07ZeroPrefixAndConfigurationPrecedence() throws {
    let source = try inspector("[1,2]")
    let empty = try source.inspectArray(sampling: .prefix(maximumRows: 0)).result
    #expect(empty.totalRows == 2 && empty.examinedRows == 0)
    #expect(empty.rowCoverage == .prefix(examined: 0, total: 2))
    #expect(empty.observedAllObjects == nil && empty.observedUniformRowKind == nil)
    #expect(empty.firstSeenColumns.isEmpty && empty.traversal.completion == .restricted)
    var limits = JSONLimits.balanced; limits[.nodes] = 0
    let constrained = JSONShapeInspector(document: source.document, limits: limits)
    #expect(inspectionFailure { _ = try constrained.inspectArray(sampling: .prefix(maximumRows: -1)) }?.category == .configuration)
    #expect(inspectionFailure { _ = try constrained.inspectArray(maximumColumns: -1) }?.category == .configuration)
    #expect(inspectionFailure { _ = try constrained.inspectArray(sampling: .prefix(maximumRows: 0)) }?.category == .resource)
}

@Test func inspectionI08FirstSeenOrderAndPermutationMetamorphism() throws {
    let first = try inspector(#"[{"z":1,"a":2},{"b":3,"a":4},{"z":5,"c":6}]"#).inspectArray().result
    #expect(first.firstSeenColumns.map(\.key) == ["z", "a", "b", "c"].map { JSONKey($0) })
    #expect(first.firstSeenColumns.map(\.firstRow) == [0, 0, 1, 2])
    #expect(first.firstSeenColumns.map(\.present) == [2, 2, 1, 1])
    #expect(first.firstSeenColumns.map(\.missing) == [1, 1, 2, 2])
    let permuted = try inspector(#"[{"b":3,"a":4},{"z":1,"a":2},{"z":5,"c":6}]"#).inspectArray().result
    #expect(permuted.firstSeenColumns.map(\.key) == ["b", "a", "z", "c"].map { JSONKey($0) })
    #expect(first.rowKinds == permuted.rowKinds)
    let reordered = try inspector(#"[{"a":2,"z":1},{"b":3,"a":4},{"z":5,"c":6}]"#).inspectArray().result
    #expect(reordered.firstSeenColumns.map(\.key) == ["a", "z", "b", "c"].map { JSONKey($0) })
}

@Test func inspectionI09ScalarDistinctKeysNeverNormalize() throws {
    let evidence = try inspector(#"[{"é":null,"e\u0301":1},{"e\u0301":2}]"#).inspectArray().result
    let columns = evidence.firstSeenColumns
    #expect(columns.count == 2 && columns[0].key != columns[1].key)
    #expect(columns[0].key.string == columns[1].key.string) // Swift's canonical equivalence is not the key authority.
    #expect(columns[0].present == 1 && columns[0].missing == 1 && columns[0].explicitNull == 1)
    #expect(columns[1].present == 2 && columns[1].missing == 0)
}

@Test func inspectionI10NumericKeyAndIndexKeepTypedSelection() throws {
    let source = try inspector(#"{"0":[{"0":null}],"a":[[{"0":1}]]}"#)
    let key = try source.inspectArray(at: [.key("0")]).result
    #expect(key.sourceSelection == [.key("0")] && key.firstSeenColumns[0].key == JSONKey("0"))
    let index = try source.inspectArray(at: [.key("a"), .index(0)]).result
    #expect(index.sourceSelection == [.key("a"), .index(0)])
    #expect(inspectionFailure { _ = try source.inspectArray(at: [.index(0)]) }?.category == .typeMismatch)
    #expect(inspectionFailure { _ = try source.inspectArray(at: [.key("a"), .key("0")]) }?.category == .typeMismatch)
}

@Test func inspectionI11NullAndAbsenceHaveDifferentCounts() throws {
    let column = try inspector(#"[{"a":null},{},{"a":false}]"#).inspectArray().result.firstSeenColumns[0]
    #expect(column.present == 2 && column.explicitNull == 1 && column.missing == 1)
    #expect(column.kinds.nulls == 1 && column.kinds.booleans == 1)
    #expect(column.kinds.objects == 0 && column.kinds.numbers == 0)
}

@Test func inspectionI12NonObjectsAreOutsideMissingDenominator() throws {
    let result = try inspector(#"[{"a":1},{},42,null,false,[]]"#).inspectArray().result
    #expect(result.observedObjectRows == 2 && result.observedNonObjectRows == 4)
    #expect(result.firstSeenColumns[0].present == 1 && result.firstSeenColumns[0].missing == 1)
    #expect(result.rowKinds.numbers == 1 && result.rowKinds.nulls == 1)
}

@Test func inspectionI13ExactDecimalsAndLexemesRemainCanonical() throws {
    let source = try inspector(#"[{"n":9007199254740993,"t":0.1,"p":0.0100}]"#)
    let root = source.document.root
    let result = try source.inspectArray().result
    #expect(result.firstSeenColumns.allSatisfy { $0.kinds.numbers == 1 })
    let large = try JSONPointer(tokens: ["0", "n"]).resolve(in: root)
    #expect(try large.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
    #expect(try JSONPointer(tokens: ["0", "t"]).resolve(in: root).numberValue == JSONNumber(parsing: "0.1"))
    #expect(try JSONPointer(tokens: ["0", "p"]).resolve(in: root).numberValue?.originalLexeme == "0.0100")
    #expect(source.document.root == root)
}

@Test func inspectionI14RaggedAndNonnumericArrayRowsAreDescriptive() throws {
    let ragged = try inspector("[[1,2],[3]]").inspectArray().result
    #expect(ragged.observedUniformRowKind == .array && ragged.observedArrayLengthRange == 1...2)
    #expect(ragged.observedRectangularArrayWidth == nil)
    let source = try inspector(#"[["a",null],["b",{}]]"#)
    #expect(try source.inspectArray().result.observedRectangularArrayWidth == 2) // Structural width only, no numeric claim.
    let prefix = try inspector("[[1,2],[3]]").inspectArray(sampling: .prefix(maximumRows: 1)).result
    #expect(prefix.observedRectangularArrayWidth == 2 && prefix.rowCoverage == .prefix(examined: 1, total: 2))
    #expect(try inspector("[[],[],0]").inspectArray().result.observedRectangularArrayWidth == nil)
}

@Test func inspectionI15PrefixStillAdmitsFullSourceExactlyOnce() throws {
    let root = JSON.object(try JSONObject(members: [
        JSONMember("outside", value: .array(Array(repeating: .null, count: 100))),
        JSONMember("rows", value: .array([.null]))
    ]))
    let document = JSONDocument(root: root)
    let ordinary = try JSONTraversal(document: document).visit(scope: .subtree(at: [.key("rows")]),
        options: .init(depthLimit: 1)) { _, _ in .continue }
    let report = try JSONShapeInspector(document: document).inspectArray(at: [.key("rows")], sampling: .prefix(maximumRows: 0))
    #expect(report.statistics[.nodes] == ordinary.statistics[.nodes] && report.statistics[.nodes] == 104)
    #expect(report.result.examinedRows == 0 && report.result.sourceAdmissionComplete)
    var limits = JSONLimits.balanced; limits[.nodes] = 2
    #expect(inspectionFailure {
        _ = try JSONShapeInspector(document: document, limits: limits).inspectArray(at: [.key("rows")], sampling: .prefix(maximumRows: 0))
    }?.resource?.metric == .nodes)
}

@Test func inspectionI16InnerColumnWorkQuotasAndCancellationAreTerminal() async throws {
    let object = try JSONObject(members: (0..<20).map { JSONMember("long-column-key-\($0)", value: .null) })
    let document = JSONDocument(root: .array([.object(object)]))
    var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
    let baseline = try JSONShapeInspector(document: document, limits: limits).inspectArray()
    let keyBytes = object.reduce(UInt64(0)) { $0 + UInt64($1.key.string.utf8.count) }
    #expect(baseline.statistics[.retainedBytes] == 256 + 20 * 192 + keyBytes)
    #expect(try JSONShapeInspector(document: document).inspectArray(maximumColumns: 20).result.firstSeenColumns.count == 20)
    do { _ = try JSONShapeInspector(document: document).inspectArray(maximumColumns: 0); Issue.record("Expected zero-column refusal") }
    catch let error as JSONShapeInspectionFailure { #expect(error == .columnLimitExceeded(limit: 0)) }
    var exact = limits; exact[.workUnits] = baseline.statistics[.workUnits]
    #expect(try JSONShapeInspector(document: document, limits: exact).inspectArray().statistics[.workUnits] == exact[.workUnits])
    exact[.workUnits] -= 1
    #expect(inspectionFailure { _ = try JSONShapeInspector(document: document, limits: exact).inspectArray() }?.resource?.attemptedUsage == baseline.statistics[.workUnits])
    exact = limits; exact[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try JSONShapeInspector(document: document, limits: exact).inspectArray().result.firstSeenColumns.count == 20)
    exact[.retainedBytes] -= 1
    #expect(inspectionFailure { _ = try JSONShapeInspector(document: document, limits: exact).inspectArray() }?.resource?.metric == .retainedBytes)
    do { _ = try JSONShapeInspector(document: document).inspectArray(maximumColumns: 19); Issue.record("Expected column refusal") }
    catch let error as JSONShapeInspectionFailure { #expect(error == .columnLimitExceeded(limit: 19)) }
    let ordinary = try JSONTraversal(document: document, limits: limits).visit(options: .init(depthLimit: 1)) { _, _ in .skipDescendants }
    let threshold = ordinary.statistics[.workUnits] + 100
    #expect(baseline.statistics[.workUnits] > threshold + 16)
    let cancelled = Mutex(false)
    let task = Task {
        var source = JSONShapeInspector(document: document, limits: limits)
        source.checkpointObserver = { work in
            if work >= threshold { cancelled.withLock { $0 = true }; withUnsafeCurrentTask { $0?.cancel() } }
        }
        return try source.inspectArray()
    }
    do { _ = try await task.value; Issue.record("Cancellation cannot publish partial evidence") }
    catch is CancellationError { }
    #expect(cancelled.withLock { $0 })
}

@Test func inspectionI17CoverageSpansReplacementAndSharedInvocations() async throws {
    let document = try JSONParser().parseDocument(Data(#"{"rows":[{"a":null},{"b":1}]}"#.utf8))
    let source = JSONShapeInspector(document: document)
    let mapped = try source.inspectArray(at: [.key("rows")], includeSourceSpan: true)
    #expect(mapped.result.sourceSpan == (try document.sourceMap?.span(at: [.key("rows")])))
    #expect(mapped.result.rowCoverage == .complete && mapped.result.traversal.completion == .restricted)
    let replacement = JSONShapeInspector(document: document.replacingRoot(document.root))
    #expect(try replacement.inspectArray(at: [.key("rows")], includeSourceSpan: true).result.sourceSpan == nil)
    let prefix = try source.inspectArray(at: [.key("rows")], sampling: .prefix(maximumRows: 1))
    #expect(prefix.result.rowCoverage == .prefix(examined: 1, total: 2) && prefix.result.traversal.completion == .visitorStopped)
    try await withThrowingTaskGroup(of: JSONOperationReport<JSONShapeArrayEvidence>.self) { group in
        for _ in 0..<8 { group.addTask { try source.inspectArray(at: [.key("rows")], includeSourceSpan: true) } }
        for try await report in group {
            #expect(report.statistics[.workUnits] == mapped.statistics[.workUnits])
            #expect(report.statistics.peakLogicalRetainedBytes == mapped.statistics.peakLogicalRetainedBytes)
            #expect(report.result.sourceSelection == [.key("rows")] && report.result.rowKinds == mapped.result.rowKinds)
        }
    }
}
