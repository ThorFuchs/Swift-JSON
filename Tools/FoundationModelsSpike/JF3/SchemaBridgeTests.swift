// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import Testing
@testable import JSONFoundationModels

private func jf3Doc(_ text: String) throws -> JSONSchemaDocument { try JSONSchemaDocument(JSONParser().parse(text)) }
private let jf3Simple = #"{"type":"object","properties":{"query":{"type":"string"}},"required":["query"],"additionalProperties":false}"#
private let jf3Augmented = #"{"title":"Object","type":"object","properties":{"query":{"type":"string"}},"required":["query"],"additionalProperties":false,"x-order":["query"]}"#

// A controlled native Codable peer, not an imitation of FoundationModels.
private struct AddsMetadata: Codable {
    init(from decoder: any Decoder) throws { _ = try JSON(from: decoder) }
    func encode(to encoder: any Encoder) throws { try JSONParser().parse(jf3Augmented).encode(to: encoder) }
}

private func compare(_ a: String, _ b: String, policy: JSONGenerationSchemaMetadataPolicy = .exact) throws -> [JSONGenerationSchemaAnnotationAddition] {
    let source = try jf3Doc(a), returned = try jf3Doc(b)
    return try JSON.withComposition { scope in
        let x = try scope.admitTrusted(source.raw), y = try scope.admitTrusted(returned.raw)
        return try scope.withMeter { meter in
            try JF3SchemaProfile.check(x, meter: &meter)
            try JF3SchemaProfile.check(y, meter: &meter)
            var additions: [JSONGenerationSchemaAnnotationAddition] = []
            try JF3SchemaProfile.compare(x, y, policy: policy, additions: &additions, meter: &meter)
            return additions
        }
    }.result
}

private func expectIssue(_ issue: JSONGenerationSchemaIssue, _ work: () throws -> Void) throws {
    do { try work(); Issue.record("Expected JF3 incompatibility") }
    catch let error as JSONGenerationSchemaFailure { #expect(error.issue == issue) }
}

@Test func jf3ExactCodableAndCanonicalPlan() throws {
    let doc = try jf3Doc(#"{"type":"object","properties":{"a":{"type":"array","items":{"type":"integer","minimum":1,"maximum":20},"minItems":1},"title":{"type":"string","enum":["x","y"]}},"required":["a"],"additionalProperties":false}"#)
    let report = try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: .balanced)
    #expect(report.result.additions.isEmpty)
    #expect(try JSONComparison.equals(report.result.canonical.document.raw, doc.raw))
    #expect(try JSONComparison.equals(report.result.roundtripped.raw, doc.raw))
    #expect(try report.result.canonical.validate(JSONParser().parse(#"{"a":[1]}"#)).isValid)
    #expect(try !report.result.canonical.validate(JSONParser().parse(#"{"a":[21]}"#)).isValid)
    #expect(report.statistics[.workUnits] > 0)
    let imported = try JF3SchemaBoundary.importSchema(doc.raw, limits: .balanced)
    #expect(try JSONComparison.equals(imported.result.document.raw, doc.raw))
}

@Test func jf3MetadataRequiresExplicitConsent() throws {
    let doc = try jf3Doc(jf3Simple)
    try expectIssue(.annotationAdditionDenied) {
        _ = try JF3SchemaBoundary.project(AddsMetadata.self, document: doc, policy: .exact, limits: .balanced)
    }
    let report = try JF3SchemaBoundary.project(AddsMetadata.self, document: doc, policy: .allowGeneratedAnnotations, limits: .balanced)
    #expect(report.result.additions.map(\.path).contains([.key(JSONKey("title"))]))
    #expect(report.result.additions.map(\.path).contains([.key(JSONKey("x-order"))]))
    #expect(report.result.additions.count == 2)
    #expect(try JSONComparison.equals(report.result.canonical.document.raw, doc.raw))
    #expect(try JSONComparison.equals(report.result.roundtripped.raw, JSONParser().parse(jf3Augmented)))
}

@Test func jf3RejectsConstraintMutationEvenWithMetadataConsent() throws {
    let base = #"{"type":"object","properties":{"n":{"type":"integer","minimum":1,"maximum":9007199254740993}},"required":["n"],"additionalProperties":false}"#
    for changed in [base.replacingOccurrences(of: "9007199254740993", with: "9007199254740992"),
                    base.replacingOccurrences(of: #","maximum":9007199254740993"#, with: ""),
                    base.replacingOccurrences(of: #"["n"]"#, with: "[]"),
                    base.replacingOccurrences(of: #""minimum":1"#, with: #""minimum":2"#)] {
        try expectIssue(.changedConstraint) { _ = try compare(base, changed, policy: .allowGeneratedAnnotations) }
    }
}

@Test func jf3MetadataIsScopedToSchemaNodes() throws {
    let a = #"{"type":"object","properties":{"title":{"type":"string","description":"original"},"x-order":{"type":"string"}},"required":["title"],"additionalProperties":false}"#
    let b = a.replacingOccurrences(of: #""type":"string","description":"original""#, with: #""type":"string","description":"original","title":"Generated""#)
    let changes = try compare(a, b, policy: .allowGeneratedAnnotations)
    #expect(changes.map(\.path) == [[.key(JSONKey("properties")), .key(JSONKey("title")), .key(JSONKey("title"))]])
    try expectIssue(.changedAnnotation) { _ = try compare(a, b.replacingOccurrences(of: "original", with: "changed"), policy: .allowGeneratedAnnotations) }
    try expectIssue(.changedConstraint) { _ = try compare(a, a.replacingOccurrences(of: #""x-order":{"type":"string"}"#, with: #""other":{"type":"string"}"#), policy: .allowGeneratedAnnotations) }
}

@Test func jf3RejectsUnqualifiedDeclarations() throws {
    let base = jf3Simple
    for extra in [#","allOf":[{}]"#, #","$defs":{"X":{"type":"string"}}"#, #","patternProperties":{"x":{"type":"string"}}"#, #","x-custom":true"#, #","$schema":"https://json-schema.org/draft/2020-12/schema""#] {
        try expectIssue(.unsupportedDeclaration) { _ = try compare(String(base.dropLast()) + extra + "}", base) }
    }
    for shape in [base.replacingOccurrences(of: #""additionalProperties":false"#, with: #""additionalProperties":true"#),
                  base.replacingOccurrences(of: #""type":"string"#, with: #""type":["string","null"]"#),
                  base.replacingOccurrences(of: #""query""#, with: #""é""#),
                  jf3Augmented.replacingOccurrences(of: #""x-order":["query"]"#, with: #""x-order":["missing"]"#)] {
        try expectIssue(.unsupportedShape) { _ = try compare(shape, base) }
    }
}

@Test func jf3NativeInvalidityIsNotCompatibility() throws {
    let doc = try jf3Doc(#"{"type":"object","properties":{"n":{"type":"integer","minimum":"not a number"}},"required":["n"],"additionalProperties":false}"#)
    #expect(throws: JSONSchemaCompilationFailure.self) {
        try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: .balanced)
    }
}

@Test func jf3CumulativeBudgetBoundary() throws {
    let doc = try jf3Doc(jf3Simple)
    let measured = try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: .balanced)
    var limits = JSONLimits.balanced
    limits[.workUnits] = measured.statistics[.workUnits]
    limits[.retainedBytes] = measured.statistics.peakLogicalRetainedBytes
    #expect(try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: limits).statistics == measured.statistics)
    var less = limits; less[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: less) }
    less = limits; less[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: less) }
}

@Test func jf3CancellationIsNotIncompatibility() async throws {
    let doc = try jf3Doc(jf3Simple)
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: .balanced).result.canonical
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

@available(macOS 27.0, iOS 27.0, *)
@Generable
struct JF3GuidedArguments {
    @Guide(description: "Search query") var query: String
    @Guide(.range(1...20)) var limit: Int
    @Guide(.anyOf(["date", "title"])) var sort: String
    @Guide(.count(2)) var tags: [String]
    var note: String?
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf3AppleGuidedImport() throws {
    let bridge = JSONGenerationSchemaBridge()
    let report = try bridge.importSchemaWithReport(JF3GuidedArguments.generationSchema)
    let raw = try JSONValueEncoder().encode(JF3GuidedArguments.generationSchema)
    #expect(try JSONComparison.equals(raw, report.result.document.raw))
    let good = try JSONParser().parse(#"{"query":"test","limit":1,"sort":"date","tags":["a","b"]}"#)
    let bad = try JSONParser().parse(#"{"query":"test","limit":1,"sort":"date","tags":["a","b"],"note":null}"#)
    #expect(try report.result.validate(good).isValid)
    #expect(try !report.result.validate(bad).isValid)
    print("JF3_IMPORT \(try JSONWriter().writeString(report.result.document.raw))")
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf3AppleKnownReverseAnnotationDelta() throws {
    let bridge = JSONGenerationSchemaBridge()
    let doc = try jf3Doc(jf3Simple)
    try expectIssue(.annotationAdditionDenied) { _ = try bridge.project(doc) }
    let report = try bridge.projectWithReport(doc, metadata: .allowGeneratedAnnotations)
    let value = report.result
    #expect(value.additions.count == 2)
    #expect(value.additions.map(\.path).contains([.key(JSONKey("title"))]))
    #expect(value.additions.map(\.path).contains([.key(JSONKey("x-order"))]))
    #expect(try JSONComparison.equals(value.canonical.document.raw, doc.raw))
    #expect(try JSONComparison.equals(value.roundtripped.raw, JSONParser().parse(jf3Augmented)))
    print("JF3_REVERSE \(try JSONWriter().writeString(value.roundtripped.raw))")
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf3AppleExactPreparedSchema() throws {
    let bridge = JSONGenerationSchemaBridge()
    let doc = try jf3Doc(jf3Augmented)
    let value = try bridge.project(doc)
    #expect(value.additions.isEmpty)
    #expect(try JSONComparison.equals(value.roundtripped.raw, doc.raw))
    #expect(try value.canonical.validate(JSONParser().parse(#"{"query":"hello"}"#)).isValid)
    #expect(try !value.canonical.validate(JSONParser().parse(#"{"query":null}"#)).isValid)
    print("JF3_EXACT \(try JSONWriter().writeString(value.roundtripped.raw))")
}
#endif
