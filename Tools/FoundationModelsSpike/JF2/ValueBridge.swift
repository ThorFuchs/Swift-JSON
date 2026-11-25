// SPDX-License-Identifier: Apache-2.0
import JSON

/// Candidate only. Fixed reasons never retain caller text or framework errors.
public enum JSONGeneratedContentBridgeFailure: Error, Sendable, Equatable {
    case incompleteContent
    case changedValue
    case frameworkRejected
}

// Internal policy seam: the foreign callbacks are synchronous and opaque.
// Tests can inject a changed export without impersonating FoundationModels.
// This target is grafted into the Swift-JSON package, so its native helpers
// share the package-scoped meter. No new public core APIs are needed here.
enum JF2ValueBoundary {
    static func export<Content>(_ value: JSON, limits: JSONLimits,
        make: (String) throws -> Content, read: (Content) throws -> String
    ) throws -> JSONOperationReport<Content> {
        try JSON.withComposition(limits: limits) { scope in
            let text = try scope.withMeter(domain: .writing) { meter in
                let bytes = try JSONWriter().write(value, meter: &meter)
                // Reserve the adapter-owned String copy before construction.
                try meter.retain(UInt64(bytes.count))
                for _ in bytes { try meter.work() }
                return String(decoding: bytes, as: UTF8.self)
            }
            try scope.checkpoint()
            let candidate = try make(text)
            try scope.checkpoint()
            let exported = try read(candidate)
            try scope.checkpoint()
            let returned = try parse(exported, scope: scope)
            // Writer and parser already admitted the two graphs. Comparison
            // uses the same invocation meter, not ordinary unmetered ==.
            let equal = try scope.withMeter { meter in
                try JSONComparison.equals(value, returned, meter: &meter)
            }
            guard equal else { throw JSONGeneratedContentBridgeFailure.changedValue }
            return candidate
        }
    }

    static func importValue(limits: JSONLimits, read: () throws -> String
    ) throws -> JSONOperationReport<JSON> {
        try JSON.withComposition(limits: limits) { scope in
            try scope.checkpoint()
            let exported = try read()
            try scope.checkpoint()
            return try parse(exported, scope: scope)
        }
    }

    private static func parse(_ text: String, scope: borrowing JSONCompositionScope) throws -> JSON {
        try scope.withMeter(domain: .parsing) { meter in
            try meter.beginCompositionDocument()
            var bytes: [UInt8] = []
            for byte in text.utf8 {
                try meter.work()
                try meter.require(.inputBytes, UInt64(bytes.count) + 1)
                // Conservative visible foreign text plus owned UTF-8 copy.
                // The framework has already allocated its opaque String.
                try meter.retain(2)
                bytes.append(byte)
            }
            return try JSONParser().parse(bytes, meter: &meter)
        }
    }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

/// Candidate exact JSON-value export and completed JSON-representation import.
/// Not a promise to preserve generation IDs, object order, number spellings or
/// the framework's hidden representation. Native accounting excludes opaque
/// framework callbacks and their allocation/work. No model is invoked.
@available(macOS 27.0, iOS 27.0, *)
public struct JSONGeneratedContentBridge: Sendable {
    public let limits: JSONLimits

    public init(limits: JSONLimits = .balanced) { self.limits = limits }

    public func generatedContent(from value: JSON) throws -> GeneratedContent {
        try generatedContentWithReport(from: value).result
    }

    public func generatedContentWithReport(from value: JSON) throws -> JSONOperationReport<GeneratedContent> {
        try JF2ValueBoundary.export(value, limits: limits, make: { text in
            do { return try GeneratedContent(json: text) }
            catch is CancellationError { throw CancellationError() }
            catch {
                try Task.checkCancellation()
                throw JSONGeneratedContentBridgeFailure.frameworkRejected
            }
        }, read: Self.completedJSON)
    }

    public func json(from content: GeneratedContent) throws -> JSON {
        try jsonWithReport(from: content).result
    }

    public func jsonWithReport(from content: GeneratedContent) throws -> JSONOperationReport<JSON> {
        try JF2ValueBoundary.importValue(limits: limits) { try Self.completedJSON(content) }
    }

    private static func completedJSON(_ content: GeneratedContent) throws -> String {
        guard content.isComplete else { throw JSONGeneratedContentBridgeFailure.incompleteContent }
        return content.jsonString
    }
}
#endif
