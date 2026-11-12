// SPDX-License-Identifier: Apache-2.0
// Public-API probe compiled at the macOS 15 / iOS 18 floor and run on the host.
import Foundation
import JSON
import JSONSchema
import JSONSchemaExamples
import JSONStreaming
import JSONPatch
import JSONHTML
import JSONBridges
import JSONNavigation
import JSONInspection
import JSONTransform
import JSONValueDSL
import JSONSchemaDSL

private struct OneChunk: AsyncSequence, Sendable {
    let bytes: [UInt8]
    func makeAsyncIterator() -> Iterator { Iterator(bytes: bytes) }
    struct Iterator: AsyncIteratorProtocol {
        var bytes: [UInt8]?
        mutating func next() async -> JSONByteChunk? {
            guard let chunk = bytes else { return nil }
            bytes = nil
            return JSONByteChunk(chunk)
        }
    }
}

/// Runs one witness per product and returns the number of passed witnesses.
public func runFloorProbe() async throws -> Int {
    var passed = 0
    let value = try JSON.parse(#"{"orders":[{"id":7,"next":null}],"present":1,"list":[1,2]}"#)

    // JSONSchema
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSON.parse(#"{"type":"integer","minimum":0}"#)))
    let validation = try plan.validate(42)
    precondition(validation.isValid)
    passed += 1

    // JSONPatch
    let patch = try JSONPatch(operations: [.remove(path: JSONPointer(parsing: "/present")),
                                           .add(path: JSONPointer(parsing: "/list/-"), value: 3)])
    let patched = try patch.applying(to: value)
    let expectedPatch = try JSON.parse(#"{"orders":[{"id":7,"next":null}],"list":[1,2,3]}"#)
    precondition(patched == .document(expectedPatch))
    passed += 1

    // JSONStreaming
    var located = 0
    for try await event in JSONLocatedTopLevelArraySequence(OneChunk(bytes: Array("[1,{\"a\":2},[]]".utf8))) {
        if case .element = event { located += 1 }
    }
    precondition(located == 3)
    passed += 1

    // JSONNavigation
    let nodes = try JSONTraversal(document: .init(root: value)).collect(scope: .subtree(at: [.key("orders")])).result.nodes
    precondition(!nodes.isEmpty)
    passed += 1

    // JSONInspection
    let document = try JSONParser().parseDocument(Data(#"{"orders":[{"id":7,"next":null}]}"#.utf8))
    let profile = JSONStoreProfile(version: .v1, collectionsAt: [], collections: [
        .init(name: "orders", recordsAt: [.key("orders")], idKey: "id", idKind: .integer,
              referenceFields: [.init(key: "next", presence: .required, nullable: true)])
    ], references: .strict(marker: .v1))
    let store = try JSONStoreBuilder(document: document, profile: profile).build().result
    let found = try store.lookup(collection: "orders", id: 7).result
    precondition(found != nil)
    passed += 1

    // JSONTransform
    let selection = try JSONTransformProgramDefinition.prepare(source: ".[] | select($values[.] > 1)", variables: ["values"])
        .result.compile().result
    let indices = try selection.selectIndices(in: [1, 2, 3]).result
    precondition(indices == [1, 2])
    passed += 1

    // JSONHTML
    let html = try JSONHTMLRenderer().renderWithReport(value)
    precondition(html.statistics.documentBytes > 0 && !html.result.isEmpty)
    passed += 1

    // JSONBridges
    let decimal = try Decimal(jsonNumber: JSONNumber(parsing: "0.1"))
    precondition(decimal == Decimal(string: "0.1"))
    passed += 1

    return passed
}
