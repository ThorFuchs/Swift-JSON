// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONInspection

private struct CapacityCounters: Encodable {
    let work: UInt64, nodes: UInt64, retained: UInt64, peak: UInt64
    init(_ statistics: JSONOperationStatistics) {
        work = statistics[.workUnits]; nodes = statistics[.nodes]
        retained = statistics[.retainedBytes]; peak = statistics.peakLogicalRetainedBytes
    }
}
private struct CapacitySingles: Encodable {
    let workSum: UInt64, nodesSum: UInt64
    let maximumInvocationRetained: UInt64, maximumInvocationPeak: UInt64
}
private struct CapacityCell: Encodable {
    let id: String, operation: String, requests: Int, fixture: String, outcome: String
    let report: CapacityCounters?, independentSingles: CapacitySingles?
    let requestBoundary: Bool?, workBoundary: Bool?, retentionBoundary: Bool?
    let errorMetric: String?, errorLimit: UInt64?, errorAttempted: UInt64?, errorStage: String?
}
private struct CapacityReceipt: Encodable {
    let schemaVersion = 1
    let profile = "balanced"
    let scope = "Owned-work and logical retention observations; no elapsed-time, allocation, RSS or throughput measurement. Fixture construction, expected-value comparison and caller array copies are caller work."
    let cells: [CapacityCell]
}
private enum CapacityInvariant: Error { case result, boundary, overflow }
private func capacitySum(_ lhs: UInt64, _ rhs: UInt64) throws -> UInt64 {
    let (result, overflow) = lhs.addingReportingOverflow(rhs)
    guard !overflow else { throw CapacityInvariant.overflow }; return result
}
private func capacityProfile() -> JSONStoreProfile {
    .init(version: .v1, collectionsAt: [], collections: [
        .init(name: "records", recordsAt: [.key("records")], idKey: "id", referenceFields: [.init(key: "next", presence: .required, nullable: true)])
    ], references: .strict(marker: .v1, validateTargets: true))
}
private func capacityFixture(_ count: Int) throws -> Data {
    var records: [JSON] = []
    for index in 0..<count {
        let next: JSON = index + 1 == count ? .null : .object(try JSONObject(members: [
            .init("collection", value: "records"), .init("id", value: .string(String(index + 1)))]))
        records.append(.object(try JSONObject(members: [
            .init("id", value: .string(String(index))), .init("amount", value: .number(JSONNumber(parsing: String(UInt64(9_007_199_254_740_993) + UInt64(index))))), .init("next", value: next)])))
    }
    return try JSONWriter(options: .init(numberStyle: .preserved)).write(.object(JSONObject(members: [.init("records", value: .array(records))])))
}
private func sumSingles(_ count: Int, _ body: (Int) throws -> JSONOperationReport<JSON>) throws -> CapacitySingles {
    var work: UInt64 = 0, nodes: UInt64 = 0, peak: UInt64 = 0, retained: UInt64 = 0
    for index in 0..<count {
        let report = try body(index)
        work = try capacitySum(work, report.statistics[.workUnits]); nodes = try capacitySum(nodes, report.statistics[.nodes])
        peak = max(peak, report.statistics.peakLogicalRetainedBytes)
        retained = max(retained, report.statistics[.retainedBytes])
    }
    // Operations finish independently; maxima are not added as simultaneous live memory.
    return .init(workSum: work, nodesSum: nodes, maximumInvocationRetained: retained, maximumInvocationPeak: peak)
}
private func capacityResource(_ body: () throws -> Void, metric: JSONResourceMetric) throws {
    do { try body(); throw CapacityInvariant.boundary }
    catch let error as JSONFailure { guard error.resource?.metric == metric else { throw error } }
}
private func capacityBoundaries<Result>(_ report: JSONOperationReport<Result>, _ body: (JSONLimits) throws -> JSONOperationReport<Result>) throws {
    var limits = JSONLimits.balanced
    limits[.workUnits] = report.statistics[.workUnits]
    limits[.retainedBytes] = report.statistics.peakLogicalRetainedBytes
    _ = try body(limits)
    limits[.workUnits] -= 1
    try capacityResource({ _ = try body(limits) }, metric: .workUnits)
    limits = .balanced; limits[.retainedBytes] = report.statistics.peakLogicalRetainedBytes - 1
    try capacityResource({ _ = try body(limits) }, metric: .retainedBytes)
}

func structuralCapacity(output: URL) throws {
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let fixtureDirectory = output.appendingPathComponent("fixtures")
    try FileManager.default.createDirectory(at: fixtureDirectory, withIntermediateDirectories: true)
    let fixedBytes = try capacityFixture(8)
    try fixedBytes.write(to: fixtureDirectory.appendingPathComponent("fixed-eight.json"))
    let document = try JSONParser().parseDocument(fixedBytes)
    let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
    let store = try JSONStoreBuilder(document: document, profile: capacityProfile()).build().result
    var amountOrdinals: [Int] = []
    for ordinal in 0..<snapshot.recordCount {
        if case .key(let key)? = try snapshot.record(at: ordinal).componentFromParent, key == JSONKey("amount") { amountOrdinals.append(ordinal) }
    }
    guard amountOrdinals.count == 8 else { throw CapacityInvariant.result }
    let expected = try (0..<8).map { JSON.number(try JSONNumber(parsing: String(UInt64(9_007_199_254_740_993) + UInt64($0)))) }
    var cells: [CapacityCell] = []
    for count in [1, 8, 64, 512] {
        let paths = (0..<count).map { [JSONLocationComponent.key("records"), .index($0 % 8), .key("amount")] }
        let ordinals = (0..<count).map { amountOrdinals[$0 % 8] }
        let positions = try (0..<count).map { try store.record(collection: 0, row: $0 % 8).position }
        for operation in ["path-batch", "snapshot-batch", "store-values"] {
            func batch(_ limits: JSONLimits, maximum: Int) throws -> JSONOperationReport<[JSON]> {
                switch operation {
                case "path-batch": return try JSONInspectionBatch(document: document, limits: limits).values(at: paths, maximumRequests: maximum)
                case "snapshot-batch": return try snapshot.values(for: ordinals, maximumRequests: maximum, limits: limits)
                default: return try store.values(at: positions, maximumRequests: maximum, limits: limits)
                }
            }
            let report = try batch(.balanced, maximum: count)
            guard report.result.count == count else { throw CapacityInvariant.result }
            for (index, value) in report.result.enumerated() {
                let observed = operation == "store-values" ? try value.requiredMember("amount") : value
                guard observed == expected[index % 8] else { throw CapacityInvariant.result }
            }
            let singles = try sumSingles(count) { index in
                switch operation {
                case "path-batch": return try document.readWithReport { try $0["records"][index % 8]["amount"].requiredValue() }
                case "snapshot-batch": return try snapshot.value(for: ordinals[index])
                default: return try store.value(at: positions[index])
                }
            }
            guard singles.nodesSum == report.statistics[.nodes] * UInt64(count) else { throw CapacityInvariant.result }
            do { _ = try batch(.balanced, maximum: count - 1); throw CapacityInvariant.boundary }
            catch let error as JSONInspectionBatchFailure {
                guard error == .requestLimitExceeded(limit: count - 1, actual: count) else { throw error }
            }
            try capacityBoundaries(report) { try batch($0, maximum: count) }
            cells.append(.init(id: operation + "-" + String(count), operation: operation, requests: count, fixture: "fixed-eight.json", outcome: "completed",
                report: .init(report.statistics), independentSingles: singles, requestBoundary: true, workBoundary: true, retentionBoundary: true,
                errorMetric: nil, errorLimit: nil, errorAttempted: nil, errorStage: nil))
        }
        let name = "chain-" + String(count) + ".json", fixture = try capacityFixture(count)
        try fixture.write(to: fixtureDirectory.appendingPathComponent(name))
        func refusal(_ error: JSONFailure, stage: String) throws -> CapacityCell {
            guard error.category == .resource, let resource = error.resource else { throw error }
            return .init(id: "follow-chain-" + String(count), operation: "follow-chain", requests: count, fixture: name, outcome: "operational_error",
                report: nil, independentSingles: nil, requestBoundary: nil, workBoundary: nil, retentionBoundary: nil,
                errorMetric: resource.metric.rawValue, errorLimit: resource.limit, errorAttempted: resource.attemptedUsage, errorStage: stage)
        }
        let chain: JSONConfiguredStore
        do { chain = try JSONStoreBuilder(document: JSONParser().parseDocument(fixture), profile: capacityProfile()).build().result }
        catch let error as JSONFailure { cells.append(try refusal(error, stage: "construction")); continue }
        let start = try chain.record(collection: 0, row: 0).position
        var bounds = JSONStoreFollowLimits(); bounds.maximumDepth = count - 1; bounds.maximumFrontier = 1
        bounds.maximumVisited = count; bounds.maximumResults = count
        let report: JSONOperationReport<[JSONStorePosition]>
        do { report = try chain.follow(from: start, bounds: bounds) }
        catch let error as JSONFailure { cells.append(try refusal(error, stage: "follow")); continue }
        guard report.result.map(\.row) == Array(0..<count) else { throw CapacityInvariant.result }
        // Boundary failures are acceptance failures, never reclassified as diagnostic capacity refusals.
        try capacityBoundaries(report) { try chain.follow(from: start, bounds: bounds, limits: $0) }
        bounds.maximumResults = count - 1
        do { _ = try chain.follow(from: start, bounds: bounds); throw CapacityInvariant.boundary }
        catch let error as JSONStoreFailure { guard error.code == .capacityExceeded && error.capacity == "maximumResults" else { throw error } }
        cells.append(.init(id: "follow-chain-" + String(count), operation: "follow-chain", requests: count, fixture: name, outcome: "completed",
            report: .init(report.statistics), independentSingles: nil, requestBoundary: true, workBoundary: true, retentionBoundary: true,
            errorMetric: nil, errorLimit: nil, errorAttempted: nil, errorStage: nil))

    }
    let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(CapacityReceipt(cells: cells)).write(to: output.appendingPathComponent("cells.json"))
    print("CAPACITY18 observed cells=\(cells.count) completed=\(cells.filter { $0.outcome == "completed" }.count) operational=\(cells.filter { $0.outcome == "operational_error" }.count)")
}
