// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema
@Test func rawDeclarationInspectionNeverInfersOrNarrowsConstraints() throws {
    let raw = try JSONParser().parse(#"{"type":["string","null"],"maximum":9007199254740993,"default":null,"unknown":{"é":1,"é":2},"allOf":[{"type":"object"}]}"#)
    let view = try JSONSchemaDocument(raw).node()
    #expect(view.raw == raw && view.declaredKeywords.count == 5)
    #expect(view.declaredAnnotations.presence(of: "default") == .null)
    #expect(try view.declaration(of: "type") == .value(.array(["string","null"])))
    #expect(try view.declaredConstraints["maximum"]?.numberValue?.integer(as: Int64.self) == 9_007_199_254_740_993)
    let allOf = try JSONSchemaDocument(JSONParser().parse(#"{"allOf":[{"type":"object"}]}"#)).node()
    #expect(try allOf.declaration(of: "type") == .absent)
}
@Test func schemaInspectionNavigationPreservesBooleanAndExactNames() throws {
    let document = try JSONSchemaDocument(JSONParser().parse(#"{"$defs":{"é":true,"é":false,"0":{"title":"numeric key"}}}"#))
    #expect(try document.node(at: JSONPointer(tokens: ["$defs","é"])).raw == true)
    #expect(try document.node(at: JSONPointer(tokens: ["$defs","e\u{301}"])).raw == false)
    let numeric = try document.node(at: JSONPointer(tokens: ["$defs","0"]))
    #expect(numeric.documentPointer.tokens.last?.string == "0")
    #expect(numeric.declaredAnnotations.presence(of: "title") == .value("numeric key"))
    var limits = JSONLimits.balanced; limits[.workUnits] = 3
    #expect(throws: JSONFailure.self) { try document.node(limits: limits) }
}
