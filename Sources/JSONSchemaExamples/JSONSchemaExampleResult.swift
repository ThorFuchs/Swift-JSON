// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema

/// A candidate certified by completed native validation against the prepared root.
///
/// Only the generator initializes results. G1 offers explicit candidates and static
/// references, not general schema synthesis or an arbitrary satisfiability decision.
public struct JSONSchemaExampleResult: Sendable {
    /// The exact candidate that received the attached valid verdict.
    public let value: JSON
    /// The native validator's completed valid result, including its actual diagnostics/annotations.
    public let validation: JSONValidationResult
    /// The caller's seed; G1 records it but makes no random choices.
    public let seed: UInt64
    /// The requested candidate preference.
    public let profile: JSONSchemaExampleProfile
    /// The versioned candidate algorithm, currently s3-g1-candidates-v1.
    public let generatorVersion: String
    /// SHA-256 of the documented normalized source/registry transport, not original text or JCS.
    public let sourceSnapshotDigest: String
    /// The transport and hashing identity, currently swift-json-schema-snapshot-g1-v1.
    public let schemaDigestAlgorithm: String
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
