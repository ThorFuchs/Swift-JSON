// SPDX-License-Identifier: Apache-2.0
// Generated from every JSONSchemaExamples DocC Swift block; do not edit by hand.
import JSON
import JSONSchema
import JSONSchemaExamples

func runSchemaExampleDocumentation() throws -> Int {
    var completed = 0
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/AdvancedConstruction.md", line: 6)
        let document = try JSONSchemaDocument(JSONParser().parse(
            #"{"type":"array","minItems":2,"uniqueItems":true,"items":{"type":"string"},"contains":{"pattern":"^SKU-[0-9]{4}$"},"minContains":2,"maxContains":2}"#
        ))
        let result = try JSONSchemaExampleGenerator(document: document).generate(seed: 42)
        precondition(result.validation.isValid)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/DeterministicConstruction.md", line: 8)
        let corpus = JSONSchemaExampleCorpus(values: [.string("example"), .null])
        let prepared = try JSONSchemaExampleGenerator(
            document: JSONSchemaDocument(JSONParser().parse("true")),
            options: .init(corpus: corpus)
        )
        let result = try prepared.generate(seed: 42, profile: .demonstration)
        precondition(result.validation.isValid)
        precondition(result.corpusDigest == prepared.corpusDigest)
        precondition(result.randomDraws > 0)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/DeterministicConstruction.md", line: 73)
        let prepared = try JSONSchemaExampleGenerator(
            document: JSONSchemaDocument(JSONParser().parse(#"{"type":"string","minLength":3}"#))
        )
        let first = try prepared.generate(seed: 42, profile: .demonstration)
        let second = try prepared.generate(seed: 42, profile: .demonstration)
        precondition(first.value == second.value && first.traceDigest == second.traceDigest)
        precondition(first.statistics == second.statistics)
        precondition(first.sourceSnapshotDigest == prepared.sourceSnapshotDigest)
        precondition(first.policyDigest == prepared.policyDigest && first.corpusDigest == prepared.corpusDigest)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/PoliciesAndLimits.md", line: 14)
        var limits = JSONLimits.conservative
        limits[.workUnits] = 2_000_000
        var evaluation = JSONSchemaOptions(limits: limits)
        evaluation.collectAnnotations = true
        let options = JSONSchemaExampleOptions(
            limits: limits, maximumAttempts: 4, validationOptions: evaluation
        )
        let prepared = try JSONSchemaExampleGenerator(
            document: JSONSchemaDocument(JSONParser().parse(#"{"enum":[0,"ok"],"type":"string"}"#)),
            options: options
        )
        let result = try prepared.generate()
        let ceiling = min(prepared.options.limits[.workUnits],
                          prepared.options.validationOptions.limits[.workUnits])
        let used = result.statistics[.workUnits]
        precondition(used <= ceiling)
        let remainingWork = ceiling - used
        precondition(remainingWork < ceiling && result.attempts == 2)
        precondition(result.statistics[.evaluationWorkUnits] > 0)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/PoliciesAndLimits.md", line: 57)
        let document = try JSONSchemaDocument(JSONParser().parse(
            #"{"const":"not-an-email","format":"email","default":"example@example.com"}"#
        ))
        let annotated = try JSONSchemaExampleGenerator(document: document).generate()
        precondition(annotated.value == .string("not-an-email"))
        precondition(!annotated.validationOptions.formatAssertion)
        let plan = try JSONSchemaCompiler().compile(document)
        let asserted = try plan.validate(annotated.value, options: .init(formatAssertion: true))
        precondition(!asserted.isValid)
        precondition(document.raw.objectValue?["default"] == .string("example@example.com"))
        precondition(!annotated.compilationOptions.formatAssertion)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/TypedConstruction.md", line: 6)
        let document = try JSONSchemaDocument(JSONParser().parse(
            #"{"type":"integer","minimum":9007199254740993}"#
        ))
        let generator = try JSONSchemaExampleGenerator(document: document)
        let result = try generator.generate(seed: 42)
        precondition(result.validation.isValid)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/TypedConstruction.md", line: 80)
        let document = try JSONSchemaDocument(JSONParser().parse(
            #"{"type":"object","required":["é","e\u0301"],"properties":{"é":{"const":9007199254740993},"e\u0301":{"const":null},"optional":{"default":42}}}"#
        ))
        let result = try JSONSchemaExampleGenerator(document: document).generate()
        let object = result.value.objectValue
        let exact = try JSONNumber(parsing: "9007199254740993")
        precondition(object?.count == 2 && object?["é"]?.numberValue == exact)
        precondition(object?["e\u{301}"] == .null && object?["optional"] == nil)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/VerifiedCandidates.md", line: 12)
        let document = try JSONSchemaDocument(JSONParser().parse(
            #"{"const":9007199254740993}"#
        ))
        let prepared = try JSONSchemaExampleGenerator(document: document)
        let result = try prepared.generate(seed: 42, profile: .minimal)
        let text = try JSONWriter().writeString(result.value)
        precondition(result.validation.isValid && text == "9007199254740993")
        precondition(result.attempts == 1 && result.statistics[.evaluationWorkUnits] > 0)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/VerifiedCandidates.md", line: 40)
        let parser = JSONParser()
        let resource = try JSONSchemaDocument(parser.parse(
            #"{"$defs":{"count":{"type":"integer","minimum":9007199254740993}}}"#
        ), retrievalURI: JSONSchemaURI("https://example.com/schemas/counts"))
        let registry = try JSONSchemaRegistry(documents: [resource])
        let root = try JSONSchemaDocument(parser.parse(
            ##"{"$ref":"https://example.com/schemas/counts#/$defs/count"}"##
        ))
        let prepared = try JSONSchemaExampleGenerator(document: root, registry: registry)
        let result = try prepared.generate()
        let plan = try JSONSchemaCompiler().compile(root, registry: registry)
        let independentlyValid = try plan.validate(result.value).isValid
        let exact = try JSONNumber(parsing: "9007199254740993")
        let roundtrip = try JSONParser().parse(JSONWriter().write(result.value))
        precondition(independentlyValid && result.value.numberValue == exact)
        precondition(roundtrip == result.value)
        #sourceLocation()
        completed += 1
    }
    do {
        #sourceLocation(file: "Sources/JSONSchemaExamples/Documentation.docc/VerifiedCandidates.md", line: 72)
        let document = try JSONSchemaDocument(JSONParser().parse(
            #"{"const":1,"type":"string"}"#
        ))
        let prepared = try JSONSchemaExampleGenerator(document: document)
        var exhausted = false
        do {
            _ = try prepared.generate()
        } catch JSONSchemaExampleFailure.searchExhausted(let attempts) {
            precondition(attempts == 1)
            exhausted = true
        }
        precondition(exhausted)
        #sourceLocation()
        completed += 1
    }
    precondition(completed == 10)
    return completed
}
