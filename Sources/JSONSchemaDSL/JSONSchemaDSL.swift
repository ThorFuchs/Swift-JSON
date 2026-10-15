// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONDSLCore
import JSONSchema

/// Stages one schema document; only finalization is checked and callbacks/staging are unmetered.
///
/// - Parameters:
///   - limits: Inclusive finite finalization capacities and work quotas; staging is excluded.
///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
public func document<Content: JSONSchemaClausesContent>(
    limits: JSONLimits = .balanced,
    @JSONContentBuilder _ content: () -> Content
) throws -> JSONSchemaDocument {
    try Task.checkCancellation()
    try limits.validate()
    var entries: [JSONDSLMember] = []
    content().writeSchemaClauses(to: &entries)
    return try JSONDSLNode.object(entries).finalize(limits: limits, domain: .schemaCompilation) {
        raw, meter in
        try JSONSchemaDocument(raw, meter: &meter)
    }
}
/// Admits an ordinary Boolean schema through the existing JSONSchemaDocument authority.
///
/// - Parameters:
///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
///   - limits: Inclusive finite finalization capacities and work quotas; staging is excluded.
public func boolean(_ allowsAll: Bool, limits: JSONLimits = .balanced) throws -> JSONSchemaDocument
{
    try JSONSchemaDocument(.boolean(allowsAll), limits: limits)
}

/// One staged schema declaration (`keyword: exact value`), not an evaluation rule.
public struct SchemaClause: Sendable, JSONSchemaClausesContent {
    /// The staged exact keyword/value declaration.
    public let entry: JSONDSLMember
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public init(_ name: String, value: JSONDSLNode) { entry = .init(name, value) }
    /// Emits schema keyword declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaClauses(to members: inout [JSONDSLMember]) { members.append(entry) }
}

/// Document/schema keyword types; no type inference from sibling declarations.
public enum SchemaType: String, Sendable {
    /// The explicit JSON Schema `object` type name.
    case object
    /// The explicit JSON Schema `array` type name.
    case array
    /// The explicit JSON Schema `string` type name.
    case string
    /// The explicit JSON Schema `number` type name.
    case number
    /// The explicit JSON Schema `integer` type name.
    case integer
    /// The explicit JSON Schema `boolean` type name.
    case boolean
    /// The explicit JSON Schema `null` type name.
    case null
}

/// Fluent namespace that covers standard Draft 2020-12 keywords, but does not
/// infer effective schema shape, override compiler policy or resolve remote refs.
public enum Schema {
    private static func one(_ key: String, _ value: JSON) -> SchemaClause {
        .init(key, value: .literal(value))
    }
    private static func jsonStringArray(_ values: [String]) -> JSONDSLNode {
        .array(values.map { .literal(.string($0)) })
    }
    private static func jsonArray(_ values: [JSON]) -> JSONDSLNode { .array(values.map(JSONDSLNode.literal)) }
    private static func makeObject<Content: JSONSchemaClausesContent>(_ content: Content) -> JSONDSLNode {
        var entries: [JSONDSLMember] = []
        content.writeSchemaClauses(to: &entries)
        return .object(entries)
    }
    private static func schemaKeyword<Content: JSONSchemaClausesContent>(
        _ name: String, _ content: Content
    ) -> SchemaClause { .init(name, value: makeObject(content)) }

    // Core and identification.
    /// Declares `$schema` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func schemaURI(_ value: String) -> SchemaClause { one("$schema", .string(value)) }
    /// Declares `$id` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func identifier(_ value: String) -> SchemaClause { one("$id", .string(value)) }
    /// Declares `$anchor` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func anchor(_ value: String) -> SchemaClause { one("$anchor", .string(value)) }
    /// Declares `$dynamicAnchor` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func dynamicAnchor(_ value: String) -> SchemaClause {
        one("$dynamicAnchor", .string(value))
    }
    /// Declares `$ref` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func reference(_ value: String) -> SchemaClause { one("$ref", .string(value)) }
    /// Declares `$dynamicRef` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func dynamicReference(_ value: String) -> SchemaClause {
        one("$dynamicRef", .string(value))
    }
    /// Declares `$comment` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func comment(_ value: String) -> SchemaClause { one("$comment", .string(value)) }
    /// Declares `$vocabulary` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - entries: Ordered URI/requirement or named declaration pairs; exact duplicates fail finalization.
    public static func vocabulary(_ entries: [(String, Bool)]) -> SchemaClause {
        .init("$vocabulary", value: .object(entries.map { .init($0.0, .literal(.boolean($0.1))) }))
    }
    /// Declares `$defs` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func definitions<Content: JSONSchemaDefinitionsContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause {
        var entries: [JSONDSLMember] = []
        content().writeSchemaDefinitions(to: &entries)
        return .init("$defs", value: .object(entries))
    }

    // Scalar assertions and typed vocabularies.
    /// Declares `type` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func type(_ value: SchemaType) -> SchemaClause { one("type", .string(value.rawValue)) }
    /// Declares `type` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - values: Explicit exact payloads in declaration order; nested arrays remain values.
    public static func types(_ values: [SchemaType]) -> SchemaClause {
        .init("type", value: jsonStringArray(values.map(\.rawValue)))
    }
    /// Declares `enum` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - values: Explicit exact payloads in declaration order; nested arrays remain values.
    public static func enumValues(_ values: [JSON]) -> SchemaClause {
        .init("enum", value: jsonArray(values))
    }
    /// Declares `const` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func constant(_ value: JSON) -> SchemaClause { one("const", value) }
    /// Declares `minimum` using an explicit exact decimal without binary floating-point narrowing.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func minimum(_ value: JSONNumber) -> SchemaClause { one("minimum", .number(value)) }
    /// Declares `maximum` using an explicit exact decimal without binary floating-point narrowing.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func maximum(_ value: JSONNumber) -> SchemaClause { one("maximum", .number(value)) }
    /// Declares `exclusiveMinimum` using an explicit exact decimal without binary floating-point narrowing.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func exclusiveMinimum(_ value: JSONNumber) -> SchemaClause {
        one("exclusiveMinimum", .number(value))
    }
    /// Declares `exclusiveMaximum` using an explicit exact decimal without binary floating-point narrowing.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func exclusiveMaximum(_ value: JSONNumber) -> SchemaClause {
        one("exclusiveMaximum", .number(value))
    }
    /// Declares `multipleOf` using an explicit exact decimal without binary floating-point narrowing.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func multipleOf(_ value: JSONNumber) -> SchemaClause { one("multipleOf", .number(value)) }
    /// Declares `minLength` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func minLength(_ value: Int) -> SchemaClause {
        one("minLength", .number(JSONNumber(integer: value)))
    }
    /// Declares `maxLength` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func maxLength(_ value: Int) -> SchemaClause {
        one("maxLength", .number(JSONNumber(integer: value)))
    }
    /// Declares `pattern` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func pattern(_ value: String) -> SchemaClause { one("pattern", .string(value)) }
    /// Declares `minItems` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func minItems(_ value: Int) -> SchemaClause {
        one("minItems", .number(JSONNumber(integer: value)))
    }
    /// Declares `maxItems` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func maxItems(_ value: Int) -> SchemaClause {
        one("maxItems", .number(JSONNumber(integer: value)))
    }
    /// Declares `uniqueItems` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func uniqueItems(_ value: Bool) -> SchemaClause { one("uniqueItems", .boolean(value)) }
    /// Declares `minContains` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func minContains(_ value: Int) -> SchemaClause {
        one("minContains", .number(JSONNumber(integer: value)))
    }
    /// Declares `maxContains` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func maxContains(_ value: Int) -> SchemaClause {
        one("maxContains", .number(JSONNumber(integer: value)))
    }
    /// Declares `minProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func minProperties(_ value: Int) -> SchemaClause {
        one("minProperties", .number(JSONNumber(integer: value)))
    }
    /// Declares `maxProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func maxProperties(_ value: Int) -> SchemaClause {
        one("maxProperties", .number(JSONNumber(integer: value)))
    }
    /// Declares required names explicitly; property declarations never infer requiredness.
    ///
    /// - Parameters:
    ///   - names: Explicit required member names, preserved in declaration order.
    public static func required(_ names: String...) -> SchemaClause {
        .init("required", value: jsonStringArray(names))
    }
    /// Declares format metadata; assertion policy remains with the existing compiler and validator.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    public static func format(_ name: String) -> SchemaClause { one("format", .string(name)) }

    // Metadata/annotation vocabulary; not assertions and never mutate an instance.
    /// Declares `title` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func title(_ value: String) -> SchemaClause { one("title", .string(value)) }
    /// Declares `description` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func description(_ value: String) -> SchemaClause { one("description", .string(value)) }
    /// Declares default metadata without inserting or changing any instance value.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func defaultValue(_ value: JSON) -> SchemaClause { one("default", value) }
    /// Declares `examples` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - values: Explicit exact payloads in declaration order; nested arrays remain values.
    public static func examples(_ values: [JSON]) -> SchemaClause {
        .init("examples", value: jsonArray(values))
    }
    /// Declares `deprecated` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func deprecated(_ value: Bool = true) -> SchemaClause { one("deprecated", .boolean(value)) }
    /// Declares `readOnly` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func readOnly(_ value: Bool = true) -> SchemaClause { one("readOnly", .boolean(value)) }
    /// Emits typed declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func writeOnly(_ value: Bool = true) -> SchemaClause { one("writeOnly", .boolean(value)) }
    /// Declares `contentEncoding` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func contentEncoding(_ value: String) -> SchemaClause {
        one("contentEncoding", .string(value))
    }
    /// Declares `contentMediaType` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - value: The exact declared payload; it is not coerced or interpreted by the DSL.
    public static func contentMediaType(_ value: String) -> SchemaClause {
        one("contentMediaType", .string(value))
    }

    // Object applicators.
    /// Declares `properties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func properties<Content: JSONSchemaPropertiesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause {
        var members: [JSONDSLMember] = []
        content().writeSchemaProperties(to: &members)
        return .init("properties", value: .object(members))
    }
    /// Declares `patternProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func patternProperties<Content: JSONSchemaPatternsContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause {
        var members: [JSONDSLMember] = []
        content().writeSchemaPatterns(to: &members)
        return .init("patternProperties", value: .object(members))
    }
    /// Declares `dependentSchemas` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func dependentSchemas<Content: JSONSchemaDependentSchemasContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause {
        var members: [JSONDSLMember] = []
        content().writeDependentSchemas(to: &members)
        return .init("dependentSchemas", value: .object(members))
    }
    /// Declares `dependentRequired` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func dependentRequired<Content: JSONSchemaDependenciesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause {
        var members: [JSONDSLMember] = []
        content().writeSchemaDependencies(to: &members)
        return .init("dependentRequired", value: .object(members))
    }
    /// Declares `propertyNames` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func propertyNames<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("propertyNames", content()) }
    /// Declares `additionalProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public static func additionalProperties(_ allowsAll: Bool) -> SchemaClause {
        one("additionalProperties", .boolean(allowsAll))
    }
    /// Declares `additionalProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func additionalProperties<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("additionalProperties", content()) }
    /// Declares `unevaluatedProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public static func unevaluatedProperties(_ allowsAll: Bool) -> SchemaClause {
        one("unevaluatedProperties", .boolean(allowsAll))
    }
    /// Declares `unevaluatedProperties` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func unevaluatedProperties<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("unevaluatedProperties", content()) }

    // Array applicators.
    /// Declares `items` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public static func items(_ allowsAll: Bool) -> SchemaClause { one("items", .boolean(allowsAll)) }
    /// Declares `items` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func items<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("items", content()) }
    /// Declares `prefixItems` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func prefixItems<Content: JSONSchemaNodesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause {
        var nodes: [JSONDSLNode] = []
        content().writeSchemaNodes(to: &nodes)
        return .init("prefixItems", value: .array(nodes))
    }
    /// Declares `contains` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func contains<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("contains", content()) }
    /// Declares `unevaluatedItems` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public static func unevaluatedItems(_ allowsAll: Bool) -> SchemaClause {
        one("unevaluatedItems", .boolean(allowsAll))
    }
    /// Declares `unevaluatedItems` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func unevaluatedItems<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("unevaluatedItems", content()) }

    // Logical/conditional applicators.
    private static func alternatives<Content: JSONSchemaNodesContent>(_ name: String, content: Content)
        -> SchemaClause
    {
        var nodes: [JSONDSLNode] = []
        content.writeSchemaNodes(to: &nodes)
        return .init(name, value: .array(nodes))
    }
    /// Declares `allOf` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func allOf<Content: JSONSchemaNodesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { alternatives("allOf", content: content()) }
    /// Declares `anyOf` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func anyOf<Content: JSONSchemaNodesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { alternatives("anyOf", content: content()) }
    /// Declares `oneOf` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func oneOf<Content: JSONSchemaNodesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { alternatives("oneOf", content: content()) }
    /// Declares `not` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func not<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("not", content()) }
    /// Declares `if` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func ifSchema<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("if", content()) }
    /// Declares `then` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func thenSchema<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("then", content()) }
    /// Declares `else` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func elseSchema<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("else", content()) }
    /// Declares `contentSchema` without repairing, validating or evaluating its schema semantics.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public static func contentSchema<Content: JSONSchemaClausesContent>(
        @JSONContentBuilder _ content: () -> Content
    ) -> SchemaClause { schemaKeyword("contentSchema", content()) }

    // Full-fidelity escape: preservation of extension metadata, unknown optional vocabularies.
    // The canonical compiler, not this DSL, determines whether a keyword is admitted.
    /// Preserves an exact raw declaration; the existing compiler determines its syntax and meaning.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - exactValue: The exact authored input for this declaration; no semantic fallback is applied.
    public static func rawKeyword(_ name: String, _ exactValue: JSON) -> SchemaClause {
        one(name, exactValue)
    }
}

/// Declares one subschema in an alternatives list (or a Boolean schema).
public struct Rule: Sendable, JSONSchemaNodesContent {
    /// The staged subschema, without evaluation or inferred constraints.
    public let node: JSONDSLNode
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public init<Content: JSONSchemaClausesContent>(@JSONContentBuilder _ content: () -> Content) {
        var members: [JSONDSLMember] = []
        content().writeSchemaClauses(to: &members)
        node = .object(members)
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public init(_ allowsAll: Bool) { node = .literal(.boolean(allowsAll)) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - raw: The exact authored input for this declaration; no semantic fallback is applied.
    public init(raw: JSON) { node = .literal(raw) }
    /// Emits subschemas in a composition list into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - nodes: The unmetered staged subschema list, preserving order and Boolean schemas.
    public func writeSchemaNodes(to nodes: inout [JSONDSLNode]) { nodes.append(node) }
}

/// A property/definition/pattern property entry. Exact duplicate names are checked later.
public struct Property: Sendable, JSONSchemaPropertiesContent {
    /// The ordered exact named subschema declaration.
    public let member: JSONDSLMember
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public init<Content: JSONSchemaClausesContent>(
        _ name: String, @JSONContentBuilder _ content: () -> Content
    ) {
        var members: [JSONDSLMember] = []
        content().writeSchemaClauses(to: &members)
        member = .init(name, .object(members))
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public init(_ name: String, allowsAll: Bool) { member = .init(name, .literal(.boolean(allowsAll))) }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - rawSchema: The exact authored input for this declaration; no semantic fallback is applied.
    public init(_ name: String, rawSchema: JSON) { member = .init(name, .literal(rawSchema)) }
    /// Emits property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaProperties(to members: inout [JSONDSLMember]) { members.append(member) }
}

/// A dependentRequired entry. Does not silently infer presence from properties.
public struct RequiredDependency: Sendable, JSONSchemaDependenciesContent {
    /// The literal decoded-scalar member name; it is not a Pointer or dotted path.
    public let key: String
    /// Explicit required member names; no property inference is performed.
    public let names: [String]
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - requires: Explicit required member names; none are inferred from property declarations.
    public init(_ key: String, requires: [String]) {
        self.key = key
        self.names = requires
    }
    /// Emits dependent-required declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDependencies(to members: inout [JSONDSLMember]) {
        members.append(.init(key, .array(names.map { .literal(.string($0)) })))
    }
}

/// A named `$defs` entry. It cannot be placed in `properties` by accident.
public struct Definition: Sendable, JSONSchemaDefinitionsContent {
    /// The ordered exact named subschema declaration.
    public let member: JSONDSLMember
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public init<Content: JSONSchemaClausesContent>(
        _ name: String, @JSONContentBuilder _ content: () -> Content
    ) {
        var entries: [JSONDSLMember] = []
        content().writeSchemaClauses(to: &entries)
        member = .init(name, .object(entries))
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - name: The exact declaration name or keyword-specific text, without normalization.
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public init(_ name: String, allowsAll: Bool) { member = .init(name, .literal(.boolean(allowsAll))) }
    /// Emits named schema definitions into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDefinitions(to members: inout [JSONDSLMember]) { members.append(member) }
}

/// A regular-expression property key. The compiler validates the pattern dialect.
public struct PatternProperty: Sendable, JSONSchemaPatternsContent {
    /// The ordered exact named subschema declaration.
    public let member: JSONDSLMember
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - pattern: The exact pattern text; regex validity belongs to the schema compiler.
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public init<Content: JSONSchemaClausesContent>(
        _ pattern: String, @JSONContentBuilder _ content: () -> Content
    ) {
        var entries: [JSONDSLMember] = []
        content().writeSchemaClauses(to: &entries)
        member = .init(pattern, .object(entries))
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - pattern: The exact pattern text; regex validity belongs to the schema compiler.
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public init(_ pattern: String, allowsAll: Bool) { member = .init(pattern, .literal(.boolean(allowsAll))) }
    /// Emits patterned property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaPatterns(to members: inout [JSONDSLMember]) { members.append(member) }
}

/// A dependentSchemas entry (subschema, not a list of required property names).
public struct DependentSchema: Sendable, JSONSchemaDependentSchemasContent {
    /// The ordered exact named subschema declaration.
    public let member: JSONDSLMember
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - content: Trusted synchronous authored declarations; callback execution and staging are unmetered.
    public init<Content: JSONSchemaClausesContent>(
        _ key: String, @JSONContentBuilder _ content: () -> Content
    ) {
        var entries: [JSONDSLMember] = []
        content().writeSchemaClauses(to: &entries)
        member = .init(key, .object(entries))
    }
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - key: The literal decoded-scalar key, without path parsing or normalization.
    ///   - allowsAll: True for an accepting Boolean schema, false for a rejecting Boolean schema.
    public init(_ key: String, allowsAll: Bool) { member = .init(key, .literal(.boolean(allowsAll))) }
    /// Emits dependent schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeDependentSchemas(to members: inout [JSONDSLMember]) { members.append(member) }
}
