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
    func textInfo() async throws -> JSONPDFTextInfo
    func textRun(at index: Int) async throws -> JSONPDFTextRun
    func beginFragments() async throws
    func nextFragment() async throws -> JSONPDFFragmentStep
    func capture(_ rectangle: JSONPDFRectangle) async throws -> Data
    func stop()
}

extension JSONPDFPageBackend {
    package func beginFragments() async throws { throw JSONPDFFailure.layoutFailed }
    package func nextFragment() async throws -> JSONPDFFragmentStep { throw JSONPDFFailure.layoutFailed }
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
        // Generated artifacts have default-src none and img-src data: only when
        // native media was admitted. Permit those data images; no remote source is emitted.
        configuration.loadsSubresources = true
        configuration.defaultNavigationPreferences.allowsContentJavaScript = false
        configuration.deviceSensorAuthorization = .init(decision: .deny)
        let page = WebPage(configuration: configuration, navigationDecider: JSONPDFOfflineNavigation())
        page.mediaType = .print
        self.page = page
    }
    package func load(_ html: String) async throws {
        guard let page else { throw CancellationError() }
        var events = 0
        do {
            for try await event in page.load(html: html) {
                try Task.checkCancellation()
                events += 1
                guard events <= 8 else { throw JSONPDFFailure.navigationFailed }
                if event == .finished { return }
            }
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.navigationFailed }
        throw JSONPDFFailure.navigationFailed
    }
    package func layout(width: Double) async throws -> JSONPDFGeometry {
        guard let page else { throw CancellationError() }
        do {
            // Fixed client-world print-profile code; content JS stays disabled. Fonts
            // readiness and a synchronous layout query replace correctness sleeps.
            let value = try await page.callJavaScript(
                "const s=document.styleSheets[0]; s.insertRule('body{margin:0!important;padding:0!important;width:'+width+'px!important;background:#fff!important;color:#000!important}',s.cssRules.length); s.insertRule('main{margin:0!important;padding:0!important;max-width:none!important}',s.cssRules.length); s.insertRule('h1{display:none!important}',s.cssRules.length); s.insertRule('.rich .print-json{display:flow-root!important;margin:0!important;padding:0!important}',s.cssRules.length); s.insertRule('.rich .source-download,.rich .screen-view,.rich .document-header,.rich .exact-source,.rich .view-tabs,.rich .preview-issues,.rich .toolbar,.rich #jh-status,.rich .search-results,.rich dialog,.rich noscript{display:none!important}',s.cssRules.length); s.insertRule('pre{margin:0!important;white-space:pre-wrap!important;overflow-wrap:anywhere!important;font:11px/16px Menlo,monospace!important}',s.cssRules.length); await document.fonts.ready; const images=document.querySelectorAll('.print-json img'); for(const image of images){await image.decode();if(!image.complete||image.naturalWidth===0)throw new Error('Image decode failed');} const rich=document.body.classList.contains('rich'); const p=rich?document.querySelector('.print-json'):document.querySelector('pre'); const r=p.getBoundingClientRect(); return [r.width,r.height,16,document.fonts.status==='loaded'?1:0,r.x,r.y];",
                arguments: ["width": width], contentWorld: .defaultClient)
            guard let values = value as? [Double], values.count == 6, values[3] == 1,
                  values[4] == 0, values[5] == 0 else { throw JSONPDFFailure.layoutFailed }
            return .init(width: values[0], height: ceil(values[1]), lineHeight: values[2])
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.layoutFailed }
    }
    package func textInfo() async throws -> JSONPDFTextInfo {
        guard let page else { throw CancellationError() }
        do {
            let result = try await page.callJavaScript(
                "return [getComputedStyle(document.querySelector('pre')).tabSize,document.querySelector('pre code').childNodes.length];",
                contentWorld: .defaultClient)
            guard let values = result as? [Any], values.count == 2,
                  let tab = values[0] as? String, let tabWidth = Double(tab), (1...8).contains(tabWidth),
                  let count = values[1] as? Int, count > 0 else { throw JSONPDFFailure.layoutFailed }
            return .init(count: count, tabWidth: tabWidth)
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.layoutFailed }
    }
    package func textRun(at index: Int) async throws -> JSONPDFTextRun {
        guard let page else { throw CancellationError() }
        do {
            // One native DOM primitive per call: no uninterruptible owned JS loop
            // and no owned run array allocated outside the job's cumulative meter.
            let result = try await page.callJavaScript(
                "const t=document.querySelector('pre code').childNodes.item(index);if(!t)return null;return [t.nodeType===3?'whitespace':t.className,t.textContent];",
                arguments: ["index": index], contentWorld: .defaultClient)
            guard let row = result as? [String], row.count == 2,
                  ["whitespace", "punctuation", "key", "string", "number", "boolean", "null"].contains(row[0]) else {
                throw JSONPDFFailure.layoutFailed
            }
            return .init(kind: row[0], text: row[1])
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.layoutFailed }
    }
    package func beginFragments() async throws {
        guard let page else { throw CancellationError() }
        do {
            _ = try await page.callJavaScript("const root=document.querySelector('.print-json'); window.__jhPDFScan={walker:document.createTreeWalker(root,NodeFilter.SHOW_TEXT),rects:null,index:0,media:root.querySelectorAll('img,math'),mediaIndex:0}; return 1;", contentWorld: .defaultClient)
        } catch is CancellationError { throw CancellationError() }
        catch { throw JSONPDFFailure.layoutFailed }
    }
    package func nextFragment() async throws -> JSONPDFFragmentStep {
        guard let page else { throw CancellationError() }
        do {
            // At most one text node/media element/rectangle per invocation. DOM
            // lists are SDK state; no owned JavaScript loop or generated array grows.
            let value = try await page.callJavaScript("const s=window.__jhPDFScan;if(s.rects&&s.index<s.rects.length){const r=s.rects.item(s.index++);return [1,r.top,r.bottom];}const n=s.walker.nextNode();if(n){const r=document.createRange();r.selectNodeContents(n);s.rects=r.getClientRects();s.index=0;return [0,0,0];}if(s.mediaIndex<s.media.length){const r=s.media.item(s.mediaIndex++).getBoundingClientRect();return [1,r.top,r.bottom];}delete window.__jhPDFScan;return [2,0,0];", contentWorld: .defaultClient)
            guard let values = value as? [Double], values.count == 3 else { throw JSONPDFFailure.layoutFailed }
            switch values[0] {
            case 0: return .advance
            case 1: return .span(.init(top: values[1], bottom: values[2]))
            case 2: return .end
            default: throw JSONPDFFailure.layoutFailed
            }
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
        // Safety: the SDK initializer reads one live, initialized CGRect during
        // this synchronous call. No pointer is retained in Swift or crosses actors.
        var box = CGRect(x: 0, y: 0, width: contentWidth, height: contentHeight)
        guard let pageContext = unsafe CGContext(consumer: consumer, mediaBox: &box, nil) else { throw JSONPDFFailure.captureFailed }
        let path = CGMutablePath(); path.addRect(box)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: textOffset, length: 0), path, nil)
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
        // Safety: the SDK initializer reads one live, initialized CGRect during
        // this synchronous call. No pointer is retained in Swift or crosses actors.
        var box = CGRect(x: 0, y: 0, width: width, height: height)
        guard let context = unsafe CGContext(consumer: consumer, mediaBox: &box, nil) else {
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
