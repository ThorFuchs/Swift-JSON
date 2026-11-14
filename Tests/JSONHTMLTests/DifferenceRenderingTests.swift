// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONHTML

private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }
private func page(_ source: String, _ target: String, options: JSONHTMLRenderingOptions = .init()) throws -> String {
    String(decoding: try JSONHTMLRenderer(options: options).renderDifference(from: parse(source), to: parse(target)), as: UTF8.self)
}
/// Decodes the base64 payload of the first data link whose download name matches.
private func download(_ html: String, named name: String) throws -> String {
    let marker = "download=\"\(name)\" href=\"data:"
    let start = try #require(html.range(of: marker)).upperBound
    let comma = try #require(html[start...].range(of: "base64,")).upperBound
    let end = try #require(html[comma...].firstIndex(of: "\""))
    return String(decoding: try #require(Data(base64Encoded: String(html[comma..<end]))), as: UTF8.self)
}

@Test func differencePageMarksAddedRemovedAndChangedValues() throws {
    let html = try page(#"{"keep":1,"drop":"x","change":{"n":1,"s":"a"},"list":[1,2,3]}"#,
                        #"{"keep":1.0,"change":{"n":2,"s":"a"},"list":[1,3],"new":true}"#)
    #expect(html.contains("1 added</span>") && html.contains("2 removed</span>") && html.contains("1 changed</span>"))
    #expect(html.contains("diff-row diff-added") && html.contains("diff-row diff-removed") && html.contains("diff-row diff-changed"))
    // Markers carry text, not only color.
    #expect(html.contains("<span class=\"visually-hidden\">Added: </span>"))
    #expect(html.contains("<span class=\"visually-hidden\">Removed: </span>"))
    #expect(html.contains("<span class=\"visually-hidden\">Changed from </span>"))
    // Equal decimals are unchanged; the unchanged member stays visible but collapsible.
    #expect(html.contains("diff-row diff-same"))
    // The change list links each change by its Pointer, in tree order.
    for (index, pointer) in ["/drop", "/change/n", "/list/1", "/new"].enumerated() {
        #expect(html.contains("<a href=\"#jd-c-\(index)\">"))
        #expect(html.contains("<code>\(pointer)</code>"))
        #expect(html.contains("id=\"jd-c-\(index)\""))
    }
    #expect(!html.contains("id=\"jd-c-4\""))
}

@Test func differencePageDownloadsTheExactPatchAndBothDocuments() throws {
    let html = try page(#"{"a":[0,1,2,3,4],"b":1.50}"#, #"{"a":[0,4],"b":1.50,"c/d":null}"#)
    #expect(try download(html, named: "patch.json") ==
            #"[{"op":"remove","path":"/a/3"},{"op":"remove","path":"/a/2"},{"op":"remove","path":"/a/1"},{"op":"add","path":"/c~1d","value":null}]"#)
    // Native exact bytes: the preserved lexeme survives.
    #expect(try download(html, named: "source.json").contains("1.50"))
    #expect(try download(html, named: "target.json").contains("\"c/d\""))
    #expect(html.contains("Elements #0 unchanged") || html.contains("Element #0 unchanged"))
}

@Test func differencePageIsStaticEscapedAndHashAuthorized() throws {
    let html = try page(#"{"<script>":"</p>"}"#, #"{"<script>":"<b>&"}"#, options: .init(title: "A <b> & c", presentation: .interactive))
    #expect(!html.contains("<script>") && !html.contains("<b>"))
    #expect(html.contains("&lt;script&gt;") && html.contains("A &lt;b&gt; &amp; c"))
    #expect(html.contains("script-src 'none'"))
    #expect(html.contains("style-src 'sha256-\(JSONHTMLInteractiveAssets.styleHash)' 'sha256-\(JSONHTMLDifferenceAssets.cssHash)'"))
    // The CSP hash matches the exact embedded stylesheet bytes.
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    let hex = try JSONSHA256Core.hexadecimal(JSONHTMLDifferenceAssets.css.utf8, accounting: &meter)
    var digest: [UInt8] = []
    var index = hex.startIndex
    while index < hex.endIndex {
        let next = hex.index(index, offsetBy: 2)
        digest.append(try #require(UInt8(hex[index..<next], radix: 16))); index = next
    }
    #expect(Data(digest).base64EncodedString() == JSONHTMLDifferenceAssets.cssHash)
    #expect(html.contains("<style>" + JSONHTMLDifferenceAssets.css + "</style>"))
}

@Test func equalValuesRenderNoDifferences() throws {
    let html = try page(#"{"a":[1,{"b":null}],"z":1.0}"#, #"{"z":1,"a":[1,{"b":null}]}"#)
    #expect(html.contains("No differences: both values are equal."))
    #expect(!html.contains("jd-c-") && !html.contains("id=\"jd-only\""))
    #expect(try download(html, named: "patch.json") == "[]")
    // A root kind change is one replacement.
    let root = try page("[1]", #"{"a":1}"#)
    #expect(root.contains("0 added</span>") && root.contains("1 changed</span>") && root.contains("<code>(root)</code>"))
}

@Test func differenceRenderingIsBoundedAndReported() throws {
    let source = try parse(#"{"a":[1,2,3],"b":"x"}"#), target = try parse(#"{"a":[1,3],"b":"y","c":true}"#)
    let report = try JSONHTMLRenderer().renderDifferenceWithReport(from: source, to: target)
    #expect(report.statistics.documentBytes == UInt64(report.result.count))
    #expect(report.statistics.outlineEntries == 3)
    var options = JSONHTMLRenderingOptions()
    options.limits.maxDocumentBytes = 2_000
    do { _ = try JSONHTMLRenderer(options: options).renderDifference(from: source, to: target); Issue.record("Expected a document size failure") }
    catch let failure as JSONHTMLFailure { #expect(failure == .limitExceeded(.documentBytes, limit: 2_000, attempted: 2_001)) }
    options = .init(); options.title = "bad\u{7}"
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try JSONHTMLRenderer(options: options).renderDifference(from: source, to: target) }
}

@Test func cancelledDifferenceRenderingThrowsCancellation() async {
    let wide = JSON.array((0..<5_000).map { .number(JSONNumber(integer: $0)) })
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        _ = try JSONHTMLRenderer().renderDifference(from: wide, to: .array([]))
    }
    task.cancel()
    do { try await task.value; Issue.record("Cancelled rendering must throw") }
    catch { #expect(error is CancellationError) }
}
