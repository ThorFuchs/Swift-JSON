// SPDX-License-Identifier: Apache-2.0
import JSON

/// Structured bounded issue; no rejected instance payload or arbitrary error description is retained.
public struct JSONValidationIssue: Sendable {
    public let instanceLocation: JSONPointer
    public let keywordLocation: JSONPointer
    public let absoluteKeywordLocation: JSONSchemaURI?
    public let keyword: JSONKey
    public init(instanceLocation: JSONPointer, keywordLocation: JSONPointer, absoluteKeywordLocation: JSONSchemaURI?, keyword: JSONKey) {
        self.instanceLocation = instanceLocation; self.keywordLocation = keywordLocation
        self.absoluteKeywordLocation = absoluteKeywordLocation; self.keyword = keyword
    }
}
