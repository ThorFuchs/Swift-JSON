// SPDX-License-Identifier: Apache-2.0
#if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
import CoreTransferable
import Foundation
import JSON
import UniformTypeIdentifiers

extension JSON: Transferable {
    /// Fixed finite JSON, static HTML, UTF-8 text and Markdown representations.
    ///
    /// Only native JSON imports. Each request owns an independent invocation;
    /// closures prepare no PDF and mutate no shared cache. Numeric lexemes and
    /// insertion order are preserved. Generic text negotiation is system policy.
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(contentType: .json) { value in
            try JSONExportDocument.prepare(value, options: .init(formats: [.json])).data(for: .json)
        } importing: { data in
            try JSONParser(options: .init(limits: .balanced)).parse(data)
        }.suggestedFileName("JSON.json")
        DataRepresentation(exportedContentType: .html) { value in
            try JSONExportDocument.prepare(value, options: .init(formats: [.html])).data(for: .html)
        }.suggestedFileName("JSON.html")
        DataRepresentation(exportedContentType: .utf8PlainText) { value in
            try JSONExportDocument.prepare(value, options: .init(formats: [.plainText])).data(for: .plainText)
        }.suggestedFileName("JSON.txt")
        DataRepresentation(exportedContentType: .markdown) { value in
            try JSONExportDocument.prepare(value, options: .init(formats: [.markdown])).data(for: .markdown)
        }.suggestedFileName("JSON.md")
    }
}

extension JSONExportDocument: Transferable {
    /// Export-only prepared bytes; per-item conditions omit hidden or absent artifacts.
    ///
    /// No transfer closure renders or changes the document. Static type discovery
    /// describes possible representations; instance discovery respects selection.
    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { try $0.transferData(for: .json) }
            .exportingCondition { $0.advertisedFormats.contains(.json) }
            .suggestedFileName { $0.filenameStem + ".json" }
        DataRepresentation(exportedContentType: .html) { try $0.transferData(for: .html) }
            .exportingCondition { $0.advertisedFormats.contains(.html) }
            .suggestedFileName { $0.filenameStem + ".html" }
        DataRepresentation(exportedContentType: .rtf) { try $0.transferData(for: .rtf) }
            .exportingCondition { $0.advertisedFormats.contains(.rtf) }
            .suggestedFileName { $0.filenameStem + ".rtf" }
        DataRepresentation(exportedContentType: .utf8PlainText) { try $0.transferData(for: .plainText) }
            .exportingCondition { $0.advertisedFormats.contains(.plainText) }
            .suggestedFileName { $0.filenameStem + ".txt" }
        DataRepresentation(exportedContentType: .markdown) { try $0.transferData(for: .markdown) }
            .exportingCondition { $0.advertisedFormats.contains(.markdown) }
            .suggestedFileName { $0.filenameStem + ".md" }
    }
}
#endif
