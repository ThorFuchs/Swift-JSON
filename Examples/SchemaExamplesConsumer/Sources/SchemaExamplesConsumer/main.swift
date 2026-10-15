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
            guard result.value == expectedValue, result.validation.isValid,
                  result.attempts == attempts, result.seed == 42,
                  result.statistics[.evaluationWorkUnits] > 0,
                  result.sourceSnapshotDigest == generator.sourceSnapshotDigest,
                  native.isValid, roundtrip == result.value else { throw ConsumerFailure.mismatch(passed) }
            passed += 1
        }
        let registry = try JSONSchemaRegistry(documents: [schema(#"{"const":"offline"}"#, uri: "https://e.test/value")])
        let prepared = try JSONSchemaExampleGenerator(document: schema(#"{"$ref":"https://e.test/value"}"#), registry: registry)
        guard try prepared.generate().value == .string("offline") else { throw ConsumerFailure.mismatch(passed) }
        passed += 1
        do {
            _ = try JSONSchemaExampleGenerator(document: schema("false")).generate()
            throw ConsumerFailure.mismatch(passed)
        } catch JSONSchemaExampleFailure.provenUnsatisfiable(.falseSchema) { passed += 1 }
        do {
            _ = try JSONSchemaExampleGenerator(document: schema(#"{"const":1,"type":"string"}"#)).generate()
            throw ConsumerFailure.mismatch(passed)
        } catch JSONSchemaExampleFailure.searchExhausted(attempts: 1) { passed += 1 }
        guard passed == 12 else { throw ConsumerFailure.mismatch(passed) }
        print("SCHEMA_EXAMPLES_CONSUMER passed cases=12")
    }
}
