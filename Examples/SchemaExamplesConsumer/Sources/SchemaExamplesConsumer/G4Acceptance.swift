// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONSchemaExamples

private enum G4AcceptanceFailure: Error { case mismatch }
enum G4Acceptance {
    static func run(fixturePath: String, manifestPath: String) throws {
        // Caller-owned qualification I/O and native oracle calls do not claim
        // instruction or memory caps from the generator's own public reports.
        let input = try JSONParser().parse(Data(contentsOf: URL(fileURLWithPath: fixturePath)))
        let manifest = try JSONParser().parse(Data(contentsOf: URL(fileURLWithPath: manifestPath)))
        guard let cases = input.objectValue?["cases"]?.arrayValue,
              let requiredIDs = manifest.objectValue?["g4_must_generate_ids"]?.arrayValue,
              let incompleteIDs = manifest.objectValue?["g4_may_fail_ids"]?.arrayValue else { throw G4AcceptanceFailure.mismatch }
        var results: [JSON] = [], observedRequired: [JSON] = [], observedIncomplete: [JSON] = []
        var witnesses = 0, schemas = 0, mustValid = 0, mayValid = 0, explicit = 0
        for value in cases {
            guard let c = value.objectValue, let raw = c["schema"], let id = c["id"]?.stringValue,
                  let witnessRows = c["witnesses"]?.arrayValue else { throw G4AcceptanceFailure.mismatch }
            let options = JSONSchemaExampleOptions(validationOptions: .init(formatAssertion: c["validation"]?.objectValue?["formatAssertion"]?.booleanValue == true))
            var documents: [JSONSchemaDocument] = []
            if let resources = c["resources"]?.objectValue {
                for member in resources { documents.append(try .init(member.value, retrievalURI: JSONSchemaURI(member.key.string))) }
            }
            let document = try JSONSchemaDocument(raw), registry = try JSONSchemaRegistry(documents: documents)
            let plan = try JSONSchemaCompiler(options: options.compilationOptions).compile(document, registry: registry)
            let validator = JSONSchemaValidator(options: options.validationOptions)
            // Evaluate every witness in all 44 cases, including the six negatives
            // attached to the two trivial G3 proof cases. These are native checks.
            for witness in witnessRows {
                guard let instance = witness.objectValue?["instance"], let expected = witness.objectValue?["valid"]?.booleanValue,
                      try validator.validate(instance, against: plan).isValid == expected else { throw G4AcceptanceFailure.mismatch }
                witnesses += 1
            }
            schemas += 1
            guard c["acceptanceGate"] == .string("G4") else { continue }
            let must = c["generatorExpectation"] == .string("must-generate")
            guard must || c["generatorExpectation"] == .string("may-fail-explicitly") else { throw G4AcceptanceFailure.mismatch }
            let generator = try JSONSchemaExampleGenerator(document: document, registry: registry, options: options)
            for (name, profile) in [("minimal",JSONSchemaExampleProfile.minimal),("demonstration",.demonstration)] {
                for seed in [UInt64(0),1,42,UInt64.max] {
                    var row: [JSONMember] = [.init("id",value: .string(id)),.init("profile",value: .string(name)),
                                             .init("seed",value: .number(JSONNumber(integer: seed))),.init("required",value: .boolean(must))]
                    do {
                        let result = try generator.generate(seed: seed, profile: profile)
                        let bytes = try JSONWriter(options: .init(keyOrder: .scalar, numberStyle: .normalized)).write(result.value)
                        let ceiling = min(options.limits[.workUnits], options.validationOptions.limits[.workUnits])
                        guard result.validation.isValid, result.validation.diagnosticsComplete,
                              try validator.validate(result.value, against: plan).isValid,
                              try JSONParser().parse(bytes) == result.value,
                              result.statistics[.workUnits] <= ceiling else { throw G4AcceptanceFailure.mismatch }
                        row += [.init("outcome",value: .string("validated")),.init("value",value: result.value),
                                .init("nativeCertified",value: true),.init("independentNativeValid",value: true),.init("roundtrip",value: true),
                                .init("trace",value: .string(result.traceDigest)),.init("snapshot",value: .string(result.sourceSnapshotDigest)),
                                .init("corpus",value: .string(result.corpusDigest)),.init("policy",value: .string(result.policyDigest)),
                                .init("work",value: .number(JSONNumber(integer: result.statistics[.workUnits]))),
                                .init("evaluationWork",value: .number(JSONNumber(integer: result.statistics[.evaluationWorkUnits]))),
                                .init("remainingWork",value: .number(JSONNumber(integer: ceiling - result.statistics[.workUnits]))),
                                .init("peakLogicalRetainedBytes",value: .number(JSONNumber(integer: result.statistics.peakLogicalRetainedBytes))),
                                .init("attempts",value: .number(JSONNumber(integer: result.attempts)))]
                        if must { mustValid += 1 } else { mayValid += 1 }
                    } catch let failure as JSONSchemaExampleFailure {
                        guard !must else { throw failure }
                        switch failure {
                        case .unsupportedFeature(let feature):
                            let code: String
                            switch feature {
                            case .candidateConstruction: code = "candidateConstruction"
                            case .dynamicReference: code = "dynamicReference"
                            case .cyclicReference: code = "cyclicReference"
                            }
                            row += [.init("outcome",value: .string("unsupported")),.init("reason",value: .string(code))]
                        case .searchExhausted(let attempts):
                            guard attempts > 0 && attempts <= options.maximumAttempts else { throw G4AcceptanceFailure.mismatch }
                            row += [.init("outcome",value: .string("searchExhausted")),.init("attempts",value: .number(JSONNumber(integer: attempts)))]
                        default: throw G4AcceptanceFailure.mismatch
                        }
                        // No value or successful statistics are invented after error.
                        explicit += 1
                    }
                    // Core operational errors/cancellation propagate and fail acceptance.
                    results.append(.object(try JSONObject(members: row)))
                }
            }
            if must { observedRequired.append(.string(id)) } else { observedIncomplete.append(.string(id)) }
        }
        guard schemas == 44, witnesses == 155, observedRequired == requiredIDs, observedIncomplete == incompleteIDs,
              observedRequired.count == 10, observedIncomplete.count == 8, mustValid == 80,
              mayValid + explicit == 64, results.count == 144 else { throw G4AcceptanceFailure.mismatch }
        let report = try JSONObject(members: [
            .init("algorithm",value: .string("s3-candidates-v4")),.init("requiredIDs",value: .array(observedRequired)),
            .init("incompleteIDs",value: .array(observedIncomplete)),.init("results",value: .array(results)),
            .init("schemas",value: 44),.init("witnesses",value: 155),.init("mustValid",value: 80),
            .init("mayValid",value: .number(JSONNumber(integer: mayValid))),.init("explicit",value: .number(JSONNumber(integer: explicit)))
        ])
        print("G4_RECEIPT " + (try JSONWriter().writeString(.object(report))))
        print("SCHEMA_EXAMPLES_G4 passed required=10 incomplete=8 profiles=2 seeds=4 invocations=144 witnesses=155")
    }
}
