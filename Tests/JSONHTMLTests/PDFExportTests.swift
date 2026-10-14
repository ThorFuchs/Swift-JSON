// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing
@testable import JSONHTML
#if canImport(AppKit)
import AppKit
#endif
#if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
import CoreTransferable
import UniformTypeIdentifiers
#endif
#if canImport(PDFKit) && canImport(WebKit)
import PDFKit
#endif

@Test func exportPDFConfigurationIsFiniteAndRejectsUnsupportedGeometry() throws {
    for margin in [Double.nan, .infinity, -1, 145] {
        #expect(throws: JSONPDFFailure.invalidConfiguration) { try JSONPDFOptions(marginPoints: margin).validate() }
    }
    #expect(throws: JSONPDFFailure.invalidConfiguration) { try JSONPDFOptions(timeoutMilliseconds: 600_001).validate() }
    for limits in [JSONPDFLimits(maxHTMLBytes: .max), .init(maxCaptureBytes: .max),
                   .init(maxPDFBytes: .max), .init(maxPreparedBytes: .max), .init(maxPages: .max),
                   .init(maxContentHeightPoints: 14_401)] {
        #expect(throws: JSONPDFFailure.invalidConfiguration) { try limits.validate() }
    }
    try JSONPDFOptions(marginPoints: 0, timeoutMilliseconds: 0,
        limits: .init(maxHTMLBytes: 0, maxCaptureBytes: 0, maxPDFBytes: 0,
                      maxPreparedBytes: 0, maxPages: 0, maxContentHeightPoints: 0)).validate()
}

@Test func exportPDFRequiresExplicitPreparationAndRetainsOriginalCapPolicy() throws {
    #expect(throws: JSONExportFailure.preparationRequired(.pdf)) {
        try JSONExportDocument.prepare(.null, options: .init(formats: [.html, .pdf]))
    }
    let item = try JSONExportDocument.prepare(.null)
    #expect(item.availableFormats == [.json, .html, .plainText, .markdown])
    #expect(throws: JSONExportFailure.unavailableFormat(.pdf)) { try item.data(for: .pdf) }
    #expect(throws: JSONExportFailure.unavailableFormat(.pdf)) { try item.selecting([.pdf]) }
}

@Test func exportPDFCheckedCountersRejectOverflowAndUseInclusiveLimits() throws {
    #expect(try pdfAdd(.pdfBytes, 2, 3, 5) == 5)
    #expect(throws: JSONPDFFailure.limitExceeded(.pdfBytes, limit: 4, attempted: 5)) { try pdfAdd(.pdfBytes, 2, 3, 4) }
    #expect(throws: JSONPDFFailure.counterOverflow(.preparedBytes)) { try pdfAdd(.preparedBytes, .max, 1, .max) }
}

@Test @MainActor func exportPDFMissingHTMLNeverRerendersOrAltersSelection() async throws {
    let original = try JSONExportDocument.prepare(.null, options: .init(formats: [.json]))
    #expect(throws: JSONPDFFailure.missingHTML) { try original.pdfInput() }
    do { _ = try await original.preparingPDF(); Issue.record("Missing HTML was silently regenerated") }
    catch { #expect(error as? JSONPDFFailure == .missingHTML) }
    #expect(original.availableFormats == [.json] && original.advertisedFormats == [.json])
}

#if canImport(PDFKit) && canImport(WebKit)
@MainActor private func pdfBootstrap() {
    #if canImport(AppKit)
    _ = NSApplication.shared
    #endif
}
@MainActor private func pdfFixture(_ count: Int = 150) throws -> JSONExportDocument {
    let values = (0..<count).map { JSON.string("ROW-\($0)-END 9007199254740993 é e\u{301} 😀 العربية </script>") }
    return try JSONExportDocument.prepare(.array(values + [.string("LAST-CONTENT-SENTINEL")]))
}
@Suite(.serialized) struct ApplePDFTests {
@Test @MainActor func applePDFPaginatedA4AndLetterHaveCompleteSelectableRegions() async throws {
    pdfBootstrap()
    let original = try pdfFixture()
    for paper in [JSONPDFPaper.a4, .usLetter] {
        let report = try await original.preparingPDFWithReport(options: .init(paper: paper))
        let data = try report.result.data(for: .pdf)
        let pdf = try #require(PDFDocument(data: data))
        #expect(report.pageCount == UInt64(pdf.pageCount) && report.pageCount >= 3)
        let text = try #require(pdf.string)
        for index in 0..<150 { #expect(text.components(separatedBy: "ROW-\(index)-END").count == 2) }
        #expect(text.contains("9007199254740993") && text.contains("LAST-CONTENT-SENTINEL"))
        #expect(pdf.page(at: pdf.pageCount - 1)?.string?.contains("LAST-CONTENT-SENTINEL") == true)
        for index in 0..<pdf.pageCount {
            let page = try #require(pdf.page(at: index))
            #expect(abs(page.bounds(for: .mediaBox).width - paper.width) < 0.1)
            #expect(abs(page.bounds(for: .mediaBox).height - paper.height) < 0.1)
        }
        #expect(try report.result.data(for: .json) == original.data(for: .json))
        #expect(!original.availableFormats.contains(.pdf))
        #expect(report.operation[.nodes] == 0 && report.operation[.inputBytes] == report.inputHTMLBytes)
        #expect(report.operation[.outputBytes] == report.capturedPDFBytes + report.outputPDFBytes)
    }
}

@Test @MainActor func applePDFContinuousIsExplicitAndAllSixRootsRemainVisible() async throws {
    pdfBootstrap()
    let long = try pdfFixture()
    let continuous = try await long.preparingPDFWithReport(options: .init(layout: .continuous))
    let pdf = try #require(PDFDocument(data: continuous.result.data(for: .pdf)))
    #expect(pdf.pageCount == 1 && continuous.pageCount == 1)
    #expect(try #require(pdf.page(at: 0)).bounds(for: .mediaBox).height > 2_000)
    #expect(pdf.string?.contains("LAST-CONTENT-SENTINEL") == true)
    for source in ["null", "true", "9007199254740993", #""é😀{}\\""#, "[]", "{}"] {
        let item = try JSONExportDocument.prepare(JSONParser().parse(source))
        let result = try await item.preparingPDF()
        let document = try #require(PDFDocument(data: result.data(for: .pdf)))
        #expect(document.pageCount == 1 && !(document.string ?? "").isEmpty)
    }
}

@Test @MainActor func applePDFWrapsWideContentAndHonorsZeroAndWideMargins() async throws {
    pdfBootstrap()
    let root: JSON = .string("FIRST-SENTINEL " + String(repeating: "https://example.test/long-key-😀-e\u{301}/", count: 300) + " LAST-CONTENT-SENTINEL")
    let item = try JSONExportDocument.prepare(root)
    for margin in [0.0, 144.0] {
        let report = try await item.preparingPDFWithReport(options: .init(marginPoints: margin))
        let pdf = try #require(PDFDocument(data: report.result.data(for: .pdf)))
        #expect(pdf.pageCount > 1)
        #expect(pdf.page(at: 0)?.string?.contains("FIRST-SENTINEL") == true)
        #expect(pdf.page(at: pdf.pageCount - 1)?.string?.contains("LAST-CONTENT-SENTINEL") == true)
    }
}

@Test @MainActor func applePDFNativeCapsRejectPartialArtifactsAndPreserveOriginal() async throws {
    pdfBootstrap()
    let item = try pdfFixture()
    let originalJSON = try item.data(for: .json)
    let cases = [
        JSONPDFLimits(maxHTMLBytes: 0), .init(maxCaptureBytes: 1), .init(maxPDFBytes: 1),
        .init(maxPreparedBytes: 1), .init(maxPages: 1), .init(maxContentHeightPoints: 1)
    ]
    for limits in cases {
        do { _ = try await item.preparingPDF(options: .init(limits: limits)); Issue.record("Restrictive PDF cap accepted output") }
        catch { #expect(error is JSONPDFFailure || error is JSONFailure) }
        #expect(try item.data(for: .json) == originalJSON && !item.availableFormats.contains(.pdf))
    }
}

@Test @MainActor func applePDFCancellationAtEveryStageDoesNotInstallOutput() async throws {
    pdfBootstrap()
    let item = try pdfFixture(80)
    for stage in [JSONPDFStage.input, .loading, .layout, .extraction, .capture, .composition, .installation] {
        var task: Task<JSONPDFPreparationReport, any Error>?
        var extractionVisits = 0
        task = Task { @MainActor in
            try await item.preparingPDFWithReport(options: .init(), factory: { JSONPDFWebPage() },
                observer: { observed in
                    if observed == .extraction { extractionVisits += 1 }
                    if observed == stage && (stage != .extraction || extractionVisits >= 3) { task?.cancel() }
                })
        }
        do { _ = try await task!.value; Issue.record("Cancellation accepted PDF at \(stage)") }
        catch { #expect(error is CancellationError) }
        #expect(!item.availableFormats.contains(.pdf))
    }
}

@Test @MainActor func applePDFOwnedBudgetsAreCumulativeAndInclusive() async throws {
    pdfBootstrap()
    let item = try JSONExportDocument.prepare(.string("é e\u{301} 😀 exact 9007199254740993"))
    let baseline = try await item.preparingPDFWithReport()
    #expect(baseline.operation[.workUnits] > baseline.inputHTMLBytes + baseline.outputPDFBytes)
    let resultBytes = baseline.existingPreparedBytes + baseline.outputPDFBytes
    #expect(baseline.operation[.retainedBytes] == resultBytes + UInt64(item.filenameStem.utf8.count) + 16 + UInt64(baseline.result.availableFormats.count) * 48)
    for metric in [JSONResourceMetric.inputBytes, .workUnits, .outputBytes, .retainedBytes] {
        var core = JSONLimits.balanced
        let ceiling = metric == .retainedBytes ? baseline.operation.peakLogicalRetainedBytes : baseline.operation[metric]
        core[metric] = ceiling
        let exact = try await item.preparingPDFWithReport(options: .init(limits: .init(core: core)))
        #expect(exact.pageCount == 1)
        core[metric] = ceiling - 1
        do { _ = try await item.preparingPDF(options: .init(limits: .init(core: core))); Issue.record("Nested PDF helper reset \(metric)") }
        catch { #expect((error as? JSONFailure)?.resource?.metric == metric) }
    }
}

@Test @MainActor func applePDFHiddenHTMLAndReplacementPreserveImmutablePolicy() async throws {
    pdfBootstrap()
    let original = try JSONExportDocument.prepare(.null).selecting([.json])
    let first = try await original.preparingPDFWithReport()
    #expect(first.result.advertisedFormats == [.json, .pdf] && first.result.availableFormats.count == 5)
    let second = try await first.result.preparingPDFWithReport()
    #expect(second.result.availableFormats.count == 5 && second.existingPreparedBytes == first.existingPreparedBytes + first.outputPDFBytes)
    #expect(try second.result.data(for: .json) == original.data(for: .json))
    let sum = try original.pdfInput().bytes
    let tight = try JSONExportDocument.prepare(.null, options: .init(limits: .init(maxPreparedBytes: sum)))
    do { _ = try await tight.preparingPDF(); Issue.record("Original aggregate cap was widened") }
    catch { #expect((error as? JSONPDFFailure) != nil) }
    #expect(!tight.availableFormats.contains(.pdf))
}

@Test @MainActor func applePDFFailureAndImmediateDeadlineNeverAdvertiseAnArtifact() async throws {
    pdfBootstrap()
    let item = try JSONExportDocument.prepare(.null)
    do { _ = try await item.preparingPDF(options: .init(timeoutMilliseconds: 0)); Issue.record("Expired deadline accepted PDF") }
    catch { #expect(error as? JSONPDFFailure == .timedOut) }
    // Real iOS emoji fallback produced height 162 with nominal 16-point lines.
    // Pagination uses CoreText visible ranges, not a WebKit line-grid assumption.
    let nonGrid = SuspendedPDFBackend(ready: {})
    nonGrid.geometryHeight = 18.25
    let complete = try await item.preparingPDFWithReport(options: .init(), factory: { nonGrid }, observer: nil)
    #expect(complete.pageCount == 1 && nonGrid.stopped)
    let broken = SuspendedPDFBackend(ready: {})
    broken.failure = .captureFailed
    do { _ = try await item.preparingPDFWithReport(options: .init(layout: .continuous), factory: { broken }, observer: nil); Issue.record("Failed capture accepted PDF") }
    catch { #expect(error as? JSONPDFFailure == .captureFailed && broken.stopped) }
    #expect(!item.availableFormats.contains(.pdf))
}

@Test @MainActor func applePDFTransferOffersOnlyPreparedSelectedBytes() async throws {
    pdfBootstrap()
    let item = try JSONExportDocument.prepare(.null)
    let report = try await item.preparingPDFWithReport()
    #if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
    let selected = try report.result.selecting([.pdf])
    #expect(selected.exportedContentTypes() == [.pdf])
    #expect(try await selected.exported(as: .pdf) == report.result.data(for: .pdf))
    do { _ = try await item.exported(as: .pdf); Issue.record("Unprepared transfer generated PDF") } catch {}
    do { _ = try await report.result.selecting([.json]).exported(as: .pdf); Issue.record("Hidden PDF transferred") } catch {}
    #endif
}

@MainActor private final class SuspendedPDFBackend: JSONPDFPageBackend {
    var pending: CheckedContinuation<Data, any Error>?
    var stopped = false
    var failure: JSONPDFFailure?
    var geometryHeight: Double = 16
    let ready: @MainActor () -> Void
    init(ready: @escaping @MainActor () -> Void) { self.ready = ready }
    func load(_ html: String) async throws {}
    func layout(width: Double) async throws -> JSONPDFGeometry { .init(width: width, height: geometryHeight, lineHeight: 16) }
    func textInfo() async throws -> JSONPDFTextInfo { .init(count: 1, tabWidth: 4) }
    func textRun(at index: Int) async throws -> JSONPDFTextRun { .init(kind: "null", text: "null") }
    func capture(_ rectangle: JSONPDFRectangle) async throws -> Data {
        if let failure { throw failure }
        return try await withCheckedThrowingContinuation { pending = $0; ready() }
    }
    func stop() { stopped = true }
}
@Test @MainActor func applePDFTimeoutReturnsWithoutWaitingForUncooperativeCapture() async throws {
    pdfBootstrap()
    let item = try JSONExportDocument.prepare(.null)
    let backend = SuspendedPDFBackend(ready: {})
    let start = ContinuousClock.now
    do {
        _ = try await item.preparingPDFWithReport(options: .init(layout: .continuous, timeoutMilliseconds: 100),
            factory: { backend }, observer: nil)
        Issue.record("Uncooperative capture did not time out")
    } catch { #expect(error as? JSONPDFFailure == .timedOut) }
    #expect(start.duration(to: .now) < .seconds(2) && backend.stopped)
    // Resume the ignored late result so the qualification probe leaves no hung task.
    backend.pending?.resume(returning: Data()); backend.pending = nil
    await Task.yield()
    #expect(!item.availableFormats.contains(.pdf))
}

@Test @MainActor func applePDFSimultaneousJobsHaveIndependentStateAndCancellation() async throws {
    pdfBootstrap()
    let item = try pdfFixture(80)
    let stopped = SuspendedPDFBackend(ready: {})
    let cancelled = Task { @MainActor in
        try await item.preparingPDFWithReport(options: .init(layout: .continuous), factory: { stopped }, observer: nil)
    }
    while stopped.pending == nil { await Task.yield() }
    let successful = Task { @MainActor in try await item.preparingPDFWithReport() }
    cancelled.cancel()
    do { _ = try await cancelled.value; Issue.record("Cancelled job returned PDF") }
    catch { #expect(error is CancellationError && stopped.stopped) }
    stopped.pending?.resume(returning: Data()); stopped.pending = nil
    let result = try await successful.value
    #expect(result.pageCount > 1 && result.result.availableFormats.contains(.pdf))
}
}
#else
@Test @MainActor func exportPDFUnavailableBackendRemainsUnadvertised() async throws {
    let item = try JSONExportDocument.prepare(.null)
    do { _ = try await item.preparingPDF(); Issue.record("Unsupported platform advertised PDF") }
    catch { #expect(error as? JSONPDFFailure == .backendUnavailable) }
    #expect(!item.availableFormats.contains(.pdf))
}
#endif
