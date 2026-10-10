// SPDX-License-Identifier: Apache-2.0
import JSON
/// Builds an ordinary schema document; compilation remains the authority.
public enum JSONSchemaBuilder {
    public static func object(limits: JSONLimits = .balanced, _ body: (inout JSONObjectAccumulator) throws -> Void) throws -> JSONSchemaDocument {
        let object = try JSONObject.build(limits: limits, body)
        return try JSONSchemaDocument(.object(object), limits: limits)
    }
    public static func boolean(_ value: Bool, limits: JSONLimits = .balanced) throws -> JSONSchemaDocument {
        try JSONSchemaDocument(.boolean(value), limits: limits)
    }
}
