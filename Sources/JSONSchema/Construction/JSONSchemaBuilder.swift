// SPDX-License-Identifier: Apache-2.0
import JSON
/// Checked construction of ordinary schema declarations.
///
/// The compiler remains the authority for schema syntax and dialect behavior.
public enum JSONSchemaBuilder {
    /// Builds an ordinary object schema with a checked member accumulator.
    ///
    /// - Throws: Duplicate keys, construction/resource failure, caller errors or cancellation.
    ///
    /// - Parameters:
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    ///   - body: A synchronous callback borrowing the exclusive builder; its errors propagate.
    public static func object(limits: JSONLimits = .balanced, _ body: (inout JSONObjectAccumulator) throws -> Void) throws -> JSONSchemaDocument {
        let object = try JSONObject.build(limits: limits, body)
        return try JSONSchemaDocument(.object(object), limits: limits)
    }
    /// Builds an admitted Boolean schema: true accepts all instances, false rejects all.
    ///
    /// - Throws: Resource or configuration failure, or cancellation.
    ///
    /// - Parameters:
    ///   - value: Whether the Boolean schema accepts every instance or rejects every instance.
    ///   - limits: Finite inclusive capacities and work quotas for this call.
    public static func boolean(_ value: Bool, limits: JSONLimits = .balanced) throws -> JSONSchemaDocument {
        try JSONSchemaDocument(.boolean(value), limits: limits)
    }
}
