// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// A candidate certified by completed native validation against the prepared root.
///
/// Only the generator initializes results. The current algorithm offers declared hints, static
/// references and conservative typed construction, not arbitrary satisfiability decisions.
public struct JSONSchemaExampleResult: Sendable {
    /// The exact candidate that received the attached valid verdict.
    public let value: JSON
    /// The native validator's completed valid result, including its actual diagnostics/annotations.
    public let validation: JSONValidationResult
    /// The caller's SplitMix64 seed, bound into the deterministic trace.
    public let seed: UInt64
    /// The requested candidate preference.
    public let profile: JSONSchemaExampleProfile
    /// The versioned candidate algorithm, currently s3-candidates-v3.
    public let generatorVersion: String
    /// SHA-256 of the documented normalized source/registry transport, not original text or JCS.
    public let sourceSnapshotDigest: String
    /// The transport and hashing identity, currently swift-json-schema-snapshot-v1.
    public let schemaDigestAlgorithm: String
    /// The versioned ordered corpus transport identity.
    public let corpusDigestAlgorithm: String
    /// SHA-256 of the prepared exact corpus, including token order.
    public let corpusDigest: String
    /// The versioned all-caps policy transport identity.
    public let policyDigestAlgorithm: String
    /// SHA-256 binding generation, compilation and validation configuration.
    public let policyDigest: String
    /// The random algorithm identity, splitmix64-v1, even when no draws were needed.
    public let rngAlgorithm: String
    /// All raw draws, including those rejected by unbiased bounded selection.
    public let randomDraws: UInt64
    /// The versioned complete decision transport identity.
    public let traceDigestAlgorithm: String
    /// SHA-256 of every bounded abstract decision through the final valid verdict.
    public let traceDigest: String
    /// The complete event count; trace exhaustion throws rather than truncating.
    public let traceEventCount: UInt64
    /// The exact instance evaluation policy used for certification.
    public let validationOptions: JSONSchemaOptions
    /// The separate compilation policy that helped establish the prepared plan's assertions.
    public let compilationOptions: JSONSchemaOptions
    /// The total completed candidate validations, including preceding invalid verdicts.
    public let attempts: UInt64
    /// The shared invocation ledger, including all completed candidate checks.
    ///
    /// evaluationWorkUnits is included in workUnits. Preparation is separate.
    /// Discarded validation ownership is released without refunding work; bytes are not RSS.
    public let statistics: JSONOperationStatistics
}
