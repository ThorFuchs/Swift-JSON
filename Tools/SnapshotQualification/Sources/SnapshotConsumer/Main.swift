// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONNavigation
import JSONInspection

private func expect(_ condition: @autoclosure () throws -> Bool) throws {
    let satisfied = try condition(); precondition(satisfied)
}
private func check(_ name: String, _ body: () throws -> Void) rethrows {
    try body(); print("SNAPSHOT_CHECK \(name) passed")
}
private func failure(_ body: () throws -> Void) -> JSONFailure {
    do { try body(); preconditionFailure("Expected failure") }
    catch let error as JSONFailure { return error }
    catch { preconditionFailure("Unexpected error: \(error)") }
}
private func sendable<T: Sendable>(_ value: T) { _ = value }

@main struct SnapshotConsumer {
    static func main() async throws {
        let source = #"{"":null,"0":[9007199254740993,0.1,0.0100],"é":true,"e\u0301":false,"/":{"~":[]}}"#
        let document = try JSONParser().parseDocument(Data(source.utf8))
        let builder = JSONStructuralSnapshotBuilder(document: document)
        let report = try builder.build()
        let snapshot = report.result
        sendable(builder); sendable(snapshot); sendable(try snapshot.record(at: 0))
        try check("roots") {
            for text in ["null", "false", "1", #""s""#, "{}", "[]"] {
                let one = try JSONStructuralSnapshotBuilder(document: .init(root: JSON.parse(text))).build().result
                try expect(one.recordCount == 1)
                let root = try one.record(at: 0)
                try expect(root.ordinal == 0 && root.parentOrdinal == nil && root.componentFromParent == nil)
                try expect(root.childCount == 0 && root.depth == 0 && root.subtreeEndExclusive == 1)
            }
        }
        try check("typed-paths") {
            try expect(try snapshot.location(for: 0).result == [])
            try expect(try snapshot.location(for: 1).result == [.key("")])
            try expect(try snapshot.location(for: 2).result == [.key("0")])
            try expect(try snapshot.location(for: 3).result == [.key("0"), .index(0)])
            try expect(try snapshot.record(at: 2).componentFromParent != .index(0))
        }
        try check("unicode") {
            try expect(try snapshot.record(at: 6).componentFromParent == .key("é"))
            try expect(try snapshot.record(at: 7).componentFromParent == .key("e\u{301}"))
            try expect(try snapshot.record(at: 6).componentFromParent != snapshot.record(at: 7).componentFromParent)
        }
        try check("numbers") {
            try expect(try snapshot.value(for: 3).result.numberValue?.integer(as: UInt64.self) == 9_007_199_254_740_993)
            try expect(try snapshot.value(for: 4).result.numberValue == JSONNumber(parsing: "0.1"))
            try expect(try snapshot.value(for: 5).result.numberValue?.originalLexeme == "0.0100")
            try expect(try snapshot.value(for: 1).result == .null)
        }
        try check("duplicate-refusal") {
            let error = failure { _ = try JSONParser().parse(#"{"a":0,"\u0061":1}"#) }
            try expect(error.code == .duplicateKey)
        }
        try check("preorder-ranges") {
            let expected = [10,2,6,4,5,6,7,8,10,10]
            try expect(snapshot.recordCount == expected.count)
            for ordinal in 0..<snapshot.recordCount {
                let record = try snapshot.record(at: ordinal)
                try expect(record.ordinal == ordinal && record.subtreeEndExclusive == expected[ordinal])
                if let parent = record.parentOrdinal {
                    try expect(parent < ordinal)
                    try expect(try snapshot.record(at: parent).depth + 1 == record.depth)
                }
            }
        }
        try check("core-differential") {
            let hits = try JSONTraversal(document: document).collect().result.nodes
            try expect(hits.count == snapshot.recordCount)
            for ordinal in hits.indices {
                let path = try snapshot.location(for: ordinal).result
                try expect(path == hits[ordinal].absoluteLocation)
                let pointer = try JSONPointer(tokens: path.map {
                    switch $0 { case .key(let k): k.string; case .index(let i): String(i) }
                })
                try expect(try pointer.resolve(in: document.root) == snapshot.value(for: ordinal).result)
            }
        }
        try check("source-binding") {
            let fresh = try JSONStructuralSnapshotBuilder(document: document.replacingRoot(.array([42]))).build().result
            try expect(try snapshot.value(for: 1).result == .null)
            try expect(try fresh.value(for: 1).result == 42)
            try expect(try snapshot.location(for: 1).result == [.key("")])
            try expect(try fresh.location(for: 1).result == [.index(0)])
            try expect(try fresh.sourceSpan(for: 1).result == nil)
            try expect(try snapshot.sourceSpan(for: 1).result != nil)
        }
        try check("bounds") {
            for ordinal in [-1, snapshot.recordCount, Int.max] {
                for body in [{ _ = try snapshot.record(at: ordinal) },
                             { _ = try snapshot.location(for: ordinal) },
                             { _ = try snapshot.value(for: ordinal) },
                             { _ = try snapshot.sourceSpan(for: ordinal) }] {
                    do { try body(); preconditionFailure("Invalid position admitted") }
                    catch let error as JSONStructuralSnapshotFailure { try expect(error == .ordinalOutOfBounds(ordinal)) }
                    catch { preconditionFailure("Unexpected failure: \(error)") }
                }
            }
        }
        try check("separate-admission") {
            let path = try snapshot.location(for: 3), value = try snapshot.value(for: 3)
            let span = try snapshot.sourceSpan(for: 3)
            for stats in [path.statistics, value.statistics, span.statistics] {
                try expect(stats[.nodes] == report.statistics[.nodes])
                try expect(stats[.sourceMapEntries] == report.statistics[.sourceMapEntries])
                try expect(stats[.workUnits] > 0)
            }
            try expect(report.statistics[.nodes] == UInt64(snapshot.recordCount))
            var noNodes = JSONLimits.balanced; noNodes[.nodes] = 0
            try expect(failure { _ = try snapshot.value(for: 3, limits: noNodes) }.resource?.metric == .nodes)
            print("SNAPSHOT_RESOURCE work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes) nodes=\(report.statistics[.nodes])")
        }
        try check("capacity-configuration") {
            try expect(try builder.build(maximumRecords: snapshot.recordCount).result.recordCount == snapshot.recordCount)
            for cap in [0, snapshot.recordCount-1] {
                do { _ = try builder.build(maximumRecords: cap); preconditionFailure("No partial success") }
                catch let error as JSONStructuralSnapshotFailure { try expect(error == .recordLimitExceeded(limit: cap)) }
            }
            var limits = JSONLimits.balanced; limits[.nodes] = 0
            try expect(failure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build(maximumRecords: -1) }.category == .configuration)
        }
        try check("inclusive-budgets") {
            var limits = JSONLimits.balanced; limits[.workUnits] = report.statistics[.workUnits]
            try expect(try JSONStructuralSnapshotBuilder(document: document, limits: limits).build().result.recordCount == snapshot.recordCount)
            limits[.workUnits] -= 1
            try expect(failure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build() }.resource?.metric == .workUnits)
            limits = .balanced; limits[.retainedBytes] = report.statistics.peakLogicalRetainedBytes
            _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build()
            limits[.retainedBytes] -= 1
            try expect(failure { _ = try JSONStructuralSnapshotBuilder(document: document, limits: limits).build() }.resource?.metric == .retainedBytes)
        }
        try check("coverage-separation") {
            let rows = try JSON.parse(#"[{"a":null},{"b":1},false]"#)
            let evidence = try JSONShapeInspector(document: .init(root: rows)).inspectArray(sampling: .prefix(maximumRows: 2)).result
            try expect(evidence.rowCoverage == .prefix(examined: 2, total: 3))
            try expect(evidence.observedAllObjects == true)
            try expect(try JSONStructuralSnapshotBuilder(document: .init(root: rows)).build().result.recordCount == 6)
        }
        try await withThrowingTaskGroup(of: UInt64.self) { group in
            for _ in 0..<4 { group.addTask { try snapshot.value(for: 3).statistics[.workUnits] } }
            let expected = try snapshot.value(for: 3).statistics[.workUnits]
            for try await work in group { try expect(work == expected) }
        }
        print("SNAPSHOT_CHECK concurrent-lookups passed")
        print("SNAPSHOT_CONSUMER passed cases=14")
    }
}
