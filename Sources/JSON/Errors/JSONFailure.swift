// SPDX-License-Identifier: Apache-2.0
public struct JSONFailure: Error, Sendable, Equatable {
    public enum Category: String, Sendable, Codable {
        case syntax, typeMismatch, missingValue, pointer, patch, conversion, configuration, resource
    }
    public enum Code: String, Sendable, Codable {
        case invalidLimits, limitExceeded, counterOverflow, invalidSyntax, invalidUTF8, duplicateKey
        case unexpectedEOF, trailingData, wrongKind, missingMember, invalidNumber, inexactConversion
        case invalidPointer, invalidIndex, missingTarget, failedTest, invalidOperation
    }
    public let category: Category
    public let code: Code
    public let location: JSONSourceLocation?
    public let resource: JSONResourceViolation?
    public init(_ category: Category, code: Code, location: JSONSourceLocation? = nil,
                resource: JSONResourceViolation? = nil) {
        self.category = category; self.code = code; self.location = location; self.resource = resource
    }
}
