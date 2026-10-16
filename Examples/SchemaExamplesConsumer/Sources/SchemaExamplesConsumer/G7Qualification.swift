// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONSchemaExamples

private enum G7Failure: Error { case mismatch }
enum G7Qualification {
    static func run(path: String) throws {
        let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
        let bytes = try handle.readToEnd() ?? Data()
        try handle.close()
        guard let cases = try JSONParser().parse(bytes).objectValue?["cases"]?.arrayValue,
              cases.count == 64 else { throw G7Failure.mismatch }
        var count = 0
        for row in cases {
            guard let id = row.objectValue?["id"], let raw = row.objectValue?["schema"],
                  let bad = row.objectValue?["invalid"] else { throw G7Failure.mismatch }
            let generator = try JSONSchemaExampleGenerator(document: .init(raw))
            let independent = try JSONSchemaCompiler().compile(generator.document)
            guard try !independent.validate(bad).isValid else { throw G7Failure.mismatch }
            for (name, profile) in [("minimal", JSONSchemaExampleProfile.minimal), ("demonstration", .demonstration)] {
                for seed in [UInt64(0), 1, 42, UInt64.max] {
                    let result = try generator.generate(seed: seed, profile: profile)
                    guard result.validation.isValid, result.validation.diagnosticsComplete,
                          try independent.validate(result.value).isValid,
                          result.statistics[.evaluationWorkUnits] > 0,
                          try JSONParser().parse(JSONWriter().write(result.value)) == result.value else { throw G7Failure.mismatch }
                    let output = try JSONObject(members: [
                        .init("id", value: id), .init("profile", value: .string(name)),
                        .init("seed", value: .number(JSONNumber(integer: seed))),
                        .init("value", value: result.value), .init("trace", value: .string(result.traceDigest)),
                        .init("work", value: .number(JSONNumber(integer: result.statistics[.workUnits]))),
                        .init("evaluationWork", value: .number(JSONNumber(integer: result.statistics[.evaluationWorkUnits]))),
                        .init("attempts", value: .number(JSONNumber(integer: result.attempts)))])
                    print("G7_RESULT " + String(decoding: try JSONWriter(options: .init(keyOrder: .scalar, numberStyle: .normalized)).write(.object(output)), as: UTF8.self))
                    count += 1
                }
            }
        }
        guard count == 512 else { throw G7Failure.mismatch }
        print("SCHEMA_EXAMPLES_G7 passed schemas=64 certified=512 invalid=64")
    }
}
