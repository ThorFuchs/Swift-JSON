// SPDX-License-Identifier: Apache-2.0
import FoundationModels
import JSON
import JSONSchema

@main struct Consumer {
    static func main() throws {
        // Compile-time test of the public Decodable conformance, isolated
        // from forward schema and GeneratedContent probes.
        let raw = try JSONParser().parse(#"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"],"additionalProperties":false}"#)
        _ = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw))
        do {
            let decoded = try JSONValueDecoder().decode(GenerationSchema.self, from: raw)
            let returned = try JSONValueEncoder().encode(decoded)
            print("JF1_REVERSE_JSON \(try JSONWriter().writeString(returned))")
            print("JF1_REVERSE_VALUE_EQUAL \(raw == returned)")
            _ = try JSONSchemaCompiler().compile(JSONSchemaDocument(returned))
            print("JF1_REVERSE_NATIVE_COMPILE true")
        } catch {
            print("JF1_REVERSE_REJECTED \(String(reflecting: type(of: error)))")
        }
        print("JF1_DECODE_COMPLETE")
    }
}
