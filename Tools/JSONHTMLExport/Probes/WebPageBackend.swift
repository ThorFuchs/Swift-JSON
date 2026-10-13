// SPDX-License-Identifier: Apache-2.0
// T0 experiment only: compiling/capturing a region does not qualify paginated PDF.
import Foundation
import WebKit
#if os(macOS)
import AppKit
import PDFKit
#endif

struct OfflineNavigation: WebPage.NavigationDeciding {
    @MainActor mutating func decidePolicy(for action: WebPage.NavigationAction,
        preferences: inout WebPage.NavigationPreferences) async -> WKNavigationActionPolicy {
        preferences.allowsContentJavaScript = false
        return action.request.url?.absoluteString == "about:blank" ? .allow : .cancel
    }
}

@main struct BackendProbe {
    @MainActor static func main() async throws {
        #if os(macOS)
        _ = NSApplication.shared
        #endif
        var configuration = WebPage.Configuration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.loadsSubresources = false
        configuration.defaultNavigationPreferences.allowsContentJavaScript = false
        let page = WebPage(configuration: configuration, navigationDecider: OfflineNavigation())
        defer { page.stopLoading() }
        page.mediaType = .print
        let rows = (0..<150).map { "row-\($0): 9007199254740993 é é 😀" }.joined(separator: "\n")
        let html = "<!doctype html><html><head><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; script-src 'none'\"></head><body><pre>\(rows)\nLAST-CONTENT-SENTINEL</pre></body></html>"
        var finished = false
        for try await event in page.load(html: html) {
            if event == .finished { finished = true }
        }
        guard finished else { throw CocoaError(.fileReadUnknown) }
        let data = try await page.exported(as: .pdf(region: .rect(CGRect(x: 0, y: 0, width: 595.28, height: 3_500))))
        guard data.count <= 8_388_608 else { throw CocoaError(.fileWriteOutOfSpace) }
        #if os(macOS)
        let output = URL(fileURLWithPath: CommandLine.arguments[1])
        try data.write(to: output)
        guard let document = PDFDocument(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        let bounds = (0..<document.pageCount).map { document.page(at: $0)!.bounds(for: .mediaBox).debugDescription }
        let text = document.string ?? ""
        print("WEBPAGE_PROBE finished=\(finished) bytes=\(data.count) pages=\(document.pageCount) bounds=\(bounds) sentinel=\(text.contains("LAST-CONTENT-SENTINEL"))")
        #endif
    }
}
