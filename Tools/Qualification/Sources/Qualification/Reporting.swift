// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

struct HarnessFailure: Error { let message: String; init(_ message: String) { self.message = message } }
func errorCode(_ error: any Error) -> String {
    if let error = error as? JSONFailure { return error.category.rawValue + ":" + error.code.rawValue + (error.resource.map { ":" + $0.metric.rawValue } ?? "") }
    if error is CancellationError { return "cancelled" }
    if let error = error as? HarnessFailure { return error.message }
    if let error = error as? JSONSchemaCompilationFailure { return "schemaCompilation:\(error.category)" }
    if let error = error as? JSONSchemaEvaluationFailure { return "schemaEvaluation:\(error.category)" }
    return String(describing: type(of: error))
}
// Fixture/provenance work is trusted harness work, outside owned library quotas.
private struct FixtureHashAccounting: JSONHashAccounting {
    mutating func hashWork(_ amount: UInt64) throws {}
    mutating func hashRetain(_ bytes: UInt64) throws {}
    mutating func hashRelease(_ bytes: UInt64) throws {}
    mutating func hashInput(_ bytes: UInt64) throws {}
}
func digest(_ bytes: Data) throws -> String {
    var accounting = FixtureHashAccounting()
    return try JSONSHA256Core.hexadecimal(bytes, accounting: &accounting)
}
func loadValue(_ url: URL) throws -> JSON { try JSONParser().parse(Data(contentsOf: url)) }
extension JSON {
    subscript(_ name: String) -> JSON { objectValue?[name] ?? .null }
    func text() throws -> String { guard let result = stringValue else { throw HarnessFailure("Expected fixture string") }; return result }
    func array() throws -> [JSON] { guard let result = arrayValue else { throw HarnessFailure("Expected fixture array") }; return result }
    func integer() throws -> Int { guard let number = numberValue else { throw HarnessFailure("Expected fixture integer") }; return try number.integer(as: Int.self) }
    func bool() throws -> Bool { guard let value = booleanValue else { throw HarnessFailure("Expected fixture boolean") }; return value }
}
struct CaseReceipt: Codable, Sendable {
    let id: String
    let outcome: String
    var reason: String? = nil
}
struct SuiteReceipt: Encodable, Sendable {
    let repository: String, commit: String, input_manifest_sha256: String
    let expected_cases: Int
    var observed_cases = 0, passed_cases = 0, policy_cases = 0, failed_cases = 0, unexpected_skips = 0
    var cases: [CaseReceipt] = []
    var status: String { failed_cases == 0 && observed_cases == expected_cases ? "passed" : "failed" }
    mutating func append(_ id: String, _ outcome: String, reason: String? = nil) {
        observed_cases += 1
        if outcome == "expected_policy" { policy_cases += 1 }
        else if outcome == "failed" { failed_cases += 1 }
        else { passed_cases += 1 }
        cases.append(.init(id: id, outcome: outcome, reason: reason))
    }
    enum CodingKeys: String, CodingKey { case repository, commit, input_manifest_sha256, expected_cases, observed_cases, passed_cases, policy_cases, failed_cases, unexpected_skips, cases, status }
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(repository, forKey: .repository); try c.encode(commit, forKey: .commit)
        try c.encode(input_manifest_sha256, forKey: .input_manifest_sha256); try c.encode(expected_cases, forKey: .expected_cases)
        try c.encode(observed_cases, forKey: .observed_cases); try c.encode(passed_cases, forKey: .passed_cases)
        try c.encode(policy_cases, forKey: .policy_cases); try c.encode(failed_cases, forKey: .failed_cases)
        try c.encode(unexpected_skips, forKey: .unexpected_skips); try c.encode(cases, forKey: .cases); try c.encode(status, forKey: .status)
    }
}
struct AuthoredReceipt: Codable, Sendable {
    let name: String
    var observed = 0, failed = 0
    var failures: [String] = []
    var seed: String? = nil
    var input_sha256: String? = nil
    mutating func check(_ condition: Bool, _ id: String) { observed += 1; if !condition { failed += 1; failures.append(id) } }
}
struct QualificationReport: Encodable, Sendable {
    let schema_version = 1
    let command: String
    let time_utc = ISO8601DateFormatter().string(from: Date())
    let environment = ["os": ProcessInfo.processInfo.operatingSystemVersionString, "architecture": qualificationArchitecture,
                       "swift_language": "6", "required_tools": "6.4", "resource_profile": "balanced", "logical_accounting_version": "1"]
    var status = "failed", suites: [SuiteReceipt] = [], authored: [AuthoredReceipt] = [], errors: [String] = []
    let runtime_network_access = false
}
private var qualificationArchitecture: String {
    #if arch(arm64)
    "arm64"
    #elseif arch(x86_64)
    "x86_64"
    #else
    "unqualified"
    #endif
}
struct VerifiedSuite {
    let root: URL, repository: String, commit: String, expected: Int, manifestHash: String
    let files: [String]
    init(_ entry: JSON, root repositoryRoot: URL) throws {
        repository = try entry["repository"].text(); commit = try entry["commit"].text(); expected = try entry["expected_cases"].integer()
        guard expected > 0, try entry["status"].text() == "imported" else { throw HarnessFailure("Suite missing or zero: " + repository) }
        root = try Self.path(try entry["fixture_path"].text(), relativeTo: repositoryRoot)
        let manifestURL = try Self.path(try entry["manifest"].text(), relativeTo: repositoryRoot)
        let bytes = try Data(contentsOf: manifestURL); manifestHash = try digest(bytes)
        let manifest = try JSONParser().parse(bytes)
        guard try manifest["commit"].text() == commit, try manifest["repository"].text() == repository, try manifest["expected_cases"].integer() == expected else { throw HarnessFailure("Suite manifest identity mismatch") }
        var paths: [String] = [], licenses = 0
        for record in try manifest["files"].array() {
            let path = try record["path"].text(), data = try Data(contentsOf: Self.path(path, relativeTo: root))
            guard try digest(data) == record["sha256"].text(), data.count == record["bytes"].integer() else { throw HarnessFailure("Fixture hash/size mismatch: " + path) }
            if try record["license"].bool() { licenses += 1 }
            paths.append(path)
        }
        guard !paths.isEmpty, licenses > 0, Set(paths).count == paths.count else { throw HarnessFailure("Empty/duplicate/unlicensed fixture manifest") }
        files = paths
    }
    static func path(_ path: String, relativeTo root: URL) throws -> URL {
        guard !path.hasPrefix("/"), !path.split(separator: "/").contains(".."), !path.isEmpty else { throw HarnessFailure("Invalid fixture path") }
        return root.appendingPathComponent(path)
    }
    func receipt() -> SuiteReceipt { .init(repository: repository, commit: commit, input_manifest_sha256: manifestHash, expected_cases: expected) }
}
