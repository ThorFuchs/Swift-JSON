// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONFilterRuntime

/// A typed operational or language error without CLI exits or rejected payloads.
public struct JSONTransformFailure: Error, Sendable, Equatable {
    /// The boundary at which the operation failed.
    public enum Category: String, Sendable {
        /// Query grammar or declaration failure.
        case compilation
        /// An uncaught query-language exception.
        case language
        /// Inclusive finite resource ceiling or checked-counter failure.
        case resource
        /// Cancellation observed in owned work.
        case cancelled
        /// A caller-supplied input callback failed.
        case provider
        /// Invalid limits, bindings or execution state.
        case configuration
    }
    /// The stable error category.
    public let category: Category
    /// The engine's fixed reason identifier; never an instance payload.
    public let code: String
    /// Query UTF-8 byte offset when compilation provided one.
    public let byteOffset: UInt64?
    /// Transform or native resource counter, if known.
    public let metric: String?
    /// Inclusive violated resource ceiling.
    public let limit: UInt64?
    /// Attempted usage, when representable.
    public let attemptedUsage: UInt64?
    /// Whether checked arithmetic overflowed.
    public let overflow: Bool

    init(_ category: Category, _ code: String, byteOffset: UInt64? = nil,
         metric: String? = nil, limit: UInt64? = nil, attemptedUsage: UInt64? = nil, overflow: Bool = false) {
        self.category = category; self.code = code; self.byteOffset = byteOffset
        self.metric = metric; self.limit = limit; self.attemptedUsage = attemptedUsage; self.overflow = overflow
    }
    static func classify(_ error: any Error) -> Self {
        if let failure = error as? Self { return failure }
        if error is CancellationError { return .init(.cancelled, "cancelled") }
        if let failure = error as? FilterCompileFailure { return .init(.compilation, failure.code, byteOffset: UInt64(failure.offset)) }
        if let failure = error as? FilterLanguageFailure { return .init(.language, failure.code) }
        if let failure = error as? TransformRuntimeFailure {
            let category: Category
            switch failure.category {
            case .usage: category = .configuration
            case .compile: category = .compilation
            case .language: category = .language
            case .input, .io: category = .provider
            case .resource: category = .resource
            case .cancelled: category = .cancelled
            }
            let metric = JSONTransformLimits.Metric.allCases.first { $0.runtime.rawValue == failure.metric }?.rawValue ?? failure.metric
            return .init(category, failure.code, byteOffset: failure.byteOffset, metric: metric,
                         limit: failure.limit, attemptedUsage: failure.attemptedUsage, overflow: failure.overflow)
        }
        if let failure = error as? JSONFailure {
            return .init(failure.category == .resource ? .resource : .configuration, failure.code.rawValue,
                         byteOffset: failure.location?.byteOffset, metric: failure.resource?.metric.rawValue,
                         limit: failure.resource?.limit, attemptedUsage: failure.resource?.attemptedUsage,
                         overflow: failure.resource?.overflow ?? (failure.code == .counterOverflow))
        }
        return .init(.configuration, "operationFailed")
    }
}
