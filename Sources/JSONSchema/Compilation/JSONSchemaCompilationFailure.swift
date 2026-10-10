// SPDX-License-Identifier: Apache-2.0
import JSON
public struct JSONSchemaCompilationFailure: Error, Sendable, Equatable {
    public enum Category: String, Sendable { case rootKind, dialect, vocabulary, schemaSyntax, identifier, anchor, missingResource, reference, metaSchema }
    public let category: Category
    public let location: JSONPointer?
    public init(_ category: Category, location: JSONPointer? = nil) { self.category = category; self.location = location }
}
