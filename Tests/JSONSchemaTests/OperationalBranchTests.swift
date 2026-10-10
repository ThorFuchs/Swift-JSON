// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test(arguments: ["anyOf", "oneOf", "allOf"])
func successfulAlternativesCannotSwallowRegexExhaustion(keyword: String) throws {
    let raw = try JSONParser().parse("{\"\(keyword)\":[true,{\"pattern\":\"^(a+)+$\"}]}")
    let plan = try JSONSchemaCompiler().compileWithReport(raw).result
    var limits = JSONLimits.balanced; limits[.regexSearchWorkUnits] = 2000
    for output in [JSONValidationOutput.flag, .basic] {
        do {
            _ = try JSONSchemaValidator(options: .init(limits: limits, output: output)).validate(.string(String(repeating: "a", count: 100)+"!"), against: plan)
            Issue.record("Regex exhaustion became a verdict")
        } catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .regexSearchWorkUnits) }
    }
}

@Test func notConditionAndAlternativesPropagateOperationalFailures() throws {
    for text in [#"{"not":{"multipleOf":3}}"#, #"{"if":{"multipleOf":3},"then":true,"else":true}"#, #"{"anyOf":[true,{"multipleOf":3}]}"#] {
        let plan = try JSONSchemaCompiler().compileWithReport(JSONParser().parse(text)).result
        var limits = JSONLimits.balanced; limits[.numericWorkUnits] = 40
        #expect(throws: JSONFailure.self) { try JSONSchemaValidator(options: .init(limits: limits)).validate(.number(JSONNumber(parsing: "1e1000")), against: plan) }
    }
    let cycle = try JSONSchemaCompiler().compileWithReport(JSONParser().parse(##"{"anyOf":[true,{"$ref":"#"}]}"##)).result
    #expect(throws: JSONSchemaEvaluationFailure.self) { try JSONSchemaValidator().validate(.null, against: cycle) }
    let ordinary = try JSONSchemaCompiler().compileWithReport(JSONParser().parse(#"{"anyOf":[true,false]}"#)).result
    #expect(try JSONSchemaValidator().validate(.null, against: ordinary).isValid)
}
