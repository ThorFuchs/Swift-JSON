// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing

@testable import JSONHTML

private struct MathGold: Decodable, Sendable {
    let id, source, expected: String
    let mathml: String?
}
private struct InlineGold: Decodable, Sendable { let id, source, expected: String }
private struct Base64Gold: Decodable, Sendable {
    let encoded: String
    let decodedHex: String?
    let valid: Bool
}
private struct GoldFile<T: Decodable>: Decodable { let cases: [T] }
private func previewFixtureURL(_ name: String, _ extensionName: String = "json") throws -> URL {
    // WASI Foundation's Bundle named-resource search truncates some extensions.
    // Use the exact pinned path under the generated SwiftPM resource directory.
    let root = try #require(Bundle.module.resourceURL)
    return URL(fileURLWithPath: root.path + "/Fixtures/Enrichment/" + name + "." + extensionName)
}
private func gold<T: Decodable>(_ name: String, _: T.Type) throws -> T {
    return try JSONDecoder().decode(T.self, from: Data(contentsOf: previewFixtureURL(name)))
}
private let mathGold = try! gold("math-cases", GoldFile<MathGold>.self).cases
private let inlineGold = try! gold("inline-cases", GoldFile<InlineGold>.self).cases
private let base64Gold = try! gold("base64-cases", GoldFile<Base64Gold>.self).cases
private func inlineBody(_ source: String, options: JSONHTMLRenderingOptions = .init()) throws -> (
    String, Bool
) {
    var meter = try JSONWorkMeter(limits: options.limits.core, domain: .writing)
    var ledger = JSONHTMLMediaLedger()
    let plan = try JSONHTMLInlineScanner.scan(
        source, options: options, ledger: &ledger, meter: &meter)
    var out = JSONHTMLDocumentBuffer(limits: options.limits)
    try plan.emit(output: &out, meter: &meter)
    try meter.release(plan.reservation)
    #expect(meter.used(.retainedBytes) == UInt64(out.bytes.count))
    return (String(decoding: out.bytes, as: UTF8.self), plan.formatted)
}
// Canonicalization approved by the gold fixture: single-child groups are unwrapped.
private func unwrapSingleRows(_ source: String) -> String {
    var s = source
    for tag in ["mi", "mn", "mo"] {
        let expression = "<mrow>(<" + tag + ">[^<]*</" + tag + ">)</mrow>"
        while s.range(of: expression, options: .regularExpression) != nil {
            s = s.replacingOccurrences(of: expression, with: "$1", options: .regularExpression)
        }
    }
    return s
}
@Test(arguments: mathGold) private func structuredMiniMathMatchesIndependentGold(_ item: MathGold)
    throws
{
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    let tree = try JSONHTMLMiniMath.parse(item.source, policy: .init(), meter: &meter)
    if item.expected == "converted" {
        let tree = try #require(tree, Comment(rawValue: item.id))
        var output = JSONHTMLDocumentBuffer(limits: .init())
        try tree.emit(output: &output, meter: &meter)
        #expect(
            String(decoding: output.bytes, as: UTF8.self)
                == unwrapSingleRows(try #require(item.mathml)),
            Comment(rawValue: item.id))
        try meter.release(tree.reservation)
        #expect(meter.used(.retainedBytes) == UInt64(output.bytes.count))
    } else {
        #expect(tree == nil, Comment(rawValue: item.id))
        #expect(meter.used(.retainedBytes) == 0)
    }
    let publicReport = try JSONHTMLRenderer(
        options: .init(layout: .structured, presentation: .formatted)
    ).renderStringWithReport(.string("\\(" + item.source + "\\)"))
    #expect(publicReport.statistics.renderedJSONNodes == 1)
    if item.expected == "converted" {
        #expect(
            publicReport.result.components(separatedBy: unwrapSingleRows(try #require(item.mathml)))
                .count
                - 1 == 2)
    } else {
        #expect(!publicReport.result.contains("<math "))
    }
}
@Test(arguments: inlineGold) private func structuredInlineMatchesIndependentDialectCases(
    _ item: InlineGold
) throws {
    let (html, formatted) = try inlineBody(item.source)
    switch item.expected {
    case "strong": #expect(html == "<strong>bold</strong>")
    case "em": #expect(html == "<em>italic</em>")
    case "strong_with_em": #expect(html == "<strong>outer <em>inner</em></strong>")
    case "em_with_strong": #expect(html == "<em>outer <strong>inner</strong></em>")
    case "math": #expect(html.contains("<math ") && !html.contains("merror"))
    case "inert_link", "inert_link_with_strong":
        #expect(html.contains("inert-link") && !html.contains("href="))
    case "literal":
        #expect(
            !formatted && !html.contains("<math") && !html.contains("<strong>")
                && !html.contains("<em>"),
            Comment(rawValue: item.id))
    case "literal_or_inert_reference":
        #expect(!html.contains("<img") && !html.contains("href=") && !html.contains("<script>"))
    default:
        Issue.record(
            Comment(rawValue: "Unrecognized independent fixture verdict: " + item.expected))
    }
}
@Test(arguments: base64Gold) private func structuredCanonicalBase64MatchesPadBitGold(
    _ item: Base64Gold
) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    do {
        let decoded = try JSONHTMLRasterAdmission.canonical(
            Array(item.encoded.utf8), maximum: 100, meter: &meter)
        #expect(item.valid)
        #expect(decoded.map { String(format: "%02x", $0) }.joined() == item.decodedHex)
    } catch is JSONHTMLPreviewRejection { #expect(!item.valid) }
}
@Test func structuredDefaultsAndOldInitializerShapesAreIndependent() throws {
    let old:
        (String, JSONHTMLTheme, Int, JSONIndentationUnit, Int, JSONHTMLLimits) ->
            JSONHTMLRenderingOptions = JSONHTMLRenderingOptions.init
    let explicit:
        (
            String, JSONHTMLTheme, Int, JSONIndentationUnit, Int, JSONHTMLLimits,
            JSONHTMLPresentation,
            Int, Int?
        ) -> JSONHTMLRenderingOptions = JSONHTMLRenderingOptions.init
    #expect(old("JSON", .light, 2, .spaces, 4, .init()).layout == .structured)
    #expect(
        explicit("JSON", .light, 2, .spaces, 4, .init(), .formatted, 2, nil).presentation
            == .formatted)
    #expect(JSONHTMLRenderingOptions().presentation == .interactive)
    for layout in [JSONHTMLLayout.structured, .syntax] {
        for presentation in [JSONHTMLPresentation.formatted, .interactive] {
            let report = try JSONHTMLRenderer(
                options: .init(layout: layout, presentation: presentation)
            )
            .renderStringWithReport(.array([.null]))
            #expect(report.statistics.renderedJSONNodes == 2)
            #expect(report.statistics.operation[.nodes] == 2)
            #expect(report.result.contains("<script>") == (presentation == .interactive))
        }
    }
}
@Test func structuredFormsCardsFlowAndOriginalTokensChooseLayout() throws {
    let root = try JSONParser().parse(
        #"{"first":[true,null,"x"],"records":[{"a":1},false],"long":["12345678901234567890123456789012345678901234567890123456789012345"]}"#
    )
    var options = JSONHTMLRenderingOptions(layout: .structured, presentation: .formatted)
    options.previewPolicy.maxSourceScalars = 1
    options.previewPolicy.maxEscapedDisplayScalars = 1
    let html = try JSONHTMLRenderer(options: options).renderString(root)
    #expect(html.contains("<dl class=\"object-form\">"))
    #expect(
        html.range(of: "&quot;first&quot;")!.lowerBound
            < html.range(of: "&quot;records&quot;")!.lowerBound)
    #expect(html.components(separatedBy: "class=\"scalar-flow\"").count - 1 == 2)  // screen plus print, only original short list
    #expect(html.components(separatedBy: "class=\"indexed-list\"").count - 1 == 4)
    #expect(!html.contains("<table"))
}
@Test func structuredPrefixesPreserveScalarsEscapesAndOriginalWithoutJavaScript() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    var policy = JSONHTMLPreviewPolicy()
    let text = String(repeating: "😀", count: 513)
    let p = try JSONHTMLDisplay.prefix(text, policy: policy, meter: &meter)
    #expect(p.shortened && p.scalars == 512 && p.reservation == 2048)
    try meter.release(p.reservation)
    policy.maxEscapedDisplayScalars = 7
    let escaped = try JSONHTMLDisplay.prefix("\u{0}\u{202e}x", policy: policy, meter: &meter)
    #expect(escaped.source == "\u{0}" && escaped.displayScalars == 6 && escaped.shortened)
    try meter.release(escaped.reservation)
    policy.maxSourceScalars = 0
    let zero = try JSONHTMLDisplay.prefix("e\u{301}", policy: policy, meter: &meter)
    #expect(zero.source.isEmpty && zero.shortened)
    let html = try JSONHTMLRenderer(options: .init(layout: .structured, presentation: .formatted))
        .renderString(.string(text + "TAIL"))
    #expect(!html.contains("<script>"))
    #expect(html.contains("String preview · first 512 decoded scalars"))
    #expect(html.contains("<summary>Original value (complete)</summary>"))
    #expect(html.contains(String(repeating: "😀", count: 513) + "TAIL"))
}
@Test func structuredControlDisplayKeepsFullKeysNumbersAndScalarIdentity() throws {
    let root = try JSONParser().parse(#"{"é":"\u0000\u202e","é":9007199254740993,"long":"tail"}"#)
    let html = try JSONHTMLRenderer(options: .init(layout: .structured, presentation: .formatted))
        .renderString(root)
    #expect(html.contains("\\u0000\\u202e"))
    #expect(html.contains("&quot;é&quot;") && html.contains("&quot;e\u{301}&quot;"))
    #expect(html.contains("9007199254740993"))
    let structured = String(html[..<html.range(of: "<details class=\"exact-source\">")!.lowerBound])
    #expect(!structured.contains("\u{202e}"))  // Exact syntax retains original writer bytes by contract.
}
@Test func structuredColorsUseCompleteGrammarAndExactHintedRanges() throws {
    struct Colors: Decodable { let validStrings, literalStrings: [String] }
    let cases = try gold("colors", Colors.self)
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    for source in cases.validStrings {
        #expect(try JSONHTMLColor.parse(source, policy: .init(), meter: &meter) != nil)
    }
    for source in cases.literalStrings + ["rgba(0,0,0,1.000000000000000001)"] {
        #expect(try JSONHTMLColor.parse(source, policy: .init(), meter: &meter) == nil)
    }
    let normalized = try JSONParser().parse("[1,0,0,0.5]")
    #expect(
        try JSONHTMLColor.hinted(normalized, units: .normalized, order: .rgba, meter: &meter)?.r
            == 255)
    #expect(
        try JSONHTMLColor.hinted(normalized, units: .integer8, order: .rgb, meter: &meter) == nil)
    #expect(
        try JSONHTMLColor.hinted(
            JSONParser().parse("[1.000000000000000001,0,0]"), units: .normalized, order: .rgb,
            meter: &meter) == nil)
}
@Test func structuredTypedHintsSuppressInferenceAndReportMissingWrongKinds() throws {
    let root = try JSONParser().parse(
        ##"{"é":"#369","é":"**bold**","0":[255,0,0],"missingKind":false}"##)
    var options = JSONHTMLRenderingOptions(layout: .structured, presentation: .formatted)
    options.previewHints = [
        .init(path: [.key("é")], kind: .literal),
        .init(path: [.key("0")], kind: .color(units: .integer8, order: .rgb)),
        .init(path: [.key("missingKind")], kind: .inlineText),
        .init(path: [.index(0)], kind: .inlineText),
    ]
    options.effectivePreviewHints = [
        .init(path: [.key("é")], kind: .color(units: .integer8, order: .rgb))
    ]
    let report = try JSONHTMLRenderer(options: options).renderStringWithReport(root)
    #expect(report.statistics.previewIssues == 2)
    #expect(report.result.contains("<strong>bold</strong>"))
    #expect(report.result.components(separatedBy: "<svg class=\"color-swatch\"").count - 1 == 2)  // one unique hinted array, two representations
    #expect(report.statistics.renderedJSONNodes == 8)
    options.previewHints.append(options.previewHints[0])
    #expect(throws: JSONHTMLFailure.invalidConfiguration) {
        try JSONHTMLRenderer(options: options).render(root)
    }
}
@Test func structuredAdmitsDeclaredMediaOnceAndRejectsMismatchedRemoteSVG() throws {
    let mediaURL = try previewFixtureURL("media")
    guard case .object(let media) = try JSONParser().parse(Array(Data(contentsOf: mediaURL))) else {
        Issue.record("Fixture must be an object")
        return
    }
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    var ledger = JSONHTMLMediaLedger()
    for name in ["pngDataURI", "jpegDataURI"] {
        guard case .string(let s) = media[JSONKey(name)] else {
            Issue.record("Missing fixture")
            continue
        }
        let image = try #require(
            JSONHTMLRasterAdmission.decode(
                s, type: nil, policy: .init(), ledger: &ledger, meter: &meter))
        #expect(image.width == 4 && image.height == 4)
        try meter.release(image.reservation)
    }
    for name in [
        "mismatch", "invalidEncoding", "noncanonicalPadBits", "oversizedHeader", "remote", "svg",
    ] {
        guard case .string(let s) = media[JSONKey(name)] else {
            Issue.record("Missing fixture")
            continue
        }
        let before = meter.used(.retainedBytes)
        #expect(
            try JSONHTMLRasterAdmission.decode(
                s, type: nil, policy: .init(), ledger: &ledger, meter: &meter) == nil)
        #expect(meter.used(.retainedBytes) == before)
    }
    guard case .string(let png) = media[JSONKey("pngDataURI")] else {
        Issue.record("Missing PNG")
        return
    }
    var options = JSONHTMLRenderingOptions(layout: .structured, presentation: .interactive)
    options.previewPolicy.maxImagePreviews = 1
    let report = try JSONHTMLRenderer(options: options).renderStringWithReport(.string(png))
    #expect(report.statistics.imagePreviews == 1 && report.statistics.decodedImageBytes > 0)
    #expect(report.result.components(separatedBy: "<img ").count - 1 == 2)
    #expect(report.result.contains("img-src data:"))
    let plain = try JSONHTMLRenderer(options: options).renderString(
        .string("https://example.invalid/photo.png"))
    #expect(!plain.contains("<img ") && !plain.contains("img-src data:"))
}
@Test func structuredInlineCutoffAndMathRejectionAreAtomic() throws {
    var options = JSONHTMLRenderingOptions(layout: .structured, presentation: .formatted)
    options.previewPolicy.maxSourceScalars = 6
    options.previewPolicy.maxEscapedDisplayScalars = 6
    let html = try JSONHTMLRenderer(options: options).renderString(.string("$x_i^2$ **bold**"))
    #expect(!html.contains("<math ") && !html.contains("<strong>"))
    let (unsupported, _) = try inlineBody("before $x^12 + \\unknown$ **after**")
    #expect(
        !unsupported.contains("<math ") && unsupported.contains("$x^12 + \\\\unknown$")
            && unsupported.contains("<strong>after</strong>"))
    options.previewPolicy.maxInlineTokens = 0
    let (literal, formatted) = try inlineBody("**bold** $x^2$", options: options)
    #expect(!formatted && literal == "**bold** $x^2$")
}
@Test func structuredLinksAreExplicitValidatedAndNeverLoadRemoteImages() throws {
    var options = JSONHTMLRenderingOptions()
    options.linkActivation = .httpAndHTTPS
    let (active, _) = try inlineBody("[go](https://example.invalid/a_(b))", options: options)
    #expect(active.contains("href=\"https://example.invalid/a_(b)\""))
    #expect(
        active.contains("noopener noreferrer") && active.contains("referrerpolicy=\"no-referrer\""))
    for source in [
        "https://user:secret@example.invalid/", "https://[]/", "https://:/", "javascript:alert(1)",
        "https://example.invalid:99999/", "https://example.invalid/\u{202e}x",
        "https://example.invalid/%zz",
    ] {
        #expect(!(try inlineBody("[go](" + source + ")", options: options).0).contains("href="))
    }
    #expect(
        !(try inlineBody("![alt](https://example.invalid/a.png)", options: options).0).contains(
            "<img"))
}
@Test func structuredGlobalWorkOutputRetentionFailureIsNotLiteralFallback() throws {
    let root: JSON = .string("**text** $\\frac{x}{y}$")
    let renderer = JSONHTMLRenderer(options: .init(layout: .structured, presentation: .formatted))
    let measured = try renderer.renderWithReport(root)
    for metric in [JSONResourceMetric.workUnits, .outputBytes, .retainedBytes] {
        var limits = JSONLimits.balanced
        limits[metric] =
            metric == .retainedBytes
            ? measured.statistics.operation.peakLogicalRetainedBytes - 1
            : measured.statistics.operation[metric] - 1
        var options = renderer.options
        options.limits.core = limits
        #expect(throws: JSONFailure.self) { try JSONHTMLRenderer(options: options).render(root) }
    }
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    try meter.retain(17)
    var tight = renderer.options
    tight.limits.maxDocumentBytes = 100
    #expect(throws: JSONHTMLFailure.self) {
        try JSONHTMLRenderer(options: tight).render(root, meter: &meter)
    }
    #expect(meter.used(.retainedBytes) == 17)
    let work = meter.used(.workUnits)
    #expect(throws: JSONHTMLFailure.self) { try meter.work() }
    #expect(meter.used(.workUnits) == work)
}
@Test func structuredCancellationInsidePreviewScanReleasesScratchAndLatches() async throws {
    let task = Task {
        var limits = JSONLimits.balanced
        limits[.cancellationQuantum] = 1
        let root: JSON = .string(String(repeating: "**bold** $x_i^2$ ", count: 200))
        var admission = try JSONWorkMeter(limits: limits, domain: .writing)
        try JSONAdmission.value(root, meter: &admission)
        let threshold = admission.used(.workUnits) + 256
        var meter = try JSONWorkMeter(limits: limits, domain: .writing)
        try meter.retain(17)
        meter.checkpointObserver = { work in
            if work >= threshold { withUnsafeCurrentTask { $0?.cancel() } }
        }
        #expect(throws: CancellationError.self) {
            try JSONHTMLRenderer().render(root, meter: &meter)
        }
        #expect(meter.used(.retainedBytes) == 17 && meter.used(.workUnits) >= threshold)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
    }
    try await task.value
}
@Test func structuredPreparedExportIsCompleteStaticAndRetainsImmutablePolicy() throws {
    let string = String(repeating: "x", count: 700) + "TAIL"
    let item = try JSONExportDocument.prepare(.string(string))
    let html = String(decoding: try item.data(for: .html), as: UTF8.self)
    #expect(!html.contains("<script>"))
    #expect(html.contains("class=\"rich light tabs-4\""))
    #expect(html.contains(string))
    #expect(!html.contains("String preview ·"))
    #expect(item.htmlPolicy?.layout == .structured && item.htmlPolicy?.valueProfile == .complete)
    #expect(try item.selecting([.json]).htmlPolicy?.layout == .structured)
    #expect(
        try item.data(for: .json)
            == Data(
                JSONWriter(
                    options: .init(indentation: 1, numberStyle: .preserved, indentationUnit: .tabs)
                )
                .write(.string(string))))
}
@Test func structuredSharedRendererPlansHaveInvocationOwnedState() async throws {
    let root = try JSONParser().parse(
        ##"{"color":"#369c","text":"**bold** $x_i^2$","records":[{"x":true},null]}"##)
    let renderer = JSONHTMLRenderer()
    let expected = try renderer.renderWithReport(root)
    try await withThrowingTaskGroup(of: JSONHTMLRenderReport<Data>.self) { group in
        for _ in 0..<12 { group.addTask { try renderer.renderWithReport(root) } }
        var count = 0
        for try await actual in group {
            #expect(actual.result == expected.result && actual.statistics == expected.statistics)
            count += 1
        }
        #expect(count == 12)
    }
}

@Test func structuredHTMLSavingUsesImmutableBytesAndNoMutatedDOMSerializer() throws {
    let renderer = JSONHTMLRenderer()
    let bytes = try renderer.render(.string("**bold** $x^2$"))
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(
        UUID().uuidString + ".html")
    defer { try? FileManager.default.removeItem(at: file) }
    #if os(WASI)
        try bytes.write(to: file)  // WASI has no atomic temporary-file writer; the same immutable bytes are verified.
    #else
        try bytes.write(to: file, options: .atomic)
    #endif
    #expect(try Data(contentsOf: file) == bytes)
    #expect(!String(decoding: bytes, as: UTF8.self).contains("outerHTML"))
    #expect(!String(decoding: bytes, as: UTF8.self).contains("download-html"))
}
@Test func structuredMathDescriptorChecksAllowlistArityAndAcyclicOrderBeforeOutput() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    for nodes in [
        [JSONHTMLMathNode(tag: "script", text: "x", children: [])],
        [JSONHTMLMathNode(tag: "mfrac", text: "", children: [])],
        [JSONHTMLMathNode(tag: "mrow", text: "", children: [0])],
    ] {
        var out = JSONHTMLDocumentBuffer(limits: .init())
        let tree = JSONHTMLMathTree(nodes: nodes, root: 0, reservation: 0)
        #expect(throws: JSONHTMLFailure.invalidConfiguration) {
            try tree.emit(output: &out, meter: &meter)
        }
        #expect(out.bytes.isEmpty)
    }
}

@Test(arguments: [
    "sourceScalars", "prefixBytes", "displayScalars", "inlineNesting", "inlineTokens",
    "destinationBytes", "altScalars", "mathScalars", "mathBytes", "mathDepth", "mathNodes",
    "mathTokens", "encodedBytes", "decodedBytes", "aggregateBytes", "width", "height", "pixels",
    "headerBytes", "images", "hints", "colorBytes",
])
func structuredAllPreviewCeilingsRejectBeforeGrowthAndKeepInclusiveEdges(metric: String) throws {
    var policy = JSONHTMLPreviewPolicy()
    if ["sourceScalars", "prefixBytes", "displayScalars"].contains(metric) {
        for n: UInt64 in [0, 1, 2] {
            switch metric {
            case "sourceScalars": policy.maxSourceScalars = n
            case "prefixBytes": policy.maxPrefixUTF8Bytes = n
            default: policy.maxEscapedDisplayScalars = n
            }
            var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
            let p = try JSONHTMLDisplay.prefix("x", policy: policy, meter: &meter)
            #expect(p.shortened == (n == 0))
            #expect(p.source == (n == 0 ? "" : "x"))
        }
    } else if ["inlineNesting", "inlineTokens", "destinationBytes", "altScalars"].contains(metric) {
        let boundary: UInt64 = metric == "inlineTokens" ? 3 : metric == "destinationBytes" ? 4 : 1
        for n in [boundary - 1, boundary, boundary + 1] {
            var options = JSONHTMLRenderingOptions()
            switch metric {
            case "inlineNesting": options.previewPolicy.maxInlineNesting = n
            case "inlineTokens": options.previewPolicy.maxInlineTokens = n
            case "destinationBytes": options.previewPolicy.maxDestinationUTF8Bytes = n
            default: options.previewPolicy.maxAltScalars = n
            }
            let source =
                metric == "destinationBytes"
                ? "[a](x\\(y\\))"
                : metric == "altScalars" ? "![a](https://example.invalid/)" : "**b**"
            let (_, formatted) = try inlineBody(source, options: options)
            #expect(formatted == (n >= boundary), Comment(rawValue: metric))
        }
    } else if metric.hasPrefix("math") {
        let boundary: UInt64 = UInt64(1)
        for n in [boundary - 1, boundary, boundary + 1] {
            switch metric {
            case "mathScalars": policy.maxMathSourceScalars = n
            case "mathBytes": policy.maxMathSourceUTF8Bytes = n
            case "mathDepth": policy.maxMathSyntaxDepth = n
            case "mathNodes": policy.maxMathNodes = n
            default: policy.maxMathTokens = n
            }
            var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
            let tree = try JSONHTMLMiniMath.parse("x", policy: policy, meter: &meter)
            #expect((tree != nil) == (n >= boundary), Comment(rawValue: metric))
        }
    } else if metric == "hints" {
        for n: UInt64 in [0, 1, 2] {
            var options = JSONHTMLRenderingOptions(layout: .structured, presentation: .formatted)
            options.previewPolicy.maxHintRecords = n
            options.previewHints = [.init(path: [], kind: .literal)]
            if n == 0 {
                #expect(throws: JSONHTMLFailure.invalidConfiguration) {
                    try JSONHTMLRenderer(options: options).render(.null)
                }
            } else {
                #expect(
                    try JSONHTMLRenderer(options: options).renderWithReport(.null).statistics
                        .renderedJSONNodes == 1)
            }
        }
    } else if metric == "colorBytes" {
        for n: UInt64 in [3, 4, 5] {
            policy.maxColorCandidateBytes = n
            var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
            #expect(
                (try JSONHTMLColor.parse("#369", policy: policy, meter: &meter) != nil) == (n >= 4))
            #expect(meter.used(.retainedBytes) == 0)
        }
    } else {
        let url = try previewFixtureURL("sample", "png")
        let data = try Data(contentsOf: url)
        let encoded = data.base64EncodedString()
        let boundary: UInt64 =
            switch metric {
            case "encodedBytes": UInt64(encoded.utf8.count)
            case "decodedBytes", "aggregateBytes": UInt64(data.count)
            case "width", "height": 4
            case "pixels": 16
            case "images": 1
            default: 1
            }
        if metric == "headerBytes" {
            // Find the native scanner's exact required bound without changing the source.
            var first: UInt64 = 0
            for n: UInt64 in 1...256 {
                var m = try JSONWorkMeter(limits: .balanced, domain: .writing)
                var l = JSONHTMLMediaLedger()
                policy.maxImageHeaderBytes = n
                if try JSONHTMLRasterAdmission.decode(
                    encoded, type: .png, policy: policy, ledger: &l, meter: &m) != nil
                {
                    first = n
                    break
                }
            }
            #expect(first > 1)
            for n in [first - 1, first, first + 1] {
                var m = try JSONWorkMeter(limits: .balanced, domain: .writing)
                var l = JSONHTMLMediaLedger()
                policy.maxImageHeaderBytes = n
                #expect(
                    (try JSONHTMLRasterAdmission.decode(
                        encoded, type: .png, policy: policy, ledger: &l, meter: &m) != nil)
                        == (n >= first))
            }
        } else {
            for n in [boundary - 1, boundary, boundary + 1] {
                switch metric {
                case "encodedBytes": policy.maxEncodedImageBytes = n
                case "decodedBytes": policy.maxDecodedImageBytes = n
                case "aggregateBytes": policy.maxAggregateDecodedImageBytes = n
                case "width": policy.maxImageWidth = n
                case "height": policy.maxImageHeight = n
                case "pixels": policy.maxImagePixels = n
                default: policy.maxImagePreviews = n
                }
                var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
                var ledger = JSONHTMLMediaLedger()
                let image = try JSONHTMLRasterAdmission.decode(
                    encoded, type: .png, policy: policy, ledger: &ledger, meter: &meter)
                #expect((image != nil) == (n >= boundary), Comment(rawValue: metric))
                #expect(ledger.images == (n >= boundary ? 1 : 0))
                if image == nil { #expect(meter.used(.retainedBytes) == 0) }
            }
        }
    }
}

@Test func structuredFlowUsesInclusiveOriginalTokenAndItemCounts() throws {
    var options = JSONHTMLRenderingOptions(layout: .structured, presentation: .formatted)
    options.previewPolicy.maxSourceScalars = 1
    options.previewPolicy.maxEscapedDisplayScalars = 1
    for count in [10, 11] {
        let html = try JSONHTMLRenderer(options: options).renderString(
            .array(Array(repeating: .null, count: count)))
        #expect(html.contains("class=\"scalar-flow\"") == (count == 10))
    }
    for length in [58, 59] {
        let html = try JSONHTMLRenderer(options: options).renderString(
            .array([.string(String(repeating: "x", count: length))]))
        #expect(html.contains("class=\"scalar-flow\"") == (length == 58))  // Quotes add two scalars; shortened prefix does not change eligibility.
    }
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    var policy = JSONHTMLPreviewPolicy()
    policy.maxEscapedDisplayScalars = 11
    let p = try JSONHTMLDisplay.prefix("\u{110bd}", policy: policy, meter: &meter)
    #expect(p.source.isEmpty && p.shortened)  // A format scalar's 12-scalar surrogate escape is atomic.
}
