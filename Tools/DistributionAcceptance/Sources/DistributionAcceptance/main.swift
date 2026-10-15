// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONStreaming
import JSONPatch

@main struct DistributionAcceptance {
    static func main() throws {
        switch CommandLine.arguments.dropFirst().first {
        case "intact":
            let registry = try JSONSchemaRegistry.draft2020_12()
            guard registry.documents.count == 9 else { throw ProbeError.registry }
            let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(true))
            guard try JSONSchemaValidator().validate(7, against: plan).isValid else { throw ProbeError.verdict }
            print("DISTRIBUTION intact nine_offline_resources")
        case "unavailable":
            do { _ = try JSONSchemaRegistry.draft2020_12(); throw ProbeError.accepted }
            catch let failure as JSONSchemaCompilationFailure {
                guard failure.category == .metaSchema else { throw failure }
                print("DISTRIBUTION unavailable structured_metaSchema")
            }
        default: throw ProbeError.arguments
        }
    }
    enum ProbeError: Error { case registry, verdict, accepted, arguments }
}
