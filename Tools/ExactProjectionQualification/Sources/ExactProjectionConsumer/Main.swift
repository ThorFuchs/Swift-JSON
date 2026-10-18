// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONInspection

private func expect(_ value: @autoclosure () throws -> Bool) throws { let ok = try value(); precondition(ok) }
private func check(_ name: String, _ body: () throws -> Void) rethrows {
    try body(); print("EXACT_PROJECTION_CHECK \(name) passed")
}
private func document(_ text: String) throws -> JSONDocument {
    try JSONParser().parseDocument(Data(text.utf8))
}
private func resource(_ body: () throws -> Void) -> JSONFailure {
    do { try body(); preconditionFailure("Expected operational error") }
    catch let error as JSONFailure { return error }
    catch { preconditionFailure("Unexpected error: \(error)") }
}
private func sendable<T: Sendable>(_ value: T) { _ = value }

@main struct ExactProjectionConsumer {
    static func main() async throws {
        let source = try document(#"{"s":[0.10,0.1,1e-1,null,null,9007199254740993,9007199254740992,{"x":1,"y":2},{"y":2,"x":1},"é","e\u0301"],"m":[[0.0100,9007199254740993],[-2,0.1]],"empty":[[],[]]}"#)
        let built = try JSONStructuralSetProjection.build(document: source, at: [.key("s")])
        let set = built.result
        let matrixBuilt = try JSONNumericMatrixProjection.build(document: source, at: [.key("m")])
        let matrix = matrixBuilt.result
        sendable(set); sendable(matrix); sendable(JSONP2ProjectionFailure.rowOutOfBounds(0))
        try check("public-import") { try expect(set.inputCount == 11 && matrix.elementCount == 4) }
        try check("first-lexeme") {
            try expect(set.representativeIndices == [0,3,5,6,7,9,10])
            try expect(try set.member(at: 0).result.numberValue?.originalLexeme == "0.10")
        }
        try check("large-integers") {
            try expect(try set.member(at: 2).result.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
            try expect(try set.member(at: 2).result != set.member(at: 3).result)
        }
        try check("exact-scalars") {
            try expect(try set.member(at: 5).result != set.member(at: 6).result)
            let distinct = try JSONStructuralSetProjection.build(document: document(#"[{"é":1},{"e\u0301":1}]"#)).result
            try expect(distinct.uniqueCount == 2)
        }
        try check("ordered-and-unordered") {
            let view = try JSONStructuralSetProjection.build(document: document(#"[{"x":1,"y":2},{"y":2,"x":1},[1,2],[2,1]]"#)).result
            try expect(view.representativeIndices == [0,2,3])
            let object = try view.member(at: 0).result.objectValue!
            try expect(object[0].key == JSONKey("x"))
        }
        try check("null-and-missing") {
            try expect(try set.member(at: 1).result == .null)
            do { _ = try JSONStructuralSetProjection.build(document: source, at: [.key("missing")]); preconditionFailure() }
            catch let error as JSONAccessFailure { try expect(error.cause.code == .missingMember) }
        }
        try check("source-positions") {
            for (position, offset) in set.representativeIndices.enumerated() {
                try expect(try set.member(at: position).result == JSONPointer(tokens: ["s", String(offset)]).resolve(in: source.root))
            }
        }
        try check("captured-source") {
            let replaced = source.replacingRoot(.null)
            try expect(replaced.sourceMap == nil && replaced.sourceBytes == nil)
            try expect(set.document.sourceMap != nil && matrix.document.sourceBytes == source.sourceBytes)
            try expect(try set.member(at: 0).result.numberValue?.originalLexeme == "0.10")
        }
        try check("numeric-matrix") {
            try expect(try matrix.element(row: 0, column: 0).result.originalLexeme == "0.0100")
            try expect(try matrix.element(row: 0, column: 1).result.integer(as: UInt64.self) == 9_007_199_254_740_993)
        }
        try check("zero-shapes") {
            let zero = try JSONNumericMatrixProjection.build(document: document("[]")).result
            let transposed = try JSONNumericMatrixProjection.build(document: source, at: [.key("empty")]).result.transposed()
            try expect(zero.rowCount == 0 && zero.columnCount == 0)
            try expect(transposed.rowCount == 0 && transposed.columnCount == 2 && transposed.elementCount == 0)
            do { _ = try transposed.element(row: 0, column: 0); preconditionFailure() }
            catch JSONP2ProjectionFailure.rowOutOfBounds(0) { }
        }
        try check("orientation") {
            let twice = matrix.transposed().transposed()
            try expect(!twice.isTransposed && twice.rowCount == 2 && twice.columnCount == 2)
            for row in 0..<2 { for column in 0..<2 {
                try expect(try matrix.transposed().element(row: column, column: row).result.originalLexeme == twice.element(row: row, column: column).result.originalLexeme)
            } }
        }
        try check("shape-refusals") {
            do { _ = try JSONNumericMatrixProjection.build(document: document("[[1],[2,3]]")); preconditionFailure() }
            catch JSONP2ProjectionFailure.raggedRow(let path, let expected, let actual) { try expect(path == [.index(1)] && expected == 1 && actual == 2) }
            do { _ = try JSONNumericMatrixProjection.build(document: document("[false]")); preconditionFailure() }
            catch JSONP2ProjectionFailure.nonArrayRow(let path, .boolean) { try expect(path == [.index(0)]) }
            do { _ = try JSONNumericMatrixProjection.build(document: document("[[null]]")); preconditionFailure() }
            catch JSONP2ProjectionFailure.nonNumericCell(let path, .null) { try expect(path == [.index(0), .index(0)]) }
        }
        try check("bounds-precedence") {
            var none = JSONLimits.balanced; none[.nodes] = 0
            do { _ = try matrix.element(row: -1, column: Int.max, limits: none); preconditionFailure() }
            catch JSONP2ProjectionFailure.rowOutOfBounds(-1) { }
            do { _ = try matrix.element(row: 0, column: Int.max, limits: none); preconditionFailure() }
            catch JSONP2ProjectionFailure.columnOutOfBounds(Int.max) { }
            do { _ = try set.member(at: Int.max, limits: none); preconditionFailure() }
            catch JSONP2ProjectionFailure.memberOutOfBounds(Int.max) { }
        }
        try check("inclusive-capacity") {
            try expect(try JSONStructuralSetProjection.build(document: source, at: [.key("s")], maximumUniqueItems: 7).result.uniqueCount == 7)
            do { _ = try JSONStructuralSetProjection.build(document: source, at: [.key("s")], maximumUniqueItems: 6); preconditionFailure() }
            catch JSONP2ProjectionFailure.uniqueItemLimitExceeded(limit: 6) { }
            try expect(try JSONNumericMatrixProjection.build(document: source, at: [.key("m")], maximumRows: 2, maximumColumns: 2, maximumElements: 4).result.elementCount == 4)
            do { _ = try JSONNumericMatrixProjection.build(document: source, at: [.key("m")], maximumElements: 3); preconditionFailure() }
            catch JSONP2ProjectionFailure.elementLimitExceeded(limit: 3) { }
        }
        try check("cumulative-reports") {
            let admitted = try source.root.readWithReport { _ in true }
            for stats in [built.statistics, matrixBuilt.statistics, try set.member(at: 0).statistics, try matrix.element(row: 0, column: 0).statistics] {
                try expect(stats[.nodes] == admitted.statistics[.nodes] && stats[.workUnits] > 0)
            }
            print("EXACT_PROJECTION_RESOURCE work=\(built.statistics[.workUnits]) retained=\(built.statistics[.retainedBytes]) peak=\(built.statistics.peakLogicalRetainedBytes) nodes=\(built.statistics[.nodes])")
        }
        try check("inclusive-ledgers") {
            for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
                var limits = JSONLimits.balanced
                limits[metric] = metric == .workUnits ? built.statistics[metric] : built.statistics.peakLogicalRetainedBytes
                try expect(try JSONStructuralSetProjection.build(document: source, at: [.key("s")], limits: limits).result.uniqueCount == 7)
                limits[metric] -= 1
                try expect(resource { _ = try JSONStructuralSetProjection.build(document: source, at: [.key("s")], limits: limits) }.resource?.metric == metric)
            }
        }
        try check("typed-root-paths") {
            let nested = try document(#"{"":{"0":[[0.10]]}}"#)
            let view = try JSONNumericMatrixProjection.build(document: nested, at: [.key(""), .key("0")]).result
            try expect(try view.element(row: 0, column: 0).result.originalLexeme == "0.10")
            do { _ = try JSONNumericMatrixProjection.build(document: nested, at: [.key(""), .index(0)]); preconditionFailure() }
            catch let error as JSONAccessFailure { try expect(error.cause.code == .wrongKind) }
        }
        try check("separate-read-cost") {
            for size in [0,16,128] {
                let doc = try document("{\"s\":[0.10],\"m\":[[0.10]],\"rest\":[" + Array(repeating: "0", count: size).joined(separator: ",") + "]}")
                let s = try JSONStructuralSetProjection.build(document: doc, at: [.key("s")]).result
                let m = try JSONNumericMatrixProjection.build(document: doc, at: [.key("m")]).result
                let member = try s.member(at: 0), cell = try m.element(row: 0, column: 0)
                try expect(member.statistics[.nodes] == UInt64(size + 7) && cell.statistics[.nodes] == UInt64(size + 7))
                try expect(member.statistics[.retainedBytes] == 0 && cell.statistics[.retainedBytes] == 0)
                print("EXACT_ACCESS_COST sibling_items=\(size) nodes=\(cell.statistics[.nodes]) member_work=\(member.statistics[.workUnits]) cell_work=\(cell.statistics[.workUnits]) read_retained=\(cell.statistics[.retainedBytes]) read_peak=\(cell.statistics.peakLogicalRetainedBytes)")
            }
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<8 { group.addTask {
                try expect(try set.member(at: 0).result.numberValue?.originalLexeme == "0.10")
                try expect(try matrix.transposed().element(row: 1, column: 0).result.integer(as: UInt64.self) == 9_007_199_254_740_993)
            } }
            try await group.waitForAll()
        }
        print("EXACT_PROJECTION_CHECK concurrent-reads passed")
        let cancelled = Task { withUnsafeCurrentTask { $0?.cancel() }; return try set.member(at: 0) }
        do { _ = try await cancelled.value; preconditionFailure("Cancelled operation cannot publish") } catch is CancellationError { }
        try expect(try set.member(at: 0).result.numberValue?.originalLexeme == "0.10")
        print("EXACT_PROJECTION_CHECK cancellation-health passed")
        print("EXACT_PROJECTION_CONSUMER passed cases=20")
    }
}
