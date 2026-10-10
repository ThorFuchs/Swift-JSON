// SPDX-License-Identifier: Apache-2.0
import JSON
/// Immutable explicitly supplied resources. No network fetch or process-global cache.
public struct JSONSchemaRegistry: Sendable {
    public let documents: [JSONSchemaDocument]
    public static let empty = Self(admitted: [])
    public init(documents: [JSONSchemaDocument] = [], limits: JSONLimits = .balanced) throws {
        var meter = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
        try meter.require(.schemaDocuments, UInt64(documents.count))
        var admitted: [JSONSchemaDocument] = [], uris: [JSONSchemaURI] = []
        for document in documents {
            guard let uri = document.retrievalURI else { throw JSONSchemaCompilationFailure(.identifier) }
            let key = try uri.withoutFragment(meter: &meter)
            for previous in uris {
                if try JSONComparison.textEquals(previous.string, key.string, meter: &meter) { throw JSONSchemaCompilationFailure(.identifier) }
            }
            try meter.resetValueBounds(); try JSONAdmission.value(document.raw, meter: &meter, owned: true)
            try meter.work(); try meter.retain(JSONLogicalWeights.frame)
            admitted.append(document); uris.append(key)
        }
        self.documents = admitted
    }
    public func adding(_ document: JSONSchemaDocument, limits: JSONLimits = .balanced) throws -> Self {
        var meter = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
        try meter.require(.schemaDocuments, UInt64(documents.count) + 1)
        var copy: [JSONSchemaDocument] = []
        for item in documents { try meter.work(); try meter.retain(JSONLogicalWeights.frame); copy.append(item) }
        try meter.retain(JSONLogicalWeights.frame); copy.append(document)
        return try Self.checked(copy, meter: &meter)
    }
    package static func checked(_ documents: [JSONSchemaDocument], meter: inout JSONWorkMeter) throws -> Self {
        var keys: [JSONSchemaURI] = []
        for document in documents {
            guard let uri = document.retrievalURI else { throw JSONSchemaCompilationFailure(.identifier) }
            let key = try uri.withoutFragment(meter: &meter)
            for previous in keys { if try JSONComparison.textEquals(previous.string, key.string, meter: &meter) { throw JSONSchemaCompilationFailure(.identifier) } }
            try meter.resetValueBounds(); try JSONAdmission.value(document.raw, meter: &meter, owned: true)
            try meter.work(); try meter.retain(JSONLogicalWeights.frame); keys.append(key)
        }
        return Self(admitted: documents)
    }
    package init(admitted documents: [JSONSchemaDocument]) { self.documents = documents }
}
