// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// Finite preparation, search and validation policies for an offline generator.
public struct JSONSchemaExampleOptions: Sendable {
    /// Generation capacities; their intersection with validation limits governs each invocation.
    public var limits: JSONLimits
    /// The positive finite ceiling on candidate validations, including invalid candidates.
    public var maximumAttempts: UInt64
    /// Immutable ordered candidates admitted and hashed during preparation.
    public var corpus: JSONSchemaExampleCorpus
    /// Compilation and snapshot preparation policy, separate from instance evaluation.
    public var compilationOptions: JSONSchemaOptions
    /// Unchanged evaluator policy; required vocabulary assertions remain authoritative.
    public var validationOptions: JSONSchemaOptions

    /// Creates policies checked when the generator is prepared.
    /// - Parameters:
    ///   - limits: Finite generation capacities and cumulative quotas.
    ///   - maximumAttempts: A positive value strictly below UInt64.max.
    ///   - corpus: Exact synthetic tokens; never authoritative over schema constraints.
    ///   - compilationOptions: Offline compilation and preparation limits/policies.
    ///   - validationOptions: Instance evaluation limits and diagnostic/format policies.
    public init(limits: JSONLimits = .balanced, maximumAttempts: UInt64 = 16,
                corpus: JSONSchemaExampleCorpus = .synthetic,
                compilationOptions: JSONSchemaOptions = .init(),
                validationOptions: JSONSchemaOptions = .init()) {
        self.limits = limits; self.maximumAttempts = maximumAttempts; self.corpus = corpus
        self.compilationOptions = compilationOptions; self.validationOptions = validationOptions
    }
}

/// A candidate preference, without a guarantee of globally minimal output.
public enum JSONSchemaExampleProfile: Sendable {
    /// Prefer stable declared candidates and small conservative typed values.
    case minimal
    /// Seeded declared-candidate scans and synthetic tokens for admitted typed strings.
    case demonstration
}

/// A construction feature not implemented by this algorithm version.
public enum JSONSchemaExampleUnsupportedFeature: Sendable, Equatable {
    /// No supported declaration supplied a candidate; this does not establish unsatisfiability.
    case candidateConstruction
    /// Construction would need evaluation-scope-aware dynamic reference navigation.
    case dynamicReference
    /// Candidate discovery revisited a compiled node without finding a witness.
    case cyclicReference
}

/// A sound trivial root-schema proof, distinct from incomplete search.
public enum JSONSchemaUnsatisfiableProof: Sendable, Equatable {
    /// The original root is the Boolean false schema.
    case falseSchema
    /// The active root applicator negates true or an empty object schema.
    case notTrue
}

/// An invalid generator-specific configuration, without raw schema content.
public enum JSONSchemaExampleConfigurationIssue: Sendable, Equatable {
    /// maximumAttempts was zero or UInt64.max.
    case attemptLimit
    /// The corpus had no candidates.
    case emptyCorpus
}

/// Bounded construction failures; core operational errors and cancellation propagate separately.
public enum JSONSchemaExampleFailure: Error, Sendable, Equatable {
    /// A construction feature is unsupported, without a validity verdict.
    /// - Parameter feature: The stable unsupported-feature code.
    case unsupportedFeature(_ feature: JSONSchemaExampleUnsupportedFeature)
    /// All offered candidates failed validation or the attempt ceiling was reached.
    /// - Parameter attempts: The number of completed candidate validations.
    case searchExhausted(attempts: UInt64)
    /// A reviewed trivial proof establishes that the original root cannot accept any instance.
    /// - Parameter proof: The sound proof kind; never inferred from exhaustion.
    case provenUnsatisfiable(_ proof: JSONSchemaUnsatisfiableProof)
    /// Generator configuration was invalid before compilation or search.
    /// - Parameter issue: The stable configuration code.
    case invalidConfiguration(_ issue: JSONSchemaExampleConfigurationIssue)
}
