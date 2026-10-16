// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONNavigation
import JSONInspection

@main struct InspectionConsumer {
    static func main() throws {
        var checks = 0
        func check(_ id: String, _ condition: Bool) {
            precondition(condition, id); checks += 1
            print("INSPECTION_CHECK \(id) passed")
        }
        let text = #"[{"é":1,"n":9007199254740993,"x":null},{"e\u0301":2,"n":0.0100},false]"#
        let document = try JSONParser().parseDocument(Data(text.utf8))
        let inspector = JSONShapeInspector(document: document)
        let full = try inspector.inspectArray(includeSourceSpan: true)
        let prefix = try inspector.inspectArray(sampling: .prefix(maximumRows: 2))
        check("coverage", full.result.rowCoverage == .complete && full.result.traversal.completion == .restricted && prefix.result.rowCoverage == .prefix(examined: 2, total: 3) && prefix.result.traversal.completion == .visitorStopped)
        check("observed-only", prefix.result.observedAllObjects == true && full.result.observedAllObjects == false && full.result.observedNonObjectRows == 1)
        let columns = full.result.firstSeenColumns
        check("exact-keys", columns.map(\.key) == [JSONKey("é"), JSONKey("n"), JSONKey("x"), JSONKey("e\u{301}")])
        check("null-missing", columns[2].present == 1 && columns[2].explicitNull == 1 && columns[2].missing == 1 && full.result.observedObjectRows == 2)
        let exact = try document.root.read { try $0[0]["n"].requiredInteger(as: UInt64.self) }
        let number = try document.root.read { try $0[1]["n"].requiredNumber() }
        check("exact-numbers", exact == 9_007_199_254_740_993 && number.originalLexeme == "0.0100")
        let admitted = try document.readWithReport { _ in true }
        check("one-admission", full.statistics[.nodes] == admitted.statistics[.nodes] && prefix.statistics[.nodes] == admitted.statistics[.nodes] && prefix.result.sourceAdmissionComplete)
        let zero = try inspector.inspectArray(sampling: .prefix(maximumRows: 0), maximumColumns: 0)
        check("zero-prefix", zero.result.examinedRows == 0 && zero.result.observedAllObjects == nil && zero.result.observedUniformRowKind == nil)
        var capacity = false
        do { _ = try inspector.inspectArray(maximumColumns: 0) }
        catch JSONShapeInspectionFailure.columnLimitExceeded(limit: 0) { capacity = true }
        check("capacity", capacity)
        var missing = false, wrong = false
        do { _ = try inspector.inspectArray(at: [.index(8)]) }
        catch let failure as JSONAccessFailure { missing = failure.cause.category == .missingValue && failure.path == [.index(8)] }
        do { _ = try inspector.inspectArray(at: [.index(2)]) }
        catch let failure as JSONAccessFailure { wrong = failure.cause.category == .typeMismatch && failure.path == [.index(2)] }
        check("access-fidelity", missing && wrong)
        let replaced = try JSONShapeInspector(document: document.replacingRoot(document.root)).inspectArray(includeSourceSpan: true)
        check("source-coherence", full.result.sourceSpan != nil && replaced.result.sourceSpan == nil)
        var limits = JSONLimits.balanced; limits[.workUnits] = prefix.statistics[.workUnits]
        let exactWork = try JSONShapeInspector(document: document, limits: limits).inspectArray(sampling: .prefix(maximumRows: 2))
        limits[.workUnits] -= 1
        var refused = false
        do { _ = try JSONShapeInspector(document: document, limits: limits).inspectArray(sampling: .prefix(maximumRows: 2)) }
        catch let failure as JSONFailure { refused = failure.resource?.metric == .workUnits }
        check("inclusive-work", refused && exactWork.statistics[.workUnits] == prefix.statistics[.workUnits])
        var bad = false
        limits[.nodes] = 0
        do { _ = try JSONShapeInspector(document: document, limits: limits).inspectArray(sampling: .prefix(maximumRows: -1)) }
        catch let failure as JSONFailure { bad = failure.category == .configuration && failure.code == .invalidLimits }
        check("configuration-precedence", bad)
        print("INSPECTION_RESOURCE work=\(prefix.statistics[.workUnits]) retained=\(prefix.statistics[.retainedBytes]) peak=\(prefix.statistics.peakLogicalRetainedBytes) nodes=\(prefix.statistics[.nodes])")
        print("INSPECTION_CONSUMER passed cases=\(checks)")
    }
}
