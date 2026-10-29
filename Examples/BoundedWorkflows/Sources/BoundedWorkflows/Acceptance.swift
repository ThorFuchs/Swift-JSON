// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONPatch
import JSONInspection
import JSONTransform

// Authored application recipe. These stages are separate native operations;
// caller array assembly is not a library-wide instruction or memory quota.
func structuralAcceptance() throws {
    func witness(_ name: String, _ condition: Bool) {
        precondition(condition, name); print("ACCEPTANCE18_CASE \(name) passed")
    }
    let source = try JSONParser().parseDocument(Data(#"{"u":[{"id":"é","amount":9007199254740993,"next":{"collection":"u","id":"e\u0301"}},{"id":"e\u0301","amount":0.10000000000000001,"next":null}]}"#.utf8))
    let schema = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(
        #"{"type":"object","required":["u"],"properties":{"u":{"type":"array","items":{"type":"object","required":["id","amount","next"],"properties":{"id":{"type":"string"},"amount":{"type":"number"},"next":{"type":["object","null"]}}}}}}"#)))
    let validation = try JSONSchemaValidator().validate(source.root, against: schema)
    precondition(validation.isValid)
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [], collections: [
        .init(name: "u", recordsAt: [.key("u")], idKey: "id", referenceFields: [.init(key: "next", presence: .required, nullable: true)])
    ], references: .strict(marker: .v1, validateTargets: true))
    let store = try JSONStoreBuilder(document: source, profile: profile).build().result
    guard let first = try store.lookup(collection: "u", id: "é").result else { preconditionFailure() }
    let values = try store.values(at: store.follow(from: first).result)
    let transform = try JSONTransformProgram.compile(".[] | .amount")
    let output = try transform.withExecution(input: .array(values.result)) { execution in
        var output: [JSON] = []
        while let value = try execution.next() { output.append(value.value) }
        return JSON.array(output)
    }
    witness("schema-store-transform", try JSONWriter(options: .init(numberStyle: .preserved)).write(output.result) == Data("[9007199254740993,0.10000000000000001]".utf8))
    let patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/u/1/amount"), value: .number(JSONNumber(parsing: "1.25")))])
    guard case .document(let changed) = try patch.applying(to: source.root) else { preconditionFailure() }
    let document = source.replacingRoot(changed), rebuilt = try JSONStoreBuilder(document: document, profile: profile).build().result
    do { _ = try rebuilt.value(at: first); preconditionFailure() }
    catch let error as JSONStoreFailure { witness("patched-owner", error.code == .invalidPosition) }
    witness("source-map-reset", document.sourceMap == nil && document.sourceBytes == nil && store.document.sourceMap != nil)
    let invalid = try JSONSchemaValidator().validate(.null, against: schema)
    var native = JSONLimits.balanced; native[.evaluationWorkUnits] = 0
    do { _ = try JSONSchemaValidator(options: .init(limits: native)).validate(source.root, against: schema); preconditionFailure() }
    catch let error as JSONFailure { witness("schema-refusal", !invalid.isValid && error.resource?.metric == .evaluationWorkUnits) }
    let rootPointer = try JSONPointer(parsing: "")
    let removed = try JSONPatch(operations: [.remove(path: rootPointer)]).applying(to: source.root)
    let null = try JSONPatch(operations: [.replace(path: rootPointer, value: .null)]).applying(to: source.root)
    witness("root-removal", removed == .removed && null == .document(.null) && removed != null)
    var limits = JSONTransformLimits(); limits[.results] = 1
    do {
        _ = try transform.withExecution(input: .array(values.result), limits: limits) { execution in
            let yielded = try execution.next(); precondition(yielded != nil)
            do { _ = try execution.next(); preconditionFailure() }
            catch let error as JSONTransformFailure { precondition(error.category == .resource && error.metric == "results") }
        }
        preconditionFailure("A caught failure cannot reopen successful completion")
    } catch let error as JSONTransformFailure { witness("terminal-transform", error.category == .resource && error.metric == "results") }
    print("ACCEPTANCE18 passed cases=6")
}
