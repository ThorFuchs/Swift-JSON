// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import Testing
@testable import JSONFoundationModels

private let textSchema = #"{"type":"object","properties":{"q":{"type":"string"},"note":{"type":"string"}},"required":["q"],"additionalProperties":false}"#
private let numberSchema = #"{"type":"object","properties":{"n":{"type":"integer"}},"required":["n"],"additionalProperties":false}"#
private let good = #"{"q":"test"}"#
private let invalid = #"{"q":"test","note":null}"#
private func parse4(_ text: String) throws -> JSON { try JSONParser().parse(text) }
private func plan4(_ text: String = textSchema) throws -> CompiledJSONSchema {
    try JSONSchemaCompiler().compile(JSONSchemaDocument(parse4(text)))
}
private func invalid4(_ work: () throws -> Void) throws {
    do { try work(); Issue.record("Expected invalidArguments") }
    catch let failure as JSONGenerationArgumentFailure {
        guard case .invalidArguments(let result) = failure else {
            Issue.record("Wrong argument failure"); return
        }
        #expect(!result.isValid && result.diagnosticsComplete)
        #expect(!result.issues.isEmpty)
    }
}
private func changed4(_ work: () throws -> Void) throws {
    do { try work(); Issue.record("Expected typedValueChanged") }
    catch let failure as JSONGenerationArgumentFailure {
        guard case .typedValueChanged = failure else { Issue.record("Wrong argument failure"); return }
    }
}

@Test func jf4ValidatedExportBeforeForeignCallback() throws {
    let plan = try plan4()
    let value = try parse4(good)
    let report = try JF4ArgumentBoundary.export(value, plan: plan, limits: .balanced, make: { $0 }, read: { $0 })
    #expect(try JSONComparison.equals(value, parse4(report.result)))
    #expect(report.statistics[.workUnits] > 0)
    try invalid4 {
        _ = try JF4ArgumentBoundary.export(parse4(invalid), plan: plan, limits: .balanced, make: { text in
            Issue.record("Invalid input reached foreign constructor"); return text
        }, read: { text in Issue.record("Invalid input reached foreign reader"); return text })
    }
}

@Test func jf4ValidatedImportRejectsInvalidIncompleteMalformed() throws {
    let plan = try plan4()
    let report = try JF4ArgumentBoundary.importValue(good, plan: plan, limits: .balanced, read: { $0 })
    #expect(try JSONComparison.equals(report.result, parse4(good)))
    try invalid4 {
        _ = try JF4ArgumentBoundary.importValue(invalid, plan: plan, limits: .balanced, read: { $0 })
    }
    #expect(throws: JSONGeneratedContentBridgeFailure.incompleteContent) {
        try JF4ArgumentBoundary.importValue(good, plan: plan, limits: .balanced, read: { _ in
            throw JSONGeneratedContentBridgeFailure.incompleteContent
        })
    }
    #expect(throws: JSONFailure.self) {
        try JF4ArgumentBoundary.importValue("{}", plan: plan, limits: .balanced, read: { _ in "{}{}" })
    }
}

@Test func jf4TypedRoundtripAndValidationOrdering() throws {
    let plan = try plan4(), value = try parse4(good)
    let result = try JF4ArgumentBoundary.decodeJSON(value, plan: plan, limits: .balanced,
        make: { $0 }, read: { $0 }, decode: { $0 }, render: { $0 })
    #expect(try JSONComparison.equals(value, parse4(result.result)))
    let imported = try JF4ArgumentBoundary.decodeContent(good, plan: plan, limits: .balanced,
        read: { $0 }, decode: { $0 }, render: { $0 })
    #expect(try JSONComparison.equals(value, parse4(imported.result)))
    try invalid4 {
        _ = try JF4ArgumentBoundary.decodeContent(invalid, plan: plan, limits: .balanced, read: { $0 },
            decode: { text in Issue.record("Invalid input reached typed initializer"); return text },
            render: { text in Issue.record("Invalid input reached renderer"); return text })
    }
}

@Test func jf4RejectsChangedTypedValuesEvenIfValid() throws {
    let plan = try plan4(), value = try parse4(good)
    for changed in [#"{"q":"other"}"#, #"{"q":"test","note":"added"}"#] {
        try changed4 {
            _ = try JF4ArgumentBoundary.decodeJSON(value, plan: plan, limits: .balanced,
                make: { $0 }, read: { $0 }, decode: { _ in changed }, render: { $0 })
        }
        try changed4 {
            _ = try JF4ArgumentBoundary.decodeContent(good, plan: plan, limits: .balanced,
                read: { $0 }, decode: { _ in changed }, render: { $0 })
        }
    }
    let reordered = #"{"note":"ok","q":"test"}"#
    let result = try JF4ArgumentBoundary.decodeContent(#"{"q":"test","note":"ok"}"#,
        plan: plan, limits: .balanced, read: { $0 }, decode: { _ in reordered }, render: { $0 })
    #expect(result.result == reordered)
}

@Test func jf4EncodeValidatesTypedRepresentation() throws {
    let plan = try plan4()
    let report = try JF4ArgumentBoundary.encode(good, plan: plan, limits: .balanced, render: { $0 }, read: { $0 })
    #expect(try JSONComparison.equals(report.result, parse4(good)))
    try invalid4 {
        _ = try JF4ArgumentBoundary.encode(invalid, plan: plan, limits: .balanced, render: { $0 }, read: { $0 })
    }
}

@Test func jf4SchemaValidDoesNotWaiveValueFidelity() throws {
    let plan = try plan4(numberSchema)
    let value = try parse4(#"{"n":9007199254740993}"#)
    #expect(try plan.validate(value).isValid)
    #expect(throws: JSONGeneratedContentBridgeFailure.changedValue) {
        try JF4ArgumentBoundary.decodeJSON(value, plan: plan, limits: .balanced,
            make: { _ in #"{"n":9007199254740992}"# }, read: { $0 },
            decode: { text in Issue.record("Changed value reached typed initializer"); return text }, render: { $0 })
    }
}

@Test func jf4CumulativeTypedBudgetBoundary() throws {
    let plan = try plan4(), value = try parse4(good)
    func run(_ limits: JSONLimits) throws -> JSONOperationReport<String> {
        try JF4ArgumentBoundary.decodeJSON(value, plan: plan, limits: limits,
            make: { $0 }, read: { $0 }, decode: { $0 }, render: { $0 })
    }
    let baseline = try run(.balanced)
    var limits = JSONLimits.balanced
    limits[.workUnits] = baseline.statistics[.workUnits]
    limits[.retainedBytes] = baseline.statistics.peakLogicalRetainedBytes
    #expect(try run(limits).statistics == baseline.statistics)
    var less = limits; less[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { try run(less) }
    less = limits; less[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try run(less) }
}

@Test func jf4CancellationAfterTypedCallback() async throws {
    let plan = try plan4(), value = try parse4(good)
    let task = Task {
        try JF4ArgumentBoundary.decodeJSON(value, plan: plan, limits: .balanced,
            make: { $0 }, read: { $0 }, decode: { text in
                withUnsafeCurrentTask { $0?.cancel() }; return text
            }, render: { text in Issue.record("Cancelled typed conversion rendered"); return text })
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}
