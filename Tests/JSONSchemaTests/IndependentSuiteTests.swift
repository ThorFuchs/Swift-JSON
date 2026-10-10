// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema

private let schemaSuiteRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/External/schema")
private func suiteValue(_ path: URL) throws -> JSON { try JSONParser().parse(Data(contentsOf: path)) }
@Test func pinnedDraft202012RequiredSuite() throws { try runSchemaSuite(optional: false) }
@Test func pinnedDraft202012OptionalSemanticSuite() throws { try runSchemaSuite(optional: true) }
private func runSchemaSuite(optional: Bool) throws {
    let selectionURL = schemaSuiteRoot.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Schema/ResourceSelection.json")
    let selections = try suiteValue(selectionURL).objectValue!["groups"]!.arrayValue!
    var observed = 0, failed = 0, compiled = 0
    var cachedFile = "", cachedGroups: [JSON] = []
    for selection in selections {
        let fields = selection.objectValue!, file = fields["file"]!.stringValue!
        if file.contains("/optional/") != optional { continue }
        if file.contains("/optional/format/") { continue }
        if file.hasSuffix("/dependencies-compatibility.json") || file.hasSuffix("/cross-draft.json") { continue }
        if file != cachedFile { cachedGroups = try suiteValue(schemaSuiteRoot.appendingPathComponent(file)).arrayValue!; cachedFile = file }
        let group = cachedGroups[try fields["group"]!.numberValue!.integer(as: Int.self)] .objectValue!
        let description = group["description"]!.stringValue!, cases = group["tests"]!.arrayValue!
        var documents: [JSONSchemaDocument] = []
        for resource in fields["resources"]!.arrayValue! {
            let path = resource.stringValue!
            documents.append(try JSONSchemaDocument(suiteValue(schemaSuiteRoot.appendingPathComponent(path)),retrievalURI: JSONSchemaURI("http://localhost:1234/" + path.dropFirst("remotes/".count))))
        }
        do {
            let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(group["schema"]!),registry: JSONSchemaRegistry(documents: documents))
            compiled += 1
            for item in cases {
                let test = item.objectValue!; observed += 1
                do {
                    let result = try JSONSchemaValidator(options: .init(output: .flag)).validate(test["data"]!,against: plan)
                    if result.isValid != test["valid"]!.booleanValue! {
                        failed += 1
                        Issue.record("SUITE mismatch \(file): \(description): \(test["description"]!.stringValue!)")
                    }
                } catch {
                    failed += 1
                    Issue.record("SUITE evaluation error \(file): \(description): \(test["description"]!.stringValue!): \(error)")
                }
            }
        } catch {
            observed += cases.count; failed += cases.count
            Issue.record("SUITE compilation error \(file): \(description): \(error)")
        }
    }
    print("SCHEMA_RECEIPT optional=\(optional) observed=\(observed) failures=\(failed) compiled_groups=\(compiled)")
    #expect(observed == (optional ? 125 : 1301))
    #expect(failed == 0)
}

@Test func pinnedDraft202012OptionalFormats() throws {
    let directory = schemaSuiteRoot.appendingPathComponent("tests/draft2020-12/optional/format")
    let files = try FileManager.default.contentsOfDirectory(at: directory,includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    var observed = 0, failed = 0
    for file in files {
        for groupValue in try suiteValue(file).arrayValue! {
            let group = groupValue.objectValue!
            let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(group["schema"]!))
            for testValue in group["tests"]!.arrayValue! {
                let test = testValue.objectValue!; observed += 1
                do {
                    let result = try JSONSchemaValidator(options: .init(formatAssertion: true,output: .flag)).validate(test["data"]!,against: plan)
                    if result.isValid != test["valid"]!.booleanValue! {
                        failed += 1; Issue.record("FORMAT mismatch \(file.lastPathComponent): \(test["description"]!.stringValue!)")
                    }
                } catch { failed += 1; Issue.record("FORMAT error \(file.lastPathComponent): \(test["description"]!.stringValue!): \(error)") }
            }
        }
    }
    print("FORMAT_RECEIPT observed=\(observed) failures=\(failed)")
    #expect(observed == 874)
    #expect(failed == 0)
}

@Test func schemaPolicyLedgerAccountsForEveryDiscoveredCase() throws {
    let manifest = try suiteValue(schemaSuiteRoot.appendingPathComponent("manifest.json"))
    let root = schemaSuiteRoot.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let policy = try suiteValue(root.appendingPathComponent("Documentation/Qualification/Evidence/SchemaMilestone/schema-policy-exceptions.json"))
    var discovered = 0, policyIDs: Set<String> = [], actualIDs: Set<String> = []
    for entry in policy.objectValue!["cases"]!.arrayValue! {
        let o = entry.objectValue!, id = o["file"]!.stringValue! + ":" + String(try o["group"]!.numberValue!.integer(as: Int.self)) + ":" + String(try o["test"]!.numberValue!.integer(as: Int.self))
        #expect(policyIDs.insert(id).inserted)
    }
    for entry in manifest.objectValue!["files"]!.arrayValue! {
        let path = entry.objectValue!["path"]!.stringValue!
        guard path.hasPrefix("tests/draft2020-12/"),path.hasSuffix(".json") else { continue }
        for (g,group) in try suiteValue(schemaSuiteRoot.appendingPathComponent(path)).arrayValue!.enumerated() {
            for (t,_) in group.objectValue!["tests"]!.arrayValue!.enumerated() {
                discovered += 1; let id = path + ":" + String(g) + ":" + String(t)
                if policyIDs.contains(id) { actualIDs.insert(id) }
            }
        }
    }
    #expect(discovered == 2337 && actualIDs == policyIDs && policyIDs.count == 37)
}
