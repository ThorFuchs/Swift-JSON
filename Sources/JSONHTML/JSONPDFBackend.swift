// SPDX-License-Identifier: Apache-2.0
#if canImport(WebKit) && canImport(CoreGraphics)
import Foundation
import WebKit
import CoreGraphics
import CoreText
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@MainActor package protocol JSONPDFPageBackend: AnyObject {
    func load(_ html: String) async throws
    func layout(width: Double) async throws -> JSONPDFGeometry
    func text(maximumBytes: UInt64) async throws -> JSONPDFText
    func capture(_ rectangle: JSONPDFRectangle) async throws -> Data
    func stop()
}

private struct JSONPDFOfflineNavigation: WebPage.NavigationDeciding {
    @MainActor mutating func decidePolicy(for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        preferences.allowsContentJavaScript = false
        return action.request.url?.absoluteString == "about:blank" ? .allow : .cancel
    }
}

@MainActor package final class JSONPDFWebPage: JSONPDFPageBackend {
    private var page: WebPage?
    package init() {
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.loadsSubresources = false
        configuration.defaultNavigationPreferences.allowsContentJavaScript = false
        configuration.deviceSensorAuthorization = .init(decision: .deny)
        let page = WebPage(configuration: configuration, navigationDecider: JSONPDFOfflineNavigation())
        page.mediaType = .print
        self.page = page
    }
    package func load(_ html: String) async throws {
        guard let page else { throw CancellationError() }
        var finished = false
        do {
            for try await event in page.load(html: html) {
                try Task.checkCancellation()
                if event == .finished { finished = true }
            }
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.navigationFailed }
        guard finished else { throw JSONPDFFailure.navigationFailed }
    }
    package func layout(width: Double) async throws -> JSONPDFGeometry {
        guard let page else { throw CancellationError() }
        do {
            // Fixed client-world print-profile code; content JS stays disabled. Fonts
            // readiness and a synchronous layout query replace correctness sleeps.
            let value = try await page.callJavaScript(
                "const s=document.styleSheets[0]; s.insertRule('body{margin:0!important;padding:0!important;width:'+width+'px!important;background:#fff!important;color:#000!important}',s.cssRules.length); s.insertRule('main{margin:0!important}',s.cssRules.length); s.insertRule('h1{display:none!important}',s.cssRules.length); s.insertRule('pre{margin:0!important;white-space:pre-wrap!important;overflow-wrap:anywhere!important;font:11px/16px Menlo,monospace!important}',s.cssRules.length); await document.fonts.ready; const p=document.querySelector('pre'); const r=p.getBoundingClientRect(); return [r.width,r.height,parseFloat(getComputedStyle(p).lineHeight),document.fonts.status==='loaded'?1:0,r.x,r.y];",
                arguments: ["width": width], contentWorld: .defaultClient)
            guard let values = value as? [Double], values.count == 6, values[3] == 1,
                  values[4] == 0, values[5] == 0 else { throw JSONPDFFailure.layoutFailed }
            return .init(width: values[0], height: values[1], lineHeight: values[2])
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.layoutFailed }
    }
    package func text(maximumBytes: UInt64) async throws -> JSONPDFText {
        guard let page else { throw CancellationError() }
        do {
            // The only accepted source is our immutable static HTML. Every child
            // and text unit is bounded by the already admitted HTML byte ceiling.
            let result = try await page.callJavaScript(
                "const c=document.querySelector('pre code'); let n=0,u=0,a=[]; for(const t of c.childNodes){if(++n>cap)return null;let v=t.textContent;u+=v.length;if(u>cap)return null;a.push([t.nodeType===3?'whitespace':t.className,v]);}return [getComputedStyle(document.querySelector('pre')).tabSize,a];",
                arguments: ["cap": maximumBytes], contentWorld: .defaultClient)
            guard let values = result as? [Any], values.count == 2,
                  let tab = values[0] as? String, let tabWidth = Double(tab), (1...8).contains(tabWidth),
                  let rows = values[1] as? [[String]], rows.count <= maximumBytes else { throw JSONPDFFailure.layoutFailed }
            var runs: [JSONPDFTextRun] = []
            for row in rows {
                try Task.checkCancellation()
                guard row.count == 2, ["whitespace", "punctuation", "key", "string", "number", "boolean", "null"].contains(row[0]) else {
                    throw JSONPDFFailure.layoutFailed
                }
                runs.append(.init(kind: row[0], text: row[1]))
            }
            return .init(runs: runs, tabWidth: tabWidth)
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.layoutFailed }
    }
    package func capture(_ rectangle: JSONPDFRectangle) async throws -> Data {
        guard let page else { throw CancellationError() }
        do {
            return try await page.exported(as: .pdf(region: .rect(CGRect(x: rectangle.x,
                y: rectangle.y, width: rectangle.width, height: rectangle.height))))
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.captureFailed }
    }
    package func stop() { page?.stopLoading(); page = nil }
}

// CoreGraphics objects are invocation-owned on a separate actor. A synchronous
// SDK draw may finish after the main-actor deadline; no task-group loser is awaited.
package actor JSONPDFCompositor {
    private var buffer: CFMutableData?
    private var context: CGContext?
    private let width: Double
    private let height: Double
    private let margin: Double
    private var pages: UInt64 = 0
    private var setter: CTFramesetter?
    private var textLength = 0
    private var textOffset = 0
    package func configure(_ source: JSONPDFText) throws {
        try Task.checkCancellation()
        let font = CTFontCreateWithName("Menlo-Regular" as CFString, 11, nil)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = 16; paragraph.maximumLineHeight = 16
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.defaultTabInterval = 6.6 * source.tabWidth
        paragraph.tabStops = []
        let value = NSMutableAttributedString(string: "")
        for run in source.runs {
            try Task.checkCancellation()
            let rgb: (Double, Double, Double)
            switch run.kind {
            case "key": rgb = (102/255.0, 59/255.0, 131/255.0)
            case "string": rgb = (22/255.0, 99/255.0, 58/255.0)
            case "number": rgb = (7/255.0, 94/255.0, 146/255.0)
            case "boolean", "null": rgb = (147/255.0, 70/255.0, 27/255.0)
            default: rgb = (0, 0, 0)
            }
            value.append(NSAttributedString(string: run.text, attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1),
                .paragraphStyle: paragraph]))
        }
        guard value.length > 0 else { throw JSONPDFFailure.layoutFailed }
        textLength = value.length; textOffset = 0
        setter = CTFramesetterCreateWithAttributedString(value)
    }
    package func nextTextPage(contentWidth: Double, contentHeight: Double) throws -> JSONPDFTextPage {
        try Task.checkCancellation()
        guard let setter, textOffset < textLength,
              let data = CFDataCreateMutable(nil, 0), let consumer = CGDataConsumer(data: data) else {
            throw JSONPDFFailure.captureFailed
        }
        var box = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        guard let pageContext = CGContext(consumer: consumer, mediaBox: &box, nil) else { throw JSONPDFFailure.captureFailed }
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: textOffset, length: 0), CGPath(rect: box, transform: nil), nil)
        let range = CTFrameGetVisibleStringRange(frame)
        guard range.location == textOffset, range.length > 0, range.length <= textLength - textOffset else {
            pageContext.closePDF(); throw JSONPDFFailure.layoutFailed
        }
        pageContext.beginPDFPage(nil); CTFrameDraw(frame, pageContext)
        pageContext.endPDFPage(); pageContext.closePDF()
        textOffset += range.length
        let lines = CFArrayGetCount(CTFrameGetLines(frame))
        try Task.checkCancellation()
        let (heightPoints, overflow) = UInt64(lines).multipliedReportingOverflow(by: 16)
        guard !overflow else { throw JSONPDFFailure.counterOverflow(.contentHeightPoints) }
        return .init(data: data as Data, isComplete: textOffset == textLength,
                     utf16Units: UInt64(range.length), heightPoints: heightPoints)
    }
    package init(width: Double, height: Double, margin: Double) throws {
        self.width = width; self.height = height; self.margin = margin
        guard let buffer = CFDataCreateMutable(nil, 0), let consumer = CGDataConsumer(data: buffer) else {
            throw JSONPDFFailure.captureFailed
        }
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, nil) else {
            throw JSONPDFFailure.captureFailed
        }
        self.buffer = buffer; self.context = context
    }
    package func append(_ data: Data, region: JSONPDFRectangle) throws {
        try Task.checkCancellation()
        guard let context, let provider = CGDataProvider(data: data as CFData),
              let source = CGPDFDocument(provider), source.numberOfPages == 1,
              let page = source.page(at: 1), !source.isEncrypted else {
            throw JSONPDFFailure.captureFailed
        }
        let bounds = page.getBoxRect(.mediaBox)
        guard bounds.minX == 0, bounds.minY == 0, abs(bounds.width - region.width) < 0.1, abs(bounds.height - region.height) < 0.1 else {
            throw JSONPDFFailure.captureFailed
        }
        context.beginPDFPage(nil); context.saveGState()
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: margin, y: height - margin - region.height)
        context.drawPDFPage(page)
        context.restoreGState(); context.endPDFPage()
        pages += 1
        try Task.checkCancellation()
    }
    package func finish(maximumBytes: UInt64, expectedPages: UInt64) throws -> Data {
        try Task.checkCancellation()
        guard let context, let buffer, pages == expectedPages else { throw JSONPDFFailure.captureFailed }
        context.closePDF(); self.context = nil; self.buffer = nil; self.setter = nil
        let count = UInt64(CFDataGetLength(buffer))
        try pdfRequire(.pdfBytes, count, maximumBytes)
        // Opaque native buffer materialization; the caller charges accepted bytes
        // before retaining/installing its immutable result.
        let data = buffer as Data
        guard let provider = CGDataProvider(data: data as CFData), let document = CGPDFDocument(provider),
              UInt64(document.numberOfPages) == expectedPages else { throw JSONPDFFailure.captureFailed }
        return data
    }
    package func stop() { context?.closePDF(); context = nil; buffer = nil; setter = nil }
}
#endif
