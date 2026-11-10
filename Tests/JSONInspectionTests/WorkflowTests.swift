// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
@testable import JSONInspection

private enum WorkflowTestError: Error { case expectedFailure }
private func wfCore(_ body: () throws -> Void) throws -> JSONFailure {
    do { try body(); Issue.record("Expected core failure"); throw WorkflowTestError.expectedFailure }
    catch let error as JSONFailure { return error }
}
private func wfStore(_ body: () throws -> Void) throws -> JSONStoreFailure {
    do { try body(); Issue.record("Expected store failure"); throw WorkflowTestError.expectedFailure }
    catch let error as JSONStoreFailure { return error }
}
private func wfDocument(_ text: String) throws -> JSONDocument {
    try JSONParser().parseDocument(Data(text.utf8))
}
private func wfStoreFixture() throws -> JSONConfiguredStore {
    let document = try wfDocument(#"{"collections":{"users":[{"id":"é","count":9007199254740993,"friend":{"collection":"users","id":"e\u0301"},"optional":null},{"id":"e\u0301","friend":{"collection":"users","id":"é"}}],"items":[{"id":"x","owner":{"collection":"users","id":"é"}}]}}"#)
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [.key("collections")], collections: [
        .init(name: "items", recordsAt: [.key("items")], idKey: "id", referenceFields: [.init(key: "owner", presence: .required, nullable: false)]),
        .init(name: "users", recordsAt: [.key("users")], idKey: "id", referenceFields: [
            .init(key: "friend", presence: .required, nullable: false), .init(key: "optional", presence: .optional, nullable: true)])],
        references: .strict(marker: .v1, validateTargets: true))
    return try JSONStoreBuilder(document: document, profile: profile).build().result
}
private func wfStar() throws -> JSONConfiguredStore {
    let document = try wfDocument(#"{"u":[{"id":"0","left":{"collection":"u","id":"1"},"right":{"collection":"u","id":"2"}},{"id":"1"},{"id":"2"}]}"#)
    return try JSONStoreBuilder(document: document, profile: .init(version: .v1, collectionsAt: [], collections: [
        .init(name: "u", recordsAt: [.key("u")], idKey: "id", referenceFields: [
            .init(key: "left", presence: .optional, nullable: true), .init(key: "right", presence: .optional, nullable: true)])],
        references: .strict(marker: .v1, validateTargets: true))).build().result
}

@Test func workflowB01PathsPreserveOrderRepeatsNullAndExactScalars() throws {
    let document = try wfDocument(#"{"é":9007199254740993,"e\u0301":null,"a/b~":0.1}"#)
    let report = try JSONInspectionBatch(document: document).values(at: [[.key("e\u{301}")], [.key("é")], [.key("e\u{301}")], [.key("a/b~")]])
    #expect(report.result == [.null, .number(try JSONNumber(parsing: "9007199254740993")), .null, .number(try JSONNumber(parsing: "0.1"))])
    #expect(report.statistics[.workUnits] > 0)
}
@Test func workflowB02OneCompleteAdmissionAndEmptyBatch() throws {
    let document = try wfDocument("[1,2,3]")
    let base = try JSONTraversal(document: document).visit { _,_ in .skipDescendants }
    let batch = try JSONInspectionBatch(document: document).values(at: [[.index(1)], [.index(1)]])
    #expect(batch.statistics[.nodes] == base.statistics[.nodes])
    #expect(batch.statistics[.sourceMapEntries] == base.statistics[.sourceMapEntries])
    let empty = try JSONInspectionBatch(document: document).values(at: [], maximumRequests: 0)
    #expect(empty.result.isEmpty && empty.statistics[.nodes] == base.statistics[.nodes])
    var limits = JSONLimits.balanced; limits[.nodes] = 0
    #expect(try wfCore { _ = try JSONInspectionBatch(document: document, limits: limits).values(at: []) }.resource?.metric == .nodes)
}
@Test func workflowB03RequestCapacityConfigurationAndExactBoundary() throws {
    let batch = JSONInspectionBatch(document: .init(root: .null))
    #expect(try batch.values(at: [[],[]], maximumRequests: 2).result == [.null,.null])
    do { _ = try batch.values(at: [[],[]], maximumRequests: 1); Issue.record("Expected batch refusal") }
    catch let error as JSONInspectionBatchFailure { #expect(error == .requestLimitExceeded(limit: 1, actual: 2)) }
    for invalid in [-1, Int.max] {
        #expect(try wfCore { _ = try batch.values(at: [], maximumRequests: invalid) }.code == .invalidLimits)
    }
}
@Test func workflowB04MissingAndWrongKindRetainTypedPaths() throws {
    let batch = JSONInspectionBatch(document: try wfDocument(#"{"a":null}"#))
    for (path, category, code) in [([JSONLocationComponent.key("missing")], JSONFailure.Category.missingValue, JSONFailure.Code.missingMember),
                                    ([.key("a"),.index(0)], .typeMismatch, .wrongKind)] {
        do { _ = try batch.values(at: [[],path]); Issue.record("Expected atomic access refusal") }
        catch let error as JSONAccessFailure {
            #expect(error.path == path && error.cause.category == category && error.cause.code == code)
            #expect(error.cause.location != nil)
        }
    }
}
@Test func workflowB05UnselectedSuffixAndCumulativeWorkCannotReset() throws {
    let document = try wfDocument(#"{"selected":null,"outside":[1,2,3,4]}"#)
    var limits = JSONLimits.balanced; limits[.nodes] = 2
    #expect(try wfCore { _ = try JSONInspectionBatch(document: document, limits: limits).values(at: [[.key("selected")]]) }.resource?.metric == .nodes)
    let paths = Array(repeating: [JSONLocationComponent.key("selected")], count: 8)
    let measured = try JSONInspectionBatch(document: document).values(at: paths)
    limits = .balanced; limits[.workUnits] = measured.statistics[.workUnits]
    #expect(try JSONInspectionBatch(document: document, limits: limits).values(at: paths).result.count == 8)
    limits[.workUnits] -= 1
    let failure = try wfCore { _ = try JSONInspectionBatch(document: document, limits: limits).values(at: paths) }
    #expect(failure.resource?.metric == .workUnits && failure.resource?.limit == limits[.workUnits])
}
@Test func workflowB06SnapshotBatchKeepsOneSourceAndOrdinalMeaning() throws {
    let snapshot = try JSONStructuralSnapshotBuilder(document: wfDocument("[9,8,null]")).build().result
    let batch = try snapshot.values(for: [2,1,3,2])
    #expect(batch.result == [8,9,.null,8])
    let one = try snapshot.value(for: 2)
    #expect(batch.statistics[.nodes] == one.statistics[.nodes])
    var limits = JSONLimits.balanced; limits[.nodes] = 0
    do { _ = try snapshot.values(for: [1,99], limits: limits); Issue.record("Expected bad ordinal") }
    catch let error as JSONStructuralSnapshotFailure { #expect(error == .ordinalOutOfBounds(99)) }
}
@Test func workflowB07InnerCancellationInvalidatesOriginalScope() async throws {
    let document = try wfDocument("[1,2,3]")
    let lifetime = Mutex(false), outputs = Mutex(0)
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var batch = JSONInspectionBatch(document: document, limits: limits)
        batch.lifetimeObserver = { root, state in lifetime.withLock { $0 = root && state } }
        batch.outputObserver = { count in
            outputs.withLock { $0 = count }
            if count == 2 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        return try batch.values(at: Array(repeating: [.index(0)], count: 20))
    }
    do { _ = try await task.value; Issue.record("Expected cancellation") } catch is CancellationError {}
    #expect(lifetime.withLock { $0 })
    #expect(outputs.withLock { $0 } == 2)
}
@Test func workflowB08RetentionBoundaryIsFiniteAndSourceIsUnchanged() throws {
    let document = try wfDocument("[1,2]")
    let report = try JSONInspectionBatch(document: document).values(at: [[],[.index(1)]])
    var limits = JSONLimits.balanced; limits[.retainedBytes] = report.statistics.peakLogicalRetainedBytes
    _ = try JSONInspectionBatch(document: document, limits: limits).values(at: [[],[.index(1)]])
    limits[.retainedBytes] -= 1
    #expect(try wfCore { _ = try JSONInspectionBatch(document: document, limits: limits).values(at: [[],[.index(1)]]) }.resource?.metric == .retainedBytes)
    #expect(document.root == [1,2] && document.sourceMap != nil)
}
@Test func workflowS01PublicStorePreservesPhysicalAndDeclaredOrder() throws {
    let store = try wfStoreFixture()
    #expect(store.collectionCount == 2 && store.recordCount == 3)
    #expect(try store.collectionName(at: 0) == "users")
    #expect(try store.collectionName(at: 1) == "items")
    #expect(try store.recordCount(in: 0) == 2 && store.references.count == 5)
    #expect(try store.record(collection: 0, row: 0).idPath == [.key("collections"),.key("users"),.index(0),.key("id")])
}
@Test func workflowS02LookupUsesDecodedScalarIDsAndDistinguishesMissing() throws {
    let store = try wfStoreFixture()
    let composed = try #require(store.lookup(collection: "users", id: "é").result)
    let decomposed = try #require(store.lookup(collection: "users", id: "e\u{301}").result)
    #expect(composed.row == 0 && decomposed.row == 1 && composed != decomposed)
    #expect(try store.lookup(collection: "users", id: "absent").result == nil)
    let error = try wfStore { _ = try store.lookup(collection: "unknown", id: "é") }
    #expect(error.code == .unknownCollection && error.domain == .operation && error.phase == 9)
}
@Test func workflowS03OwnerTokensCannotRebindAnotherInstance() throws {
    let store = try wfStoreFixture(), other = try JSONStoreBuilder(document: store.document, profile: store.profile).build().result
    let position = try store.record(collection: 0, row: 0).position
    #expect(position != (try other.record(collection: 0, row: 0).position))
    #expect(try wfStore { _ = try other.values(at: [position]) }.code == .invalidPosition)
    #expect(try wfStore { _ = try other.follow(from: position) }.code == .invalidPosition)
}
@Test func workflowS04StoreBatchValuesPreserveOrderExactnessAndOneAdmission() throws {
    let store = try wfStoreFixture(), a = try store.record(collection: 0, row: 0).position, b = try store.record(collection: 0, row: 1).position
    let report = try store.values(at: [b,a,b])
    #expect(try report.result[0].requiredMember("id") == .string("e\u{301}"))
    #expect(try report.result[1].requiredMember("count") == .number(JSONNumber(parsing: "9007199254740993")))
    #expect(report.result[0] == report.result[2])
    let source = try JSONTraversal(document: store.document).visit { _,_ in .skipDescendants }
    #expect(report.statistics[.nodes] == source.statistics[.nodes])
    #expect(try store.value(at: a).result == report.result[1])
    #expect(try store.values(at: [], maximumRequests: 0).statistics[.nodes] == source.statistics[.nodes])
}
@Test func workflowS05ReferenceSlotsKeepAbsentNullAndLinkDistinct() throws {
    let store = try wfStoreFixture()
    if case .link(let p) = store.references[0].state { #expect(p.row == 1) } else { Issue.record("Expected link") }
    if case .null = store.references[1].state {} else { Issue.record("Expected null") }
    if case .absent = store.references[3].state {} else { Issue.record("Expected absence") }
}
@Test func workflowS06FollowCompletesCyclesAndPreservesBFSOrder() throws {
    let store = try wfStoreFixture(), start = try store.record(collection: 1, row: 0).position
    let report = try store.follow(from: start)
    #expect(report.result.map(\.collection) == [1,0,0] && report.result.map(\.row) == [0,0,1])
    let star = try wfStar(), root = try star.record(collection: 0, row: 0).position
    #expect(try star.follow(from: root).result.map(\.row) == [0,1,2])
}
@Test func workflowS07FollowAllFourInclusiveBoundsThrowInsteadOfTruncate() throws {
    let store = try wfStar(), start = try store.record(collection: 0, row: 0).position
    let cases: [(String, WritableKeyPath<JSONStoreFollowLimits,Int>, Int)] = [
        ("maximumDepth",\JSONStoreFollowLimits.maximumDepth,1), ("maximumFrontier",\JSONStoreFollowLimits.maximumFrontier,2),
        ("maximumVisited",\JSONStoreFollowLimits.maximumVisited,3), ("maximumResults",\JSONStoreFollowLimits.maximumResults,3)]
    for (name,key,needed) in cases {
        var bounds = JSONStoreFollowLimits(); bounds[keyPath: key] = needed
        #expect(try store.follow(from: start, bounds: bounds).result.count == 3)
        bounds[keyPath: key] = needed - 1
        let failure = try wfStore { _ = try store.follow(from: start, bounds: bounds) }
        #expect(failure.code == .capacityExceeded && failure.capacity == name && failure.limit == needed - 1)
        for invalid in [-1, Int.max] {
            bounds[keyPath: key] = invalid
            #expect(try wfCore { _ = try store.follow(from: start, bounds: bounds) }.code == .invalidLimits)
        }
    }
}
@Test func workflowS08FollowAndLookupHaveCumulativeQuotaAndNoSecondAdmission() throws {
    let store = try wfStar(), start = try store.record(collection: 0, row: 0).position
    let report = try store.follow(from: start)
    let lookup = try store.lookup(collection: "u", id: "2")
    #expect(report.statistics[.nodes] == lookup.statistics[.nodes])
    for work in [report.statistics[.workUnits], lookup.statistics[.workUnits]] { #expect(work > 1) }
    var limits = JSONLimits.balanced; limits[.workUnits] = report.statistics[.workUnits]
    #expect(try store.follow(from: start, limits: limits).result.count == 3)
    limits[.workUnits] -= 1
    #expect(try wfCore { _ = try store.follow(from: start, limits: limits) }.resource?.metric == .workUnits)
}
@Test func workflowS09FollowInnerCancellationAndInvalidation() async throws {
    let store = try wfStar(), start = try store.record(collection: 0, row: 0).position
    let lifetime = Mutex(false), edges = Mutex(0)
    let task = Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        return try store.followForQualification(from: start, bounds: .init(), limits: limits,
            checkpointObserver: { _ in }, lifetimeObserver: { root, state in lifetime.withLock { $0 = root && state } },
            edgeObserver: { count in
                edges.withLock { $0 = count }
                if count == 1 { withUnsafeCurrentTask { $0?.cancel() } }
            })
    }
    do { _ = try await task.value; Issue.record("Expected inner cancellation") } catch is CancellationError {}
    #expect(edges.withLock { $0 } == 1 && lifetime.withLock { $0 })
    #expect(try store.follow(from: start).result.count == 3)
}
@Test func workflowS10SourceReplacementCannotInventSpansOrRebindPositions() throws {
    let store = try wfStoreFixture(), position = try store.record(collection: 0, row: 0).position
    let copy = try JSONStoreBuilder(document: store.document.replacingRoot(store.document.root), profile: store.profile).build().result
    #expect(store.document.sourceMap != nil && copy.document.sourceMap == nil)
    #expect(try wfStore { _ = try copy.value(at: position) }.code == .invalidPosition)
    let original = try store.record(at: position)
    #expect(try store.document.sourceMap?.span(at: original.path) != nil)
}
@Test func workflowS11DisabledReferencesRemainOrdinaryData() throws {
    let document = try wfDocument(#"{"u":[{"id":"a","arbitrary":{"collection":"missing","id":"not-a-link"}}]}"#)
    let store = try JSONStoreBuilder(document: document, profile: .init(version: .v1, collectionsAt: [], collections: [
        .init(name: "u", recordsAt: [.key("u")], idKey: "id", referenceFields: [])], references: .disabled)).build().result
    let start = try store.record(collection: 0, row: 0).position
    var bounds = JSONStoreFollowLimits(); bounds.maximumDepth = 0
    #expect(try store.follow(from: start, bounds: bounds).result == [start] && store.references.isEmpty)
}
@Test func workflowSharedImmutablePlansHaveIndependentBatchAndStoreHealth() async throws {
    let store = try wfStar(), start = try store.record(collection: 0, row: 0).position
    let batch = JSONInspectionBatch(document: store.document)
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for i in 0..<8 { group.addTask {
            if i % 2 == 0 {
                var limits = JSONLimits.balanced; limits[.workUnits] = 0
                do { _ = try store.follow(from: start, limits: limits); return false }
                catch let error as JSONFailure { return error.resource?.metric == .workUnits }
            }
            let read = try batch.values(at: [[]])
            return try store.follow(from: start).result.count == 3 && read.result == [store.document.root]
        } }
        for try await ok in group { #expect(ok) }
    }
}

@Test func workflowS12StorePathsHonorInvocationPointerAndDiagnosticLimits() throws {
    let store = try wfStar(), position = try store.record(collection: 0, row: 0).position
    for (metric, boundary) in [(JSONResourceMetric.pointerTokens, UInt64(2)), (.pointerBytes, 4), (.diagnosticBytes, 4)] {
        var limits = JSONLimits.balanced; limits[metric] = boundary
        #expect(try store.value(at: position, limits: limits).result == store.value(at: position).result)
        limits[metric] = boundary - 1
        #expect(try wfCore { _ = try store.value(at: position, limits: limits) }.resource?.metric == metric)
    }
}
@Test func workflowS13FollowSelfCycleAndLongNarrowChain() throws {
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [], collections: [
        .init(name: "u", recordsAt: [.key("u")], idKey: "id", referenceFields: [.init(key: "next", presence: .required, nullable: false)])],
        references: .strict(marker: .v1, validateTargets: true))
    func store(_ text: String) throws -> JSONConfiguredStore { try JSONStoreBuilder(document: wfDocument(text), profile: profile).build().result }
    let single = try store(#"{"u":[{"id":"0","next":{"collection":"u","id":"0"}}]}"#)
    let start = try single.record(collection: 0, row: 0).position
    var bounds = JSONStoreFollowLimits(); bounds.maximumDepth = 0; bounds.maximumFrontier = 1
    #expect(try single.follow(from: start, bounds: bounds).result == [start])
    let chain = try store(#"{"u":[{"id":"0","next":{"collection":"u","id":"1"}},{"id":"1","next":{"collection":"u","id":"2"}},{"id":"2","next":{"collection":"u","id":"3"}},{"id":"3","next":{"collection":"u","id":"3"}}]}"#)
    let first = try chain.record(collection: 0, row: 0).position
    bounds.maximumDepth = 3
    #expect(try chain.follow(from: first, bounds: bounds).result.map(\.row) == [0,1,2,3])
    bounds.maximumDepth = 2
    let failure = try wfStore { _ = try chain.follow(from: first, bounds: bounds) }
    #expect(failure.code == .capacityExceeded && failure.capacity == "maximumDepth" && failure.limit == 2)
}

@Test func workflowB09NestedSnapshotRepeatsQuotasAndLateCancellation() async throws {
    let document = try wfDocument(#"{"a/b~":{"":{"é":[1,2],"e\u0301":null}}}"#)
    let snapshot = try JSONStructuralSnapshotBuilder(document: document).build().result
    // DFS: root0, a/b~1, empty2, é3, 1 at4, 2 at5, decomposed null6.
    let ordinals = [5,4,5,6], report = try snapshot.values(for: [5,4,5,6])
    #expect(report.result == [2,1,2,.null] && report.statistics[.retainedBytes] == 160)
    var limits = JSONLimits.balanced; limits[.workUnits] = report.statistics[.workUnits]
    #expect(try snapshot.values(for: ordinals, limits: limits).result == report.result)
    limits[.workUnits] -= 1
    #expect(try wfCore { _ = try snapshot.values(for: ordinals, limits: limits) }.resource?.metric == .workUnits)
    let outputs = Mutex(0), lifetime = Mutex(false)
    let task = Task {
        var inner = JSONLimits.balanced; inner[.cancellationQuantum] = 1
        return try snapshot.valuesForQualification(for: ordinals, limits: inner, outputObserver: { count in
            outputs.withLock { $0 = count }; if count == 2 { withUnsafeCurrentTask { $0?.cancel() } }
        }, lifetimeObserver: { root, state in lifetime.withLock { $0 = root && state } })
    }
    do { _ = try await task.value; Issue.record("Expected late cancellation") } catch is CancellationError {}
    #expect(outputs.withLock { $0 } == 2 && lifetime.withLock { $0 })
    #expect(try snapshot.values(for: [5]).result == [2])
}
@Test func workflowS14MetadataAliasesAndScratchHaveExactRetentionDisposition() throws {
    let store = try wfStar(), start = try store.record(collection: 0, row: 0).position
    let lookup = try store.lookup(collection: "u", id: "0")
    #expect(lookup.statistics[.retainedBytes] == 32)
    let follow = try store.follow(from: start)
    #expect(follow.statistics[.retainedBytes] == 128)
    let values = try store.values(at: [start,start])
    #expect(values.statistics[.retainedBytes] == 96)
    #expect(follow.statistics.peakLogicalRetainedBytes >= store.overlayLogicalBytes)
    var limits = JSONLimits.balanced; limits[.retainedBytes] = follow.statistics.peakLogicalRetainedBytes
    #expect(try store.follow(from: start, limits: limits).result == follow.result)
    limits[.retainedBytes] -= 1
    #expect(try wfCore { _ = try store.follow(from: start, limits: limits) }.resource?.metric == .retainedBytes)
}
