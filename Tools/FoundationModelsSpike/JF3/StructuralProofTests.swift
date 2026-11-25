// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import Testing
@testable import JSONFoundationModels

private let inlineChild = #"{"type":"object","properties":{"child":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false}},"required":["child"],"additionalProperties":false}"#
private let hoistedChild = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/Child"}},"required":["child"],"additionalProperties":false,"$defs":{"Child":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false}}}"##
private let childPath = ["properties", "child"]
private func doc33(_ text: String) throws -> JSONSchemaDocument {
    try JSONSchemaDocument(JSONParser().parse(text))
}
private func names33(_ path: [JSONLocationComponent]) throws -> [String] {
    try path.map {
        guard case .key(let key) = $0 else { throw Matrix33Error.unexpectedIndex }
        return key.string
    }
}
private enum Matrix33Error: Error { case unexpectedIndex, missingFixture, expectedRejection }

private struct Rewrite33: Encodable, Equatable {
    let kind: String
    let path: [String]
    let definition: String?
    init(_ rewrite: JSONGenerationSchemaStructuralRewrite) throws {
        kind = rewrite.kind.rawValue; path = try names33(rewrite.path); definition = rewrite.definition?.string
    }
}
private struct Proof33 {
    let additions: [[String]]
    let rewrites: [Rewrite33]
}
private func prove33(_ source: String, _ raw: String, limits: JSONLimits = .balanced) throws -> JSONOperationReport<Proof33> {
    let a = try doc33(source), b = try doc33(raw)
    // Use the actual native compilation path for the canonical fixture.
    let state = try JF3SchemaBoundary.state(limits)
    _ = try JF3SchemaBoundary.compile(a, state: state)
    try JSONAdmission.value(b.raw, meter: &state.meter, owned: true)
    let proof = try JF33StructuralProof.verify(a.raw, b.raw, meter: &state.meter)
    try state.meter.operationDomain(.schemaCompilation)
    _ = try JSONSchemaCompiler(options: .init(limits: state.meter.limits)).compile(b, registry: .empty, meter: &state.meter)
    try state.meter.operationDomain(.core)
    let result = try Proof33(additions: proof.additions.map { try names33($0.path) }, rewrites: proof.rewrites.map(Rewrite33.init))
    return .init(result: result, statistics: try state.meter.compositionStatistics())
}
private func reject33(_ source: String, _ raw: String, _ issue: JSONGenerationSchemaIssue, _ path: [String]) throws {
    do {
        _ = try prove33(source, raw)
        Issue.record("Expected structural rejection at \(path)")
    } catch let error as JSONGenerationSchemaFailure {
        #expect(error.issue == issue)
        #expect(try names33(error.path) == path)
    }
}

// A controlled Codable peer exercises the whole metered projection path, not
// an imitation of FoundationModels. Actual Apple behavior is tested separately.
private struct Hoisted33: Codable {
    init(from decoder: any Decoder) throws { _ = try JSON(from: decoder) }
    func encode(to encoder: any Encoder) throws { try JSONParser().parse(hoistedChild).encode(to: encoder) }
}

@Test func jf33PairedProofAndCanonicalAuthority() throws {
    let original = try doc33(inlineChild)
    let report = try JF3SchemaBoundary.project(Hoisted33.self, document: original, policy: .allowStructuralEquivalence, limits: .balanced)
    #expect(report.result.additions.isEmpty)
    #expect(report.result.rewrites.count == 1)
    let rewrite = try #require(report.result.rewrites.first)
    #expect(rewrite.kind == .localReference)
    #expect(try names33(rewrite.path) == childPath)
    #expect(rewrite.definition == JSONKey("Child"))
    #expect(try JSONComparison.equals(original.raw, report.result.canonical.document.raw))
    #expect(try JSONComparison.equals(report.result.roundtripped.raw, JSONParser().parse(hoistedChild)))
    let other = try JSONSchemaCompiler().compile(report.result.roundtripped)
    for (text, valid) in [(#"{"child":{"n":9007199254740993}}"#,true),(#"{"child":{"n":9007199254740994}}"#,false)] {
        let instance = try JSONParser().parse(text)
        #expect(try report.result.canonical.validate(instance).isValid == valid)
        #expect(try other.validate(instance).isValid == valid)
    }
    for policy in [JSONGenerationSchemaMetadataPolicy.exact, .allowGeneratedAnnotations] {
        #expect(throws: JSONGenerationSchemaFailure.self) {
            try JF3SchemaBoundary.project(Hoisted33.self, document: original, policy: policy, limits: .balanced)
        }
    }
}

@Test func jf33ReferenceGrammarAndEscaping() throws {
    // RFC 6901 tilde escaping and percent decoding exactly once.
    let escaped = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/A~1B~0C%25"}},"required":["child"],"additionalProperties":false,"$defs":{"A/B~C%":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false}}}"##
    let proof = try prove33(inlineChild, escaped).result
    #expect(proof.rewrites.first?.definition == "A/B~C%")
    let once = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/A%252FB"}},"required":["child"],"additionalProperties":false,"$defs":{"A%2FB":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false}}}"##
    #expect(try prove33(inlineChild, once).result.rewrites.first?.definition == "A%2FB")
    for ref in ["https://example.invalid/schema#/$defs/Child", "#/$defs/Missing", "#/properties/child",
                "#/$defs/Child/type", "#/$defs/Chi~2ld", "#/$defs/Chi%GGld", "#Child", "#"] {
        // All strings are authored safe ASCII literals, and the resulting
        // complete fixture is parsed independently before proof.
        let raw = hoistedChild.replacingOccurrences(of: "#/$defs/Child", with: ref)
        try reject33(inlineChild, raw, .invalidLocalReference, childPath + ["$ref"])
    }
}

@Test func jf33RejectsSiblingScopesAndUnusedDefinitions() throws {
    let siblings = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/Child","description":"extra"}},"required":["child"],"additionalProperties":false,"$defs":{"Child":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false}}}"##
    try reject33(inlineChild, siblings, .invalidLocalReference, childPath + ["$ref"])
    let unused = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/Child"}},"required":["child"],"additionalProperties":false,"$defs":{"Child":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false},"Unused":{"type":"string"}}}"##
    try reject33(inlineChild, unused, .unusedDefinition, ["$defs","Unused"])
    let scoped = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/Child"}},"required":["child"],"additionalProperties":false,"$defs":{"Child":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false,"$id":"https://example.invalid/changed"}}}"##
    try reject33(inlineChild, scoped, .unsupportedDeclaration, childPath + ["$id"])
    let alias = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/A"}},"required":["child"],"additionalProperties":false,"$defs":{"A":{"$ref":"#/$defs/B"},"B":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false}}}"##
    try reject33(inlineChild, alias, .invalidLocalReference, childPath + ["$ref"])
    let dynamic = ##"{"type":"object","properties":{"child":{"$dynamicRef":"#/$defs/Child"}},"required":["child"],"additionalProperties":false}"##
    try reject33(inlineChild, dynamic, .changedConstraint, childPath + ["type"])
    let rootRef = ##"{"$ref":"#/$defs/Child","$defs":{"Child":{"type":"object","properties":{},"required":[],"additionalProperties":false}}}"##
    try reject33(inlineChild, rootRef, .invalidLocalReference, ["$ref"])
}

@Test func jf33RejectsCyclesAndProvesEachSharedUse() throws {
    let source = #"{"type":"object","properties":{"child":{"type":"object","properties":{"child":{"type":"object","properties":{},"required":[],"additionalProperties":false}},"required":["child"],"additionalProperties":false}},"required":["child"],"additionalProperties":false}"#
    let cyclic = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/Loop"}},"required":["child"],"additionalProperties":false,"$defs":{"Loop":{"type":"object","properties":{"child":{"$ref":"#/$defs/Loop"}},"required":["child"],"additionalProperties":false}}}"##
    try reject33(source, cyclic, .cyclicLocalReference, childPath + ["properties","child","$ref"])
    let mutual = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/A"}},"required":["child"],"additionalProperties":false,"$defs":{"A":{"type":"object","properties":{"child":{"$ref":"#/$defs/B"}},"required":["child"],"additionalProperties":false},"B":{"type":"object","properties":{"child":{"$ref":"#/$defs/A"}},"required":["child"],"additionalProperties":false}}}"##
    // The finite source has no corresponding third child: either a shape
    // difference or a cycle must fail; never follow an unpaired branch.
    #expect(throws: JSONGenerationSchemaFailure.self) { try prove33(source, mutual) }

    let shared = #"{"type":"object","properties":{"a":{"type":"object","properties":{"n":{"type":"integer"}},"required":["n"],"additionalProperties":false,"title":"Same"},"b":{"type":"object","properties":{"n":{"type":"integer"}},"required":["n"],"additionalProperties":false,"title":"Same"}},"required":["a","b"],"additionalProperties":false}"#
    let aliasBoth = ##"{"type":"object","properties":{"a":{"$ref":"#/$defs/Same"},"b":{"$ref":"#/$defs/Same"}},"required":["a","b"],"additionalProperties":false,"$defs":{"Same":{"type":"object","properties":{"n":{"type":"integer"}},"required":["n"],"additionalProperties":false,"title":"Same"}}}"##
    #expect(try prove33(shared, aliasBoth).result.rewrites.count == 2)
    let distinct = #"{"type":"object","properties":{"a":{"type":"object","properties":{"n":{"type":"integer"}},"required":["n"],"additionalProperties":false,"title":"Same"},"b":{"type":"object","properties":{"n":{"type":"string"}},"required":["n"],"additionalProperties":false,"title":"Same"}},"required":["a","b"],"additionalProperties":false}"#
    try reject33(distinct, aliasBoth, .changedConstraint, ["properties","b","properties","n","type"])
}

@Test func jf33RequiredIsSetButGuidanceIsOrdered() throws {
    let base = #"{"type":"object","properties":{"a":{"type":"string","enum":["z","a"]},"b":{"type":"integer"}},"required":["b","a"],"additionalProperties":false,"x-order":["b","a"],"description":"original"}"#
    let reordered = base.replacingOccurrences(of: #""required":["b","a"]"#, with: #""required":["a","b"]"#)
    let result = try prove33(base, reordered).result
    #expect(result.rewrites.count == 1)
    #expect(result.rewrites.first?.kind == "requiredPermutation")
    #expect(result.rewrites.first?.path == ["required"])
    for names in [#"["a","a"]"#,#"["a"]"#,#"["a","c"]"#] {
        let altered = base.replacingOccurrences(of: #""required":["b","a"]"#, with: "\"required\":" + names)
        try reject33(base, altered, .changedConstraint, ["required"])
    }
    try reject33(base, base.replacingOccurrences(of: #""enum":["z","a"]"#, with: #""enum":["a","z"]"#), .changedConstraint, ["properties","a","enum"])
    try reject33(base, base.replacingOccurrences(of: #""x-order":["b","a"]"#, with: #""x-order":["a","b"]"#), .changedAnnotation, ["x-order"])
    try reject33(base, base.replacingOccurrences(of: "original", with: "modified"), .changedAnnotation, ["description"])
}

@Test func jf33NeverHidesNumericOrMetadataLoss() throws {
    let rounded = hoistedChild.replacingOccurrences(of: "9007199254740993", with: "9007199254740992")
    try reject33(inlineChild, rounded, .changedConstraint, childPath + ["properties","n","maximum"])
    let added = ##"{"type":"object","properties":{"child":{"$ref":"#/$defs/Child"}},"required":["child"],"additionalProperties":false,"$defs":{"Child":{"type":"object","properties":{"n":{"type":"integer","maximum":9007199254740993}},"required":["n"],"additionalProperties":false,"title":"Child","x-order":["n"]}},"title":"Root","x-order":["child"]}"##
    let result = try prove33(inlineChild, added).result
    #expect(result.additions.count == 4)
    #expect(result.additions.contains(childPath + ["title"]))
    let badOrder = added.replacingOccurrences(of: #""x-order":["n"]"#, with: #""x-order":["missing"]"#)
    try reject33(inlineChild, badOrder, .unsupportedShape, childPath + ["x-order"])
    let unknown = added.replacingOccurrences(of: #""title":"Child""#, with: #""title":"Child","format":"email""#)
    try reject33(inlineChild, unknown, .unsupportedDeclaration, childPath + ["format"])
}

@Test func jf33CumulativeBudgetBoundary() throws {
    let original = try doc33(inlineChild)
    let baseline = try JF3SchemaBoundary.project(Hoisted33.self, document: original, policy: .allowStructuralEquivalence, limits: .balanced)
    var limits = JSONLimits.balanced
    limits[.workUnits] = baseline.statistics[.workUnits]
    limits[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try JF3SchemaBoundary.project(Hoisted33.self, document: original, policy: .allowStructuralEquivalence, limits: limits).statistics == baseline.statistics)
    var less = limits; less[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { try JF3SchemaBoundary.project(Hoisted33.self, document: original, policy: .allowStructuralEquivalence, limits: less) }
    less = limits; less[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try JF3SchemaBoundary.project(Hoisted33.self, document: original, policy: .allowStructuralEquivalence, limits: less) }
}

@Test func jf33CancellationDuringProof() async throws {
    let a = try doc33(inlineChild), b = try doc33(hoistedChild)
    let task = Task {
        try JSON.withComposition { scope in
            let x = try scope.admitTrusted(a.raw), y = try scope.admitTrusted(b.raw)
            return try scope.withMeter { meter in
                meter.checkpointObserver = { _ in withUnsafeCurrentTask { $0?.cancel() } }
                _ = try JF33StructuralProof.verify(x, y, meter: &meter)
                return true
            }
        }.result
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels
private struct Corpus33: Decodable {
    let reverse: [Vector]
    let outside: [Outside]
    struct Vector: Decodable {
        let id: String; let schema: String; let cases: [Instance]
    }
    struct Instance: Decodable {
        let source: String; let valid: Bool
    }
    struct Outside: Decodable {
        let id: String; let schema: String; let issue: String; let path: [String]
    }
}
private func corpus33() throws -> Corpus33 {
    guard let url = Bundle.module.url(forResource: "ReverseMatrix", withExtension: "json") else {
        throw Matrix33Error.missingFixture
    }
    return try JSONValueDecoder().decode(Corpus33.self, from: JSONParser().parse(Data(contentsOf: url)))
}
private struct Result33: Encodable {
    let id: String; let outcome: String
    var schema: String? = nil
    var verdicts: [Bool]? = nil
    var additions: [[String]]? = nil
    var rewrites: [Rewrite33]? = nil
    var issue: String? = nil
    var path: [String]? = nil
}
private func emit33(_ label: String, _ row: Result33) throws {
    print("JF33_\(label) \(try JSONWriter().writeString(JSONValueEncoder().encode(row)))")
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf33AppleStructuralMatrix() throws {
    let bridge = JSONGenerationSchemaBridge()
    let corpus = try corpus33()
    #expect(corpus.reverse.count == 19)
    for vector in corpus.reverse {
        let original = try doc33(vector.schema)
        do {
            let report = try bridge.projectWithReport(original, metadata: .allowStructuralEquivalence)
            let value = report.result
            #expect(vector.id != "precise-decimal-bound")
            #expect(report.statistics[.workUnits] > 0)
            #expect(try JSONComparison.equals(original.raw, value.canonical.document.raw))
            let raw = try JSONValueEncoder().encode(value.schema)
            #expect(try JSONComparison.equals(raw, value.roundtripped.raw))
            let returned = try JSONSchemaCompiler().compile(value.roundtripped)
            var verdicts: [Bool] = []
            for test in vector.cases {
                let instance = try JSONParser().parse(test.source)
                #expect(try value.canonical.validate(instance).isValid == test.valid)
                let actual = try returned.validate(instance).isValid
                #expect(actual == test.valid)
                verdicts.append(actual)
            }
            try emit33("MATRIX", .init(id: vector.id, outcome: "accepted", schema: JSONWriter().writeString(raw),
                verdicts: verdicts, additions: value.additions.map { try names33($0.path) }, rewrites: value.rewrites.map(Rewrite33.init)))
        } catch let error as JSONGenerationSchemaFailure {
            #expect(vector.id == "precise-decimal-bound", "\(vector.id)")
            #expect(error.issue == .changedConstraint)
            #expect(try names33(error.path) == ["properties","n","minimum"])
            try emit33("MATRIX", .init(id: vector.id, outcome: "rejected", issue: error.issue.rawValue, path: names33(error.path)))
        }
    }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf33AppleOutsideProfile() throws {
    let bridge = JSONGenerationSchemaBridge()
    for fixture in try corpus33().outside {
        let original = try doc33(fixture.schema)
        _ = try JSONSchemaCompiler().compile(original)
        do {
            _ = try bridge.project(original, metadata: .allowStructuralEquivalence)
            Issue.record("Expected unchanged canonical profile rejection: \(fixture.id)")
        } catch let error as JSONGenerationSchemaFailure {
            #expect(error.issue.rawValue == fixture.issue)
            #expect(try names33(error.path) == fixture.path)
            try emit33("OUTSIDE", .init(id: fixture.id, outcome: "rejected", issue: error.issue.rawValue, path: names33(error.path)))
        }
    }
}
#endif
