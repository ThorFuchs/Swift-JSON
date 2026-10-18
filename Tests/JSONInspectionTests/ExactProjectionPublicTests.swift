// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONInspection

private func publicDocument(_ text: String) throws -> JSONDocument {
    try JSONParser().parseDocument(Data(text.utf8))
}
private func publicResource(_ operation: () throws -> Void) -> JSONFailure? {
    do { try operation(); Issue.record("Expected operational refusal") }
    catch let error as JSONFailure { return error }
    catch { Issue.record("Unexpected error: \(error)") }
    return nil
}

@Test func exactProjectionPUB01FirstRepresentativesAreMetamorphic() throws {
    for repeats in 1...8 {
        let members = Array(repeating: #"0.10,0.1,1e-1,{"x":1,"y":2},{"y":2,"x":1},[1,2],[2,1],null"#, count: repeats).joined(separator: ",")
        let source = try publicDocument("[" + members + "]")
        let set = try JSONStructuralSetProjection.build(document: source).result
        #expect(set.representativeIndices == [0,3,5,6,7])
        #expect(try set.member(at: 0).result.numberValue?.originalLexeme == "0.10")
        for (position, original) in set.representativeIndices.enumerated() {
            #expect(try set.member(at: position).result == JSONPointer(tokens: [String(original)]).resolve(in: source.root))
        }
    }
}
@Test func exactProjectionPUB02TypedSelectionsRemainPhysical() throws {
    let source = try publicDocument(#"{"":{"0":[[9007199254740993,0.0100]]},"a/b~":[null,null]}"#)
    let matrix = try JSONNumericMatrixProjection.build(document: source, at: [.key(""), .key("0")]).result
    let set = try JSONStructuralSetProjection.build(document: source, at: [.key("a/b~")]).result
    #expect(set.selectedArrayPath == [.key("a/b~")])
    #expect(try set.member(at: 0).result == .null)
    #expect(try matrix.element(row: 0, column: 1).result.originalLexeme == "0.0100")
    #expect(try JSONPointer(parsing: "//0/0/0").resolve(in: source.root).numberValue == matrix.element(row: 0, column: 0).result)
    do { _ = try JSONNumericMatrixProjection.build(document: source, at: [.key(""), .index(0)]); Issue.record("Typed index must refuse") }
    catch let error as JSONAccessFailure { #expect(error.path == [.key(""), .index(0)] && error.cause.code == .wrongKind) }
}
@Test func exactProjectionPUB03BoundsAndConfigurationPrecedence() throws {
    let source = try publicDocument("[[1]]")
    let matrix = try JSONNumericMatrixProjection.build(document: source).result
    let set = try JSONStructuralSetProjection.build(document: source).result
    var none = JSONLimits.balanced; none[.nodes] = 0
    #expect(publicResource { _ = try JSONNumericMatrixProjection.build(document: source, limits: none, maximumColumns: -1) }?.code == .invalidLimits)
    #expect(throws: JSONP2ProjectionFailure.rowOutOfBounds(-1)) { _ = try matrix.element(row: -1, column: Int.max, limits: none) }
    #expect(throws: JSONP2ProjectionFailure.columnOutOfBounds(Int.max)) { _ = try matrix.element(row: 0, column: Int.max, limits: none) }
    #expect(throws: JSONP2ProjectionFailure.memberOutOfBounds(Int.max)) { _ = try set.member(at: Int.max, limits: none) }
    #expect(publicResource { _ = try matrix.element(row: 0, column: 0, limits: none) }?.resource?.metric == .nodes)
}
@Test func exactProjectionPUB04ReadCostIncludesUnselectedSource() throws {
    var costs: [UInt64] = []
    for count in [0, 16, 128] {
        let source = try publicDocument("{\"s\":[0.10,0.1],\"m\":[[0.0100]],\"rest\":[" + Array(repeating: "0", count: count).joined(separator: ",") + "]}")
        let set = try JSONStructuralSetProjection.build(document: source, at: [.key("s")])
        let matrix = try JSONNumericMatrixProjection.build(document: source, at: [.key("m")])
        let member = try set.result.member(at: 0), cell = try matrix.result.element(row: 0, column: 0)
        for statistics in [set.statistics, matrix.statistics, member.statistics, cell.statistics] {
            #expect(statistics[.nodes] == UInt64(count + 8))
            #expect(statistics[.sourceMapEntries] == set.statistics[.sourceMapEntries])
        }
        #expect(member.statistics[.retainedBytes] == 0 && cell.statistics[.retainedBytes] == 0)
        for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
            var limits = JSONLimits.balanced
            limits[metric] = metric == .workUnits ? member.statistics[metric] : member.statistics.peakLogicalRetainedBytes
            #expect(try set.result.member(at: 0, limits: limits).result == member.result)
            limits[metric] -= 1
            #expect(publicResource { _ = try set.result.member(at: 0, limits: limits) }?.resource?.metric == metric)
        }
        costs.append(member.statistics[.workUnits])
        print("EXACT_ACCESS_COST sibling_items=\(count) nodes=\(member.statistics[.nodes]) set_build_work=\(set.statistics[.workUnits]) matrix_build_work=\(matrix.statistics[.workUnits]) member_work=\(member.statistics[.workUnits]) cell_work=\(cell.statistics[.workUnits]) read_retained=\(cell.statistics[.retainedBytes]) read_peak=\(cell.statistics.peakLogicalRetainedBytes)")
    }
    #expect(costs[0] < costs[1] && costs[1] < costs[2])
}
@Test func exactProjectionPUB05ShapeOrientationIsMetamorphic() throws {
    for rows in 0...4 { for columns in 0...4 {
        let row = "[" + (0..<columns).map { String($0) }.joined(separator: ",") + "]"
        let source = try publicDocument("[" + Array(repeating: row, count: rows).joined(separator: ",") + "]")
        let matrix = try JSONNumericMatrixProjection.build(document: source).result
        let width = rows == 0 ? 0 : columns
        #expect(matrix.rowCount == rows && matrix.columnCount == width)
        #expect(matrix.transposed().rowCount == width && matrix.transposed().columnCount == rows)
        #expect(matrix.transposed().transposed().isTransposed == false)
        for r in 0..<rows { for c in 0..<width {
            #expect(try matrix.element(row: r, column: c).result == matrix.transposed().element(row: c, column: r).result)
        } }
    } }
}
@Test func exactProjectionPUB06ParserAndShapeFailuresStayDistinct() throws {
    #expect(throws: JSONFailure.self) { _ = try publicDocument(#"{"x":1,"\u0078":2}"#) }
    for (text, expected) in [
        ("[[1],[2,3]]", JSONP2ProjectionFailure.raggedRow(at: [.index(1)], expected: 1, actual: 2)),
        ("[null]", .nonArrayRow(at: [.index(0)], kind: .null)),
        ("[[null]]", .nonNumericCell(at: [.index(0), .index(0)], kind: .null))] {
        #expect(throws: expected) { _ = try JSONNumericMatrixProjection.build(document: publicDocument(text)) }
    }
    do { _ = try JSONStructuralSetProjection.build(document: publicDocument("{}"), at: [.key("missing")]); Issue.record("Absent selection must fail") }
    catch let error as JSONAccessFailure { #expect(error.cause.code == .missingMember) }
}
@Test func exactProjectionPUB07SharedPublicViewsKeepIndependentHealth() async throws {
    let source = try publicDocument(#"{"s":[0.10,0.1,null],"m":[[9007199254740993,0.0100]]}"#)
    let set = try JSONStructuralSetProjection.build(document: source, at: [.key("s")]).result
    let matrix = try JSONNumericMatrixProjection.build(document: source, at: [.key("m")]).result.transposed()
    let baseline = try set.member(at: 0)
    try await withThrowingTaskGroup(of: JSONOperationStatistics.self) { group in
        for index in 0..<16 { group.addTask {
            if index.isMultiple(of: 2) {
                var none = JSONLimits.balanced; none[.nodes] = 0
                do { _ = try matrix.element(row: 0, column: 0, limits: none); Issue.record("Must refuse") }
                catch let error as JSONFailure { #expect(error.resource?.metric == .nodes) }
            }
            #expect(try matrix.element(row: 0, column: 0).result.integer(as: UInt64.self) == 9_007_199_254_740_993)
            return try set.member(at: 0).statistics
        } }
        for try await statistics in group {
            #expect(statistics[.workUnits] == baseline.statistics[.workUnits])
            #expect(statistics[.retainedBytes] == baseline.statistics[.retainedBytes])
        }
    }
}
@Test func exactProjectionPUB08CancellationKeepsCapturedSourceHealthy() async throws {
    let source = try publicDocument("[0.10,0.1]")
    let set = try JSONStructuralSetProjection.build(document: source).result
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try set.member(at: 0)
    }
    do { _ = try await task.value; Issue.record("No successful cancelled read") } catch is CancellationError { }
    #expect(try set.member(at: 0).result.numberValue?.originalLexeme == "0.10")
    #expect(set.document.sourceMap != nil)
    #expect(source.replacingRoot(.null).sourceMap == nil)
}
