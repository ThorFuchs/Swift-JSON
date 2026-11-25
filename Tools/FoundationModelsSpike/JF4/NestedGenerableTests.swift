// SPDX-License-Identifier: Apache-2.0
#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels
import JSON
import JSONSchema
import JSONFoundationModels
import Testing

private func emit42<T: Encodable>(_ kind: String, _ value: T) throws {
    print("JF42_\(kind) \(try JSONWriter().writeString(JSONValueEncoder().encode(value)))")
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf42AppleNestedRoundtrip() throws {
    // Record the real macro shape even if the new bounded import rejects it.
    let raw = try JSONValueEncoder().encode(JF42Request.generationSchema)
    try emit42("RAW", JSONWriter().writeString(raw))
    let codec = try JF42Example.prepare()
    #expect(try JSONComparison.equals(raw, codec.prepared.canonical.document.raw))
    let receipts = try JF42Example.typed(codec)
    #expect(receipts.count == 2)
    try emit42("SCHEMA", JSONWriter().writeString(codec.prepared.canonical.document.raw))
    for receipt in receipts { try emit42("TYPED", receipt) }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf42AppleNestedValidation() throws {
    let codec = try JF42Example.prepare()
    let receipts = try JF42Example.invalid(codec)
    #expect(receipts.count == 24)
    for receipt in receipts { try emit42("INVALID", receipt) }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf42AppleActualReferenceImport() throws {
    // The previously qualified JF3.2 nested anchor. Import the actual
    // GenerationSchema graph, not a separately authored expanded substitute.
    let document = try JSONSchemaDocument(JSONParser().parse(#"{"type":"object","properties":{"child":{"type":"object","properties":{"name":{"type":"string"}},"required":["name"],"additionalProperties":false,"title":"Child","x-order":["name"]}},"required":["child"],"additionalProperties":false,"title":"Root","x-order":["child"]}"#))
    let bridge = JSONGenerationSchemaBridge()
    let projected = try bridge.project(document, metadata: .allowStructuralEquivalence)
    #expect(projected.rewrites.count == 1)
    #expect(projected.roundtripped.raw.objectValue?["$defs"] != nil)
    #expect(throws: JSONGenerationSchemaFailure.self) { try bridge.importSchema(projected.schema) }
    let report = try bridge.importSchemaWithReport(projected.schema, policy: .allowLocalObjectDefinitions)
    #expect(report.statistics[.workUnits] > 0)
    #expect(try JSONComparison.equals(report.result.document.raw, projected.roundtripped.raw))
    #expect(try report.result.validate(JSONParser().parse(#"{"child":{"name":"Swift"}}"#)).isValid)
    #expect(try !report.result.validate(JSONParser().parse(#"{"child":{}}"#)).isValid)
    try emit42("IMPORTED", JSONWriter().writeString(report.result.document.raw))
}
#endif
