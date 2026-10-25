// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONNavigation
@testable import JSONInspection

// Test-only typed fixture adapter: no production wire decoder and no store verdict logic.
func storeFixture(_ path: String) throws -> Data {
    let root = try #require(Bundle.module.resourceURL)
    let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: root.path + "/StoreFixtures/" + path))
    defer { try? handle.close() }
    return try handle.readToEnd() ?? Data()
}
func storeMember(_ value: JSON, _ key: String) throws -> JSON {
    let object = try #require(value.objectValue)
    return try #require(object[key])
}
func storeText(_ value: JSON) throws -> String { try #require(value.stringValue) }
func storeInt(_ value: JSON) throws -> Int { try #require(value.numberValue).integer(as: Int.self) }
func storeBool(_ value: JSON) throws -> Bool {
    guard case .boolean(let boolean) = value else { throw JSONFailure(.typeMismatch, code: .wrongKind) }
    return boolean
}
func storePath(_ value: JSON) throws -> [JSONLocationComponent] {
    try #require(value.arrayValue).map { part in
        let object = try #require(part.objectValue)
        if let key = object["key"] { return .key(JSONKey(try storeText(key))) }
        return .index(try storeInt(try storeMember(part,"index")))
    }
}
func storeProfile(_ value: JSON) throws -> JSONStoreProfile {
    #expect(try storeText(storeMember(value,"version")) == JSONStoreProfileVersion.v1.rawValue)
    let declarations = try #require(try storeMember(value,"collections").arrayValue)
    let collections = try declarations.map { declaration in
        let fields = try #require(try storeMember(declaration,"referenceFields").arrayValue).map { field in
            JSONStoreReferenceField(key: JSONKey(try storeText(storeMember(field,"key"))),
                presence: try #require(JSONStoreFieldPresence(rawValue: storeText(storeMember(field,"presence")))),
                nullable: try storeBool(storeMember(field,"nullable")))
        }
        return JSONStoreCollectionProfile(name: JSONKey(try storeText(storeMember(declaration,"name"))),
            recordsAt: try storePath(storeMember(declaration,"recordsAt")),
            idKey: JSONKey(try storeText(storeMember(declaration,"idKey"))), referenceFields: fields)
    }
    let refs = try storeMember(value,"references")
    let mode = try storeText(storeMember(refs,"mode"))
    #expect(mode == "disabled" || mode == "strict")
    if mode == "strict" { #expect(try storeText(storeMember(refs,"marker")) == JSONStoreMarkerVersion.v1.rawValue) }
    let references: JSONStoreReferences = mode == "disabled" ? .disabled
        : .strict(marker: .v1, validateTargets: try storeBool(storeMember(refs,"validateTargets")))
    return JSONStoreProfile(version: .v1, collectionsAt: try storePath(storeMember(value,"collectionsAt")),
                            collections: collections, references: references)
}
// Immutable independent input oracle, scoped to each caller. Do not retain the
// parsed JSON in a process-global cache: Linux LSan must observe its teardown.
func storeManifestCases() throws -> [JSON] {
    let manifest = try JSONParser(options: .init(limits: .offline)).parse(storeFixture("VECTORS.json"))
    return try #require(try storeMember(manifest,"cases").arrayValue)
}
func storeCase(_ id: String) throws -> JSON {
    let cases = try storeManifestCases()
    return try #require(cases.first { try storeText(storeMember($0,"id")) == id })
}
func storeInput(_ fixture: JSON) throws -> JSONDocument {
    let bytes = try storeFixture(storeText(storeMember(fixture,"file")))
    // This separate fixture-integrity operation is caller work, not the build ledger.
    var hashMeter = try JSONWorkMeter(limits: .offline, domain: .core)
    let hash = try JSONSHA256Core.hexadecimal(bytes, accounting: &hashMeter)
    #expect(hash == (try storeText(storeMember(fixture,"sha256"))))
    return try JSONParser().parseDocument(bytes)
}
func storeTokens(_ path: [JSONLocationComponent]) -> [String] {
    path.map { switch $0 { case .key(let key): key.string; case .index(let index): String(index) } }
}

// Independent public typed-read delegate; never used inside the engine operation.
func storeTypedValue(_ path: [JSONLocationComponent], in document: JSONDocument) throws -> JSON {
    try document.read { cursor in
        var selected = cursor
        for component in path {
            switch component { case .key(let key): selected = try selected[key]; case .index(let i): selected = try selected[i] }
        }
        return try selected.requiredValue()
    }
}

private let storeBuildVectorIDs = ["D001", "D002", "D003", "D004", "D005", "D006", "D007", "D008", "D009", "D010", "D011", "D012", "D013", "D014", "D015", "D016", "D017", "D018", "D019", "D020", "D021", "D022", "D023", "D024", "D025", "D026", "D027", "D028", "D029", "D030", "D031", "D032", "D033", "D034", "D035", "D036", "D038", "D039", "D040", "D041", "D042", "D043", "D044", "D045", "D046", "D047", "D048", "D049", "D050", "D052", "D054", "D055", "D056", "D057", "D058", "D059", "D060", "D061", "D062", "D063", "D064", "D065", "D066", "D067", "D068"]

@Test(arguments: storeBuildVectorIDs)
func storeD1NativeVector(id: String) throws {
    let fixture = try storeCase(id), expected = try storeMember(fixture,"expected")
    let document = try storeInput(fixture), profile = try storeProfile(storeMember(fixture,"profile"))
    let kind = try storeText(storeMember(expected,"kind"))
    do {
        let report = try JSONStoreBuilder(document: document, profile: profile).build()
        #expect(kind == "success")
        let store = report.result
        if let count = expected.objectValue?["collectionCount"] { #expect(store.collectionCount == (try storeInt(count))) }
        if let count = expected.objectValue?["recordCount"] { #expect(store.recordCount == (try storeInt(count))) }
        if let count = expected.objectValue?["referenceSlots"] { #expect(store.references.count == (try storeInt(count))) }
        var states: [String] = [], links = 0
        for reference in store.references {
            switch reference.state {
            case .absent: states.append("absent")
            case .null: states.append("null")
            case .link(let target):
                states.append("link"); links += 1
                _ = try store.record(at: target)
                if let row = expected.objectValue?["targetRow"] { #expect(target.row == (try storeInt(row))) }
            }
        }
        if let count = expected.objectValue?["links"] { #expect(links == (try storeInt(count))) }
        if let expectedStates = expected.objectValue?["states"] {
            #expect(states == (try #require(expectedStates.arrayValue).map(storeText)))
        }
        // Every positive record's exact original ID path resolves through core authority.
        for ci in 0..<store.collectionCount {
            for row in 0..<(try store.recordCount(in: ci)) {
                let record = try store.record(collection: ci, row: row)
                let pointer = try JSONPointer(tokens: storeTokens(record.idPath))
                #expect(try pointer.resolve(in: document.root) == .string(record.id))
                #expect(try storeTypedValue(record.idPath,in:document) == .string(record.id))
                #expect(try JSONPointer(tokens:storeTokens(record.path)).resolve(in:document.root) == storeTypedValue(record.path,in:document))
                for reference in store.references[record.referenceRange] {
                    let key = try #require(reference.path.last)
                    guard case .key(let field) = key else { Issue.record("Reference path must end in an exact key"); continue }
                    let parent = try storeTypedValue(record.path,in:document)
                    let presence = try parent.presence(of:field.string)
                    switch reference.state {
                    case .absent:
                        #expect(presence == .absent)
                        do { _ = try JSONPointer(tokens:storeTokens(reference.path)).resolve(in:document.root); Issue.record("Absent reference resolved") }
                        catch let error as JSONFailure { #expect(error.category == .pointer && error.code == .missingTarget) }
                        do { _ = try storeTypedValue(reference.path,in:document); Issue.record("Absent reference read as a value") }
                        catch let error as JSONAccessFailure { #expect(error.cause.category == .missingValue) }
                    case .null:
                        #expect(presence == .null)
                        #expect(try storeTypedValue(reference.path,in:document) == .null)
                        #expect(try JSONPointer(tokens:storeTokens(reference.path)).resolve(in:document.root) == .null)
                    case .link:
                        let original = try JSONPointer(tokens:storeTokens(reference.path)).resolve(in:document.root)
                        #expect(presence == .value(original))
                        #expect(try storeTypedValue(reference.path,in:document) == original)
                    }
                }
            }
        }
        let admission = try JSONTraversal(document: document).visit { _,_ in .skipDescendants }
        #expect(report.statistics[.nodes] == admission.statistics[.nodes])
        #expect(report.statistics[.sourceMapEntries] == admission.statistics[.sourceMapEntries])
        #expect(report.statistics[.workUnits] > 0 && report.statistics[.retainedBytes] > 0)
        #expect(store.document.sourceBytes == document.sourceBytes)
        print("STORE_VECTOR \(id) passed driver=native-build phase=8 kind=success work=\(report.statistics[.workUnits]) nodes=\(report.statistics[.nodes]) retained=\(report.statistics[.retainedBytes])")
    } catch let error as JSONStoreFailure {
        #expect(error.code.rawValue == kind)
        #expect(error.phase == (try storeInt(storeMember(expected,"phase"))))
        #expect(error.domain.rawValue == (try storeText(storeMember(expected,"domain"))))
        #expect(error.path == (try storePath(storeMember(expected,"at"))))
        if let first = expected.objectValue?["firstAt"] { #expect(error.firstPath == (try storePath(first))) }
        if let cause = expected.objectValue?["coreCause"] {
            #expect(error.coreCause?.code.rawValue == (try storeText(cause)))
        }
        print("STORE_VECTOR \(id) passed driver=native-build phase=\(error.phase) kind=\(error.code.rawValue)")
    }
}

@Test func storeD1StrictParserD037RejectsDecodedDuplicateMarker() throws {
    let fixture = try storeCase("D037")
    let data = try storeFixture(storeText(storeMember(fixture,"file")))
    do { _ = try JSONParser().parseDocument(data); Issue.record("Duplicate decoded marker keys must fail native parsing") }
    catch let failure as JSONFailure {
        #expect(failure.category == .syntax)
        #expect(failure.code == .duplicateKey)
    }
    print("STORE_VECTOR D037 passed driver=strict-parser phase=parse kind=duplicateDecodedKey")
}
