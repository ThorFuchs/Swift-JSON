// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONSchemaOptions: Sendable {
    public var limits: JSONLimits
    public var formatAssertion: Bool
    public var output: JSONValidationOutput
    public var diagnosticPolicy: JSONValidationDiagnosticPolicy
    public var collectAnnotations: Bool
    public init(limits: JSONLimits = .balanced, formatAssertion: Bool = false, output: JSONValidationOutput = .basic, diagnosticPolicy: JSONValidationDiagnosticPolicy = .complete, collectAnnotations: Bool = false) {
        self.limits = limits; self.formatAssertion = formatAssertion; self.output = output
        self.diagnosticPolicy = diagnosticPolicy; self.collectAnnotations = collectAnnotations
    }
}
