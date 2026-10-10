// SPDX-License-Identifier: Apache-2.0
/// Evaluation errors are operational failures, separate from a completed invalidity verdict.
public struct JSONSchemaEvaluationFailure: Error, Sendable, Equatable {
    public enum Category: String, Sendable { case nonproductiveReference, backend, outputUnavailable }
    public let category: Category
    public init(_ category: Category) { self.category = category }
}
