// SPDX-License-Identifier: Apache-2.0
import JSON

// A SwiftUI-ContentBuilder-inspired but fully independent typed content structure.
// The builder itself is intentionally domain-agnostic: contexts supply conformance.
// No SwiftUI import, SwiftUI types, implicit JSON coercion or runtime reflection.

/// Typed sibling storage whose context conformances determine domain eligibility.
public struct JSONContentTuple<each Element> {
    /// Typed siblings in their original authored order.
    public let elements: (repeat each Element)
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public init(_ elements: repeat each Element) { self.elements = (repeat each elements) }
}
/// Optional typed content; absence emits no declaration.
public struct JSONContentOptional<Component> {
    /// Selected typed content, or nil for omission.
    public let component: Component?
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - component: The selected typed content, or nil to omit it.
    public init(_ component: Component?) { self.component = component }
}
/// Exactly one selected branch without semantic coercion.
public enum JSONContentChoice<First, Second> {
    /// Content selected by the first conditional branch.
    case first(First)
    /// Content selected by the second conditional branch.
    case second(Second)
}
/// Ordered typed iterations in trusted authored staging.
public struct JSONContentLoop<Component> {
    /// Typed loop iterations in order.
    public let components: [Component]
    /// Stores exact authored content without admission, coercion or schema evaluation.
    ///
    /// - Parameters:
    ///   - components: Typed loop iterations in their original order.
    public init(_ components: [Component]) { self.components = components }
}

/// Structural composition shared by the two optional DSL products.
@resultBuilder
public enum JSONContentBuilder {
    /// Preserves typed siblings in a variadic tuple; domain eligibility comes from conditional conformances.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public static func buildBlock<each Element>(_ elements: repeat each Element) -> JSONContentTuple<
        repeat each Element
    > {
        .init(repeat each elements)
    }
    /// Preserves optional content; nil contributes no declaration.
    ///
    /// - Parameters:
    ///   - component: The selected typed content, or nil to omit it.
    public static func buildOptional<Component>(_ component: Component?) -> JSONContentOptional<Component> {
        .init(component)
    }
    /// Preserves the selected branch without a substitute null or Boolean schema.
    ///
    /// - Parameters:
    ///   - first: The selected first branch, preserving its domain eligibility.
    public static func buildEither<First, Second>(first: First) -> JSONContentChoice<First, Second> {
        .first(first)
    }
    /// Preserves the selected branch without a substitute null or Boolean schema.
    ///
    /// - Parameters:
    ///   - second: The selected second branch, preserving its domain eligibility.
    public static func buildEither<First, Second>(second: Second) -> JSONContentChoice<First, Second> {
        .second(second)
    }
    /// Preserves loop iterations in order for their containing typed context.
    ///
    /// - Parameters:
    ///   - components: Typed loop iterations in their original order.
    public static func buildArray<Component>(_ components: [Component]) -> JSONContentLoop<Component> {
        .init(components)
    }
    /// Forwards available typed content without erasure or semantic interpretation.
    ///
    /// - Parameters:
    ///   - component: The selected typed content, or nil to omit it.
    public static func buildLimitedAvailability<Component>(_ component: Component) -> Component { component }
}

/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONValueFieldsContent {
    /// Emits ordered object members into trusted, unmetered staging.
    ///
    /// - Parameters:
    ///   - members: The caller-owned ordered buffer; emission performs no admission or evaluation.
    func writeValueFields(to members: inout [JSONDSLMember])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONValueElementsContent {
    /// Emits ordered array elements into trusted, unmetered staging.
    ///
    /// - Parameters:
    ///   - elements: The caller-owned ordered buffer; emission performs no admission or evaluation.
    func writeValueElements(to elements: inout [JSONDSLNode])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaClausesContent {
    /// Emits explicit schema keyword declarations into trusted, unmetered staging.
    ///
    /// - Parameters:
    ///   - members: The caller-owned ordered buffer; emission performs no admission or evaluation.
    func writeSchemaClauses(to members: inout [JSONDSLMember])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaPropertiesContent {
    /// Emits named property schemas into trusted, unmetered staging.
    ///
    /// - Parameters:
    ///   - members: The caller-owned ordered buffer; emission performs no admission or evaluation.
    func writeSchemaProperties(to members: inout [JSONDSLMember])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaNodesContent {
    /// Emits ordered Boolean or object subschemas into trusted, unmetered staging.
    ///
    /// - Parameters:
    ///   - nodes: The caller-owned ordered buffer; emission performs no admission or evaluation.
    func writeSchemaNodes(to nodes: inout [JSONDSLNode])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaDependenciesContent {
    /// Emits dependent-required declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    func writeSchemaDependencies(to members: inout [JSONDSLMember])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaPatternsContent {
    /// Emits pattern-keyed schemas into trusted, unmetered staging.
    ///
    /// - Parameters:
    ///   - members: The caller-owned ordered buffer; emission performs no admission or evaluation.
    func writeSchemaPatterns(to members: inout [JSONDSLMember])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaDefinitionsContent {
    /// Emits named schema definitions into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    func writeSchemaDefinitions(to members: inout [JSONDSLMember])
}
/// A typed staging emission contract; implementations are trusted authored code, outside finalization accounting.
public protocol JSONSchemaDependentSchemasContent {
    /// Emits dependent schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    func writeDependentSchemas(to members: inout [JSONDSLMember])
}

// Context-specific conditional conformances mirror ContentBuilder's design principle.
// Deliberately not type-erased; wrong-domain items are compile-time errors.

extension JSONContentTuple: JSONValueFieldsContent where repeat each Element: JSONValueFieldsContent {
    /// Emits ordered object members into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeValueFields(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeValueFields(to: &members) }
    }
}
extension JSONContentOptional: JSONValueFieldsContent where Component: JSONValueFieldsContent {
    /// Emits ordered object members into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeValueFields(to members: inout [JSONDSLMember]) {
        component?.writeValueFields(to: &members)
    }
}
extension JSONContentChoice: JSONValueFieldsContent
where First: JSONValueFieldsContent, Second: JSONValueFieldsContent {
    /// Emits ordered object members into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeValueFields(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeValueFields(to: &members)
        case .second(let item): item.writeValueFields(to: &members)
        }
    }
}
extension JSONContentLoop: JSONValueFieldsContent where Component: JSONValueFieldsContent {
    /// Emits ordered object members into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeValueFields(to members: inout [JSONDSLMember]) {
        for component in components { component.writeValueFields(to: &members) }
    }
}

extension JSONContentTuple: JSONValueElementsContent where repeat each Element: JSONValueElementsContent {
    /// Emits array elements into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public func writeValueElements(to elements: inout [JSONDSLNode]) {
        for element in repeat each self.elements { element.writeValueElements(to: &elements) }
    }
}
extension JSONContentOptional: JSONValueElementsContent where Component: JSONValueElementsContent {
    /// Emits array elements into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public func writeValueElements(to elements: inout [JSONDSLNode]) {
        component?.writeValueElements(to: &elements)
    }
}
extension JSONContentChoice: JSONValueElementsContent
where First: JSONValueElementsContent, Second: JSONValueElementsContent {
    /// Emits array elements into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public func writeValueElements(to elements: inout [JSONDSLNode]) {
        switch self {
        case .first(let item): item.writeValueElements(to: &elements)
        case .second(let item): item.writeValueElements(to: &elements)
        }
    }
}
extension JSONContentLoop: JSONValueElementsContent where Component: JSONValueElementsContent {
    /// Emits array elements into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - elements: Typed siblings or array elements in their authored order.
    public func writeValueElements(to elements: inout [JSONDSLNode]) {
        for component in components { component.writeValueElements(to: &elements) }
    }
}

extension JSONContentTuple: JSONSchemaClausesContent where repeat each Element: JSONSchemaClausesContent {
    /// Emits schema keyword declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaClauses(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeSchemaClauses(to: &members) }
    }
}
extension JSONContentOptional: JSONSchemaClausesContent where Component: JSONSchemaClausesContent {
    /// Emits schema keyword declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaClauses(to members: inout [JSONDSLMember]) {
        component?.writeSchemaClauses(to: &members)
    }
}
extension JSONContentChoice: JSONSchemaClausesContent
where First: JSONSchemaClausesContent, Second: JSONSchemaClausesContent {
    /// Emits schema keyword declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaClauses(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeSchemaClauses(to: &members)
        case .second(let item): item.writeSchemaClauses(to: &members)
        }
    }
}
extension JSONContentLoop: JSONSchemaClausesContent where Component: JSONSchemaClausesContent {
    /// Emits schema keyword declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaClauses(to members: inout [JSONDSLMember]) {
        for component in components { component.writeSchemaClauses(to: &members) }
    }
}

extension JSONContentTuple: JSONSchemaPropertiesContent
where repeat each Element: JSONSchemaPropertiesContent {
    /// Emits property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaProperties(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeSchemaProperties(to: &members) }
    }
}
extension JSONContentOptional: JSONSchemaPropertiesContent where Component: JSONSchemaPropertiesContent {
    /// Emits property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaProperties(to members: inout [JSONDSLMember]) {
        component?.writeSchemaProperties(to: &members)
    }
}
extension JSONContentChoice: JSONSchemaPropertiesContent
where First: JSONSchemaPropertiesContent, Second: JSONSchemaPropertiesContent {
    /// Emits property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaProperties(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeSchemaProperties(to: &members)
        case .second(let item): item.writeSchemaProperties(to: &members)
        }
    }
}
extension JSONContentLoop: JSONSchemaPropertiesContent where Component: JSONSchemaPropertiesContent {
    /// Emits property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaProperties(to members: inout [JSONDSLMember]) {
        for component in components { component.writeSchemaProperties(to: &members) }
    }
}

extension JSONContentTuple: JSONSchemaNodesContent where repeat each Element: JSONSchemaNodesContent {
    /// Emits subschemas in a composition list into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - nodes: The unmetered staged subschema list, preserving order and Boolean schemas.
    public func writeSchemaNodes(to nodes: inout [JSONDSLNode]) {
        for element in repeat each self.elements { element.writeSchemaNodes(to: &nodes) }
    }
}
extension JSONContentOptional: JSONSchemaNodesContent where Component: JSONSchemaNodesContent {
    /// Emits subschemas in a composition list into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - nodes: The unmetered staged subschema list, preserving order and Boolean schemas.
    public func writeSchemaNodes(to nodes: inout [JSONDSLNode]) { component?.writeSchemaNodes(to: &nodes) }
}
extension JSONContentChoice: JSONSchemaNodesContent
where First: JSONSchemaNodesContent, Second: JSONSchemaNodesContent {
    /// Emits subschemas in a composition list into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - nodes: The unmetered staged subschema list, preserving order and Boolean schemas.
    public func writeSchemaNodes(to nodes: inout [JSONDSLNode]) {
        switch self {
        case .first(let item): item.writeSchemaNodes(to: &nodes)
        case .second(let item): item.writeSchemaNodes(to: &nodes)
        }
    }
}
extension JSONContentLoop: JSONSchemaNodesContent where Component: JSONSchemaNodesContent {
    /// Emits subschemas in a composition list into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - nodes: The unmetered staged subschema list, preserving order and Boolean schemas.
    public func writeSchemaNodes(to nodes: inout [JSONDSLNode]) {
        for component in components { component.writeSchemaNodes(to: &nodes) }
    }
}

extension JSONContentTuple: JSONSchemaDependenciesContent
where repeat each Element: JSONSchemaDependenciesContent {
    /// Emits dependent-required declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDependencies(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeSchemaDependencies(to: &members) }
    }
}
extension JSONContentOptional: JSONSchemaDependenciesContent where Component: JSONSchemaDependenciesContent {
    /// Emits dependent-required declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDependencies(to members: inout [JSONDSLMember]) {
        component?.writeSchemaDependencies(to: &members)
    }
}
extension JSONContentChoice: JSONSchemaDependenciesContent
where First: JSONSchemaDependenciesContent, Second: JSONSchemaDependenciesContent {
    /// Emits dependent-required declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDependencies(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeSchemaDependencies(to: &members)
        case .second(let item): item.writeSchemaDependencies(to: &members)
        }
    }
}
extension JSONContentLoop: JSONSchemaDependenciesContent where Component: JSONSchemaDependenciesContent {
    /// Emits dependent-required declarations into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDependencies(to members: inout [JSONDSLMember]) {
        for component in components { component.writeSchemaDependencies(to: &members) }
    }
}

extension JSONContentTuple: JSONSchemaPatternsContent where repeat each Element: JSONSchemaPatternsContent {
    /// Emits patterned property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaPatterns(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeSchemaPatterns(to: &members) }
    }
}
extension JSONContentOptional: JSONSchemaPatternsContent where Component: JSONSchemaPatternsContent {
    /// Emits patterned property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaPatterns(to members: inout [JSONDSLMember]) {
        component?.writeSchemaPatterns(to: &members)
    }
}
extension JSONContentChoice: JSONSchemaPatternsContent
where First: JSONSchemaPatternsContent, Second: JSONSchemaPatternsContent {
    /// Emits patterned property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaPatterns(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeSchemaPatterns(to: &members)
        case .second(let item): item.writeSchemaPatterns(to: &members)
        }
    }
}
extension JSONContentLoop: JSONSchemaPatternsContent where Component: JSONSchemaPatternsContent {
    /// Emits patterned property schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaPatterns(to members: inout [JSONDSLMember]) {
        for component in components { component.writeSchemaPatterns(to: &members) }
    }
}

extension JSONContentTuple: JSONSchemaDefinitionsContent
where repeat each Element: JSONSchemaDefinitionsContent {
    /// Emits named schema definitions into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDefinitions(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeSchemaDefinitions(to: &members) }
    }
}
extension JSONContentOptional: JSONSchemaDefinitionsContent where Component: JSONSchemaDefinitionsContent {
    /// Emits named schema definitions into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDefinitions(to members: inout [JSONDSLMember]) {
        component?.writeSchemaDefinitions(to: &members)
    }
}
extension JSONContentChoice: JSONSchemaDefinitionsContent
where First: JSONSchemaDefinitionsContent, Second: JSONSchemaDefinitionsContent {
    /// Emits named schema definitions into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDefinitions(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeSchemaDefinitions(to: &members)
        case .second(let item): item.writeSchemaDefinitions(to: &members)
        }
    }
}
extension JSONContentLoop: JSONSchemaDefinitionsContent where Component: JSONSchemaDefinitionsContent {
    /// Emits named schema definitions into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeSchemaDefinitions(to members: inout [JSONDSLMember]) {
        for component in components { component.writeSchemaDefinitions(to: &members) }
    }
}

extension JSONContentTuple: JSONSchemaDependentSchemasContent
where repeat each Element: JSONSchemaDependentSchemasContent {
    /// Emits dependent schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeDependentSchemas(to members: inout [JSONDSLMember]) {
        for element in repeat each self.elements { element.writeDependentSchemas(to: &members) }
    }
}
extension JSONContentOptional: JSONSchemaDependentSchemasContent
where Component: JSONSchemaDependentSchemasContent {
    /// Emits dependent schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeDependentSchemas(to members: inout [JSONDSLMember]) {
        component?.writeDependentSchemas(to: &members)
    }
}
extension JSONContentChoice: JSONSchemaDependentSchemasContent
where First: JSONSchemaDependentSchemasContent, Second: JSONSchemaDependentSchemasContent {
    /// Emits dependent schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeDependentSchemas(to members: inout [JSONDSLMember]) {
        switch self {
        case .first(let item): item.writeDependentSchemas(to: &members)
        case .second(let item): item.writeDependentSchemas(to: &members)
        }
    }
}
extension JSONContentLoop: JSONSchemaDependentSchemasContent
where Component: JSONSchemaDependentSchemasContent {
    /// Emits dependent schemas into trusted staging; this does not perform admission or evaluation.
    ///
    /// - Parameters:
    ///   - members: The unmetered ordered staging buffer; this is not a checked accumulator.
    public func writeDependentSchemas(to members: inout [JSONDSLMember]) {
        for component in components { component.writeDependentSchemas(to: &members) }
    }
}

extension JSONContentTuple: Sendable where repeat each Element: Sendable {}
extension JSONContentOptional: Sendable where Component: Sendable {}
extension JSONContentChoice: Sendable where First: Sendable, Second: Sendable {}
extension JSONContentLoop: Sendable where Component: Sendable {}
