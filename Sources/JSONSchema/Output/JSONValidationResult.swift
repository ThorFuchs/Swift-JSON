// SPDX-License-Identifier: Apache-2.0
import JSON

public struct JSONEvaluationAnnotation: Sendable {
    public let instanceLocation: JSONPointer
    public let keywordLocation: JSONPointer
    public let absoluteKeywordLocation: JSONSchemaURI?
    public let keyword: JSONKey
    public let value: JSON
    public init(instanceLocation: JSONPointer, keywordLocation: JSONPointer, absoluteKeywordLocation: JSONSchemaURI?, keyword: JSONKey, value: JSON) {
        self.instanceLocation = instanceLocation; self.keywordLocation = keywordLocation
        self.absoluteKeywordLocation = absoluteKeywordLocation; self.keyword = keyword; self.value = value
    }
}

/// A completed validation verdict. Operational failures throw before a result exists.
public struct JSONValidationResult: Sendable {
    public let isValid: Bool
    public let outputStyle: JSONValidationOutput
    public let issues: [JSONValidationIssue]
    public let annotations: [JSONEvaluationAnnotation]
    public let diagnosticsComplete: Bool
    package init(isValid: Bool, outputStyle: JSONValidationOutput, issues: [JSONValidationIssue], annotations: [JSONEvaluationAnnotation], diagnosticsComplete: Bool) {
        self.isValid = isValid; self.outputStyle = outputStyle; self.issues = issues; self.annotations = annotations; self.diagnosticsComplete = diagnosticsComplete
    }
}
