// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONSchema

@Test func rawCompilationReportIncludesDocumentAdmissionWithoutResettingWork() throws {
    let raw = try JSONParser().parse(#"{"type":"integer","minimum":9007199254740993}"#)
    let document = try JSONSchemaDocument(raw)
    let existing = try JSONSchemaCompiler().compileWithReport(document)
    let composed = try JSONSchemaCompiler().compileWithReport(raw)
    #expect(composed.statistics[.workUnits] > existing.statistics[.workUnits])
    #expect(composed.statistics.domain == .schemaCompilation && composed.statistics.accountingVersion == 1)
    #expect(try JSONSchemaValidator().validate(.number(JSONNumber(parsing: "9007199254740993")), against: composed.result).isValid)
    var limits = JSONLimits.balanced; limits[.workUnits] = composed.statistics[.workUnits] - 1
    #expect(throws: JSONFailure.self) { try JSONSchemaCompiler(options: .init(limits: limits)).compileWithReport(raw) }
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaCompiler().compileWithReport(JSON.null) }
}

private func schemaInput(_ text: String, uri: String? = nil) throws -> JSONSchemaDocument {
    try .init(JSONParser().parse(text), retrievalURI: uri.map { try JSONSchemaURI($0) })
}
@Test func indexedCompilerResolvesLocalPointersAnchorsAndExplicitResources() throws {
    let remote = try schemaInput(##"{"$id":"https://example.test/number","$anchor":"value","type":"number"}"##, uri: "https://example.test/retrieved")
    let registry = try JSONSchemaRegistry(documents: [remote])
    let input = try schemaInput(##"{"$id":"https://example.test/root","$defs":{"x":{"$anchor":"local","type":"string"}},"allOf":[{"$ref":"#/$defs/x"},{"$ref":"#local"},{"$ref":"number#value"}]}"##)
    let compiled = try JSONSchemaCompiler().compile(input, registry: registry)
    let references = compiled.plan.nodes.filter { $0.document == 0 }.flatMap(\.references)
    #expect(references.contains { compiled.plan.nodes[$0.target].raw.objectValue?["type"]?.stringValue == "number" })
    #expect(references.filter { compiled.plan.nodes[$0.target].raw.objectValue?["type"]?.stringValue == "string" }.count == 2)
    #expect(try compiled.node().raw == input.raw)
}
@Test func compilerRejectsMalformedShapesAmbiguousIdentitiesAndMissingTargets() throws {
    for text in [##"{"type":"float"}"##, ##"{"required":["a","a"]}"##, ##"{"multipleOf":0}"##, ##"{"allOf":[]}"##, ##"{"items":[]}"##, ##"{"minLength":-1}"##, ##"{"$id":"https://e.test/#notEmpty"}"##, ##"{"$ref":"https://missing.test/schema"}"##, ##"{"$anchor":"0bad"}"##, ##"{"$defs":{"a":{"$anchor":"same"},"b":{"$anchor":"same"}}}"##, ##"{"$defs":{"a":{"$id":"https://e.test/a"},"b":{"$id":"https://e.test/a"}}}"##] {
        #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaCompiler().compile(schemaInput(text)) }
    }
    let exact = try JSONSchemaCompiler().compile(schemaInput(##"{"required":["é","é"],"minimum":9007199254740993}"##))
    #expect(exact.document.raw.objectValue?["minimum"]?.numberValue == (try JSONNumber(parsing: "9007199254740993")))
}
@Test func compilerResourceAndWorkLimitsAreCumulativeAcrossRegistryAndPatterns() throws {
    var limits = JSONLimits.balanced; limits[.referenceEdges] = 1
    #expect(throws: JSONFailure.self) {
        try JSONSchemaCompiler(options: .init(limits: limits)).compile(schemaInput(##"{"allOf":[{"$ref":"#"},{"$ref":"#"}]}"##))
    }
    limits = .balanced; limits[.schemaDocuments] = 9
    #expect(throws: JSONFailure.self) { try JSONSchemaCompiler(options: .init(limits: limits)).compile(schemaInput("true")) }
    limits = .balanced; limits[.compileWorkUnits] = 100
    #expect(throws: JSONFailure.self) { try JSONSchemaCompiler(options: .init(limits: limits)).compile(schemaInput(##"{"pattern":"a+"}"##)) }
}

@Test func unsupportedDialectsAndRequiredVocabulariesFailCompilation() throws {
    #expect(throws: JSONSchemaCompilationFailure.self) {
        try JSONSchemaCompiler().compile(schemaInput(#"{"$schema":"http://json-schema.org/draft-07/schema"}"#))
    }
    let meta = try schemaInput(#"{"$id":"https://example.test/dialect","$schema":"https://json-schema.org/draft/2020-12/schema","$vocabulary":{"https://example.test/unsupported":true}}"#, uri: "https://example.test/dialect")
    let registry = try JSONSchemaRegistry(documents: [meta])
    #expect(throws: JSONSchemaCompilationFailure.self) {
        try JSONSchemaCompiler().compile(schemaInput(#"{"$schema":"https://example.test/dialect"}"#), registry: registry)
    }
}

@Test func compilerPlanCapacityAppliesBeforeRawAndRegexAllocation() throws {
    var limits = JSONLimits.balanced; limits[.compiledPlanBytes] = 1
    #expect(throws: JSONFailure.self) { try JSONSchemaCompiler(options: .init(limits: limits)).compile(schemaInput("true")) }
    let input = try schemaInput(#"{"pattern":"(a|b)+","title":"bounded"}"#)
    let baseline = try JSONSchemaCompiler().compileWithReport(input)
    let live = baseline.statistics[.compiledPlanBytes]
    #expect(live > 0)
    limits = .balanced; limits[.compiledPlanBytes] = live/2
    #expect(throws: JSONFailure.self) { try JSONSchemaCompiler(options: .init(limits: limits)).compile(input) }
}

@Test func dialectURISelectsTheExactPointerOrAnchorMetaSchema() throws {
    let meta = try schemaInput(##"{"$id":"https://e.test/metas","$defs":{"restricted":{"$anchor":"restricted","$vocabulary":{"https://json-schema.org/draft/2020-12/vocab/core":true},"type":"object","required":["permit"],"properties":{"permit":{"const":true}}}}}"##,uri: "https://e.test/metas")
    let registry = try JSONSchemaRegistry(documents: [meta])
    for fragment in ["#/$defs/restricted", "#restricted"] {
        let good = try JSONParser().parse("{\"$schema\":\"https://e.test/metas" + fragment + "\",\"permit\":true,\"minimum\":100}")
        let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(good),registry: registry)
        #expect(try JSONSchemaValidator().validate(1,against: plan).isValid)
        let bad = try JSONParser().parse("{\"$schema\":\"https://e.test/metas" + fragment + "\",\"permit\":false}")
        #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaCompiler().compile(JSONSchemaDocument(bad),registry: registry) }
    }
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaCompiler().compile(schemaInput(##"{"$schema":"https://json-schema.org/draft/2020-12/schema#missing"}"##)) }
}

@Test func lazilyReferencedSchemasReceiveTheirInheritedMetaValidation() throws {
    let meta = try schemaInput(#"{"$id":"https://e.test/restricted","type":"object","properties":{"forbidden":false}}"#,uri: "https://e.test/restricted")
    let registry = try JSONSchemaRegistry(documents: [meta])
    let raw = try schemaInput(##"{"$schema":"https://e.test/restricted","unknown":{"forbidden":true},"$ref":"#/unknown"}"##)
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaCompiler().compile(raw,registry: registry) }
}

@Test func exactPatternSharingPreservesIdentityQuotasAndExclusiveSearches() throws {
    let one = try schemaInput(#"{"pattern":"é"}"#)
    let many = try schemaInput(#"{"allOf":[{"pattern":"é"},{"pattern":"é"},{"pattern":"é"}]}"#)
    let compiler = JSONSchemaCompiler(), a = try compiler.compileWithReport(one), b = try compiler.compileWithReport(many)
    #expect(a.statistics[.regexProgramInstructions] == b.statistics[.regexProgramInstructions])
    #expect(b.statistics[.aggregateRegexPatternBytes] > a.statistics[.aggregateRegexPatternBytes])
    let distinct = try compiler.compileWithReport(schemaInput(#"{"allOf":[{"pattern":"é"},{"pattern":"e\u0301"}]}"#))
    #expect(distinct.statistics[.regexProgramInstructions] > a.statistics[.regexProgramInstructions])
    #expect(try JSONSchemaValidator().validate("é",against: distinct.result).isValid == false)
    #expect(try JSONSchemaValidator().validate("é",against: b.result).isValid)
    var limits = JSONLimits.balanced; limits[.aggregateRegexPatternBytes] = a.statistics[.aggregateRegexPatternBytes]
    #expect(throws: JSONFailure.self) { try JSONSchemaCompiler(options: .init(limits: limits)).compile(many) }
}
