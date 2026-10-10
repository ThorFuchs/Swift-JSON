// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema

@Test func validationIssuesExposeReferencedResourceLocations() throws {
    let schema = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(##"{"$id":"https://e.test/root","$defs":{"x":{"type":"number"}},"properties":{"a":{"$ref":"#/$defs/x"}}}"##)))
    let result = try JSONSchemaValidator().validate(JSONParser().parse(#"{"a":"bad"}"#),against: schema)
    #expect(!result.isValid && result.diagnosticsComplete && result.issues.count == 1)
    #expect(result.issues[0].instanceLocation.string == "/a")
    #expect(result.issues[0].keywordLocation.string == "/properties/a/$ref/type")
    #expect(result.issues[0].absoluteKeywordLocation?.string == "https://e.test/root#/$defs/x/type")
}
@Test func outputCapacityCannotChangeVerdictsOrTruncateSilently() throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"allOf":[false,false]}"#)))
    var limits = JSONLimits.balanced; limits[.issues] = 0
    #expect(throws: JSONFailure.self) { try JSONSchemaValidator(options: .init(limits: limits)).validate(.null,against: plan) }
    let best = try JSONSchemaValidator(options: .init(limits: limits,diagnosticPolicy: .bestEffort)).validate(.null,against: plan)
    #expect(!best.isValid && best.issues.isEmpty && !best.diagnosticsComplete)
    let flag = try JSONSchemaValidator(options: .init(limits: limits,output: .flag)).validate(.null,against: plan)
    #expect(!flag.isValid && flag.issues.isEmpty && flag.diagnosticsComplete)
}
@Test func evaluationAnnotationsIncludeOnlySuccessfulBranchesAndNeverInsertDefaults() throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"anyOf":[{"type":"number","title":"number"},{"type":"string","title":"string"}],"default":7,"unknown":"metadata"}"#)))
    let result = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(.string("x"),against: plan)
    #expect(result.isValid)
    #expect(result.annotations.contains { $0.keyword == JSONKey("title") && $0.value == .string("string") })
    #expect(!result.annotations.contains { $0.value == .string("number") })
    #expect(result.annotations.contains { $0.keyword == JSONKey("unknown") })
    var limits = JSONLimits.balanced; limits[.annotationEntries] = 0
    #expect(throws: JSONFailure.self) { try JSONSchemaValidator(options: .init(limits: limits,collectAnnotations: true)).validate(.string("x"),against: plan) }
}

@Test func applicatorAnnotationsAndBasicOutputMatchOfficialMinimumSchema() throws {
    let objectPlan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"properties":{"é":true,"é":true},"patternProperties":{"^x":true},"additionalProperties":true}"#)))
    let object = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(JSONParser().parse(#"{"é":1,"é":2,"xyz":3,"z":4}"#),against: objectPlan)
    #expect(object.annotations.first { $0.keyword == JSONKey("properties") }?.value == (try JSONParser().parse(#"["é","é"]"#)))
    #expect(object.annotations.first { $0.keyword == JSONKey("patternProperties") }?.value == (try JSONParser().parse(#"["xyz"]"#)))
    #expect(object.annotations.first { $0.keyword == JSONKey("additionalProperties") }?.value == (try JSONParser().parse(#"["z"]"#)))
    let arrayPlan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"prefixItems":[true],"contains":{"type":"number"},"minContains":0,"unevaluatedItems":true}"#)))
    let array = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(JSONParser().parse(#"["x",2,"y"]"#),against: arrayPlan)
    #expect(array.annotations.first { $0.keyword == JSONKey("prefixItems") }?.value == 0)
    #expect(array.annotations.first { $0.keyword == JSONKey("contains") }?.value == .array([1]))
    #expect(array.annotations.first { $0.keyword == JSONKey("unevaluatedItems") }?.value == true)
    let invalid = try JSONSchemaValidator().validate(.boolean(false),against: JSONSchemaCompiler().compile(JSONSchemaDocument(false)))
    let outputPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/Schema/OutputSchema-2020-12.json")
    let outputDocument = try JSONParser().parse(Data(contentsOf: outputPath))
    let outputResource = try JSONSchemaDocument(outputDocument,retrievalURI: JSONSchemaURI("https://json-schema.org/draft/2020-12/output/schema"))
    let registry = try JSONSchemaRegistry(documents: [outputResource])
    for result in [object,array,invalid] {
        for style in [JSONValidationOutput.flag,.basic] {
            let entry = try JSONParser().parse(style == .flag ? ##"{"$ref":"https://json-schema.org/draft/2020-12/output/schema#/$defs/flag"}"## : ##"{"$ref":"https://json-schema.org/draft/2020-12/output/schema#/$defs/basic"}"##)
            let official = try JSONSchemaCompiler().compile(JSONSchemaDocument(entry),registry: registry)
            let output = try result.output(style)
            #expect(try JSONSchemaValidator(options: .init(formatAssertion: true)).validate(output,against: official).isValid)
        }
    }
    var limits = JSONLimits.balanced; limits[.outputBytes] = 1
    #expect(throws: JSONFailure.self) { try array.output(.basic,limits: limits) }
}

@Test func flagResultsCannotInventBasicDiagnosticsDuringOutputAdaptation() throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(false))
    let flag = try JSONSchemaValidator(options: .init(output: .flag)).validate(.null,against: plan)
    #expect(try flag.output().objectValue?["valid"]?.booleanValue == false)
    #expect(throws: JSONSchemaEvaluationFailure.self) { try flag.output(.basic) }
}
