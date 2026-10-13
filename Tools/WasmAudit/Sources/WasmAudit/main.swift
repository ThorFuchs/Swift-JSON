// SPDX-License-Identifier: Apache-2.0
import WasmAuditKit
import JSONSchema

@main struct Audit {
    static func main() async throws {
        let mode = CommandLine.arguments.dropFirst().first ?? "core"
        switch mode {
        case "missing-resources":
            do {
                _ = try JSONSchemaRegistry.draft2020_12()
                throw ProbeFailure.assertion("Missing resources were accepted")
            } catch let failure as JSONSchemaCompilationFailure {
                guard failure.category == .metaSchema else { throw failure }
                print("MISSING_RESOURCES structured_metaSchema")
            }
        case "benchmark": try await Probes.benchmark()
        case "profiles": try Probes.profiles(); try Probes.payloadObservation()
        case "core":
            try Probes.exactNumbers(); print("CASE exact_numbers passed")
            try Probes.scalarKeysAndOrder(); print("CASE scalar_keys_and_order passed")
            try Probes.strictCodecAndPointer(); print("CASE strict_codec_pointer passed")
            try Probes.codingAndScope(); print("CASE coding_and_scope passed")
            try Probes.cumulativeBudgets(); print("CASE cumulative_budgets passed")
            try Probes.patches(); print("CASE patch_and_merge_patch passed")
        case "resources": try Probes.resourceRegistry(); print("CASE nine_pinned_resources passed")
        case "schema":
            try Probes.schemaAndRegex(); print("CASE schema_regex_operational_errors passed")
            try await Probes.sharedPlan(); print("CASE shared_plan_eight_evaluations passed")
        case "streaming":
            try await Probes.streams(); print("CASE stream_completion_ndjson passed")
            try await Probes.awaitedSink(); print("CASE awaited_sink passed")
            try await Probes.cancellation(); print("CASE cancellation_terminal_writes passed")
        default: throw ProbeFailure.assertion("Unknown mode")
        }
        print("AUDIT_COMPLETED mode=\(mode)")
    }
}
