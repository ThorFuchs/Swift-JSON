// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

private func sameVerdict(_ a: JSONValidationResult, _ b: JSONValidationResult) throws {
    #expect(a.isValid == b.isValid && a.diagnosticsComplete == b.diagnosticsComplete)
    #expect(a.annotations.map(\.value) == b.annotations.map(\.value))
    #expect(a.annotations.map(\.instanceLocation) == b.annotations.map(\.instanceLocation))
    #expect(a.annotations.map(\.keywordLocation) == b.annotations.map(\.keywordLocation))
    #expect(try a.output() == b.output())
}

@Test func e2PlanValidationPreservesVerdictAnnotationsAndFormatPolicy() throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSON.parse(#"{"type":"string","format":"email","title":"address","minLength":2}"#)))
    for options in [JSONSchemaOptions(), .init(formatAssertion: true), .init(output: .flag), .init(collectAnnotations: true)] {
        for instance in [JSON.string("a"), "a@b.example", 42] {
            try sameVerdict(plan.validate(instance, options: options), JSONSchemaValidator(options: options).validate(instance, against: plan))
        }
    }
    #expect(try !plan.validate(42).isValid)
    #expect(try plan.validate("ab").isValid)
}

@Test func e2PlanValidationQuotasAndIncompleteDiagnosticsMatch() throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSON.parse(#"{"type":"object","required":["a","b"]}"#)))
    let instance = try JSON.parse("{}")
    for cap in 0...100 {
        var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = UInt64(cap)
        let options = JSONSchemaOptions(limits: limits)
        func failure(_ facade: Bool) throws -> JSONFailure? {
            do {
                let result = try facade ? plan.validate(instance, options: options) : JSONSchemaValidator(options: options).validate(instance, against: plan)
                #expect(!result.isValid)
                return nil
            } catch let error as JSONFailure { return error }
        }
        #expect(try failure(true) == failure(false))
    }
    var limits = JSONLimits.balanced; limits[.issues] = 0
    let options = JSONSchemaOptions(limits: limits, diagnosticPolicy: .bestEffort)
    let result = try plan.validate(instance, options: options)
    #expect(!result.isValid && !result.diagnosticsComplete)
    try sameVerdict(result, JSONSchemaValidator(options: options).validate(instance, against: plan))
    #expect(throws: JSONFailure.self) { try plan.validate(instance, options: .init(limits: limits)) }
}

@Test func e2PlanOperationalFailureAndCancellationNeverBecomeFalse() async throws {
    let cycle = try JSONSchemaCompiler().compileWithReport(JSON.parse(##"{"anyOf":[true,{"$ref":"#"}]}"##)).result
    #expect(throws: JSONSchemaEvaluationFailure.self) { try cycle.validate(.null) }
    #expect(throws: JSONSchemaEvaluationFailure.self) { try JSONSchemaValidator().validate(.null, against: cycle) }
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(true))
    let cancelled = await Task {
        withUnsafeCurrentTask { $0?.cancel() }
        #expect(throws: CancellationError.self) { try plan.validate(.null) }
        #expect(throws: CancellationError.self) { try JSONSchemaValidator().validate(.null, against: plan) }
        return true
    }.value
    #expect(cancelled)
}

@Test func e2SharedCompiledPlanFacadeHasIndependentInvocationState() async throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSON.parse(#"{"type":"string","pattern":"^a+$"}"#)))
    try await withThrowingTaskGroup(of: Bool.self) { group in
        for index in 0..<12 {
            group.addTask {
                let value: JSON = index.isMultiple(of: 2) ? "aaa" : "bbb"
                return try plan.validate(value).isValid == index.isMultiple(of: 2)
            }
        }
        for try await result in group { #expect(result) }
    }
}
