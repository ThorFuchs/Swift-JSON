// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

@main struct ProviderConsumer {
    static func main() throws {
        let parser = JSONParser()
        let raw = try parser.parse(##"{"type":"object","properties":{"value":{"type":"number","minimum":9007199254740993,"maximum":1.2300e+20},"é":{"type":"string"},"e\u0301":{"type":"string"}},"required":["value","é","e\u0301"],"additionalProperties":false}"##)
        let schema = try JSONSchemaDocument(raw)
        let format = OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1)
        let tool = OpenAIJSONSchemaBridge(profile: .openAIResponsesFunctionV1)
        var count = 0
        func check(_ good: Bool) { precondition(good); count += 1 }
        let inspection = try format.checkWithReport(schema)
        check(inspection.result.isCompatible && inspection.statistics[.compileWorkUnits] > 0)
        let value = try format.responseFormatWithReport(schema, name: "summary", description: "Exact local fragment")
        check(value.result.objectValue?[JSONKey("schema")] == raw && value.result.objectValue?[JSONKey("strict")] == .boolean(true))
        let function = try tool.functionTool(schema, name: "summarize")
        check(function.objectValue?[JSONKey("parameters")] == raw && function.objectValue?[JSONKey("type")] == .string("function"))
        let data = try format.responseFormatDataWithReport(schema, name: "summary")
        let string = try format.responseFormatStringWithReport(schema, name: "summary")
        check(try parser.parse(data.result) == parser.parse(string.result))
        check(string.result.contains("9007199254740993") && string.result.contains("1.2300e+20"))
        let keys = try JSONPointer(parsing: "/schema/properties").resolve(in: parser.parse(data.result)).objectValue
        check(keys?.count == 3 && keys?[JSONKey("é")] != nil && keys?[JSONKey("e\u{0301}")] != nil)
        let optional = try JSONSchemaDocument(parser.parse(##"{"type":"object","properties":{"value":{"type":"string"}},"additionalProperties":false}"##))
        check(try !format.check(optional).isCompatible)
        do { _ = try format.responseFormat(optional, name: "x"); preconditionFailure("No silent optionality lowering") }
        catch JSONSchemaProviderFailure.incompatible(let report) { check(!report.isCompatible && report.issues.contains { $0.code == .allPropertiesRequired }) }
        let recursive = try JSONSchemaDocument(parser.parse(##"{"type":"object","properties":{"next":{"anyOf":[{"$ref":"#"},{"type":"null"}]}},"required":["next"],"additionalProperties":false}"##))
        check(try format.check(recursive).isCompatible)
        let compiled = try JSONSchemaCompiler().compile(schema)
        let validator = JSONSchemaValidator()
        check(try validator.validate(parser.parse(##"{"value":9007199254740993,"é":"a","e\u0301":"b"}"##), against: compiled).isValid)
        check(try !validator.validate(parser.parse(##"{"value":1,"é":"a","e\u0301":"b"}"##), against: compiled).isValid)
        var bounded = JSONSchemaProviderLimits(); bounded.json[.workUnits] = data.statistics[.workUnits] - 1
        do { _ = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: bounded).responseFormatData(schema, name: "summary"); preconditionFailure("Expected shared work failure") }
        catch let error as JSONFailure { check(error.category == .resource) }
        var issues = JSONSchemaProviderLimits(); issues.json[.issues] = 0
        let truncated = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: issues).check(optional)
        check(!truncated.isCompatible && truncated.truncated && truncated.issues.isEmpty)
        var wide = JSONSchemaProviderLimits(); wide.schemaNodes = UInt64(1) << 40; wide.referenceEdges = UInt64(1) << 40; wide.declarations = UInt64(1) << 40; wide.metadataBytes = UInt64(1) << 40
        let wideAccepted = try OpenAIJSONSchemaBridge(profile: .openAIResponsesFormatV1, limits: wide).check(schema).isCompatible
        check(wideAccepted && format.profile.revision == "2026-10-15.v1" && format.profile.capabilityCategory == "documented-base-model-subset")
        if CommandLine.arguments.dropFirst().contains("--emit") {
            print(try format.responseFormatString(schema, name: "summary", description: "Exact local fragment"))
            print(try tool.functionToolString(schema, name: "summarize"))
        }
        print("PROVIDER_CONSUMER passed cases=\(count)")
        precondition(count == 14)
    }
}
