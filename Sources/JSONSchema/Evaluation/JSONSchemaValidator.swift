// SPDX-License-Identifier: Apache-2.0
import JSON

public struct JSONSchemaValidator: Sendable {
    public let options: JSONSchemaOptions
    public init(options: JSONSchemaOptions = .init()) { self.options = options }
    public func validate(_ instance: JSON, against schema: CompiledJSONSchema) throws -> JSONValidationResult {
        try validateWithReport(instance, against: schema).result
    }
    public func validateWithReport(_ instance: JSON, against schema: CompiledJSONSchema) throws -> JSONOperationReport<JSONValidationResult> {
        var meter = try JSONWorkMeter(limits: options.limits, domain: .schemaEvaluation)
        try JSONAdmission.value(instance, meter: &meter)
        var evaluator = JSONSchemaEvaluation(plan: schema.plan, options: options)
        let result = try evaluator.evaluate(instance, at: schema.plan.root, meter: &meter)
        return .init(result: result, statistics: meter.statistics())
    }
}
