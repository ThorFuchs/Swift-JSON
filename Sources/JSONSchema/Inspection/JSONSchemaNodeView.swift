// SPDX-License-Identifier: Apache-2.0
import JSON
/// A bounded raw declaration view. Inspection does not infer an effective schema or resolve dynamic scope.
public struct JSONSchemaNodeView: Sendable {
    public let raw: JSON
    public let documentPointer: JSONPointer
    public let retrievalURI: JSONSchemaURI?
    public let declaredKeywords: [JSONKey]
    public let declaredAnnotations: JSONDeclaredAnnotations
    public let declaredConstraints: JSONObject
    public let resourceURI: JSONSchemaURI?
    public let resourcePointer: JSONPointer?
    /// nil for document-only inspection or a node outside the compiled graph.
    public let referenceTargets: [JSONSchemaReferenceTarget]?
    public func declaration(of key: JSONKey, limits: JSONLimits = .balanced) throws -> JSONPresence<JSON> {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        try JSONAdmission.text(key.string, key: true, meter: &meter)
        guard let object = raw.objectValue else { return .absent }
        guard let value = try object.lookup(key.string, meter: &meter) else { return .absent }
        try JSONAdmission.value(value, meter: &meter)
        return value.isNull ? .null : .value(value)
    }
    package static func inspect(_ raw: JSON, pointer: JSONPointer, retrievalURI: JSONSchemaURI?, meter: inout JSONWorkMeter) throws -> Self {
        switch raw { case .object, .boolean: break; default: throw JSONSchemaCompilationFailure(.rootKind, location: pointer) }
        try JSONAdmission.value(raw, meter: &meter)
        let annotationNames = ["title", "description", "default", "examples", "deprecated", "readOnly", "writeOnly", "$comment", "format", "contentEncoding", "contentMediaType", "contentSchema"]
        let constraintNames = ["type", "enum", "const", "minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf", "minLength", "maxLength", "pattern", "format", "minItems", "maxItems", "uniqueItems", "minContains", "maxContains", "minProperties", "maxProperties", "required", "dependentRequired"]
        var keywords: [JSONKey] = [], annotations: [JSONMember] = [], constraints: [JSONMember] = []
        if case .object(let object) = raw {
            for member in object {
                try meter.work(); try meter.retain(JSONLogicalWeights.arraySlot); keywords.append(member.key)
                for name in annotationNames {
                    if try JSONComparison.textEquals(member.key.string, name, meter: &meter) {
                        try meter.retain(JSONLogicalWeights.member + JSONLogicalWeights.indexSlot); annotations.append(member); break
                    }
                }
                if try JSONSchemaPlan.Keyword.classify(member.key,meter: &meter) == nil {
                    try meter.retain(JSONLogicalWeights.member + JSONLogicalWeights.indexSlot); annotations.append(member)
                }
                for name in constraintNames {
                    if try JSONComparison.textEquals(member.key.string, name, meter: &meter) {
                        try meter.retain(JSONLogicalWeights.member + JSONLogicalWeights.indexSlot); constraints.append(member); break
                    }
                }
            }
        }
        return .init(raw: raw, documentPointer: pointer, retrievalURI: retrievalURI, declaredKeywords: keywords,
                     declaredAnnotations: .init(values: JSONObject(admitted: annotations)), declaredConstraints: JSONObject(admitted: constraints), resourceURI: nil, resourcePointer: nil, referenceTargets: nil)
    }
}
extension JSONSchemaDocument {
    public func node(at pointer: JSONPointer? = nil, limits: JSONLimits = .balanced) throws -> JSONSchemaNodeView {
        try nodeWithReport(at: pointer, limits: limits).result
    }
    public func nodeWithReport(at pointer: JSONPointer? = nil, limits: JSONLimits = .balanced) throws -> JSONOperationReport<JSONSchemaNodeView> {
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        let admitted = try JSONPointer.decodedTokens(pointer?.tokens ?? [], meter: &meter)
        let selected = try admitted.resolve(in: raw, meter: &meter)
        let view = try JSONSchemaNodeView.inspect(selected, pointer: admitted, retrievalURI: retrievalURI, meter: &meter)
        return .init(result: view, statistics: meter.statistics())
    }
}
