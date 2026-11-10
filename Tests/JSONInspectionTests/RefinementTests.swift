// SPDX-License-Identifier: Apache-2.0
// Public-consumer tests for the 1.9 API refinements: typed store IDs (including exact
// integer IDs), typed failure phases/capacities, collectionIndex(named:) and optional
// batch reads. Only public API is used.
import Foundation
import Testing
import JSON
import JSONInspection

private enum RefinementError: Error { case expectedFailure }
private func rfDocument(_ text: String) throws -> JSONDocument { try JSONParser().parseDocument(Data(text.utf8)) }
private func rfStoreFailure(_ body: () throws -> Void) throws -> JSONStoreFailure {
    do { try body(); Issue.record("Expected a store refusal"); throw RefinementError.expectedFailure }
    catch let error as JSONStoreFailure { return error }
}
/// Navigation errors surface as JSONAccessFailure (cause plus attempted path); other
/// core errors as JSONFailure. Normalize both so batch forms can be compared exactly.
private func rfCoreFailure(_ body: () throws -> Void) throws -> (cause: JSONFailure, path: [JSONLocationComponent]?) {
    do { try body(); Issue.record("Expected a core failure"); throw RefinementError.expectedFailure }
    catch let error as JSONAccessFailure { return (error.cause, error.path) }
    catch let error as JSONFailure { return (error, nil) }
}
private func rfProfile(idKind: JSONStoreIDKind, linkTo target: JSONKey? = nil) -> JSONStoreProfile {
    var collections: [JSONStoreCollectionProfile] = [
        .init(name: "orders", recordsAt: [.key("orders")], idKey: "id", idKind: idKind,
              referenceFields: target == nil ? [] : [.init(key: "parent", presence: .optional, nullable: true)])]
    if let target, target != "orders" {
        collections.append(.init(name: target, recordsAt: [.key(target)], idKey: "id", referenceFields: []))
    }
    return JSONStoreProfile(version: .v1, collectionsAt: [], collections: collections,
                            references: target == nil ? .disabled : .strict(marker: .v1))
}
private func rfBuild(_ text: String, _ profile: JSONStoreProfile) throws -> JSONConfiguredStore {
    try JSONStoreBuilder(document: rfDocument(text), profile: profile).build().result
}

@Test func workflowR01IntegerIDsMatchByExactMathematicalValueAcrossSpellings() throws {
    // 9007199254740993 is not representable as a Double; 1e400 would expand to 401 digits.
    let store = try rfBuild(#"{"orders":[{"id":7},{"id":9007199254740993},{"id":1e400},{"id":-0}]}"#,
                            rfProfile(idKind: .integer))
    #expect(try store.record(collection: 0, row: 0).id == 7)
    #expect(try store.record(collection: 0, row: 0).id.kind == .integer)
    for (spelling, row) in [("7", 0), ("7.0", 0), ("7e0", 0), ("70e-1", 0), ("9007199254740993", 1),
                            ("1e400", 2), ("10e399", 2), ("0", 3), ("0.0", 3)] {
        let id = JSONStoreRecordID.integer(try JSONNumber(parsing: spelling))
        let found = try #require(store.lookup(collection: "orders", id: id).result, "\(spelling)")
        #expect(found == (try store.record(collection: 0, row: row)).position)
    }
    // Neighbours, other kinds and fractions never match.
    #expect(try store.lookup(collection: "orders", id: 8).result == nil)
    #expect(try store.lookup(collection: "orders", id: .integer(JSONNumber(parsing: "9007199254740992"))).result == nil)
    #expect(try store.lookup(collection: "orders", id: "7").result == nil)
    #expect(try store.lookup(collection: "orders", id: .integer(JSONNumber(parsing: "7.5"))).result == nil)
    // An unknown collection is still a typed refusal, not nil.
    let unknown = try rfStoreFailure { _ = try store.lookup(collection: "missing", id: 7) }
    #expect(unknown.code == .unknownCollection && unknown.phase == .query && unknown.domain == .operation)
}

@Test func workflowR02IntegerIDCollectionsRefuseOtherKindsFractionsAndEquivalentDuplicates() throws {
    let profile = rfProfile(idKind: .integer)
    for (text, row) in [(#"{"orders":[{"id":1},{"id":"2"}]}"#, 1), (#"{"orders":[{"id":1.5}]}"#, 0),
                        (#"{"orders":[{"id":true}]}"#, 0)] {
        let failure = try rfStoreFailure { _ = try rfBuild(text, profile) }
        #expect(failure.code == .recordIDWrongKind && failure.phase == .identifiers && failure.domain == .source)
        #expect(failure.path == [.key("orders"), .index(row), .key("id")])
    }
    // 1 and 1.0 are the same mathematical ID: the second is a duplicate of the first.
    let duplicate = try rfStoreFailure { _ = try rfBuild(#"{"orders":[{"id":1},{"id":1.0}]}"#, profile) }
    #expect(duplicate.code == .duplicateRecordID && duplicate.phase == .identifiers)
    #expect(duplicate.path == [.key("orders"), .index(1), .key("id")])
    #expect(duplicate.firstPath == [.key("orders"), .index(0), .key("id")])
    // String-ID collections (the default) still refuse numbers.
    let stringKind = try rfStoreFailure { _ = try rfBuild(#"{"orders":[{"id":1}]}"#, rfProfile(idKind: .string)) }
    #expect(stringKind.code == .recordIDWrongKind)
}

@Test func workflowR03MarkersLinkByTypedIDAndNeverConvertBetweenKinds() throws {
    let profile = rfProfile(idKind: .integer, linkTo: "orders")
    let store = try rfBuild(#"{"orders":[{"id":1},{"id":2,"parent":{"collection":"orders","id":1.0}},{"id":3,"parent":null}]}"#, profile)
    let child = try store.record(collection: 0, row: 1)
    guard case .link(let target) = store.references[child.referenceRange.lowerBound].state else {
        Issue.record("Expected a validated link"); return
    }
    #expect(target == (try store.record(collection: 0, row: 0)).position)
    let closure = try store.follow(from: child.position).result
    #expect(closure == [child.position, target])
    // A string "1" does not reach the integer ID 1.
    let dangling = try rfStoreFailure {
        _ = try rfBuild(#"{"orders":[{"id":1},{"id":2,"parent":{"collection":"orders","id":"1"}}]}"#, profile)
    }
    #expect(dangling.code == .referenceDanglingID && dangling.phase == .targets)
    #expect(dangling.path == [.key("orders"), .index(1), .key("parent"), .key("id")])
    // A fractional marker id is a marker grammar refusal.
    let fraction = try rfStoreFailure {
        _ = try rfBuild(#"{"orders":[{"id":1},{"id":2,"parent":{"collection":"orders","id":1.5}}]}"#, profile)
    }
    #expect(fraction.code == .referenceMarkerMemberWrongKind && fraction.phase == .references)
    // A numeric marker into a string-ID collection is dangling, never converted.
    let mixed = try rfStoreFailure {
        _ = try rfBuild(#"{"orders":[{"id":1,"parent":{"collection":"users","id":5}}],"users":[{"id":"5"}]}"#,
                        rfProfile(idKind: .integer, linkTo: "users"))
    }
    #expect(mixed.code == .referenceDanglingID)
}

@Test func workflowR04RecordIDsCompareScalarsExactlyAndHashConsistently() throws {
    let composed: JSONStoreRecordID = "\u{E9}", decomposed: JSONStoreRecordID = "e\u{301}"
    #expect(composed != decomposed)
    #expect(Set<JSONStoreRecordID>([composed, decomposed, "\u{E9}"]).count == 2)
    #expect(JSONStoreRecordID.integer(try JSONNumber(parsing: "2.0")) == 2)
    #expect(Set<JSONStoreRecordID>([2, .integer(try JSONNumber(parsing: "20e-1")), "2"]).count == 2)
    #expect(JSONStoreRecordID.string("2").kind == .string)
}

@Test func workflowR05StoreFailuresAreTypedAndEquatable() throws {
    let text = #"{"orders":[{"id":1},{"id":1}]}"#
    let first = try rfStoreFailure { _ = try rfBuild(text, rfProfile(idKind: .integer)) }
    let second = try rfStoreFailure { _ = try rfBuild(text, rfProfile(idKind: .integer)) }
    #expect(first == second)
    #expect(first.phase == .identifiers && first.phase.rawValue == 5 && first.capacity == nil)
    var caps = JSONStoreCaps(); caps.records = 1
    let capacity = try rfStoreFailure {
        _ = try JSONStoreBuilder(document: rfDocument(#"{"orders":[{"id":1},{"id":2}]}"#),
                                 profile: rfProfile(idKind: .integer), caps: caps).build()
    }
    #expect(capacity.code == .capacityExceeded && capacity.capacity == .records && capacity.limit == 1)
    #expect(capacity.phase == .collections && capacity != first)
    var bounds = JSONStoreFollowLimits(); bounds.maximumResults = 1
    let store = try rfBuild(#"{"orders":[{"id":1},{"id":2,"parent":{"collection":"orders","id":1}}]}"#,
                            rfProfile(idKind: .integer, linkTo: "orders"))
    let follow = try rfStoreFailure { _ = try store.follow(from: store.record(collection: 0, row: 1).position, bounds: bounds) }
    #expect(follow.capacity == .maximumResults && follow.phase == .query && follow.limit == 1)
    let metadata = try rfStoreFailure { _ = try store.record(collection: 4, row: 0) }
    #expect(metadata.code == .invalidPosition && metadata.phase == .metadata)
}

@Test func workflowR06CollectionIndexResolvesExactNamesWithoutNormalization() throws {
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [.key("data")], collections: [
        .init(name: "\u{E9}", recordsAt: [.key("\u{E9}")], idKey: "id", referenceFields: []),
        .init(name: "e\u{301}", recordsAt: [.key("e\u{301}")], idKey: "id", idKind: .integer, referenceFields: [])
    ], references: .disabled)
    let store = try rfBuild(#"{"data":{"é":[{"id":1}],"é":[{"id":"a"}]}}"#, profile)
    let decomposed = try #require(store.collectionIndex(named: "e\u{301}"))
    let composed = try #require(store.collectionIndex(named: "\u{E9}"))
    // Physical order follows the source object, not the profile.
    #expect(decomposed == 0 && composed == 1)
    #expect(try store.collectionName(at: composed) == "\u{E9}")
    #expect(try store.record(collection: decomposed, row: 0).id == 1)
    #expect(store.collectionIndex(named: "E\u{301}") == nil && store.collectionIndex(named: "") == nil)
}

@Test func workflowR07OptionalBatchReadsReturnNilOnlyForMissingPaths() throws {
    let document = try rfDocument(#"{"a":{"b":null,"c":[10,20]},"s":"text"}"#)
    let batch = JSONInspectionBatch(document: document)
    let paths: [[JSONLocationComponent]] = [
        [.key("a"), .key("c"), .index(1)], [.key("a"), .key("b")], [.key("a"), .key("missing")],
        [.key("a"), .key("c"), .index(2)], [.key("x"), .key("y"), .index(0)], [], [.key("a"), .key("c"), .index(1)]]
    let report = try batch.optionalValues(at: paths)
    #expect(report.result.count == 7)
    // JSON is ExpressibleByNilLiteral (JSON null), so compare missing results with .none.
    #expect(report.result[0] == .some(20) && report.result[1] == .some(.null))
    #expect(report.result[2] == JSON?.none && report.result[3] == JSON?.none && report.result[4] == JSON?.none)
    #expect(report.result[5] == .some(document.root) && report.result[6] == .some(20))
    // Where every path exists, the values agree with the throwing batch.
    let present = [paths[0], paths[1], paths[5], paths[6]]
    #expect(try batch.optionalValues(at: present).result.map { $0! } == batch.values(at: present).result)
    #expect(try batch.optionalValues(at: []).result.isEmpty)
    // Wrong container kinds and negative indexes still throw, exactly like values(at:).
    for bad: [JSONLocationComponent] in [[.key("s"), .key("x")], [.key("s"), .index(0)], [.key("a"), .key("c"), .index(-1)]] {
        let optional = try rfCoreFailure { _ = try batch.optionalValues(at: [[.key("a")], bad]) }
        let strict = try rfCoreFailure { _ = try batch.values(at: [[.key("a")], bad]) }
        #expect(optional.cause.category == strict.cause.category && optional.cause.code == strict.cause.code, "\(bad)")
        #expect(optional.path == strict.path, "\(bad)")
    }
    let negative = try rfCoreFailure { _ = try batch.optionalValues(at: [[.key("a"), .key("c"), .index(-1)]]) }
    #expect(negative.cause.category == .configuration && negative.cause.code == .invalidIndex)
}

@Test func workflowR08OptionalBatchReadsKeepRequestAndPointerLimits() throws {
    let batch = JSONInspectionBatch(document: try rfDocument(#"{"a":1}"#))
    #expect(throws: JSONInspectionBatchFailure.requestLimitExceeded(limit: 1, actual: 2)) {
        _ = try batch.optionalValues(at: [[.key("a")], [.key("b")]], maximumRequests: 1)
    }
    var limits = JSONLimits.balanced; limits[.pointerTokens] = 2
    let narrow = JSONInspectionBatch(document: batch.document, limits: limits)
    let wrongKindWithinLimit = try rfCoreFailure { _ = try narrow.optionalValues(at: [[.key("a"), .key("b")]]) }
    #expect(wrongKindWithinLimit.cause.code == .wrongKind)
    #expect(try narrow.optionalValues(at: [[.key("z"), .key("b")]]).result == [JSON?.none])
    let tooLong = try rfCoreFailure { _ = try narrow.optionalValues(at: [[.key("a"), .key("b"), .key("c")]]) }
    #expect(tooLong.cause.code == .limitExceeded && tooLong.cause.resource?.metric == .pointerTokens)
    // Inclusive work boundary: exactly the used work succeeds, one unit less refuses.
    let requests: [[JSONLocationComponent]] = [[.key("a")], [.key("z")], []]
    let used = try batch.optionalValues(at: requests).statistics[.workUnits]
    var exact = JSONLimits.balanced; exact[.workUnits] = used
    #expect(try JSONInspectionBatch(document: batch.document, limits: exact).optionalValues(at: requests).result.count == 3)
    var tiny = JSONLimits.balanced; tiny[.workUnits] = used - 1
    let starved = try rfCoreFailure { _ = try JSONInspectionBatch(document: batch.document, limits: tiny).optionalValues(at: requests) }
    #expect(starved.cause.category == .resource && starved.cause.resource?.metric == .workUnits)
}
