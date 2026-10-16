// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON

#if canImport(WebKit) && canImport(CoreGraphics)
    import Synchronization
#endif

extension JSONExportDocument {
    /// Explicitly prepares a complete Apple PDF from this item's own static HTML.
    ///
    /// This is a second operation with its own finite cumulative budget. The original
    /// item remains valid on failure. PDF is added only after complete pagination.
    /// Native SDK work may outlive cancellation/deadline; late results are discarded.
    /// - Parameters:
    ///   - options: Qualified geometry, finite capacities and responsiveness policy.
    /// - Returns: A new immutable document with PDF available and advertised.
    /// - Throws: Missing HTML, configuration, capacity, backend or cancellation failure.
    @available(macOS 26.0, iOS 26.0, *)
    @MainActor public func preparingPDF(options: JSONPDFOptions = .init()) async throws -> Self {
        try await preparingPDFWithReport(options: options).result
    }

    /// Explicitly prepares PDF with owned accounting and actual native output details.
    /// - Parameters:
    ///   - options: Qualified geometry, finite capacities and responsiveness policy.
    /// - Returns: Complete immutable artifacts and a distinct PDF operation report.
    /// - Throws: Missing HTML, configuration, capacity, backend or cancellation failure.
    @available(macOS 26.0, iOS 26.0, *)
    @MainActor public func preparingPDFWithReport(options: JSONPDFOptions = .init()) async throws
        -> JSONPDFPreparationReport
    {
        #if canImport(WebKit) && canImport(CoreGraphics)
            return try await preparingPDFWithReport(
                options: options, factory: { JSONPDFWebPage() }, observer: nil)
        #else
            try Task.checkCancellation()
            try options.validate()
            _ = try pdfInput()
            throw JSONPDFFailure.backendUnavailable
        #endif
    }

    #if canImport(WebKit) && canImport(CoreGraphics)
        @available(macOS 26.0, iOS 26.0, *)
        @MainActor package func preparingPDFWithReport(
            options: JSONPDFOptions,
            factory: @escaping @MainActor () -> any JSONPDFPageBackend,
            observer: (@MainActor (JSONPDFStage) -> Void)?
        ) async throws -> JSONPDFPreparationReport {
            try Task.checkCancellation()
            try options.validate()
            let job = try JSONPDFJob(
                document: self, options: options, factory: factory, observer: observer)
            return try await job.run()
        }
    #endif
}

#if canImport(WebKit) && canImport(CoreGraphics)
    @available(macOS 26.0, iOS 26.0, *)
    private final class JSONPDFCancellationState: Sendable {
        private let state = Mutex(false)
        func cancel() { state.withLock { $0 = true } }
        var isCancelled: Bool { state.withLock { $0 } }
    }
    @available(macOS 26.0, iOS 26.0, *)
    @MainActor private final class JSONPDFJob {
        private var document: JSONExportDocument?
        private let options: JSONPDFOptions
        private let factory: @MainActor () -> any JSONPDFPageBackend
        private let observer: (@MainActor (JSONPDFStage) -> Void)?
        private var meter: JSONWorkMeter
        private var backend: (any JSONPDFPageBackend)?
        private var compositor: JSONPDFCompositor?
        private var worker: Task<Void, Never>?
        private var timer: Task<Void, Never>?
        private var continuation: CheckedContinuation<JSONPDFPreparationReport, any Error>?
        private var terminal = false
        private let cancellation = JSONPDFCancellationState()
        private let started = ContinuousClock.now
        private let deadline: ContinuousClock.Instant
        private var ownedSinceCheck: UInt64 = 0

        init(
            document: JSONExportDocument, options: JSONPDFOptions,
            factory: @escaping @MainActor () -> any JSONPDFPageBackend,
            observer: (@MainActor (JSONPDFStage) -> Void)?
        ) throws {
            self.document = document
            self.options = options
            self.factory = factory
            self.observer = observer
            meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
            deadline = started.advanced(by: .milliseconds(Int64(options.timeoutMilliseconds)))
        }
        func run() async throws -> JSONPDFPreparationReport {
            try Task.checkCancellation()
            let cancellation = self.cancellation
            return try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                    worker = Task { [self] in
                        do { finish(.success(try await prepare())) } catch {
                            finish(.failure(error))
                        }
                    }
                    timer = Task { [weak self, deadline] in
                        do {
                            try await ContinuousClock().sleep(until: deadline)
                            self?.finish(.failure(JSONPDFFailure.timedOut))
                        } catch { /* terminal path cancels only this invocation's timer */  }
                    }
                }
            } onCancel: {
                cancellation.cancel()
                Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) }
            }
        }
        private func finish(_ result: Result<JSONPDFPreparationReport, any Error>) {
            guard !terminal else { return }
            let result: Result<JSONPDFPreparationReport, any Error> =
                cancellation.isCancelled
                ? .failure(CancellationError()) : result
            terminal = true
            if case .failure(let error) = result { meter.recordFailure(error) }
            backend?.stop()
            backend = nil
            if let compositor { Task { await compositor.stop() } }
            compositor = nil
            document = nil
            timer?.cancel()
            timer = nil
            worker?.cancel()
            worker = nil
            continuation?.resume(with: result)
            continuation = nil
        }
        private func check() throws {
            guard !terminal, !cancellation.isCancelled else { throw CancellationError() }
            try meter.checkpoint()
            if ContinuousClock.now >= deadline { throw JSONPDFFailure.timedOut }
        }
        private func advance(_ stage: JSONPDFStage) throws {
            try check()
            observer?(stage)
            try check()
        }
        private func work() throws {
            try meter.work()
            ownedSinceCheck += 1
            if ownedSinceCheck >= 1_024 {
                ownedSinceCheck = 0
                try check()
            }
        }
        private func retainBytes(_ bytes: Data, output: Bool) throws {
            for _ in bytes {
                try work()
                if output { try meter.charge(.outputBytes) }
                try meter.retain(1)
            }
            try check()
        }
        private func prepare() async throws -> JSONPDFPreparationReport {
            try advance(.input)
            guard let document else { throw CancellationError() }
            try meter.work(UInt64(document.availableFormats.count))
            let input = try document.pdfInput()
            try pdfRequire(.htmlBytes, UInt64(input.html.count), options.limits.maxHTMLBytes)
            try pdfRequire(.pages, 1, options.limits.maxPages)
            try pdfRequire(.pdfBytes, 1, min(options.limits.maxPDFBytes, input.representationLimit))
            try pdfRequire(
                .preparedBytes, input.bytes - input.previousPDFBytes,
                min(options.limits.maxPreparedBytes, input.preparedLimit))
            try meter.retain(input.bytes)
            let inputMetadata =
                UInt64(document.filenameStem.utf8.count) + 16 + UInt64(
                    document.availableFormats.count) * 48
            try meter.retain(inputMetadata)
            for _ in input.html {
                try work()
                try meter.charge(.inputBytes)
                try meter.retain(1)
            }
            let html = String(decoding: input.html, as: UTF8.self)
            let width = floor(options.paper.width - 2 * options.marginPoints)
            try advance(.loading)
            try meter.work(8)
            let backend = factory()
            self.backend = backend
            try await backend.load(html)
            try advance(.layout)
            try meter.work(UInt64(input.html.count))
            try work()
            let geometry = try await backend.layout(width: width)
            try check()
            guard geometry.width.isFinite, geometry.height.isFinite, geometry.lineHeight.isFinite,
                abs(geometry.width - width) < 0.1, geometry.height > 0,
                abs(geometry.lineHeight - 16) < 0.01
            else {
                throw JSONPDFFailure.layoutFailed
            }
            let maximumHeight =
                options.layout == .continuous
                ? min(
                    options.limits.maxContentHeightPoints,
                    UInt64(floor(14_400 - 2 * options.marginPoints)))
                : options.limits.maxContentHeightPoints
            guard geometry.height < Double(UInt64.max) else {
                throw JSONPDFFailure.counterOverflow(.contentHeightPoints)
            }
            try pdfRequire(.contentHeightPoints, UInt64(ceil(geometry.height)), maximumHeight)
            let chunk =
                options.layout == .continuous
                ? geometry.height
                : floor((options.paper.height - 2 * options.marginPoints) / 16) * 16
            let pageCount = UInt64(ceil(geometry.height / chunk))
            try pdfRequire(.pages, pageCount, options.limits.maxPages)
            let height =
                options.layout == .continuous
                ? geometry.height + 2 * options.marginPoints : options.paper.height
            let compositor = try JSONPDFCompositor(
                width: options.paper.width, height: height, margin: options.marginPoints)
            self.compositor = compositor
            var captured: UInt64 = 0
            var actualPages: UInt64 = 0
            var textReservation: UInt64 = 0
            if options.layout == .paginated && document.htmlPolicy?.layout != .structured {
                // Fixed client script and conversion loops are conservatively admitted
                // under this same meter, before native extraction/attributed layout.
                try meter.work(UInt64(input.html.count))
                try advance(.extraction)
                let info = try await backend.textInfo()
                try check()
                guard info.count > 0, UInt64(info.count) <= UInt64(input.html.count) else {
                    throw JSONPDFFailure.layoutFailed
                }
                var runs: [JSONPDFTextRun] = []
                var textBytes: UInt64 = 0
                for index in 0..<info.count {
                    try advance(.extraction)
                    try work()
                    let run = try await backend.textRun(at: index)
                    try check()
                    textBytes = try pdfAdd(
                        .htmlBytes, textBytes, UInt64(run.text.utf8.count), UInt64(input.html.count)
                    )
                    try meter.retain(96)
                    textReservation += 96
                    for _ in run.text.utf16 {
                        try work()
                        try meter.retain(4)
                        textReservation += 4
                    }
                    // Admit source/attributed reservations before owned array growth.
                    runs.append(run)
                }
                try await compositor.configure(.init(runs: runs, tabWidth: info.tabWidth))
                var complete = false
                var contentHeight: UInt64 = 0
                while !complete {
                    try advance(.capture)
                    try work()
                    actualPages = try pdfAdd(.pages, actualPages, 1, options.limits.maxPages)
                    let page = try await compositor.nextTextPage(
                        contentWidth: width, contentHeight: chunk)
                    try check()
                    contentHeight = try pdfAdd(
                        .contentHeightPoints, contentHeight, page.heightPoints,
                        options.limits.maxContentHeightPoints)
                    captured = try pdfAdd(
                        .captureBytes, captured, UInt64(page.data.count),
                        options.limits.maxCaptureBytes)
                    try retainBytes(page.data, output: true)
                    try advance(.composition)
                    try work()
                    try await compositor.append(
                        page.data, region: .init(x: 0, y: 0, width: width, height: chunk))
                    try check()
                    try meter.release(UInt64(page.data.count))
                    complete = page.isComplete
                }
            } else {
                var spans: [JSONPDFFragment] = []
                if options.layout == .paginated {
                    try advance(.extraction)
                    try work()
                    try meter.retain(128)
                    textReservation += 128
                    try await backend.beginFragments(height: chunk)
                    var complete = false
                    while !complete {
                        try advance(.extraction)
                        try work()
                        switch try await backend.nextFragment() {
                        case .end: complete = true
                        case .advance: break
                        case .span(let span):
                            guard span.top.isFinite, span.bottom.isFinite, span.top >= 0,
                                span.bottom >= span.top, span.bottom <= geometry.height + 1
                            else { throw JSONPDFFailure.layoutFailed }
                            guard UInt64(spans.count) < UInt64(input.html.count) else {
                                throw JSONPDFFailure.layoutFailed
                            }
                            try meter.retain(32)
                            textReservation += 32
                            spans.append(span)
                        }
                    }
                }
                try work()
                let captureRows = try await backend.captureRowCount()
                guard captureRows >= 0, UInt64(captureRows) <= UInt64(input.html.count) else {
                    throw JSONPDFFailure.layoutFailed
                }
                var offset = 0.0
                while offset < geometry.height {
                    try advance(.capture)
                    try work()
                    var end = min(offset + chunk, geometry.height)
                    if options.layout == .paginated && end < geometry.height {
                        // Cut through actual whitespace between line/media bounds. A tall
                        // unbreakable fragment is an explicit layout failure, never a syntax fallback.
                        var changed = true
                        while changed {
                            changed = false
                            for span in spans {
                                try work()
                                if span.top < end && span.bottom > end {
                                    end = floor(span.top)
                                    changed = true
                                }
                            }
                        }
                        guard end > offset else { throw JSONPDFFailure.layoutFailed }
                    }
                    let region = JSONPDFRectangle(
                        x: 0, y: offset, width: width, height: end - offset)
                    for index in 0..<captureRows {
                        try advance(.capture)
                        try work()
                        try await backend.setCaptureVisibility(at: index, region: region)
                    }
                    let bytes = try await backend.capture(region)
                    try check()
                    captured = try pdfAdd(
                        .captureBytes, captured, UInt64(bytes.count), options.limits.maxCaptureBytes
                    )
                    try retainBytes(bytes, output: true)
                    try advance(.composition)
                    try work()
                    try await compositor.append(bytes, region: region)
                    try check()
                    try meter.release(UInt64(bytes.count))
                    actualPages = try pdfAdd(.pages, actualPages, 1, options.limits.maxPages)
                    offset += region.height
                }
            }
            try advance(.composition)
            try work()
            let pdf = try await compositor.finish(
                maximumBytes: min(options.limits.maxPDFBytes, input.representationLimit),
                expectedPages: actualPages)
            try check()
            _ = try pdfAdd(
                .preparedBytes, input.bytes - input.previousPDFBytes, UInt64(pdf.count),
                min(options.limits.maxPreparedBytes, input.preparedLimit))
            try retainBytes(pdf, output: true)
            try advance(.installation)
            // Shared immutable Data still receives a separate logical result reservation.
            try meter.retain(input.bytes - input.previousPDFBytes)
            try retainBytes(pdf, output: false)
            let resultCount =
                document.availableFormats.count + (document.availableFormats.contains(.pdf) ? 0 : 1)
            try meter.retain(
                UInt64(document.filenameStem.utf8.count) + 16 + UInt64(resultCount) * 48)
            try work()
            let result = document.addingPDF(pdf)
            try meter.release(
                input.bytes + UInt64(input.html.count) + UInt64(pdf.count) + textReservation
                    + inputMetadata)
            try check()
            return .init(
                result: result, operation: meter.statistics(),
                inputHTMLBytes: UInt64(input.html.count),
                existingPreparedBytes: input.bytes, capturedPDFBytes: captured,
                outputPDFBytes: UInt64(pdf.count), pageCount: actualPages,
                backend: document.htmlPolicy?.layout == .structured
                    ? "WebPage forced print structured regions + line/media bounds + scoped row visibility + clipped CoreGraphics"
                    : options.layout == .paginated
                        ? "WebPage static syntax + CoreText visible ranges + CoreGraphics"
                        : "WebPage continuous region + CoreGraphics",
                htmlLayout: document.htmlPolicy?.layout ?? .syntax,
                valueProfile: document.htmlPolicy?.printValueProfile ?? .complete,
                fontReadiness: "document.fonts.ready loaded",
                mediaReadiness: "print images decoded before layout/capture",
                elapsed: started.duration(to: .now))
        }
    }
#endif
