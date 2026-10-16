// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

private func referenceVerdict(_ schema: String,_ instance: String) throws -> JSONValidationResult {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(schema)))
    return try JSONSchemaValidator().validate(JSONParser().parse(instance),against: plan)
}
@Test func productiveRecursionProgressesAndNonproductiveCyclesThrow() throws {
    let recursive = ##"{"$defs":{"node":{"anyOf":[{"type":"null"},{"type":"object","properties":{"next":{"$ref":"#/$defs/node"}},"required":["next"]}]}},"$ref":"#/$defs/node"}"##
    #expect(try referenceVerdict(recursive,#"{"next":{"next":null}}"#).isValid)
    #expect(try !referenceVerdict(recursive,#"{"next":3}"#).isValid)
    #expect(throws: JSONSchemaEvaluationFailure.self) { try referenceVerdict(##"{"$ref":"#"}"##,"null") }
    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 10
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"anyOf":[false,true]}"#)))
    #expect(throws: JSONFailure.self) { try JSONSchemaValidator(options: .init(limits: limits)).validate(.null,against: plan) }
    let opaque = try JSONSchemaDocument(JSONParser().parse(##"{"$defs":{"value":{"const":42}},"$ref":"#/$defs/value"}"##),
                                       retrievalURI: JSONSchemaURI("urn:example:root?revision=1"))
    let opaquePlan = try JSONSchemaCompiler().compile(opaque)
    #expect(try JSONSchemaValidator().validate(42, against: opaquePlan).isValid)
    #expect(try !JSONSchemaValidator().validate(43, against: opaquePlan).isValid)
}
