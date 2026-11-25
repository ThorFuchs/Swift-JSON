// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import Testing
@testable import JSONFoundationModels

private struct Matrix: Decodable {
    let reverse: [Vector]
    let outside: [Outside]
    struct Vector: Decodable {
        let id: String
        let schema: String
        let cases: [Instance]
        let anchor: String?
    }
    struct Instance: Decodable {
        let id: String
        let source: String
        let valid: Bool
    }
    struct Outside: Decodable {
        let id: String
        let schema: String
        let issue: String
        let path: [String]
    }
}

private enum MatrixError: Error { case missingFixture, unexpectedIndex, expectedRejection }
private func fixtures() throws -> Matrix {
    guard let url = Bundle.module.url(forResource: "ReverseMatrix", withExtension: "json") else {
        throw MatrixError.missingFixture
    }
    return try JSONValueDecoder().decode(Matrix.self, from: JSONParser().parse(Data(contentsOf: url)))
}
private func document(_ text: String) throws -> JSONSchemaDocument { try JSONSchemaDocument(JSONParser().parse(text)) }
private func keys(_ path: [JSONLocationComponent]) throws -> [String] {
    try path.map { component in
        guard case .key(let key) = component else { throw MatrixError.unexpectedIndex }
        return key.string
    }
}
private func verdicts(_ plan: CompiledJSONSchema, _ vector: Matrix.Vector) throws -> [Bool] {
    try vector.cases.map { try plan.validate(JSONParser().parse($0.source)).isValid }
}
private func emit<T: Encodable>(_ kind: String, _ record: T) throws {
    print("JF32_\(kind) \(try JSONWriter().writeString(JSONValueEncoder().encode(record)))")
}
private struct Rejection: Encodable {
    let id: String
    let issue: String
    let path: [String]
}
private func reject<T>(_ fixture: Matrix.Outside, _ body: () throws -> T) throws -> Rejection {
    do { _ = try body(); throw MatrixError.expectedRejection }
    catch let error as JSONGenerationSchemaFailure {
        let path = try keys(error.path)
        #expect(error.issue.rawValue == fixture.issue, "\(fixture.id)")
        #expect(path == fixture.path, "\(fixture.id)")
        return .init(id: fixture.id, issue: error.issue.rawValue, path: path)
    }
}

@Test func jf32CanonicalFixtures() throws {
    let matrix = try fixtures()
    #expect(matrix.reverse.count == 19)
    for vector in matrix.reverse {
        let doc = try document(vector.schema)
        let projected = try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .exact, limits: .balanced)
        #expect(projected.result.additions.isEmpty, "\(vector.id)")
        #expect(try JSONComparison.equals(doc.raw, projected.result.roundtripped.raw), "\(vector.id)")
        #expect(try JSONComparison.equals(doc.raw, projected.result.canonical.document.raw), "\(vector.id)")
        let actual = try verdicts(projected.result.canonical, vector)
        #expect(actual == vector.cases.map(\.valid), "\(vector.id)")
    }
}

@Test func jf32OutsideProfile() throws {
    let matrix = try fixtures()
    #expect(matrix.outside.count == 12)
    for fixture in matrix.outside {
        let doc = try document(fixture.schema)
        // These fixtures must be valid native schemas, not syntax/compilation failures.
        _ = try JSONSchemaCompiler().compile(doc)
        let result = try reject(fixture) {
            try JF3SchemaBoundary.project(JSON.self, document: doc, policy: .allowGeneratedAnnotations, limits: .balanced)
        }
        try emit("PORTABLE_REJECT", result)
    }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

// Diagnostics are fixed categories and reflected error TYPE names, not error descriptions.
private struct Attempt: Encodable {
    let outcome: String
    var schema: String? = nil
    var issue: String? = nil
    var path: [String]? = nil
    var additions: [[String]]? = nil
    var verdicts: [Bool]? = nil
    var errorType: String? = nil
}
private struct Observation: Encodable {
    let id: String
    let source: String
    let canonical: [Bool]
    let raw: Attempt
    let exact: Attempt
    let optIn: Attempt
}
private func errorType(_ error: any Error) -> String { String(reflecting: type(of: error)) }
private func isCodecError(_ error: any Error) -> Bool {
    error is DecodingError || error is EncodingError || errorType(error).hasPrefix("FoundationModels.")
}

@available(macOS 27.0, iOS 27.0, *)
private func rawAttempt(_ doc: JSONSchemaDocument, _ vector: Matrix.Vector) throws -> Attempt {
    let raw: JSON
    do {
        let schema = try JSONValueDecoder().decode(GenerationSchema.self, from: doc.raw)
        raw = try JSONValueEncoder().encode(schema)
    } catch {
        guard isCodecError(error) else { throw error }
        return .init(outcome: "codecRejected", errorType: errorType(error))
    }
    let text = try JSONWriter().writeString(raw)
    try emit("RAW", ["id": vector.id, "schema": text])
    let plan: CompiledJSONSchema
    do { plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw)) }
    catch let error as JSONSchemaCompilationFailure {
        return .init(outcome: "nativeInvalid", schema: text, errorType: errorType(error))
    }
    let actual = try verdicts(plan, vector)
    do {
        _ = try JSON.withComposition { scope in
            let admitted = try scope.admitTrusted(raw)
            try scope.withMeter { meter in try JF3SchemaProfile.check(admitted, meter: &meter) }
            return true
        }
    } catch let error as JSONGenerationSchemaFailure {
        return .init(outcome: "profileRejected", schema: text, issue: error.issue.rawValue,
                     path: try keys(error.path), verdicts: actual)
    }
    return .init(outcome: "returned", schema: text, verdicts: actual)
}

@available(macOS 27.0, iOS 27.0, *)
private func bridgeAttempt(_ doc: JSONSchemaDocument, _ vector: Matrix.Vector,
                           policy: JSONGenerationSchemaMetadataPolicy) throws -> Attempt {
    do {
        let result = try JSONGenerationSchemaBridge().projectWithReport(doc, metadata: policy)
        let value = result.result
        #expect(result.statistics[.workUnits] > 0)
        #expect(try JSONComparison.equals(doc.raw, value.canonical.document.raw), "\(vector.id)")
        #expect(try verdicts(value.canonical, vector) == vector.cases.map(\.valid), "\(vector.id)")
        let raw = try JSONValueEncoder().encode(value.schema)
        #expect(try JSONComparison.equals(raw, value.roundtripped.raw), "\(vector.id)")
        let returned = try JSONSchemaCompiler().compile(value.roundtripped)
        let actual = try verdicts(returned, vector)
        #expect(actual == vector.cases.map(\.valid), "\(vector.id)")
        return .init(outcome: "accepted", schema: try JSONWriter().writeString(raw),
                     additions: try value.additions.map { try keys($0.path) }, verdicts: actual)
    } catch let error as JSONGenerationSchemaFailure {
        return .init(outcome: "profileRejected", issue: error.issue.rawValue, path: try keys(error.path))
    } catch let error as JSONSchemaCompilationFailure {
        return .init(outcome: "nativeInvalid", errorType: errorType(error))
    } catch {
        guard isCodecError(error) else { throw error }
        return .init(outcome: "codecRejected", errorType: errorType(error))
    }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf32AppleReverseMatrix() throws {
    for vector in try fixtures().reverse {
        let doc = try document(vector.schema)
        let plan = try JSONSchemaCompiler().compile(doc)
        let canonical = try verdicts(plan, vector)
        #expect(canonical == vector.cases.map(\.valid), "\(vector.id)")
        let raw = try rawAttempt(doc, vector)
        let exact = try bridgeAttempt(doc, vector, policy: .exact)
        let optIn = try bridgeAttempt(doc, vector, policy: .allowGeneratedAnnotations)
        if vector.anchor == "exact" {
            #expect(exact.outcome == "accepted" && optIn.outcome == "accepted")
        } else if vector.anchor == "annotations" {
            #expect(exact.issue == "annotationAdditionDenied" && optIn.outcome == "accepted")
        }
        try emit("REVERSE", Observation(id: vector.id, source: vector.schema, canonical: canonical,
                                          raw: raw, exact: exact, optIn: optIn))
    }
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf32ApplePreflightRejections() throws {
    let bridge = JSONGenerationSchemaBridge()
    for fixture in try fixtures().outside {
        let doc = try document(fixture.schema)
        let exact = try reject(fixture) { try bridge.project(doc) }
        let optIn = try reject(fixture) { try bridge.project(doc, metadata: .allowGeneratedAnnotations) }
        try emit("APPLE_EXACT_REJECT", exact)
        try emit("APPLE_OPTIN_REJECT", optIn)
    }
}
#endif
