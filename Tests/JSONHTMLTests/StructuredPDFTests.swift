// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing

@testable import JSONHTML

#if canImport(PDFKit) && canImport(WebKit)
    import PDFKit
    #if canImport(AppKit)
        import AppKit
    #endif
    @Suite(.serialized) struct StructuredApplePDFTests {
        @Test @MainActor func structuredPDFPrintCaptureKeepsMediaMathFullStringsAndTail()
            async throws
        {
            #if canImport(AppKit)
                _ = NSApplication.shared
            #endif
            let url = try #require(
                Bundle.module.url(
                    forResource: "media", withExtension: "json", subdirectory: "Fixtures/Enrichment"
                ))
            guard case .object(let media) = try JSONParser().parse(Array(Data(contentsOf: url)))
            else {
                Issue.record("Missing media fixture")
                return
            }
            let root = JSON.array([
                .object(
                    try JSONObject(members: [
                        JSONMember("image", value: media[JSONKey("pngDataURI")]!),
                        JSONMember("math", value: .string("$x_i^2$")),
                        JSONMember("color", value: .string("#369c")),
                    ])),
                .string(
                    "FIRST " + String(repeating: "long text ", count: 180)
                        + " LAST-CONTENT-SENTINEL"),
            ])
            let original = try JSONExportDocument.prepare(root)
            let hashInput = try original.data(for: .html)
            for layout in [JSONPDFLayout.paginated, .continuous] {
                let report = try await original.preparingPDFWithReport(
                    options: .init(layout: layout))
                let pdf = try #require(PDFDocument(data: report.result.data(for: .pdf)))
                #expect(report.htmlLayout == .structured && report.valueProfile == .complete)
                #expect(report.backend.contains("structured regions"))
                #expect(report.mediaReadiness.contains("decoded"))
                #expect(pdf.pageCount > 0 && UInt64(pdf.pageCount) == report.pageCount)
                let extracted = pdf.string ?? ""
                let compact = extracted.filter { !$0.isWhitespace }
                #expect(compact.contains("LAST-CONTENT-SENTINEL"))  // Native PDF text extraction inserts wrap newlines, including after hyphens.
                #expect(compact.components(separatedBy: "longtext").count - 1 == 180)
                let evidence = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                    .appendingPathComponent(".build/structured-pdf-" + layout.rawValue + ".pdf")
                try report.result.data(for: .pdf).write(to: evidence)
                #expect(try report.result.data(for: .html) == hashInput)
                #expect(report.operation[.nodes] == 0)
            }
        }
        @Test @MainActor func structuredPDFCapsAndFailedRasterDecodeInstallNothing() async throws {
            #if canImport(AppKit)
                _ = NSApplication.shared
            #endif
            let small = try JSONExportDocument.prepare(.null)
            let measured = try await small.preparingPDFWithReport()
            #expect(measured.htmlLayout == .structured && measured.pageCount == 1)
            let inclusive = JSONPDFLimits(
                maxHTMLBytes: measured.inputHTMLBytes, maxCaptureBytes: measured.capturedPDFBytes,
                maxPDFBytes: measured.outputPDFBytes)
            #expect(
                try await small.preparingPDFWithReport(options: .init(limits: inclusive)).pageCount
                    == 1)
            do {
                _ = try await small.preparingPDF(options: .init(limits: .init(maxPages: 0)))
                Issue.record("Expected checked cap")
            } catch { #expect(error is JSONPDFFailure) }
            #expect(!small.availableFormats.contains(.pdf))
            let url = try #require(
                Bundle.module.url(
                    forResource: "sample", withExtension: "jpg", subdirectory: "Fixtures/Enrichment"
                ))
            let jpeg = Array(try Data(contentsOf: url))
            let sof = try #require(
                (0..<(jpeg.count - 1)).first(where: { jpeg[$0] == 255 && jpeg[$0 + 1] == 192 }))
            let length = Int(jpeg[sof + 2]) * 256 + Int(jpeg[sof + 3])
            let damaged = Data(jpeg[..<(sof + 2 + length)] + [255, 217])  // Geometry exists; SOS/entropy data is deliberately absent.
            let undecodable = try JSONExportDocument.prepare(
                .string("data:image/jpeg;base64," + damaged.base64EncodedString()))
            #expect(
                String(decoding: try undecodable.data(for: .html), as: UTF8.self).contains("<img "))
            do {
                _ = try await undecodable.preparingPDF(options: .init(timeoutMilliseconds: 5_000))
                Issue.record("Undecodable raster installed a PDF")
            } catch { #expect(error as? JSONPDFFailure == .layoutFailed) }
            #expect(!undecodable.availableFormats.contains(.pdf))
        }
    }
#endif
