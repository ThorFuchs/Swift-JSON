// SPDX-License-Identifier: Apache-2.0
import JSON
/// Preserves all declarations, including unknown annotation keywords.
public struct JSONSchemaDocument: Sendable {
    public let raw: JSON
    public let retrievalURI: JSONSchemaURI?
    public let sourceMap: JSONSourceMap?
    public init(_ raw: JSON, retrievalURI: JSONSchemaURI? = nil, sourceMap: JSONSourceMap? = nil, limits: JSONLimits = .balanced) throws {
        var meter = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
        try self.init(raw, retrievalURI: retrievalURI, sourceMap: sourceMap, meter: &meter)
    }
    package init(_ raw: JSON, retrievalURI: JSONSchemaURI? = nil, sourceMap: JSONSourceMap? = nil, meter: inout JSONWorkMeter) throws {
        switch raw { case .object, .boolean: break; default: throw JSONSchemaCompilationFailure(.rootKind) }
        try JSONAdmission.value(raw, meter: &meter)
        self.raw = raw; self.retrievalURI = retrievalURI; self.sourceMap = sourceMap
    }
    package init(admitted raw: JSON, retrievalURI: JSONSchemaURI) {
        self.raw = raw; self.retrievalURI = retrievalURI; sourceMap = nil
    }
    public init(_ document: JSONDocument, retrievalURI: JSONSchemaURI? = nil, limits: JSONLimits = .balanced) throws {
        try self.init(document.root, retrievalURI: retrievalURI, sourceMap: document.sourceMap, limits: limits)
    }
}
