// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema
@Test func schemaDocumentsPreserveExactRawDeclarations() throws {
    let raw = try JSONParser().parse(#"{"unknown":{"é":1,"é":2},"maximum":9007199254740993}"#)
    let document = try JSONSchemaDocument(raw)
    #expect(document.raw == raw)
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaDocument(.array([])) }
    #expect(try JSONSchemaBuilder.boolean(false).raw == false)
}
@Test func explicitRegistrySnapshotsRejectAmbiguousRetrievalIdentities() throws {
    let uri = try JSONSchemaURI("https://example.test/schema")
    let first = try JSONSchemaDocument(true, retrievalURI: uri)
    let original = try JSONSchemaRegistry(documents: [first])
    let other = try JSONSchemaDocument(false, retrievalURI: JSONSchemaURI("other", relativeTo: uri))
    let next = try original.adding(other)
    #expect(original.documents.count == 1 && next.documents.count == 2)
    #expect(throws: JSONSchemaCompilationFailure.self) { try original.adding(first) }
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaRegistry(documents: [JSONSchemaDocument(true)]) }
}
@Test func URIResolutionUsesRFC3986AndPercentFragmentsRemainEncoded() throws {
    let base = try JSONSchemaURI("https://example.test/a/b/root.json")
    #expect(try JSONSchemaURI("../child.json#%C3%A9", relativeTo: base).string == "https://example.test/a/child.json#%C3%A9")
    #expect(try JSONSchemaURI("#/$defs/name", relativeTo: base).fragment == "/$defs/name")
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaURI("https://example.test/%ZZ") }
    #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaURI("relative") }
    for (base, reference, expected) in [
        ("urn:swift-json:root", "#/$defs/value", "urn:swift-json:root#/$defs/value"),
        ("urn:example:root?revision=1#old", "#new", "urn:example:root?revision=1#new"),
        ("urn:example:root?revision=1#old", "", "urn:example:root?revision=1"),
        ("https://e.test/path?revision=1#old", "#new", "https://e.test/path?revision=1#new"),
        ("https://e.test/path?revision=1#old", "", "https://e.test/path?revision=1"),
        ("urn:example:root", "#%C3%A9", "urn:example:root#%C3%A9")
    ] {
        #expect(try JSONSchemaURI(reference, relativeTo: JSONSchemaURI(base)).string == expected)
    }
}
@Test func pinnedOfficialMetaSchemasLoadAsImmutableResources() throws {
    let registry = try JSONSchemaRegistry.draft2020_12()
    #expect(registry.documents.count == 9)
    #expect(registry.documents.contains { $0.retrievalURI?.string == "https://json-schema.org/draft/2020-12/schema" })
    var limits = JSONLimits.balanced; limits[.schemaDocuments] = 8
    #expect(throws: JSONFailure.self) { try JSONSchemaRegistry.draft2020_12(limits: limits) }
}

@Test(arguments: [
    ("HTTP://Example.COM/a/./b/../c/%7e?q=%41#%61", "http://example.com/a/c/~?q=A#a"),
    ("https://e.test/a//b", "https://e.test/a//b"),
    ("https://e.test/a/..", "https://e.test/"),
    ("https://e.test/a/.", "https://e.test/a/"),
    ("https://e.test/../a", "https://e.test/a"),
    ("https://e.test/a/%2e%2e/b", "https://e.test/b"),
    ("https://User:Pass@EXAMPLE.COM/a%2fb", "https://User:Pass@example.com/a%2Fb"),
    ("urn:a/../b", "urn:/b"),
    ("https://e.test/e%cc%81", "https://e.test/e%CC%81")
])
func URIIdentityUsesSyntaxNormalizationWithoutUnicodeFolding(input: String, expected: String) throws {
    #expect(try JSONSchemaURI(input).string == expected)
    #expect(try JSONSchemaURI(input) == JSONSchemaURI(expected))
    #expect(try JSONSchemaURI("https://e.test/e%CC%81") != JSONSchemaURI("https://e.test/%C3%A9"))
}
