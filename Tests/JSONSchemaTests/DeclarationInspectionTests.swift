// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func compiledInspectionExposesStaticTargetsAndDynamicAmbiguity() throws {
    let document = try JSONSchemaDocument(JSONParser().parse(##"{"$id":"https://e.test/root","$defs":{"x":{"$dynamicAnchor":"node","type":["object","null"]}},"allOf":[{"$ref":"#/$defs/x"},{"$dynamicRef":"#node"}]}"##))
    let plan = try JSONSchemaCompiler().compile(document)
    let plain = try document.node(at: JSONPointer(parsing: "/allOf/0"))
    #expect(plain.referenceTargets == nil)
    let fixed = try plan.node(at: JSONPointer(parsing: "/allOf/0"))
    #expect(fixed.resourceURI?.string == "https://e.test/root")
    #expect(fixed.referenceTargets?.count == 1)
    #expect(fixed.referenceTargets?[0].pointer.string == "/$defs/x")
    #expect(fixed.referenceTargets?[0].requiresDynamicScope == false)
    let dynamic = try plan.node(at: JSONPointer(parsing: "/allOf/1"))
    #expect(dynamic.referenceTargets?[0].requiresDynamicScope == true)
    var limits = JSONLimits.balanced; limits[.pointerTokens] = 1
    #expect(throws: JSONFailure.self) { try plan.node(at: JSONPointer(parsing: "/allOf/0"),limits: limits) }
}
