// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONHTML

private func interactive(_ limits: JSONHTMLLimits = .init(), depth: Int? = 3) -> JSONHTMLRenderer {
    .init(options: .init(limits: limits, presentation: .interactive, outlineDepth: depth))
}
private func attribute(_ html: String, after marker: String, name: String) throws -> [UInt8] {
    let element = try #require(html.range(of: marker))
    let start = try #require(html.range(of: name + "=\"", range: element.lowerBound..<html.endIndex))
    let end = try #require(html[start.upperBound...].firstIndex(of: "\""))
    return Array(try #require(Data(base64Encoded: String(html[start.upperBound..<end]))))
}
private func exact(_ root: JSON) throws -> [UInt8] {
    Array(try JSONWriter(options: .init(indentation: 2, numberStyle: .preserved)).write(root))
}

@Test func interactiveHTMLRetainsOriginalInitializerFunctionShapes() throws {
    let optionsFactory: (String, JSONHTMLTheme, Int, JSONIndentationUnit, Int, JSONHTMLLimits) -> JSONHTMLRenderingOptions = JSONHTMLRenderingOptions.init
    let limitsFactory: (JSONLimits, UInt64, UInt64, UInt64) -> JSONHTMLLimits = JSONHTMLLimits.init
    let limits = limitsFactory(.balanced, 100, 1000, 100_000)
    let options = optionsFactory("Old", .light, 2, .spaces, 4, limits)
    #expect(options.presentation == .formatted)
    let report = try JSONHTMLRenderer(options: options).renderStringWithReport(.null)
    #expect(!report.result.contains("<script>"))
    #expect(report.statistics.outlineEntries == 0 && report.statistics.metadataBytes == 0 && report.statistics.copyJSONBytes == 0)
}

@Test func interactiveHTMLCopiesAllRootKindsFromNativeWriter() throws {
    for text in ["null", "true", "9007199254740993", #""é\u0000""#, "[-0.00e+2,null]", #"{"a":1,"b":1.2300e+2}"#, "[]", "{}"] {
        let root = try JSONParser().parse(text)
        let report = try interactive().renderStringWithReport(root)
        let copy = try attribute(report.result, after: "id=\"jh-copy-json\"", name: "data-bytes")
        #expect(try copy == exact(root))
        #expect(report.statistics.copyJSONBytes == UInt64(copy.count))
        #expect(report.result.hasSuffix("</script></body></html>\n"))
    }
}

@Test func interactiveHTMLPointersPreserveScalarControlsAndRFC6901Escapes() throws {
    let root = try JSONParser().parse(#"{"~1/a\u0000\r\n":[{"0":1}],"é":2,"é":3}"#)
    let html = try interactive().renderString(root)
    let vectors = ["", "/~01~1a\u{0}\r\n", "/~01~1a\u{0}\r\n/0", "/~01~1a\u{0}\r\n/0/0", "/é", "/é"]
    for (index, pointer) in vectors.enumerated() {
        #expect(try attribute(html, after: "id=\"jh-n-\(index)\"", name: "data-pointer") == Array(pointer.utf8))
        let quoted = try attribute(html, after: "id=\"jh-n-\(index)\"", name: "data-pointer-escaped")
        #expect(try quoted == Array(JSONWriter().write(.string(pointer))))
    }
    #expect(!html.contains("id=\"/"))
}

@Test func interactiveHTMLDisclosuresAndOutlineUseGeneratedOrdinals() throws {
    let root = try JSONParser().parse(#"{"a":[{"b":true}],"empty":{}}"#)
    let renderer = JSONHTMLRenderer(options: .init(presentation: .interactive, initiallyExpandedDepth: 1, outlineDepth: 1))
    let report = try renderer.renderStringWithReport(root)
    #expect(report.statistics.renderedJSONNodes == 5 && report.statistics.operation[.nodes] == 5)
    #expect(report.statistics.outlineEntries == 3)
    #expect(report.result.components(separatedBy: " open>").count - 1 == 1)
    #expect(report.result.components(separatedBy: "<details ").count - 1 == 4)
    #expect(!report.result.contains("<details name="))
    #expect(report.result.contains("data-target=\"jh-n-4\" href=\"#jh-n-4\""))
}

@Test func interactiveHTMLOutlineCanBeOmittedWithoutLosingTreeOrCopy() throws {
    var limits = JSONHTMLLimits(); limits.maxOutlineEntries = 0
    let root: JSON = .array([.array([.null])])
    let report = try interactive(limits, depth: nil).renderStringWithReport(root)
    #expect(report.statistics.outlineEntries == 0 && report.statistics.renderedJSONNodes == 3)
    #expect(!report.result.contains("<nav"))
    #expect(try attribute(report.result, after: "id=\"jh-copy-json\"", name: "data-bytes") == exact(root))
    #expect(throws: JSONHTMLFailure.limitExceeded(.outlineEntries, limit: 0, attempted: 1)) { try interactive(limits).render(root) }
}

@Test func interactiveHTMLMetadataOutlineAndHTMLBoundariesAreInclusive() throws {
    let root: JSON = .array([.object(try JSONObject(members: [JSONMember("key", value: .number(42))]))])
    let report = try interactive().renderWithReport(root)
    for metric in [JSONHTMLResourceMetric.outlineEntries, .metadataBytes, .documentBytes, .domNodes, .renderedJSONNodes] {
        let boundary: UInt64
        switch metric {
        case .outlineEntries: boundary = report.statistics.outlineEntries
        case .metadataBytes: boundary = report.statistics.metadataBytes
        case .annotations: boundary = report.statistics.annotations
        case .documentBytes: boundary = report.statistics.documentBytes
        case .domNodes: boundary = report.statistics.domNodeUpperBound
        case .renderedJSONNodes: boundary = report.statistics.renderedJSONNodes
        }
        for cap in [boundary - 1, boundary, boundary + 1] {
            var limits = JSONHTMLLimits()
            switch metric {
            case .outlineEntries: limits.maxOutlineEntries = cap
            case .metadataBytes: limits.maxMetadataBytes = cap
            case .annotations: limits.maxAnnotations = cap
            case .documentBytes: limits.maxDocumentBytes = cap
            case .domNodes: limits.maxDOMNodes = cap
            case .renderedJSONNodes: limits.maxRenderedJSONNodes = cap
            }
            if cap < boundary { #expect(throws: JSONHTMLFailure.self) { try interactive(limits).render(root) } }
            else { #expect(try interactive(limits).render(root) == report.result) }
        }
    }
}

@Test func interactiveHTMLSharesWorkOutputAndRetentionAcrossEveryTraversal() throws {
    let root = try JSONParser().parse(#"{"key":[1,2,3],"exact":9007199254740993}"#)
    let report = try interactive().renderWithReport(root)
    #expect(report.statistics.operation[.nodes] == 6)
    #expect(report.statistics.operation[.outputBytes] > report.statistics.documentBytes + report.statistics.copyJSONBytes)
    #expect(report.statistics.operation[.retainedBytes] == report.statistics.documentBytes)
    for metric in [JSONResourceMetric.workUnits, .outputBytes, .retainedBytes] {
        let boundary = metric == .retainedBytes ? report.statistics.operation.peakLogicalRetainedBytes : report.statistics.operation[metric]
        for cap in [boundary - 1, boundary, boundary + 1] {
            var limits = JSONHTMLLimits(); limits.core[metric] = cap
            if cap < boundary { #expect(throws: JSONFailure.self) { try interactive(limits).render(root) } }
            else { #expect(try interactive(limits).render(root) == report.result) }
        }
    }
}

@Test func interactiveHTMLRejectsInvalidDepthAndQueryConfiguration() throws {
    for options in [JSONHTMLRenderingOptions(presentation: .interactive, initiallyExpandedDepth: -1), .init(presentation: .interactive, outlineDepth: -1)] {
        #expect(throws: JSONHTMLFailure.invalidConfiguration) { try JSONHTMLRenderer(options: options).render(.null) }
    }
    var limits = JSONHTMLLimits(); limits.maxSearchQueryBytes = 65_537
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try interactive(limits).render(.null) }
    limits.maxSearchQueryBytes = 0
    #expect(try interactive(limits).renderString(.null).contains("data-byte-limit=\"0\""))
}

@Test func interactiveHTMLFailureReleasesScratchAndPreservesTerminalError() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
    var limits = JSONHTMLLimits(); limits.maxMetadataBytes = 20
    let renderer = interactive(limits)
    #expect(throws: JSONHTMLFailure.self) { try renderer.render(.array([.string("long string")]), meter: &meter) }
    #expect(meter.used(.retainedBytes) == 17)
    let work = meter.used(.workUnits)
    #expect(throws: JSONHTMLFailure.self) { try renderer.render(.null, meter: &meter) }
    #expect(meter.used(.workUnits) == work)
    try meter.release(17)
}

@Test func interactiveHTMLCancellationInsideTreeEmissionIsTerminal() async throws {
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
        meter.checkpointObserver = { work in if work >= 20_000 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { try interactive().render(.array(Array(repeating: .number(1), count: 40)), meter: &meter) }
        #expect(meter.used(.workUnits) >= 20_000 && meter.used(.outputBytes) > 0)
        #expect(meter.used(.retainedBytes) == 17)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
        try meter.release(17)
    }
    try await task.value
}

@Test func interactiveHTMLDeepWideAndPrintBodiesAreComplete() throws {
    var deep: JSON = .string("last-sentinel"); for _ in 0..<40 { deep = .array([deep]) }
    let wide = JSON.array((0..<150).map { .string("literal [needle] \($0)") })
    for root in [deep, wide] {
        let data = try interactive().renderWithReport(root)
        let text = try interactive().renderStringWithReport(root)
        #expect(data.statistics == text.statistics && Array(data.result) == Array(text.result.utf8))
        #expect(try attribute(text.result, after: "id=\"jh-copy-json\"", name: "data-bytes") == exact(root))
        #expect(text.result.contains("class=\"print-json\""))
        #expect(text.result.contains(root == deep ? "last-sentinel" : "literal [needle] 149"))
    }
}

@Test func interactiveHTMLAssetsAreFixedAndDataCannotExecute() throws {
    let payload = "</script><script>window.pwned=1</script><img src=x onerror=evil()>"
    let html = try interactive().renderString(.string(payload))
    #expect(html.components(separatedBy: "<script>").count - 1 == 1)
    #expect(!html.contains("<img"))
    let keyed = JSON.object(try JSONObject(members: [
        JSONMember("__proto__", value: .string(payload)),
        JSONMember("constructor", value: .null), JSONMember(payload, value: .boolean(true))]))
    let keyedHTML = try interactive().renderString(keyed)
    #expect(!keyedHTML.contains("<img"))
    #expect(keyedHTML.contains("__proto__") && keyedHTML.contains("constructor"))
    #expect(try attribute(keyedHTML, after: "id=\"jh-copy-json\"", name: "data-bytes") == exact(keyed))
    #expect(html.contains("script-src 'sha256-\(JSONHTMLInteractiveAssets.scriptHash)'"))
    #expect(html.contains("style-src 'sha256-\(JSONHTMLInteractiveAssets.styleHash)'"))
    #expect(!JSONHTMLInteractiveAssets.script.contains("innerHTML"))
    #expect(!JSONHTMLInteractiveAssets.script.contains("JSON.stringify") && !JSONHTMLInteractiveAssets.script.contains("JSON.parse"))
    #expect(!JSONHTMLInteractiveAssets.script.contains("fetch("))
}
