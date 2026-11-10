// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema
import JSONPatch
import JSONStreaming
import JSONTransform
import JSONInspection

private let acceptance18Input = #"{"u":[{"id":"é","amount":9007199254740993,"next":{"collection":"u","id":"e\u0301"}},{"id":"e\u0301","amount":0.10000000000000001,"next":null}]}"#
private func acceptance18Source() throws -> JSONDocument {
    try JSONParser().parseDocument(Data(acceptance18Input.utf8))
}
private func acceptance18Profile() -> JSONStoreProfile {
    .init(version: .v1, collectionsAt: [], collections: [
        .init(name: "u", recordsAt: [.key("u")], idKey: "id", referenceFields: [
            .init(key: "next", presence: .required, nullable: true)])
    ], references: .strict(marker: .v1, validateTargets: true))
}
private func acceptance18Plan() throws -> CompiledJSONSchema {
    try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(
        #"{"type":"object","required":["u"],"properties":{"u":{"type":"array","minItems":2,"items":{"type":"object","required":["id","amount","next"],"properties":{"id":{"type":"string"},"amount":{"type":"number"},"next":{"type":["object","null"]}}}}}}"#)))
}
private func acceptance18Store(_ source: JSONDocument) throws -> JSONConfiguredStore {
    try JSONStoreBuilder(document: source, profile: acceptance18Profile()).build().result
}
private enum Acceptance18Error: Error { case expectedFailure, removed }

@Test func acceptance18A01SchemaStoreTransformKeepsExactGoldenBytes() throws {
    let source = try acceptance18Source(), schema = try acceptance18Plan()
    let verdict = try JSONSchemaValidator().validateWithReport(source.root, against: schema)
    #expect(verdict.result.isValid && verdict.statistics[.evaluationWorkUnits] > 0)
    let store = try acceptance18Store(source)
    let start = try #require(store.lookup(collection: "u", id: "é").result)
    let closure = try store.follow(from: start), records = try store.values(at: closure.result)
    let output = try JSONTransformProgram.compile(".[] | .amount").withExecution(input: .array(records.result)) { execution in
        // This array is authored caller storage, not owned transform output accounting.
        var values: [JSON] = []
        while let item = try execution.next() { values.append(item.value) }
        return JSON.array(values)
    }
    #expect(try JSONWriter(options: .init(numberStyle: .preserved)).write(output.result) == Data("[9007199254740993,0.10000000000000001]".utf8))
    #expect(records.statistics[.nodes] == (try JSONInspectionBatch(document: source).values(at: []).statistics[.nodes]))
    #expect(closure.result.count == 2 && output.statistics[.workUnits] > 0)
}

@Test func acceptance18A02InvalidSchemaVerdictIsDistinctFromOperationalRefusal() throws {
    let plan = try acceptance18Plan()
    let invalid = try JSONSchemaValidator().validate(42, against: plan)
    #expect(!invalid.isValid && !invalid.issues.isEmpty)
    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 0
    do {
        _ = try JSONSchemaValidator(options: .init(limits: limits)).validate(acceptance18Source().root, against: plan)
        Issue.record("An exhausted evaluator returned a verdict")
    } catch let error as JSONFailure {
        #expect(error.category == .resource && error.resource?.metric == .evaluationWorkUnits)
    }
    #expect(try JSONSchemaValidator().validate(acceptance18Source().root, against: plan).isValid)
}

@Test func acceptance18A03PatchedRebuildHasNewOwnerAndNoInventedSourceMap() throws {
    let source = try acceptance18Source(), original = try acceptance18Store(source)
    let position = try #require(original.lookup(collection: "u", id: "e\u{301}").result)
    let amount = try JSONNumber(parsing: "1.25")
    let patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/u/1/amount"), value: .number(amount))])
    guard case .document(let root) = try patch.applying(to: source.root) else { throw Acceptance18Error.removed }
    let changed = source.replacingRoot(root), rebuilt = try acceptance18Store(changed)
    #expect(changed.sourceMap == nil && changed.sourceBytes == nil && original.document.sourceMap != nil)
    do { _ = try rebuilt.values(at: [position]); Issue.record("Rebound an original position") }
    catch let error as JSONStoreFailure { #expect(error.code == .invalidPosition) }
    let replacement = try #require(rebuilt.lookup(collection: "u", id: "e\u{301}").result)
    #expect(try rebuilt.value(at: replacement).result.requiredMember("amount") == .number(amount))
    #expect(try original.value(at: position).result.requiredMember("amount") == .number(JSONNumber(parsing: "0.10000000000000001")))
}

@Test func acceptance18A04DanglingPatchedReferenceCannotPublishStore() throws {
    let source = try acceptance18Source(), original = try acceptance18Store(source)
    let patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/u/1/id"), value: "renamed")])
    guard case .document(let root) = try patch.applying(to: source.root) else { throw Acceptance18Error.removed }
    do { _ = try acceptance18Store(source.replacingRoot(root)); Issue.record("Published a dangling reference") }
    catch let error as JSONStoreFailure {
        #expect(error.code == .referenceDanglingID && error.phase == 7)
        #expect(error.path == [.key("u"),.index(0),.key("next"),.key("id")])
        #expect(error.sourceSpan == nil)
    }
    let first = try #require(original.lookup(collection: "u", id: "é").result)
    #expect(try original.follow(from: first).result.count == 2 && source.root == original.document.root)
}

@Test func acceptance18A05ScalarCollectionNamesSurvivePatchAndCrossLinks() throws {
    let source = try JSONParser().parseDocument(Data(#"{"é":[{"id":"a","v":1,"go":{"collection":"e\u0301","id":"a"}}],"e\u0301":[{"id":"a","v":2,"go":{"collection":"é","id":"a"}}]}"#.utf8))
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [], collections: ["e\u{301}", "é"].map { name in
        .init(name: JSONKey(name), recordsAt: [.key(JSONKey(name))], idKey: "id", referenceFields: [.init(key: "go", presence: .required, nullable: false)])
    }, references: .strict(marker: .v1, validateTargets: true))
    let store = try JSONStoreBuilder(document: source, profile: profile).build().result
    let a = try #require(store.lookup(collection: "é", id: "a").result)
    let b = try #require(store.lookup(collection: JSONKey("e\u{301}"), id: "a").result)
    #expect(a != b && a.collection == 0 && b.collection == 1)
    #expect(try store.follow(from: a).result == [a,b])
    let patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/é/0/v"), value: 3)])
    guard case .document(let root) = try patch.applying(to: source.root) else { throw Acceptance18Error.removed }
    let selected = try JSONInspectionBatch(document: source.replacingRoot(root)).values(at: [
        [.key("é"),.index(0),.key("v")], [.key(JSONKey("e\u{301}")),.index(0),.key("v")]])
    #expect(selected.result == [3,2])
}

@Test func acceptance18A06TransformFailureStaysTerminalOverStoreInput() throws {
    let store = try acceptance18Store(acceptance18Source())
    let positions = [try store.record(collection: 0, row: 0).position, try store.record(collection: 0, row: 1).position]
    let values = try store.values(at: positions), plan = try JSONTransformProgram.compile(".[] | .amount")
    var limits = JSONTransformLimits(); limits[.results] = 1
    var reachedFailure = false
    do {
        _ = try plan.withExecution(input: .array(values.result), limits: limits) { execution in
            #expect(try execution.next()?.value == .number(JSONNumber(parsing: "9007199254740993")))
            let firstWork = execution.statistics[.workUnits], remaining = execution.remainingWorkUnits
            for _ in 0..<2 {
                do { _ = try execution.next(); Issue.record("A failed execution resumed") }
                catch let error as JSONTransformFailure {
                    #expect(error.category == .resource && error.metric == "results" && error.limit == 1)
                    reachedFailure = true
                }
            }
            #expect(execution.statistics[.workUnits] >= firstWork && execution.remainingWorkUnits <= remaining)
        }
        Issue.record("Caught failure allowed successful completion")
    } catch let error as JSONTransformFailure { #expect(error.category == .resource && error.metric == "results") }
    #expect(reachedFailure)
    #expect(try store.values(at: positions).result == values.result)
}

@Test func acceptance18A07RootRemovalIsNotNullOrAnEmptyStore() throws {
    let source = try acceptance18Source(), pointer = try JSONPointer(parsing: "")
    let removed = try JSONPatch(operations: [.remove(path: pointer)]).applying(to: source.root)
    let null = try JSONPatch(operations: [.replace(path: pointer, value: .null)]).applying(to: source.root)
    #expect(removed == .removed && null == .document(.null) && removed != null)
    guard case .document(let root) = null else { throw Acceptance18Error.removed }
    do { _ = try acceptance18Store(source.replacingRoot(root)); Issue.record("Null became an empty store") }
    catch let error as JSONStoreFailure { #expect(error.code == .collectionsNotObject) }
}

private actor Acceptance18Sink {
    var bytes: [UInt8] = [], calls = 0
    private var accepted: CheckedContinuation<Void, Never>?
    private var handoff: CheckedContinuation<Void, Never>?
    func accept(_ chunk: JSONByteChunk) async {
        calls += 1; bytes.append(contentsOf: chunk.bytes)
        await withCheckedContinuation { continuation in
            handoff = continuation
            accepted?.resume(); accepted = nil
        }
    }
    func waitForAcceptance() async {
        if handoff != nil { return }
        await withCheckedContinuation { accepted = $0 }
    }
    func completeAcceptance() {
        handoff?.resume(); handoff = nil
    }
    func snapshot() -> ([UInt8], Int) { (bytes, calls) }
}
@Test func acceptance18A08CancelledWriterKeepsOnlyItsAcceptedPrefix() async throws {
    let store = try acceptance18Store(acceptance18Source()), sink = Acceptance18Sink()
    let position = try store.record(collection: 0, row: 0).position
    let values = try store.values(at: [position]), value = JSON.array(values.result)
    let golden = try JSONWriter().write(value)
    let task = Task { try await JSONAsyncWriter(chunkSize: 4).write(value) { chunk in await sink.accept(chunk) } }
    await sink.waitForAcceptance()
    task.cancel()
    await sink.completeAcceptance()
    do { try await task.value; Issue.record("Expected deterministic cancellation") } catch is CancellationError {}
    let accepted = await sink.snapshot()
    #expect(accepted.1 == 1 && accepted.0 == Array(golden.prefix(4)))
    #expect(try store.values(at: [position]).result == values.result)
}

@Test func acceptance18SharedPlansKeepIndependentCrossProductHealth() async throws {
    let source = try acceptance18Source(), schema = try acceptance18Plan(), store = try acceptance18Store(source)
    let transform = try JSONTransformProgram.compile(".[] | .amount"), position = try store.record(collection: 0, row: 0).position
    let transformInput = JSON.array(try store.values(at: [position]).result)
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for index in 0..<12 { group.addTask {
            switch index % 4 {
            case 0:
                guard try JSONSchemaValidator().validate(source.root, against: schema).isValid else { return false }
                let values = try store.values(at: [position])
                return try transform.withExecution(input: .array(values.result)) { execution in
                    let value = try execution.next()?.value
                    return try value == .number(JSONNumber(parsing: "9007199254740993")) && execution.next() == nil
                }.result
            case 1:
                var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 0
                do { _ = try JSONSchemaValidator(options: .init(limits: limits)).validate(source.root, against: schema); return false }
                catch let error as JSONFailure { return error.resource?.metric == .evaluationWorkUnits }
            case 2:
                var limits = JSONLimits.balanced; limits[.workUnits] = 0
                do { _ = try store.values(at: [position], limits: limits); return false }
                catch let error as JSONFailure { return error.resource?.metric == .workUnits }
            default:
                var limits = JSONTransformLimits(); limits[.results] = 0
                do { _ = try transform.withExecution(input: transformInput, limits: limits) { try $0.next() }; return false }
                catch let error as JSONTransformFailure { return error.metric == "results" }
            }
        } }
        for try await success in group { #expect(success) }
    }
    #expect(try JSONSchemaValidator().validate(source.root, against: schema).isValid)
}
