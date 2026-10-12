// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema

@Test func qaRootedDefinitionsRemainDistinctFromMetadataOnlySchemas() throws {
    let definitions = try JSONParser().parse(##"{"$defs":{"count":{"type":"integer","minimum":9007199254740993},"key":{"const":"e\u0301"}}}"##)
    let unconstrained = try JSONSchemaCompiler().compile(JSONSchemaDocument(definitions))
    #expect(try JSONSchemaValidator().validate(.null, against: unconstrained).isValid)
    for (name, valid, invalid) in [
        ("count", "9007199254740993", "9007199254740992"),
        ("key", #""e\u0301""#, #""é""#)
    ] {
        let object = try #require(definitions.objectValue)
        let rooted = try object.setting(.string("#/$defs/\(name)"), for: "$ref")
        let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(.object(rooted)))
        #expect(try JSONSchemaValidator().validate(JSONParser().parse(valid), against: plan).isValid)
        #expect(try !JSONSchemaValidator().validate(JSONParser().parse(invalid), against: plan).isValid)
        #expect(try !JSONSchemaValidator().validate(.null, against: plan).isValid)
    }
}

@Test func qaWidePayloadInstancesPreserveEvaluatedScalarLocations() throws {
    let schema = try JSONParser().parse(#"{"type":"object","allOf":[{"patternProperties":{"^k[0-9]+$":{"type":"integer"}}},{"properties":{"é":{"const":1},"e\u0301":{"const":2}},"required":["é","e\u0301"]}],"unevaluatedProperties":false}"#)
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(schema))
    for width in [29, 30, 31, 32, 33, 62, 64, 127, 129] {
        let members = (0..<width).map { JSONMember("k\($0)", value: .number(JSONNumber(integer: $0))) } + [.init("é", value: 1), .init("e\u{301}", value: 2)]
        let object = try JSONObject(members: members)
        let value = try JSONCodablePayload(preserving: .object(object)).value()
        #expect(try JSONSchemaValidator().validate(value, against: plan).isValid)
        for invalid in [try object.setting(1, for: "e\u{301}"), try object.setting(.null, for: "unknown"), try object.removing("é")] {
            let report = try JSONSchemaValidator().validateWithReport(.object(invalid), against: plan)
            #expect(!report.result.isValid)
            #expect(report.statistics[.evaluationWorkUnits] > 0)
        }
        // Invalid evaluation must not mutate the reused immutable plan.
        #expect(try JSONSchemaValidator().validate(value, against: plan).isValid)
    }
}

@Test func qaRepeatedPatternSearchesShareAggregateQuotaAndRecoverOnNewInvocation() throws {
    let schema = try JSONParser().parse(#"{"patternProperties":{"^k[0-9]+$":true}}"#)
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(schema))
    let instance = JSON.object(try JSONObject(members: (0..<64).map { .init("k\($0)", value: .null) }))
    let report = try JSONSchemaValidator().validateWithReport(instance, against: plan)
    #expect(report.result.isValid && report.statistics[.aggregateRegexWorkUnits] > 0)
    var limits = JSONLimits.balanced
    limits[.aggregateRegexWorkUnits] = report.statistics[.aggregateRegexWorkUnits]
    #expect(try JSONSchemaValidator(options: .init(limits: limits)).validate(instance, against: plan).isValid)
    limits[.aggregateRegexWorkUnits] -= 1
    do { _ = try JSONSchemaValidator(options: .init(limits: limits)).validate(instance, against: plan); Issue.record("Exhaustion became a verdict") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .aggregateRegexWorkUnits) }
    #expect(try JSONSchemaValidator().validate(instance, against: plan).isValid)
}
