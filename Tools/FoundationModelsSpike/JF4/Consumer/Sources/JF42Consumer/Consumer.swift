// SPDX-License-Identifier: Apache-2.0
import FoundationModels
import JSON
import JSONSchema
import JSONSchemaDSL
import JSONFoundationModels

private enum ConsumerFailure: Error { case unsupportedOS, valueChanged, invalidAccepted }

@main
struct JF42Consumer {
    static func main() throws {
        guard #available(macOS 27.0, *) else { throw ConsumerFailure.unsupportedOS }
        try run()
    }

    @available(macOS 27.0, *)
    private static func run() throws {
        // A real external SwiftPM executable using only public library APIs.
        let nested = try JF42Example.run()
        let document = try JSONSchemaDSL.document {
            Schema.type(.object)
            Schema.properties { Property("query") { Schema.type(.string) } }
            Schema.required("query")
            Schema.additionalProperties(false)
        }
        let prepared = try JSONPreparedGeneration.prepare(document, metadata: .allowGeneratedAnnotations)
        let original = try JSONParser().parse(#"{"query":"Swift"}"#)
        let returned = try prepared.json(from: prepared.generatedContent(from: original))
        guard try JSONComparison.equals(original, returned) else { throw ConsumerFailure.valueChanged }
        do {
            _ = try prepared.generatedContent(from: JSONParser().parse("{}"))
            throw ConsumerFailure.invalidAccepted
        } catch let failure as JSONGenerationArgumentFailure {
            guard case .invalidArguments(let result) = failure,
                  !result.isValid, result.diagnosticsComplete else { throw ConsumerFailure.invalidAccepted }
        }
        let receipt = Receipt(nested: nested, canonical: try JSONWriter().writeString(document.raw),
                              projected: try JSONWriter().writeString(prepared.roundtripped.raw),
                              returned: try JSONWriter().writeString(returned))
        print("JF42_CONSUMER \(try JSONWriter().writeString(JSONValueEncoder().encode(receipt)))")
    }

    private struct Receipt: Encodable {
        let nested: JF42NestedReceipt
        let canonical: String
        let projected: String
        let returned: String
    }
}
