// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONNavigation
import JSONInspection

private func expect(_ condition: @autoclosure () throws -> Bool) throws {
    let satisfied = try condition(); precondition(satisfied)
}
private func check(_ name: String, _ body: () throws -> Void) rethrows {
    try body(); print("PROJECTION_CHECK \(name) passed")
}
private func document(_ text: String) throws -> JSONDocument {
    try JSONParser().parseDocument(Data(text.utf8))
}
private func resource(_ body: () throws -> Void) -> JSONFailure {
    do { try body(); preconditionFailure("Expected operational failure") }
    catch let error as JSONFailure { return error }
    catch { preconditionFailure("Unexpected error: \(error)") }
}
private func sendable<T: Sendable>(_ value: T) { _ = value }

@main struct ProjectionConsumer {
    static func main() async throws {
        let source = try document(#"{"":null,"0":[9007199254740993,0.1,0.0100],"rows":[{"é":null,"n":9007199254740993},{"e\u0301":0.0100},{}]}"#)
        let captured = try JSONStructuralSnapshotBuilder(document: source).build()
        let snapshot = captured.result
        let treeReport = try JSONTreeProjection.build(snapshot: snapshot)
        let tree = treeReport.result
        let built = try JSONSparseTableProjection.build(document: source, at: [.key("rows")])
        let table = built.result
        sendable(tree); sendable(table); sendable(JSONProjectionFailure.rowOutOfBounds(-1))

        try check("scalar-roots") {
            for text in ["null", "false", "1", #""s""#, "{}", "[]"] {
                let one = try JSONStructuralSnapshotBuilder(document: document(text)).build().result
                let view = try JSONTreeProjection.build(snapshot: one).result
                try expect(view.rootOrdinal == 0 && view.endExclusive == 1)
                try expect(try view.children(of: 0).result.isEmpty)
                try expect(try view.subtreeOrdinals(of: 0).result == [0])
            }
        }
        try check("selected-interval") {
            let selected = try JSONTreeProjection.build(snapshot: snapshot, rootOrdinal: 2).result
            try expect(selected.rootOrdinal == 2 && selected.endExclusive == 6)
            let root = try selected.record(at: 2)
            try expect(root.parentOrdinal == 0 && root.depth == 1)
            try expect(try selected.children(of: 2).result == [3,4,5])
            do { _ = try selected.record(at: 1); preconditionFailure("Outside interval") }
            catch JSONProjectionFailure.outsideSelectedSubtree(let ordinal) { try expect(ordinal == 1) }
        }
        try check("typed-locations") {
            try expect(try tree.location(for: 0).result == [])
            try expect(try tree.location(for: 1).result == [.key("")])
            try expect(try tree.location(for: 2).result == [.key("0")])
            try expect(try tree.location(for: 3).result == [.key("0"), .index(0)])
            try expect(try tree.record(at: 2).componentFromParent != .index(0))
        }
        try check("exact-values") {
            try expect(try tree.value(for: 3).result.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
            try expect(try tree.value(for: 4).result.numberValue == JSONNumber(parsing: "0.1"))
            try expect(try tree.value(for: 5).result.numberValue?.originalLexeme == "0.0100")
            if case .value(let n) = try table.cell(row: 0, column: 1).result {
                try expect(try n.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
            } else { preconditionFailure("Exact nonnull integer required") }
        }
        try check("canonical-order") {
            try expect(try tree.children(of: 0).result == [1,2,6])
            let visited = try JSONTraversal(document: source).collect().result
            let positions = try tree.subtreeOrdinals(of: 0).result
            try expect(positions.count == snapshot.recordCount)
            for index in positions.indices {
                try expect(try tree.location(for: positions[index]).result == visited.nodes[index].absoluteLocation)
            }
        }
        try check("source-coherence") {
            try expect(try tree.sourceSpan(for: 3).result != nil)
            let replacement = source.replacingRoot(.null)
            let other = try JSONTreeProjection.build(snapshot: JSONStructuralSnapshotBuilder(document: replacement).build().result).result
            try expect(try other.sourceSpan(for: 0).result == nil)
            try expect(try tree.value(for: 0).result == source.root)
        }
        try check("complete-columns") {
            try expect(table.rowCount == 3 && table.selectedArrayPath == [.key("rows")])
            try expect(table.columns == [JSONKey("é"), JSONKey("n"), JSONKey("e\u{301}")])
            try expect(table.document.root == source.root)
            // Row admission is complete even though nested traversal is restricted.
            try expect(table.traversal.visitedCount == 4)
        }
        try check("scalar-key-columns") {
            try expect(table.columns[0] != table.columns[2])
            if case .value(let value) = try table.cell(row: 1, column: 2).result {
                try expect(value.numberValue?.originalLexeme == "0.0100")
            } else { preconditionFailure("Scalar-distinct key required") }
            try expect(try table.cell(row: 1, column: 0).result == .absent)
        }
        try check("presence") {
            try expect(try table.cell(row: 0, column: 0).result == .null)
            try expect(try table.cell(row: 2, column: 0).result == .absent)
            try expect(try table.cell(row: 0, column: 1).result != .null)
        }
        try check("empty-tables") {
            let zero = try JSONSparseTableProjection.build(document: document("[]")).result
            let rows = try JSONSparseTableProjection.build(document: document("[{},{}]")).result
            try expect(zero.rowCount == 0 && zero.columns.isEmpty)
            try expect(rows.rowCount == 2 && rows.columns.isEmpty)
            do { _ = try rows.cell(row: 0, column: 0); preconditionFailure("No fabricated cell") }
            catch JSONProjectionFailure.columnOutOfBounds(let column) { try expect(column == 0) }
        }
        try check("equal-physical-rows") {
            let equal = try JSONSparseTableProjection.build(document: document(#"[{"0":7},{"0":7}]"#)).result
            try expect(equal.rowCount == 2 && equal.columns == [JSONKey("0")])
            try expect(try equal.cell(row: 0, column: 0).result == equal.cell(row: 1, column: 0).result)
        }
        try check("late-row-refusal") {
            let late = try document(#"{"rows":[{},{},false]}"#)
            let evidence = try JSONShapeInspector(document: late).inspectArray(at: [.key("rows")], sampling: .prefix(maximumRows: 2)).result
            try expect(evidence.observedAllObjects == true)
            do { _ = try JSONSparseTableProjection.build(document: late, at: [.key("rows")]); preconditionFailure("Prefix cannot certify suffix") }
            catch JSONProjectionFailure.nonObjectRow(let path, let kind) {
                try expect(path == [.key("rows"), .index(2)] && kind == .boolean)
            }
        }
        try check("capacity-and-bounds") {
            do { _ = try tree.children(of: 0, maximumRecords: 2); preconditionFailure("No partial catalogue") }
            catch JSONProjectionFailure.recordLimitExceeded(let cap) { try expect(cap == 2) }
            do { _ = try JSONSparseTableProjection.build(document: source, at: [.key("rows")], maximumRows: 2); preconditionFailure("All rows required") }
            catch JSONProjectionFailure.rowLimitExceeded(let cap) { try expect(cap == 2) }
            do { _ = try table.cell(row: -1, column: 0); preconditionFailure("No absent fallback") }
            catch JSONProjectionFailure.rowOutOfBounds(let row) { try expect(row == -1) }
            var none = JSONLimits.balanced; none[.nodes] = 0
            try expect(resource { _ = try JSONSparseTableProjection.build(document: source, limits: none, maximumColumns: -1) }.category == .configuration)
        }
        try check("separate-admission") {
            let lookup = try table.cell(row: 2, column: 0)
            for stats in [treeReport.statistics, built.statistics, lookup.statistics] {
                try expect(stats[.nodes] == captured.statistics[.nodes])
                try expect(stats[.sourceMapEntries] == captured.statistics[.sourceMapEntries])
                try expect(stats[.workUnits] > 0)
            }
            print("PROJECTION_RESOURCE work=\(built.statistics[.workUnits]) retained=\(built.statistics[.retainedBytes]) peak=\(built.statistics.peakLogicalRetainedBytes) nodes=\(built.statistics[.nodes])")
        }
        try check("inclusive-ledgers") {
            for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
                var limits = JSONLimits.balanced
                limits[metric] = metric == .workUnits ? built.statistics[metric] : built.statistics.peakLogicalRetainedBytes
                try expect(try JSONSparseTableProjection.build(document: source, at: [.key("rows")], limits: limits).result.rowCount == 3)
                limits[metric] -= 1
                try expect(resource { _ = try JSONSparseTableProjection.build(document: source, at: [.key("rows")], limits: limits) }.resource?.metric == metric)
            }
        }
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try JSONSparseTableProjection.build(document: source, at: [.key("rows")])
        }
        do { _ = try await cancelled.value; preconditionFailure("No artifact on cancellation") }
        catch is CancellationError { }
        try expect(try table.cell(row: 0, column: 0).result == .null)
        print("PROJECTION_CHECK cancellation-health passed")
        print("PROJECTION_CONSUMER passed cases=16")
    }
}
