// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONHTML

// The revision changes direct defaults; these unchanged exact-syntax invariants
// explicitly select the original formatted syntax contract.
private func syntaxRenderer(options: JSONHTMLRenderingOptions = .init()) -> JSONHTMLRenderer {
    var explicit = options; explicit.layout = .syntax; explicit.presentation = .formatted
    return JSONHTMLRenderer(options: explicit)
}
// Independent text extraction: fixed span markup is removed before decoding entities.
private func body(_ html: String) throws -> [UInt8] {
    let start = try #require(html.range(of: "<pre><code>"))
    let end = try #require(html.range(of: "</code></pre>", range: start.upperBound..<html.endIndex))
    var text = String(html[start.upperBound..<end.lowerBound])
    while let span = text.range(of: "<span class=\""), let close = text[span.lowerBound...].firstIndex(of: ">") {
        text.removeSubrange(span.lowerBound...close)
    }
    text = text.replacingOccurrences(of: "</span>", with: "")
    for (entity, decoded) in [("&lt;", "<"), ("&gt;", ">"), ("&quot;", "\""), ("&#39;", "'"), ("&amp;", "&")] {
        text = text.replacingOccurrences(of: entity, with: decoded)
    }
    return Array(text.utf8)
}

@Test func formattedHTMLHandlesSixRootsAndEmptyContainers() throws {
    for text in ["null", "false", "9007199254740993", #""é\u0000""#, "[true,null]", #"{"a":1}"#, "[]", "{}"] {
        let root = try JSONParser().parse(text)
        let html = try syntaxRenderer().renderString(root)
        #expect(html.hasPrefix("<!doctype html>"))
        #expect(html.hasSuffix("</html>\n"))
        #expect(!html.contains("<script"))
        let expected = try JSONWriter(options: .init(indentation: 2, numberStyle: .preserved)).write(root)
        #expect(try body(html) == Array(expected))
        #expect(try JSONParser().parse(body(html)) == root)
    }
}

@Test func formattedHTMLPreservesExactLexemesScalarKeysAndInsertionOrder() throws {
    let text = #"{"é":9007199254740993,"é":-0.00e+2,"":1.2300E-7,"0":"é","__proto__":true,"constructor":null}"#
    let root = try JSONParser().parse(text)
    let actual = try body(syntaxRenderer().renderString(root))
    let expected = "{\n  \"é\": 9007199254740993,\n  \"e\u{301}\": -0.00e+2,\n  \"\": 1.2300E-7,\n  \"0\": \"e\u{301}\",\n  \"__proto__\": true,\n  \"constructor\": null\n}"
    #expect(actual == Array(expected.utf8)) // Swift String equality alone normalizes scalars.
    #expect(try body(syntaxRenderer().renderString(.number(42))) == Array("42".utf8))
}

@Test func formattedHTMLKeepsPayloadAndTitleInert() throws {
    let payload = "</script></style><img src=x onerror=alert(1)> &quot; & < > \" ' \u{0}\n\t😀"
    let options = JSONHTMLRenderingOptions(title: "</title><script>boom</script>&\"'")
    let html = try syntaxRenderer(options: options).renderString(.string(payload))
    #expect(!html.contains("<script>"))
    #expect(!html.contains("<img"))
    #expect(html.contains("&lt;/style&gt;"))
    #expect(html.contains("&amp;quot;"))
    #expect(try body(html) == Array(JSONWriter(options: .init(numberStyle: .preserved)).write(.string(payload))))
    let hostileKey = "\r\n\u{0}\t</style>&\"'"
    let keyed = try JSONObject(members: [JSONMember(hostileKey, value: .string("e\u{301}"))])
    let keyedHTML = try syntaxRenderer().renderString(.object(keyed))
    #expect(!keyedHTML.contains("<script>"))
    let expectedKeyed = "{\n  \"\\u000d\\u000a\\u0000\\u0009</style>&\\\"'\": \"e\u{301}\"\n}"
    #expect(try body(keyedHTML) == Array(expectedKeyed.utf8))
    #expect(html.components(separatedBy: "<style>").count == 2)
    #expect(html.components(separatedBy: "</style>").count == 2)
    #expect(html.contains("script-src 'none'"))
    #expect(html.contains("default-src 'none'"))
    #expect(!html.contains("src=\""))
}

@Test func formattedHTMLTabsAreBytesAndThemesAreFixedClasses() throws {
    let root: JSON = .array([.array([.null])])
    for theme in [JSONHTMLTheme.automatic, .light, .dark] {
        let options = JSONHTMLRenderingOptions(theme: theme, indentation: 1, indentationUnit: .tabs, tabWidth: 8)
        let html = try syntaxRenderer(options: options).renderString(root)
        #expect(try body(html) == Array("[\n\t[\n\t\tnull\n\t]\n]".utf8))
        #expect(html.contains("class=\"" + theme.rawValue + " tabs-8\""))
    }
}

@Test func formattedHTMLDataAndStringReportsShareOneAdmissionAndCopyBudget() throws {
    let root: JSON = .array([true, .null, .string("x")])
    let renderer = syntaxRenderer()
    let data = try renderer.renderWithReport(root)
    let text = try renderer.renderStringWithReport(root)
    #expect(data.result == Data(text.result.utf8))
    #expect(data.statistics == text.statistics)
    #expect(data.statistics.renderedJSONNodes == 4)
    #expect(data.statistics.operation[.nodes] == 4)
    #expect(data.statistics.documentBytes == UInt64(data.result.count))
    #expect(data.statistics.operation[.outputBytes] == data.statistics.documentBytes)
    #expect(data.statistics.operation[.retainedBytes] == data.statistics.documentBytes)
    #expect(data.statistics.operation.peakLogicalRetainedBytes == data.statistics.documentBytes * 2)
}

@Test func formattedHTMLAdditionalCapsHaveInclusiveBoundaries() throws {
    let root: JSON = .array([true, .null])
    let report = try syntaxRenderer().renderWithReport(root)
    for metric in [JSONHTMLResourceMetric.documentBytes, .renderedJSONNodes, .domNodes] {
        let boundary: UInt64 = switch metric {
        case .documentBytes: report.statistics.documentBytes
        case .renderedJSONNodes: report.statistics.renderedJSONNodes
        case .domNodes: report.statistics.domNodeUpperBound
        case .outlineEntries: report.statistics.outlineEntries
        case .metadataBytes: report.statistics.metadataBytes
        case .annotations: report.statistics.annotations
        }
        for delta in [-1, 0, 1] {
            var limits = JSONHTMLLimits()
            let cap = UInt64(Int64(boundary) + Int64(delta))
            switch metric {
            case .documentBytes: limits.maxDocumentBytes = cap
            case .renderedJSONNodes: limits.maxRenderedJSONNodes = cap
            case .domNodes: limits.maxDOMNodes = cap
            case .outlineEntries: limits.maxOutlineEntries = cap
            case .metadataBytes: limits.maxMetadataBytes = cap
            case .annotations: limits.maxAnnotations = cap
            }
            let renderer = syntaxRenderer(options: .init(limits: limits))
            if delta < 0 {
                do { _ = try renderer.render(root); Issue.record("Missing HTML cap refusal") }
                catch let error as JSONHTMLFailure {
                    guard case .limitExceeded(let actual, let limit, let attempted) = error else { Issue.record("Wrong failure"); continue }
                    #expect(actual == metric && limit == cap && attempted > cap)
                }
            } else { #expect(try renderer.render(root) == report.result) }
        }
    }
}

@Test func formattedHTMLCoreCapsIncludeEscapingAssetsAndFinalCopies() throws {
    let root: JSON = .string("<&\"'")
    let report = try syntaxRenderer().renderWithReport(root)
    for metric in [JSONResourceMetric.workUnits, .retainedBytes, .outputBytes] {
        let boundary = metric == .retainedBytes ? report.statistics.operation.peakLogicalRetainedBytes : report.statistics.operation[metric]
        for delta in [-1, 0, 1] {
            var limits = JSONHTMLLimits()
            limits.core[metric] = UInt64(Int64(boundary) + Int64(delta))
            let renderer = syntaxRenderer(options: .init(limits: limits))
            if delta < 0 {
                do { _ = try renderer.render(root); Issue.record("Missing cumulative refusal") }
                catch let error as JSONFailure { #expect(error.resource?.metric == metric && error.resource?.domain == .writing) }
            } else { #expect(try renderer.render(root) == report.result) }
        }
    }
}

@Test func formattedHTMLRejectsUnsupportedConfigurationAndZeroCaps() throws {
    for options in [JSONHTMLRenderingOptions(indentation: -1), .init(indentation: 9), .init(tabWidth: 0), .init(tabWidth: 9), .init(title: "bad\n"), .init(title: "bad\u{7f}")] {
        #expect(throws: JSONHTMLFailure.invalidConfiguration) { try syntaxRenderer(options: options).render(.null) }
    }
    for limits in [JSONHTMLLimits(maxRenderedJSONNodes: 0), .init(maxDOMNodes: 0), .init(maxDocumentBytes: 0)] {
        #expect(throws: JSONHTMLFailure.self) { try syntaxRenderer(options: .init(limits: limits)).render(.null) }
    }
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try syntaxRenderer(options: .init(limits: .init(maxDocumentBytes: UInt64.max))).render(.null) }
    #expect(throws: JSONHTMLFailure.counterOverflow(.domNodes)) { try JSONHTMLDocumentBuffer.adding(.domNodes, UInt64.max, 1, UInt64.max) }
}

@Test func formattedHTMLFailureCleansScratchAndLatchesTheEnclosingMeter() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    try meter.retain(17)
    let renderer = syntaxRenderer(options: .init(limits: .init(maxDocumentBytes: 100)))
    #expect(throws: JSONHTMLFailure.self) { try renderer.render(.null, meter: &meter) }
    #expect(meter.used(.retainedBytes) == 17)
    let work = meter.used(.workUnits)
    #expect(throws: JSONHTMLFailure.self) { try renderer.render(.null, meter: &meter) }
    #expect(meter.used(.workUnits) == work)
    try meter.release(17)
}

@Test func formattedHTMLCancellationOccursInsideEmissionAndRemainsTerminal() async throws {
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
        try meter.retain(17)
        meter.checkpointObserver = { work in
            if work >= 512 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        #expect(throws: CancellationError.self) { try syntaxRenderer().render(.null, meter: &meter) }
        #expect(meter.used(.workUnits) >= 512 && meter.used(.outputBytes) > 0)
        #expect(meter.used(.retainedBytes) == 17)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
        try meter.release(17)
    }
    try await task.value
}

@Test func formattedHTMLDeepAndWideValuesRemainComplete() throws {
    var deep: JSON = .string("last-sentinel")
    for _ in 0..<80 { deep = .array([deep]) }
    let wide = try JSONObject(members: (0..<400).map { JSONMember("k\($0)", value: .number(JSONNumber(integer: $0))) })
    for root in [deep, .object(wide)] {
        let html = try syntaxRenderer().renderString(root)
        #expect(try body(html) == Array(JSONWriter(options: .init(indentation: 2, numberStyle: .preserved)).write(root)))
    }
    #expect(try syntaxRenderer().renderWithReport(deep).statistics.renderedJSONNodes == 81)
}

@Test func sharedFormattedHTMLRendererHasIndependentConcurrentInvocations() async throws {
    for mode in [JSONHTMLPresentation.formatted, .interactive] {
    var options = JSONHTMLRenderingOptions(presentation: mode); options.layout = .syntax
    let renderer = JSONHTMLRenderer(options: options)
    let root = try JSONParser().parse(#"{"é":9007199254740993,"é":[-0.00e+2,null]}"#)
    let expected = try renderer.renderWithReport(root)
    try await withThrowingTaskGroup(of: JSONHTMLRenderReport<Data>.self) { group in
        for _ in 0..<16 { group.addTask { try renderer.renderWithReport(root) } }
        var count = 0
        for try await actual in group {
            #expect(actual.result == expected.result && actual.statistics == expected.statistics)
            count += 1
        }
        #expect(count == 16)
    }
    }
}

@Test func formattedHTMLCSPHashesTheExactEmittedOriginalCSS() throws {
    let html = try syntaxRenderer().renderString(.null)
    let start = try #require(html.range(of: "<style>"))
    let end = try #require(html.range(of: "</style>"))
    let css = Array(html[start.upperBound..<end.lowerBound].utf8)
    #expect(css.count == 1304)
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    let digest = try JSONSHA256Core.hexadecimal(css, accounting: &meter)
    #expect(digest == "76028a04ba9ec6d2546671ed2b97e9bb31cbd6754c9b8c1900c10c26eb20374a")
    // This independent known answer was computed with Python hashlib, not the renderer.
    #expect(html.contains("style-src 'sha256-dgKKBLqextJUZnHtK5fpuzHL1nVMm4wZAMEMJusgN0o='"))
    #expect(!String(decoding: css, as: UTF8.self).contains("url("))
    #expect(String(decoding: css, as: UTF8.self).contains("@media print{body.light,body.dark,body.automatic{"))
}
