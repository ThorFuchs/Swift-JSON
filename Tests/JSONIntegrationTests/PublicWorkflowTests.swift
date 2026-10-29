// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
import JSON
import JSONSchema
import JSONPatch
import JSONStreaming

// Test-application state is deliberately outside the library. No private imports.
private let input = #"{"id":9007199254740993,"amount":1.2300,"label":"entry","optional":null,"é":1,"é":2}"#
private let golden = #"{"id":9007199254740993,"amount":1.2300,"label":"updated","é":1,"é":2,"ready":true}"#
private struct Entry: Codable, Equatable, Sendable { let id: Int64; let label: String }
private func plan() throws -> CompiledJSONSchema {
    let raw = try JSONParser().parse(#"{"type":"object","properties":{"id":{"type":"integer","minimum":9007199254740993},"label":{"type":"string","pattern":"^[a-z]+$"}},"required":["id","label"]}"#)
    return try JSONSchemaCompiler().compile(JSONSchemaDocument(raw))
}
private func edited(_ value: JSON) throws -> JSON {
    let patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/label"), value: "updated")])
    guard case .document(let staged) = try patch.applying(to: value) else { throw AppError.removed }
    return try JSONMergePatch(JSONParser().parse(#"{"optional":null,"ready":true}"#)).applying(to: staged)
}
private enum AppError: Error, Equatable { case removed, source, sink, terminated, accounting, invalid }
private actor Output {
    var bytes: [UInt8] = [], calls = 0
    let rejectAt: Int?, cancelAt: Int?
    init(rejectAt: Int? = nil, cancelAt: Int? = nil) { self.rejectAt = rejectAt; self.cancelAt = cancelAt }
    func accept(_ chunk: JSONByteChunk) throws {
        calls += 1
        if calls == rejectAt { throw AppError.sink }
        bytes.append(contentsOf: chunk.bytes)
        // Test-only current-task handle stays inside its standard-library callback.
        // Only this invocation is cancelled; no unsafe handle escapes or is shared.
        if calls == cancelAt { unsafe withUnsafeCurrentTask { unsafe $0?.cancel() } }
    }
    func snapshot() -> ([UInt8], Int) { (bytes, calls) }
}

@Test func qaE2EExactWorkflowHasIndependentGoldenOutput() async throws {
    let parsed = try JSONParser().parseWithReport(Array(input.utf8))
    let read = try parsed.result.readWithReport { root in
        #expect(try root.presence(of: "missing") == .absent)
        #expect(try root.presence(of: "optional") == .null)
        #expect(try root["amount"].requiredNumber().originalLexeme == "1.2300")
        #expect(try root["é"].requiredInteger(as: Int.self) == 1)
        #expect(try root[JSONKey("e\u{301}")].requiredInteger(as: Int.self) == 2)
        return try root.decode(Entry.self)
    }
    #expect(read.result == Entry(id: 9007199254740993, label: "entry"))
    let checked = try JSONSchemaValidator().validateWithReport(parsed.result, against: plan())
    #expect(checked.result.isValid && checked.statistics[.aggregateRegexWorkUnits] > 0)
    let result = try edited(parsed.result), sink = Output()
    let written = try await JSONAsyncWriter(options: .init(numberStyle: .preserved), chunkSize: 7)
        .writeWithReport(result) { try await sink.accept($0) }
    let (bytes, calls) = await sink.snapshot()
    #expect(bytes == Array(golden.utf8) && calls == (bytes.count + 6) / 7)
    #expect(written[.outputBytes] == UInt64(golden.utf8.count))
    #expect(try JSONParser().parse(bytes) == result)
    for stats in [parsed.statistics, read.statistics, checked.statistics, written] {
        #expect(stats.accountingVersion == 1 && stats[.workUnits] > 0)
        #expect(stats.peakLogicalRetainedBytes > 0)
    }
}

@Test func qaE2EVersionOneEnvelopePreservesExactInnerState() throws {
    let value = try JSONParser().parse(input), payload = try JSONCodablePayload(preserving: value)
    let envelope = try JSONValueEncoder().encode(payload)
    #expect(envelope.objectValue?["format"] == "swift-json-value")
    #expect(envelope.objectValue?["version"] == 1)
    let opened = try JSONValueDecoder().decode(JSONCodablePayload.self, from: envelope).value()
    #expect(try JSONWriter(options: .init(numberStyle: .preserved)).write(opened) == Data(input.utf8))
    #expect(opened.objectValue?.members.map { Array($0.key.string.utf8) } == value.objectValue?.members.map { Array($0.key.string.utf8) })
    #expect(try opened.presence(of: "missing") == .absent && opened.presence(of: "optional") == .null)
    #expect(try JSONWriter(options: .init(numberStyle: .preserved)).write(edited(opened)) == Data(golden.utf8))
}

@Test func qaE2EUnknownEnvelopeVersionIsCorruption() throws {
    let payload = try JSONCodablePayload(preserving: JSONParser().parse(input))
    let encoded = try JSONValueEncoder().encode(payload)
    let changed = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/version"), value: 2)])
    guard case .document(let invalid) = try changed.applying(to: encoded) else { throw AppError.removed }
    do { _ = try JSONValueDecoder().decode(JSONCodablePayload.self, from: invalid); Issue.record("Accepted an unknown envelope version") }
    catch DecodingError.dataCorrupted(let context) { #expect(context.codingPath.isEmpty) }
}

@Test func qaE2ESharedPlanRecoversAfterIndependentFailures() async throws {
    let shared = try plan()
    let outcomes = try await withThrowingTaskGroup(of: Int.self) { group in
        for index in 0..<24 {
            group.addTask {
                switch index % 3 {
                case 0:
                    let result = try JSONSchemaValidator().validate(JSONParser().parse(input), against: shared)
                    #expect(result.isValid); return 0
                case 1:
                    let result = try JSONSchemaValidator().validate(JSONParser().parse(#"{"id":1,"label":"UPPER"}"#), against: shared)
                    #expect(!result.isValid && !result.issues.isEmpty); return 1
                default:
                    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 0
                    do { _ = try JSONSchemaValidator(options: .init(limits: limits)).validate("entry", against: shared); Issue.record("Operational exhaustion became a verdict") }
                    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .evaluationWorkUnits) }
                    return 2
                }
            }
        }
        var values: [Int] = []; for try await value in group { values.append(value) }; return values
    }
    #expect(outcomes.filter { $0 == 0 }.count == 8 && outcomes.filter { $0 == 1 }.count == 8 && outcomes.filter { $0 == 2 }.count == 8)
    #expect(try JSONSchemaValidator().validate(JSONParser().parse(input), against: shared).isValid)
}

@Test func qaE2EOfflineReferenceRequiresExplicitRegistry() throws {
    let resource = try JSONSchemaDocument(JSONParser().parse(#"{"type":"integer","minimum":7}"#), retrievalURI: JSONSchemaURI("urn:acceptance:item"))
    let root = try JSONSchemaDocument(JSONParser().parse(#"{"$ref":"urn:acceptance:item"}"#))
    do { _ = try JSONSchemaCompiler().compile(root); Issue.record("Resolved an unsupplied resource") }
    catch let failure as JSONSchemaCompilationFailure { #expect(failure.category == .missingResource) }
    let registry = try JSONSchemaRegistry(documents: [resource])
    let shared = try JSONSchemaCompiler().compile(root, registry: registry)
    #expect(try JSONSchemaValidator().validate(7, against: shared).isValid)
    #expect(try !JSONSchemaValidator().validate(6, against: shared).isValid)
}

// Carries only owned instruction buckets. Per-stage shapes and live capacities stay finite.
private struct Account {
    static let buckets: [JSONResourceMetric] = [.workUnits, .numericWorkUnits, .compileWorkUnits, .evaluationWorkUnits, .regexCompileWorkUnits, .aggregateRegexWorkUnits, .patchWorkUnits, .totalWorkUnits]
    var limits: JSONLimits
    var terminal = false, reports: [JSONOperationStatistics] = []
    mutating func perform<T>(_ operation: (JSONLimits) throws -> JSONOperationReport<T>) throws -> T {
        guard !terminal else { throw AppError.terminated }
        do {
            let report = try operation(limits)
            guard report.statistics.accountingVersion == 1 else { throw AppError.accounting }
            var next = limits
            for metric in Self.buckets {
                let (remaining, overflow) = next[metric].subtractingReportingOverflow(report.statistics[metric])
                guard !overflow else { throw AppError.accounting }; next[metric] = remaining
            }
            limits = next; reports.append(report.statistics); return report.result
        } catch { terminal = true; throw error }
    }
}
private func composition(_ account: inout Account, shared: CompiledJSONSchema) throws -> Data {
    let value = try account.perform { try JSONParser(options: .init(limits: $0)).parseWithReport(Array(input.utf8)) }
    let valid = try account.perform { try JSONSchemaValidator(options: .init(limits: $0)).validateWithReport(value, against: shared) }
    guard valid.isValid else { throw AppError.invalid }
    let patch = JSONMergePatch(try JSONParser().parse(#"{"optional":null,"ready":true}"#))
    let output = try account.perform { try patch.applyingWithReport(to: value, options: .init(limits: $0)) }
    return try account.perform { try JSONWriter(options: .init(limits: $0, numberStyle: .preserved)).writeWithReport(output) }
}
@Test func qaE2ECumulativeWorkSucceedsAtNAndFailsAtNMinusOne() throws {
    let shared = try plan(); var measure = Account(limits: .balanced)
    let bytes = try composition(&measure, shared: shared)
    let total = measure.reports.reduce(UInt64(0)) { $0 + $1[.workUnits] }
    #expect(total > 0 && measure.reports.count == 4)
    var exact = JSONLimits.balanced; exact[.workUnits] = total
    var success = Account(limits: exact)
    #expect(try composition(&success, shared: shared) == bytes)
    #expect(success.limits[.workUnits] == 0 && !success.terminal)
    #expect(success.limits[.evaluationWorkUnits] == exact[.evaluationWorkUnits] - measure.reports[1][.evaluationWorkUnits])
    #expect(success.limits[.patchWorkUnits] == exact[.patchWorkUnits] - measure.reports[2][.patchWorkUnits])
    exact[.workUnits] = total - 1; var failed = Account(limits: exact)
    do { _ = try composition(&failed, shared: shared); Issue.record("N-1 succeeded") }
    catch let error as JSONFailure { #expect(error.category == .resource && error.resource?.metric == .workUnits && error.resource?.limit == failed.limits[.workUnits]) }
    #expect(failed.terminal && failed.reports.count == 3)
    let retained = failed.limits[.workUnits]
    do { _ = try failed.perform { try JSONParser(options: .init(limits: $0)).parseWithReport([48]) }; Issue.record("Restarted failed composition") }
    catch { #expect(error as? AppError == .terminated) }
    #expect(failed.limits[.workUnits] == retained && failed.reports.count == 3)
}

@Test func qaE2EPatchRollbackRootAbsenceAndMergeNullRemainDistinct() throws {
    let original = try JSONParser().parse(input)
    let patch = try JSONPatch(operations: [.replace(path: JSONPointer(parsing: "/label"), value: "changed"), .test(path: JSONPointer(parsing: "/id"), value: 0)])
    do { _ = try patch.applying(to: original); Issue.record("Failed Patch published a result") }
    catch let failure as JSONFailure { #expect(failure.category == .patch && failure.code == .failedTest) }
    #expect(try JSONWriter(options: .init(numberStyle: .preserved)).write(original) == Data(input.utf8))
    let root = try JSONPointer(parsing: "")
    #expect(try JSONPatch(operations: [.remove(path: root)]).applying(to: original) == .removed)
    #expect(try JSONMergePatch(.null).applying(to: original) == .null)
    #expect(try JSONPatch(operations: [.remove(path: root), .add(path: root, value: 7)]).applying(to: original) == .document(7))
}

@Test func qaE2EBuiltinRegistryHasAllPinnedOfflineIdentities() throws {
    let registry = try JSONSchemaRegistry.draft2020_12()
    let expected = ["schema", "meta/applicator", "meta/content", "meta/core", "meta/format-annotation", "meta/format-assertion", "meta/meta-data", "meta/unevaluated", "meta/validation"]
    #expect(registry.documents.map { $0.retrievalURI?.string } == expected.map { "https://json-schema.org/draft/2020-12/" + $0 })
    #expect(registry.documents.count == 9 && registry.documents.allSatisfy { $0.raw.objectValue != nil })
}

@Test func qaE2EAwaitedSinkFailureNeverCertifiesAcceptedPrefix() async throws {
    let sink = Output(rejectAt: 2)
    var report: JSONOperationStatistics?
    do { report = try await JSONAsyncWriter(chunkSize: 2).writeWithReport(.array([1,2,3])) { try await sink.accept($0) }; Issue.record("Sink refusal returned accounting") }
    catch { #expect(error as? AppError == .sink) }
    let (bytes, calls) = await sink.snapshot()
    #expect(bytes == Array("[1".utf8) && calls == 2 && report == nil)
}
@Test func qaE2EAwaitedSinkCancellationKeepsOnlyAcceptedBytes() async {
    // Final full-chunk acceptance is a distinct cancellation fault point: there
    // may be no later byte reservation to detect it on the writer's behalf.
    for (value, size, cancelAt, prefix) in [(JSON.array([1,2,3]), 2, 2, "[1,2"), (JSON.number(.init(integer: 7)), 1, 1, "7")] {
        let sink = Output(cancelAt: cancelAt)
        let error = await Task { () -> (any Error)? in
            do { _ = try await JSONAsyncWriter(chunkSize: size).writeWithReport(value) { try await sink.accept($0) }; return nil }
            catch { return error }
        }.value
        let (bytes, calls) = await sink.snapshot()
        #expect(error is CancellationError && bytes == Array(prefix.utf8) && calls == cancelAt)
    }
}
@Test func qaE2EAnnotationsFromFailedBranchesDoNotAuthorizeProperties() throws {
    let raw = try JSONParser().parse(#"{"anyOf":[{"properties":{"a":{"const":1}},"required":["a"]},{"properties":{"b":{"const":2}},"required":["b"]}],"unevaluatedProperties":false}"#)
    let shared = try JSONSchemaCompiler().compile(JSONSchemaDocument(raw))
    let validator = JSONSchemaValidator(options: .init(collectAnnotations: true))
    #expect(try validator.validate(JSONParser().parse(#"{"a":1}"#), against: shared).isValid)
    #expect(try validator.validate(JSONParser().parse(#"{"b":2}"#), against: shared).isValid)
    let invalid = try validator.validate(JSONParser().parse(#"{"a":0,"b":2}"#), against: shared)
    #expect(!invalid.isValid && invalid.issues.contains { $0.instanceLocation == (try? JSONPointer(parsing: "/a")) && $0.keywordLocation == (try? JSONPointer(parsing: "/unevaluatedProperties")) })
    // A failed branch can still have successfully evaluated children. Their
    // annotations must not authorize a sibling branch's unevaluated properties.
    let failedParent = try JSONParser().parse(#"{"anyOf":[{"properties":{"a":true},"required":["missing"]},{"properties":{"b":true},"required":["b"]}],"unevaluatedProperties":false}"#)
    let failedPlan = try JSONSchemaCompiler().compile(JSONSchemaDocument(failedParent))
    let failedResult = try validator.validate(JSONParser().parse(#"{"a":1,"b":2}"#), against: failedPlan)
    #expect(!failedResult.isValid)
    #expect(failedResult.issues.contains { $0.instanceLocation == (try? JSONPointer(parsing: "/a")) && $0.keywordLocation == (try? JSONPointer(parsing: "/unevaluatedProperties")) })

}

@Test func qaE2EExactScalarAndIntegerConstraintsRejectNearMatches() throws {
    let shared = try plan()
    #expect(try !JSONSchemaValidator().validate(JSONParser().parse(#"{"id":9007199254740993.5,"label":"entry"}"#), against: shared).isValid)
    let original = try JSONParser().parse(#"{"text":"é"}"#)
    let patch = try JSONPatch(operations: [.test(path: JSONPointer(parsing: "/text"), value: "é")])
    do { _ = try patch.applying(to: original); Issue.record("Canonical-equivalent scalars passed exact Patch test") }
    catch let failure as JSONFailure { #expect(failure.category == .patch && failure.code == .failedTest) }
}
