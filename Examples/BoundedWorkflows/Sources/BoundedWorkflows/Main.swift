// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONNavigation
import JSONInspection

@main struct BoundedWorkflows {
    static func main() throws {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.count == 2, arguments[0] == "--capacity" {
            try structuralCapacity(output: URL(fileURLWithPath: arguments[1]))
            return
        }
        precondition(arguments.isEmpty, "Use no arguments, or --capacity OUTPUT_DIRECTORY")
        func witness(_ id: String, _ success: Bool) {
            precondition(success, id); print("WORKFLOW_CASE \(id) passed")
        }
        let document = try JSONParser().parseDocument(Data(#"{"collections":{"u":[{"id":"é","amount":9007199254740993,"next":{"collection":"u","id":"e\u0301"}},{"id":"e\u0301","next":{"collection":"u","id":"é"}}]},"nothing":null}"#.utf8))
        let paths: [[JSONLocationComponent]] = [[.key("collections"), .key("u"), .index(0), .key("amount")], [.key("nothing")], [.key("nothing")]]
        let batch = try JSONInspectionBatch(document: document).values(at: paths)
        witness("batch-exact-order", batch.result == [.number(try JSONNumber(parsing: "9007199254740993")), .null, .null])
        do { _ = try JSONInspectionBatch(document: document).values(at: [[],[.key("missing")]]); preconditionFailure() }
        catch let error as JSONAccessFailure { witness("missing-is-error", error.cause.code == .missingMember && error.path == [.key("missing")]) }
        do { _ = try JSONInspectionBatch(document: document).values(at: paths, maximumRequests: 2); preconditionFailure() }
        catch let error as JSONInspectionBatchFailure { witness("batch-capacity", error == .requestLimitExceeded(limit: 2, actual: 3)) }
        let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
        witness("snapshot-root", try snapshot.values(for: [0,0]).result == [document.root, document.root])
        let profile = JSONStoreProfile(version: .v1, collectionsAt: [.key("collections")], collections: [
            .init(name: "u", recordsAt: [.key("u")], idKey: "id", referenceFields: [
                .init(key: "next", presence: .required, nullable: false)])], references: .strict(marker: .v1, validateTargets: true))
        let built = try JSONStoreBuilder(document: document, profile: profile).build(), store = built.result
        witness("checked-construction", store.recordCount == 2 && store.references.count == 2 && built.statistics[.nodes] > 0)
        guard let a = try store.lookup(collection: "u", id: "é").result,
              let b = try store.lookup(collection: "u", id: "e\u{301}").result else { preconditionFailure() }
        witness("scalar-identity", a != b && a.row == 0 && b.row == 1)
        witness("missing-id", try store.lookup(collection: "u", id: "absent").result == nil)
        let selected = try store.values(at: [b,a,b])
        witness("store-batch", try selected.result[0].requiredMember("id") == .string("e\u{301}") && selected.result[0] == selected.result[2])
        witness("complete-cycle", try store.follow(from: a).result == [a,b])
        let another = try JSONStoreBuilder(document: document, profile: profile).build().result
        do { _ = try another.value(at: a); preconditionFailure() }
        catch let error as JSONStoreFailure { witness("owner-refusal", error.code == .invalidPosition) }
        var bounds = JSONStoreFollowLimits(); bounds.maximumResults = 1
        do { _ = try store.follow(from: a, bounds: bounds); preconditionFailure() }
        catch let error as JSONStoreFailure { witness("complete-or-error", error.code == .capacityExceeded && error.capacity == "maximumResults") }
        let measured = try store.follow(from: a)
        var limits = JSONLimits.balanced; limits[.workUnits] = measured.statistics[.workUnits]
        let equal = try store.follow(from: a, limits: limits)
        limits[.workUnits] -= 1
        do { _ = try store.follow(from: a, limits: limits); preconditionFailure() }
        catch let error as JSONFailure {
            witness("cumulative-report", equal.result == [a,b] && equal.statistics[.workUnits] == measured.statistics[.workUnits] && error.resource?.metric == .workUnits)
        }
        print("BOUNDED_WORKFLOWS passed cases=12 work=\(measured.statistics[.workUnits]) logical_retained=\(measured.statistics[.retainedBytes])")
        try structuralAcceptance()
    }
}
