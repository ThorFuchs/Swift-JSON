// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema

func qualifySyntax(_ input: VerifiedSuite) throws -> SuiteReceipt {
    var report = input.receipt()
    let files = input.files.filter { $0.hasPrefix("test_parsing/") && $0.hasSuffix(".json") }.sorted()
    guard files.count == input.expected else { throw HarnessFailure("Syntax fixture discovery count mismatch") }
    for path in files {
        let name = URL(fileURLWithPath: path).lastPathComponent
        let duplicate = name == "y_object_duplicated_key.json" || name == "y_object_duplicated_key_and_value.json"
        do {
            _ = try JSONParser().parse(Data(contentsOf: input.root.appendingPathComponent(path)))
            report.append(path, name.hasPrefix("n_") || duplicate ? "failed" : "accepted")
        } catch let failure as JSONFailure {
            let depthPolicy = (name == "n_structure_100000_opening_arrays.json" || name == "n_structure_open_array_object.json") && failure.category == .resource && failure.resource?.metric == .maxDepth
            let policy = name.hasPrefix("i_") || duplicate || depthPolicy
            let correct = !name.hasPrefix("y_") || duplicate
            // Only implementation-defined number limits can be operational policy outcomes.
            let resourcePolicy = (name.hasPrefix("i_") && failure.category == .resource) || depthPolicy
            report.append(path, !correct || (failure.category == .resource && !resourcePolicy) ? "failed" : policy ? "expected_policy" : "rejected", reason: errorCode(failure))
        }
    }
    return report
}

func qualifySchema(_ input: VerifiedSuite, root: URL) throws -> SuiteReceipt {
    var report = input.receipt()
    let selections = try loadValue(root.appendingPathComponent("Tests/Fixtures/Schema/ResourceSelection.json"))
    let policies = try loadValue(root.appendingPathComponent("Documentation/Qualification/Evidence/SchemaMilestone/schema-policy-exceptions.json"))
    guard try selections["suite_commit"].text() == input.commit, try policies["suite_commit"].text() == input.commit else { throw HarnessFailure("Schema selection/policy pin mismatch") }
    var policyByID: [String: (String,String)] = [:]
    for record in try policies["cases"].array() {
        let id = try record["file"].text() + ":" + String(record["group"].integer()) + ":" + String(record["test"].integer())
        guard policyByID[id] == nil else { throw HarnessFailure("Duplicate policy entry") }
        policyByID[id] = (try record["description"].text(), try record["reason"].text())
    }
    guard policyByID.count == (try policies["policy_cases"].integer()) else { throw HarnessFailure("Policy count mismatch") }
    var resourcesByGroup: [String: [String]] = [:]
    for record in try selections["groups"].array() {
        let key = try record["file"].text() + ":" + String(record["group"].integer())
        guard resourcesByGroup[key] == nil else { throw HarnessFailure("Duplicate group selection") }
        resourcesByGroup[key] = try record["resources"].array().map { try $0.text() }
    }
    var visitedPolicies = Set<String>(), visitedGroups = Set<String>()
    let files = input.files.filter { $0.hasPrefix("tests/draft2020-12/") && $0.hasSuffix(".json") }.sorted()
    guard !files.isEmpty else { throw HarnessFailure("Missing Draft 2020-12 cases") }
    for file in files {
        for (groupIndex, group) in try loadValue(input.root.appendingPathComponent(file)).array().enumerated() {
            let groupID = file + ":" + String(groupIndex)
            guard let resources = resourcesByGroup[groupID] else { throw HarnessFailure("Missing explicit resource selection: " + groupID) }
            visitedGroups.insert(groupID)
            let cases = try group["tests"].array()
            guard !cases.isEmpty else { throw HarnessFailure("Empty schema test group") }
            var executable: [(String,JSON)] = []
            for (index, test) in cases.enumerated() {
                let id = groupID + ":" + String(index)
                if let policy = policyByID[id] {
                    guard policy.0 == (try test["description"].text()) else { throw HarnessFailure("Policy case identity mismatch") }
                    visitedPolicies.insert(id); report.append(id, "expected_policy", reason: policy.1)
                } else { executable.append((id,test)) }
            }
            if executable.isEmpty { continue }
            do {
                let documents = try resources.map { path -> JSONSchemaDocument in
                    guard input.files.contains(path), path.hasPrefix("remotes/") else { throw HarnessFailure("Unpinned remote resource") }
                    return try JSONSchemaDocument(loadValue(input.root.appendingPathComponent(path)), retrievalURI: JSONSchemaURI("http://localhost:1234/" + path.dropFirst("remotes/".count)))
                }
                let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(group["schema"]), registry: JSONSchemaRegistry(documents: documents))
                let validator = JSONSchemaValidator(options: .init(formatAssertion: file.contains("/optional/format/"), output: .flag))
                for (id, test) in executable {
                    do {
                        let valid = try validator.validate(test["data"], against: plan).isValid
                        report.append(id, valid == (try test["valid"].bool()) ? "evaluated" : "failed")
                    } catch { report.append(id, "failed", reason: errorCode(error)) }
                }
            } catch { for (id,_) in executable { report.append(id, "failed", reason: errorCode(error)) } }
        }
    }
    guard visitedPolicies.count == policyByID.count, visitedGroups.count == resourcesByGroup.count else { throw HarnessFailure("Orphan schema policy/resource selection") }
    return report
}
