// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONSchemaExamples

private enum G3AcceptanceFailure: Error { case mismatch }
enum G3Acceptance {
    static func run(fixturePath: String, manifestPath: String) throws {
        // Caller-owned qualification I/O and assertions are separate from the
        // generator's one invocation ledger. No private plan or meter is imported.
        let data = try JSONParser().parse(Data(contentsOf: URL(fileURLWithPath: fixturePath)))
        let manifest = try JSONParser().parse(Data(contentsOf: URL(fileURLWithPath: manifestPath)))
        guard let cases = data.objectValue?["cases"]?.arrayValue,
              let expectedIDs = manifest.objectValue?["g3_must_generate_ids"]?.arrayValue else { throw G3AcceptanceFailure.mismatch }
        var observed: [JSON] = [], results: [JSON] = [], proofs: [JSON] = [], witnessCount = 0
        for value in cases {
            guard let c = value.objectValue, c["acceptanceGate"] == .string("G3"),
                  let id = c["id"]?.stringValue, let raw = c["schema"] else { continue }
            let assertion = c["validation"]?.objectValue?["formatAssertion"]?.booleanValue == true
            let options = JSONSchemaExampleOptions(validationOptions: .init(formatAssertion: assertion))
            let generator = try JSONSchemaExampleGenerator(document: .init(raw), options: options)
            if c["generatorExpectation"] == .string("must-prove-unsatisfiable") {
                do { _ = try generator.generate(); throw G3AcceptanceFailure.mismatch }
                catch JSONSchemaExampleFailure.provenUnsatisfiable(let proof) {
                    guard id == "boolean-false" && proof == .falseSchema || id == "not-true" && proof == .notTrue else { throw G3AcceptanceFailure.mismatch }
                    proofs.append(.string(id)); continue
                }
            }
            guard c["generatorExpectation"] == .string("must-generate") else { throw G3AcceptanceFailure.mismatch }
            let plan = try JSONSchemaCompiler(options: options.compilationOptions).compile(generator.document, registry: generator.registry)
            let validator = JSONSchemaValidator(options: options.validationOptions)
            guard let witnesses = c["witnesses"]?.arrayValue else { throw G3AcceptanceFailure.mismatch }
            for witness in witnesses {
                guard let instance = witness.objectValue?["instance"], let expected = witness.objectValue?["valid"]?.booleanValue,
                      try validator.validate(instance, against: plan).isValid == expected else { throw G3AcceptanceFailure.mismatch }
                witnessCount += 1
            }
            for (name, profile) in [("minimal", JSONSchemaExampleProfile.minimal), ("demonstration", .demonstration)] {
                for seed in [UInt64(0), 1, 42, UInt64.max] {
                    let result = try generator.generate(seed: seed, profile: profile)
                    let bytes = try JSONWriter(options: .init(keyOrder: .scalar, numberStyle: .normalized)).write(result.value)
                    let roundtrip = try JSONParser().parse(bytes)
                    let ceiling = min(options.limits[.workUnits], options.validationOptions.limits[.workUnits])
                    guard result.validation.isValid, result.validation.diagnosticsComplete,
                          try validator.validate(result.value, against: plan).isValid,
                          roundtrip == result.value, result.statistics[.workUnits] <= ceiling,
                          result.statistics[.evaluationWorkUnits] > 0 else { throw G3AcceptanceFailure.mismatch }
                    let row = try JSONObject(members: [
                        .init("id", value: .string(id)), .init("profile", value: .string(name)),
                        .init("seed", value: .number(JSONNumber(integer: seed))),
                        .init("value", value: result.value), .init("trace", value: .string(result.traceDigest)),
                        .init("snapshot", value: .string(result.sourceSnapshotDigest)),
                        .init("corpus", value: .string(result.corpusDigest)), .init("policy", value: .string(result.policyDigest)),
                        .init("attempts", value: .number(JSONNumber(integer: result.attempts))),
                        .init("work", value: .number(JSONNumber(integer: result.statistics[.workUnits]))),
                        .init("evaluationWork", value: .number(JSONNumber(integer: result.statistics[.evaluationWorkUnits]))),
                        .init("remainingWork", value: .number(JSONNumber(integer: ceiling - result.statistics[.workUnits]))),
                        .init("peakLogicalRetainedBytes", value: .number(JSONNumber(integer: result.statistics.peakLogicalRetainedBytes))),
                        .init("nativeCertified", value: true), .init("independentNativeValid", value: true), .init("roundtrip", value: true)
                    ])
                    results.append(.object(row))
                }
            }
            observed.append(.string(id))
        }
        guard observed == expectedIDs, observed.count == 24, results.count == 192, proofs.count == 2,
              witnessCount == 90 else { throw G3AcceptanceFailure.mismatch }
        let report = try JSONObject(members: [
            .init("algorithm", value: .string("s3-candidates-v3")), .init("ids", value: .array(observed)),
            .init("results", value: .array(results)), .init("proofs", value: .array(proofs)), .init("witnesses", value: 90)
        ])
        print("G3_RECEIPT " + (try JSONWriter().writeString(.object(report))))
        print("SCHEMA_EXAMPLES_G3 passed cases=24 profiles=2 seeds=4 validated=192 witnesses=90 proofs=2")
    }
}
