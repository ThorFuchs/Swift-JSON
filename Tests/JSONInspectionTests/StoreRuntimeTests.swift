// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation
@testable import JSONInspection

private enum StoreTestError: Error { case expectedFailure }
private func storeBuild(_ id: String = "D002", caps: JSONStoreCaps = .init(),
                        limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSONConfiguredStore> {
    let fixture = try storeCase(id)
    return try JSONStoreBuilder(document: storeInput(fixture), profile: storeProfile(storeMember(fixture,"profile")),
                                limits: limits, caps: caps).build()
}
private func storeRefusal(_ body: () throws -> Void) throws -> JSONStoreFailure {
    do { try body(); Issue.record("Expected typed store refusal"); throw StoreTestError.expectedFailure }
    catch let error as JSONStoreFailure { return error }
}
private func storeCoreRefusal(_ body: () throws -> Void) throws -> JSONFailure {
    do { try body(); Issue.record("Expected original core resource refusal"); throw StoreTestError.expectedFailure }
    catch let error as JSONFailure { return error }
}
private func storeSimpleProfile(name: JSONKey = "users", id: JSONKey = "uuid",
                                path: [JSONLocationComponent] = [.key("collections")],
                                fields: [JSONStoreReferenceField] = []) -> JSONStoreProfile {
    .init(version: .v1, collectionsAt: path, collections: [
        .init(name: name, recordsAt: [.key(name)], idKey: id, referenceFields: fields)],
        references: fields.isEmpty ? .disabled : .strict(marker: .v1, validateTargets: true))
}
private func storeRows(_ count: Int, nullReference: Bool = false) throws -> JSONDocument {
    var rows: [JSON] = []
    for i in 0..<count {
        var members = [JSONMember("uuid", value: .string(String(i)))]
        if nullReference { members.append(.init("friend", value: .null)) }
        rows.append(.object(try JSONObject(members: members)))
    }
    let collections = JSON.object(try JSONObject(members: [.init("users", value: .array(rows))]))
    return .init(root: .object(try JSONObject(members: [.init("collections", value: collections)])))
}

@Test func storeR01ExactPathsSpansOwnerAndReplacement() throws {
    let report = try storeBuild(), store = report.result
    let record = try store.record(collection: 0, row: 0)
    #expect(record.path == [.key("collections"),.key("users"),.index(0)])
    #expect(record.idPath == record.path + [.key("uuid")])
    let original = try JSONPointer(tokens: storeTokens(record.path)).resolve(in: store.document.root)
    let typed = try store.document.read { cursor in
        var selected = cursor
        for component in record.path {
            switch component { case .key(let key): selected = try selected[key]; case .index(let i): selected = try selected[i] }
        }
        return try selected.requiredValue()
    }
    #expect(original == typed)
    let second = try JSONStoreBuilder(document: store.document, profile: store.profile).build().result
    #expect(try storeRefusal { _ = try second.record(at: record.position) }.code == .invalidPosition)
    #expect(try store.record(at: record.position).id == "u1")
    for id in ["D005","D006","D004"] {
        let fixture = try storeCase(id), doc = try storeInput(fixture)
        let error = try storeRefusal { _ = try JSONStoreBuilder(document: doc, profile: storeProfile(storeMember(fixture,"profile"))).build() }
        let anchor = id == "D005" ? Array(error.path.dropLast()) : error.path
        #expect(error.sourceSpan == (try doc.sourceMap?.span(at: anchor)))
    }
    let replacement = store.document.replacingRoot(store.document.root)
    #expect(replacement.sourceMap == nil && replacement.sourceBytes == nil)
    let replaced = try JSONStoreBuilder(document: replacement, profile: store.profile).build().result
    #expect(replaced.document.sourceMap == nil)
    #expect(store.document.sourceMap != nil)
    print("STORE_RUNTIME R01 passed")
}

@Test func storeR02PreparationPrecedesOneFullSourceAdmission() throws {
    var noNodes = JSONLimits.balanced; noNodes[.nodes] = 0
    let duplicate = try storeRefusal { _ = try storeBuild("D046", limits: noNodes) }
    #expect(duplicate.phase == 1 && duplicate.code == .duplicateCollectionDeclaration)
    let sourceError = try storeCoreRefusal { _ = try storeBuild(limits: noNodes) }
    #expect(sourceError.resource?.metric == .nodes)
    let fixture = try storeCase("D002"), document = try storeInput(fixture)
    let base = try JSONTraversal(document: document).visit { _,_ in .skipDescendants }
    let report = try JSONStoreBuilder(document: document, profile: storeProfile(storeMember(fixture,"profile"))).build()
    #expect(report.statistics[.nodes] == base.statistics[.nodes])
    #expect(report.statistics[.sourceMapEntries] == base.statistics[.sourceMapEntries])
    #expect(report.statistics[.workUnits] > base.statistics[.workUnits])
    var limits = JSONLimits.balanced; limits[.inputBytes] = 0
    #expect(try storeCoreRefusal { _ = try storeBuild(limits: limits) }.resource?.metric == .inputBytes)
    let outside = try JSONParser().parseDocument(Data(#"{"collections":{"users":[]},"outside":[1,2,3]}"#.utf8))
    limits = .balanced; limits[.nodes] = 4
    #expect(try storeCoreRefusal { _ = try JSONStoreBuilder(document: outside, profile: storeSimpleProfile(), limits: limits).build() }.resource?.metric == .nodes)
    print("STORE_RUNTIME R02 passed")
}

@Test func storeR03AllInclusiveCapsCheckedArithmeticAndLateRefusal() throws {
    let ordinary = try storeBuild(), strict = try storeBuild("D038")
    let rows: [(String, WritableKeyPath<JSONStoreCaps,Int>, Int, String)] = [
        ("collections",\JSONStoreCaps.collections,1,"D002"),
        ("recordsPerCollection",\JSONStoreCaps.recordsPerCollection,1,"D002"),
        ("records",\JSONStoreCaps.records,1,"D002"),
        ("referenceFieldsPerCollection",\JSONStoreCaps.referenceFieldsPerCollection,1,"D038"),
        ("referenceFields",\JSONStoreCaps.referenceFields,1,"D038"),
        ("referenceSlots",\JSONStoreCaps.referenceSlots,1,"D038"),
        ("links",\JSONStoreCaps.links,1,"D038"),
        ("identityBytes",\JSONStoreCaps.identityBytes,5,"D002"),
        ("profileTextBytes",\JSONStoreCaps.profileTextBytes,Int(ordinary.result.profileTextBytes),"D002"),
        ("aliasBytes",\JSONStoreCaps.aliasBytes,Int(ordinary.result.identityAliasBytes),"D002"),
        ("pathComponents",\JSONStoreCaps.pathComponents,4,"D002"),
        ("overlayBytes",\JSONStoreCaps.overlayBytes,Int(ordinary.result.overlayLogicalBytes),"D002")]
    for (name,key,needed,id) in rows {
        var caps = JSONStoreCaps(); caps[keyPath:key] = needed
        _ = try storeBuild(id,caps:caps)
        caps[keyPath:key] = needed - 1
        let failure = try storeRefusal { _ = try storeBuild(id,caps:caps) }
        #expect(failure.code == .capacityExceeded && failure.capacity == name)
        caps[keyPath:key] = -1
        #expect(try storeCoreRefusal { _ = try storeBuild(id,caps:caps) }.code == .invalidLimits)
        caps[keyPath:key] = Int.max
        #expect(try storeCoreRefusal { _ = try storeBuild(id,caps:caps) }.code == .invalidLimits)
        print("STORE_CAP \(name) exact=\(needed) below=\(needed-1) passed")
    }
    for metric in [JSONResourceMetric.workUnits,.retainedBytes] {
        var limits = JSONLimits.balanced
        let needed = metric == .workUnits ? ordinary.statistics[metric] : ordinary.statistics.peakLogicalRetainedBytes
        limits[metric] = needed; _ = try storeBuild(limits:limits)
        limits[metric] -= 1
        #expect(try storeCoreRefusal { _ = try storeBuild(limits:limits) }.resource?.metric == metric)
    }
    var aliasCaps = JSONStoreCaps(); aliasCaps.aliasBytes = 7
    _ = try storeBuild("D038",caps:aliasCaps)
    aliasCaps.aliasBytes = 6
    #expect(try storeRefusal { _ = try storeBuild("D038",caps:aliasCaps) }.capacity == "aliasBytes")
    #expect(strict.result.identityAliasBytes == 1) // staged marker text was released
    for operation in [0,1] {
        #expect(try storeRefusal {
            if operation == 0 { _ = try JSONStoreAccounting.sum(UInt64.max,1) }
            else { _ = try JSONStoreAccounting.product(UInt64.max,2) }
        }.code == .counterOverflow)
    }
    var capped = JSONStoreCaps(); capped.referenceSlots = 0
    #expect(try storeRefusal { _ = try storeBuild("D024",caps:capped) }.capacity == "referenceSlots")
    capped.referenceSlots = 1
    #expect(try storeRefusal { _ = try storeBuild("D024",caps:capped) }.code == .referenceDanglingID)
    let short = try JSONParser().parseDocument(Data(#"{"collections":{"x":[{"id":"éx"}]}}"#.utf8))
    capped = .init(); capped.identityBytes = 3
    _ = try JSONStoreBuilder(document: short,profile:storeSimpleProfile(name:"x",id:"id"),caps:capped).build()
    capped.identityBytes = 2
    #expect(try storeRefusal { _ = try JSONStoreBuilder(document:short,profile:storeSimpleProfile(name:"x",id:"id"),caps:capped).build() }.capacity == "identityBytes")
    print("STORE_RUNTIME R03 passed")
}

@Test func storeR04PresenceSlotsRetentionAndScaleCalibration() throws {
    let empty = try storeBuild("D001").result
    #expect(empty.recordCount == 0 && empty.references.isEmpty)
    let states = try storeBuild("D063").result
    #expect(states.references.count == 3)
    if case .absent = states.references[0].state {} else { Issue.record("Missing state lost") }
    if case .null = states.references[1].state {} else { Issue.record("Null state lost") }
    if case .link = states.references[2].state {} else { Issue.record("Link state lost") }
    var caps = JSONStoreCaps(); caps.referenceSlots = 2
    #expect(try storeRefusal { _ = try storeBuild("D063",caps:caps) }.capacity == "referenceSlots")
    caps.referenceSlots = 3; _ = try storeBuild("D063",caps:caps)
    for size in [0,1,16,1024] {
        let document = try storeRows(size)
        let report = try JSONStoreBuilder(document:document,profile:storeSimpleProfile()).build()
        #expect(report.result.recordCount == size)
        #expect(report.statistics[.retainedBytes] >= report.result.overlayLogicalBytes)
        #expect(report.statistics.peakLogicalRetainedBytes >= report.statistics[.retainedBytes])
        print("STORE_RESOURCE rows=\(size) work=\(report.statistics[.workUnits]) retained=\(report.statistics[.retainedBytes]) peak=\(report.statistics.peakLogicalRetainedBytes) overlay=\(report.result.overlayLogicalBytes)")
    }
    #expect(35_163_280 > JSONStoreCaps().overlayBytes) // declared maxima are not jointly feasible
    print("STORE_RUNTIME R04 passed")
}

@Test func storeR05InnerCancellationAcrossPhasesAndAfterTransfer() async throws {
    let long = String(repeating:"x",count:2048)+"a"
    let text = "{\"collections\":{\"users\":[{\"uuid\":\"\(long)\",\"friend\":{\"collection\":\"users\",\"id\":\"\(long)\"}}]}}"
    let document = try JSONParser().parseDocument(Data(text.utf8))
    let profile = storeSimpleProfile(fields:[.init(key:"friend",presence:.required,nullable:false)])
    for targetPhase in [1,2,4,5,6,7,8] {
        let task = Task {
            let state = Mutex<(phase:Int,work:UInt64,start:UInt64?)>((0,0,nil))
            var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
            var builder = JSONStoreBuilder(document:document,profile:profile,limits:limits)
            builder.phaseObserver = { phase in state.withLock {
                $0.phase = phase
                if phase == targetPhase && $0.start == nil { $0.start = $0.work }
            } }
            builder.checkpointObserver = { work in state.withLock {
                $0.work = work
                if $0.phase == targetPhase, let start = $0.start,
                   work >= start + (targetPhase == 8 ? 0 : targetPhase == 4 ? 4 : targetPhase == 1 ? 8 : 128) {
                    withUnsafeCurrentTask { $0?.cancel() }
                }
            } }
            return try builder.build()
        }
        do { _ = try await task.value; Issue.record("Expected phase \(targetPhase) cancellation") }
        catch is CancellationError { }
    }
    let after = Task {
        let finish = Mutex(0)
        var builder = JSONStoreBuilder(document:document,profile:profile)
        builder.phaseObserver = { phase in
            if phase == 8 { finish.withLock { $0 += 1; if $0 == 2 { withUnsafeCurrentTask { $0?.cancel() } } } }
        }
        return try builder.build()
    }
    do { _ = try await after.value; Issue.record("Transfer cannot certify completion after cancellation") }
    catch is CancellationError { }
    print("STORE_RUNTIME R05 passed")
}

@Test func storeR06TerminalQuotasNeverPublishAndImmutableConcurrentHealth() async throws {
    let fixture = try storeCase("D038"), source = try storeInput(fixture), profile = try storeProfile(storeMember(fixture,"profile"))
    let report = try JSONStoreBuilder(document:source,profile:profile).build()
    var short = JSONLimits.balanced; short[.workUnits] = report.statistics[.workUnits] - 1
    #expect(try storeCoreRefusal { _ = try JSONStoreBuilder(document:source,profile:profile,limits:short).build() }.resource?.metric == .workUnits)
    let values = try await withThrowingTaskGroup(of: UInt64.self) { group in
        for _ in 0..<16 { group.addTask { try JSONStoreBuilder(document:source,profile:profile).build().statistics[.workUnits] } }
        var results: [UInt64] = []
        for try await value in group { results.append(value) }
        return results
    }
    #expect(values.count == 16 && values.allSatisfy { $0 == report.statistics[.workUnits] })
    // D0 tests exercise caught native failures and replacement attempts inside the only capability.
    print("STORE_RUNTIME R06 passed")
}

@Test func storeR07SourceAndStateInvalidatedOnEveryFailureAndSuccess() throws {
    let facts = Mutex<[(Bool,Bool)]>([])
    for id in ["D002","D046","D004","D055","D024"] {
        let fixture = try storeCase(id)
        var builder = try JSONStoreBuilder(document:storeInput(fixture),profile:storeProfile(storeMember(fixture,"profile")))
        builder.lifetimeObserver = { root,state in facts.withLock { $0.append((root,state)) } }
        if id == "D002" { #expect(try builder.build().result.document.sourceMap != nil) }
        else { _ = try storeRefusal { _ = try builder.build() } }
    }
    let result = facts.withLock { $0 }
    #expect(result.count == 5 && result.allSatisfy { $0.0 && $0.1 })
    print("STORE_RUNTIME R07 passed")
}

@Test func storeR08DeclarationAndPhysicalPermutationMetamorphisms() throws {
    let fixture = try storeCase("D003"), document = try storeInput(fixture)
    let original = try storeProfile(storeMember(fixture,"profile"))
    let reversed = JSONStoreProfile(version:.v1,collectionsAt:original.collectionsAt,
                                    collections:Array(original.collections.reversed()),references:original.references)
    let a = try JSONStoreBuilder(document:document,profile:original).build().result
    let b = try JSONStoreBuilder(document:document,profile:reversed).build().result
    #expect(try a.record(collection:0,row:0).path == b.record(collection:0,row:0).path)
    #expect(try a.record(collection:1,row:0).path == b.record(collection:1,row:0).path)
    let rows = try storeRows(2)
    let array = try #require(rows.root.objectValue?["collections"]?.objectValue?["users"]?.arrayValue)
    let reordered = JSONDocument(root:.object(try JSONObject(members:[.init("collections",value:.object(
        try JSONObject(members:[.init("users",value:.array(Array(array.reversed())))])))])))
    let first = try JSONStoreBuilder(document:rows,profile:storeSimpleProfile()).build().result
    let second = try JSONStoreBuilder(document:reordered,profile:storeSimpleProfile()).build().result
    #expect(try first.record(collection:0,row:0).id == second.record(collection:0,row:1).id)
    #expect(try first.record(collection:0,row:0).path != second.record(collection:0,row:1).path)
    let exact = try storeBuild("D065").result
    #expect(try JSONComparison.equals(.string(exact.record(collection:0,row:0).id),.string(exact.record(collection:0,row:1).id)) == false)
    print("STORE_RUNTIME R08 passed")
}

@Test func storeR09CompleteRowsDeepSourcesAndZeroCapacity() throws {
    for depth in [16,64,256] {
        var root = try storeRows(1).root
        for _ in 0..<depth { root = .array([root]) }
        let path = Array(repeating:JSONLocationComponent.index(0),count:depth)+[.key("collections")]
        var caps = JSONStoreCaps(); caps.pathComponents = 512
        var limits = JSONLimits.offline; limits[.maxDepth] = 512; limits[.pointerTokens] = 512
        let report = try JSONStoreBuilder(document:.init(root:root),profile:storeSimpleProfile(path:path),limits:limits,caps:caps).build()
        #expect(report.result.recordCount == 1)
    }
    var zero = JSONStoreCaps(); zero.records = 0; zero.recordsPerCollection = 0
    let empty = try JSONStoreBuilder(document:storeRows(0),profile:storeSimpleProfile(),caps:zero).build()
    #expect(empty.result.recordCount == 0)
    _ = try storeRefusal { _ = try JSONStoreBuilder(document:storeRows(1),profile:storeSimpleProfile(),caps:zero).build() }
    #expect(try storeRefusal { _ = try storeBuild("D055") }.phase == 6)
    print("STORE_RUNTIME R09 passed")
}

@Test func storeR10NoInferenceOrModelMutationAndExactPayloads() throws {
    let text = #"{"collections":{"users":[{"uuid":"u","id":false,"_id":17,"$ref":"https://example.invalid/ref","n":9007199254740993,"m":1e0}]}}"#
    let document = try JSONParser().parseDocument(Data(text.utf8),source:"https://example.invalid/source")
    let result = try JSONStoreBuilder(document:document,profile:storeSimpleProfile()).build().result
    #expect(result.references.isEmpty && result.document.root == document.root)
    #expect(result.document.source == document.source && result.document.sourceBytes == document.sourceBytes)
    let raw = try JSONPointer(parsing:"/collections/users/0/m").resolve(in:result.document.root)
    #expect(raw.numberValue?.originalLexeme == "1e0")
    #expect(try JSONPointer(parsing:"/collections/users/0/n").resolve(in:result.document.root).numberValue?.integer(as:UInt64.self) == 9_007_199_254_740_993)
    print("STORE_RUNTIME R10 passed")
}
