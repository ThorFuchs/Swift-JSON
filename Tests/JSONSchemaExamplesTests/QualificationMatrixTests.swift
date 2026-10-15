// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONSchemaExamples
import Testing

private func g7Cases() throws -> [JSON] {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Fixtures/SchemaExamples/S3-G7-seeded-v1.json")
    let handle = try FileHandle(forReadingFrom: path)
    let data = try handle.readToEnd() ?? Data()
    try handle.close()
    let root = try JSONParser().parse(data)
    return try #require(root.objectValue?["cases"]?.arrayValue)
}

@Test func g7SeededGrammarAlwaysCertifiesRoundtripsAndRejectsKnownMutations() throws {
    let cases = try g7Cases()
    #expect(cases.count == 64)
    var certified = 0, invalid = 0
    for row in cases {
        let schema = try #require(row.objectValue?["schema"])
        let document = try JSONSchemaDocument(schema)
        let generator = try JSONSchemaExampleGenerator(document: document)
        let independent = try JSONSchemaCompiler().compile(document)
        #expect(try !independent.validate(#require(row.objectValue?["invalid"])).isValid)
        invalid += 1
        for profile in [JSONSchemaExampleProfile.minimal, .demonstration] {
            for seed in [UInt64(0), 1, 42, UInt64.max] {
                let result = try generator.generate(seed: seed, profile: profile)
                #expect(result.validation.isValid && result.validation.diagnosticsComplete)
                #expect(try independent.validate(result.value).isValid)
                #expect(try JSONParser().parse(JSONWriter().write(result.value)) == result.value)
                #expect(result.statistics[.evaluationWorkUnits] > 0)
                #expect(result.statistics[.workUnits] <= generator.options.limits[.workUnits])
                #expect(result.attempts > 0 && result.attempts <= generator.options.maximumAttempts)
                certified += 1
            }
        }
    }
    #expect(certified == 512 && invalid == 64)
    print("S3_G7_MATRIX passed schemas=64 certified=512 invalid=64")
}

@Test func g7SchemaMemberPermutationPreservesScalarIdentityAndWitnesses() throws {
    for i in 0..<8 {
        let first = try JSONParser().parse("{\"type\":\"object\",\"required\":[\"é\",\"e\\u0301\"],\"properties\":{\"é\":{\"const\":\(i)},\"e\\u0301\":{\"const\":\(i+1)}}}")
        let second = try JSONParser().parse(JSONWriter(options: .init(keyOrder: .scalar)).write(first))
        let a = try JSONSchemaExampleGenerator(document: .init(first))
        let b = try JSONSchemaExampleGenerator(document: .init(second))
        #expect(a.sourceSnapshotDigest == b.sourceSnapshotDigest)
        let x = try a.generate(seed: 42), y = try b.generate(seed: 42)
        #expect(x.value == y.value && x.traceDigest == y.traceDigest)
        #expect(x.value.objectValue?.count == 2)
        #expect(x.value.objectValue?["é"] != x.value.objectValue?["e\u{301}"])
        #expect(try JSONSchemaCompiler().compile(a.document).validate(y.value).isValid)
    }
}
