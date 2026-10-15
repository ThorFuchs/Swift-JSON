// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONSchemaExamples

private enum ConsumerFailure: Error { case mismatch(Int) }
private func schema(_ text: String, uri: String? = nil) throws -> JSONSchemaDocument {
    try JSONSchemaDocument(JSONParser().parse(text), retrievalURI: uri.map { try JSONSchemaURI($0) })
}

@main struct SchemaExamplesConsumer {
    static func main() throws {
        if CommandLine.arguments.count == 3, CommandLine.arguments[1] == "--g7-fuzz" {
            try G7Qualification.run(path: CommandLine.arguments[2]); return
        }
        if CommandLine.arguments.count == 2, CommandLine.arguments[1] == "--documentation" {
            let completed = try runSchemaExampleDocumentation()
            print("SCHEMA_EXAMPLES_DOCUMENTATION passed snippets=\(completed)")
            return
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--g4-fixtures", CommandLine.arguments[3] == "--g4-manifest" {
            try G4Acceptance.run(fixturePath: CommandLine.arguments[2], manifestPath: CommandLine.arguments[4]); return
        }
        if CommandLine.arguments.count == 5, CommandLine.arguments[1] == "--g3-fixtures", CommandLine.arguments[3] == "--g3-manifest" {
            try G3Acceptance.run(fixturePath: CommandLine.arguments[2], manifestPath: CommandLine.arguments[4]); return
        }
        let samples: [(String, String, UInt64)] = [
            ("true", "null", 1),
            ("{}", "null", 1),
            (#"{"const":null}"#, "null", 1),
            (#"{"const":9007199254740993}"#, "9007199254740993", 1),
            (#"{"const":9007199254740994.5}"#, "9007199254740994.5", 1),
            (#"{"const":{"é":1,"e\u0301":2}}"#, #"{"é":1,"e\u0301":2}"#, 1),
            (#"{"enum":[1,"ok"],"type":"string"}"#, #""ok""#, 2),
            (#"{"default":1,"examples":["ok"],"type":"string"}"#, #""ok""#, 2),
            (##"{"$defs":{"x":{"const":7}},"$ref":"#/$defs/x"}"##, "7", 1)
        ]
        var passed = 0
        for (source, expected, attempts) in samples {
            let document = try schema(source)
            let generator = try JSONSchemaExampleGenerator(document: document)
            let result = try generator.generate(seed: 42)
            let expectedValue = try JSONParser().parse(expected)
            let native = try JSONSchemaCompiler().compile(document).validate(result.value)
            let roundtrip = try JSONParser().parse(JSONWriter().write(result.value))
            let workCeiling = min(generator.options.limits[.workUnits], generator.options.validationOptions.limits[.workUnits])
            guard result.value == expectedValue, result.validation.isValid,
                  result.attempts == attempts, result.seed == 42,
                  result.statistics[.evaluationWorkUnits] > 0,
                  result.sourceSnapshotDigest == generator.sourceSnapshotDigest,
                  native.isValid, roundtrip == result.value,
                  result.statistics[.workUnits] <= workCeiling else { throw ConsumerFailure.mismatch(passed) }
            let remainingWork = workCeiling - result.statistics[.workUnits]
            guard remainingWork < workCeiling else { throw ConsumerFailure.mismatch(passed) }
            passed += 1
        }
        let registry = try JSONSchemaRegistry(documents: [schema(#"{"const":"offline"}"#, uri: "https://e.test/value")])
        let prepared = try JSONSchemaExampleGenerator(document: schema(#"{"$ref":"https://e.test/value"}"#), registry: registry)
        let offline = try prepared.generate()
        let offlinePlan = try JSONSchemaCompiler().compile(prepared.document, registry: registry)
        let offlineValid = try offlinePlan.validate(offline.value).isValid
        let offlineRoundtrip = try JSONParser().parse(JSONWriter().write(offline.value))
        guard offline.value == .string("offline"), offline.validation.isValid,
              offlineValid, offlineRoundtrip == offline.value else { throw ConsumerFailure.mismatch(passed) }
        passed += 1
        do {
            _ = try JSONSchemaExampleGenerator(document: schema("false")).generate()
            throw ConsumerFailure.mismatch(passed)
        } catch JSONSchemaExampleFailure.provenUnsatisfiable(.falseSchema) { passed += 1 }
        do {
            _ = try JSONSchemaExampleGenerator(document: schema(#"{"const":1,"type":"string"}"#)).generate()
            throw ConsumerFailure.mismatch(passed)
        } catch JSONSchemaExampleFailure.searchExhausted(attempts: 1) { passed += 1 }
        let vectorGenerator = try JSONSchemaExampleGenerator(document: schema("true"))
        var vectorRows: [String] = []
        for (name, profile) in [("minimal", JSONSchemaExampleProfile.minimal), ("demonstration", .demonstration)] {
            let result = try vectorGenerator.generate(seed: 42, profile: profile)
            let bytes = try JSONWriter().write(result.value)
            let hex = bytes.map { String($0, radix: 16).count == 1 ? "0" + String($0, radix: 16) : String($0, radix: 16) }.joined()
            guard result.validation.isValid, result.corpusDigest == vectorGenerator.corpusDigest,
                  result.policyDigest == vectorGenerator.policyDigest,
                  result.generatorVersion == "s3-candidates-v4", result.rngAlgorithm == "splitmix64-v1",
                  result.corpusDigestAlgorithm == "swift-json-example-corpus-v1",
                  result.policyDigestAlgorithm == "swift-json-example-policy-v1",
                  result.traceDigestAlgorithm == "swift-json-example-trace-v2",
                  result.schemaDigestAlgorithm == "swift-json-schema-snapshot-v1",
                  try JSONSchemaCompiler().compile(vectorGenerator.document).validate(result.value).isValid else { throw ConsumerFailure.mismatch(passed) }
            vectorRows.append("\"\(name)\":{\"trace\":\"\(result.traceDigest)\",\"events\":\(result.traceEventCount),\"draws\":\(result.randomDraws),\"value_hex\":\"\(hex)\",\"trace_bytes\":\(result.statistics[.diagnosticBytes])}")
            passed += 1
        }
        print("G2_VECTORS {\"snapshot\":\"\(vectorGenerator.sourceSnapshotDigest)\",\"corpus\":\"\(vectorGenerator.corpusDigest)\",\"policy\":\"\(vectorGenerator.policyDigest)\",\(vectorRows.joined(separator: ","))}")
        let exactCorpus = JSONSchemaExampleCorpus(values: [try JSONParser().parse(#"{"é":9007199254740993,"e\u0301":9007199254740994.5}"#)])
        let exactGenerator = try JSONSchemaExampleGenerator(document: schema("true"), options: .init(corpus: exactCorpus))
        let exact = try exactGenerator.generate(seed: 42, profile: .demonstration)
        guard exact.value == exactCorpus.values[0], exact.value.objectValue?.count == 2,
              exact.randomDraws == 1, exact.validation.isValid else { throw ConsumerFailure.mismatch(passed) }
        passed += 1
        guard passed == 15 else { throw ConsumerFailure.mismatch(passed) }
        print("SCHEMA_EXAMPLES_CONSUMER passed cases=15")
    }
}
