// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONHTML

private func annotated(_ annotations: [JSONHTMLAnnotation], mode: JSONHTMLPresentation = .interactive,
                       limits: JSONHTMLLimits = .init()) -> JSONHTMLRenderer {
    var options = JSONHTMLRenderingOptions(limits: limits, presentation: mode)
    options.annotations = annotations
    return .init(options: options)
}
private func issue(_ path: [JSONLocationComponent], _ message: String = "Caller issue") -> JSONHTMLAnnotation {
    .init(path: path, severity: .error, message: message)
}
private func diagnostic(_ index: Int, in html: String) throws -> String {
    let start = try #require(html.range(of: "<li id=\"jh-a-\(index)\""))
    let end = try #require(html.range(of: "</li>", range: start.upperBound..<html.endIndex))
    return String(html[start.lowerBound..<end.upperBound])
}

@Test func annotationHTMLUsesExactTypedTargetsAndNearestParents() throws {
    let root = try JSONParser().parse(#"{"é":1,"é":2,"0":3,"array":[null],"parent":{}}"#)
    let paths: [[JSONLocationComponent]] = [
        [.key("é")], [.key("é")], [.key("0")], [.index(0)],
        [.key("array"), .index(0)], [.key("array"), .key("0")],
        [.key("parent"), .key("missing"), .index(1)], []]
    for mode in [JSONHTMLPresentation.formatted, .interactive] {
        let report = try annotated(paths.map { issue($0) }, mode: mode).renderStringWithReport(root)
        let expected: [(UInt64, Bool)] = [(1,false),(2,false),(3,false),(0,true),(5,false),(4,true),(6,true),(0,false)]
        for (index, outcome) in expected.enumerated() {
            let text = try diagnostic(index, in: report.result)
            #expect(text.contains("data-target=\"jh-n-\(outcome.0)\""))
            #expect(text.contains("data-missing=\"\(outcome.1)\""))
            #expect(text.contains(outcome.1 ? "Missing target; nearest existing parent" : "Target value"))
        }
        #expect(report.statistics.annotations == 8)
        #expect(report.result.contains("aria-describedby=\"jh-a-3 jh-a-7\""))
        #expect(try diagnostic(6, in: report.result).contains("key &quot;missing&quot; / index [1]"))
    }
}

@Test func annotationHTMLMessagesAndFullPathsAreVisibleInertData() throws {
    let key = "~1/a\u{0}\r\n</script>\"'&"
    let message = "</code><img src=x onerror=evil()>\r\n\u{0}&quot;\u{7f}\u{85}\u{202e}"
    let root = JSON.object(try JSONObject(members: [JSONMember(key, value: .null)]))
    for mode in [JSONHTMLPresentation.formatted, .interactive] {
        let html = try annotated([issue([.key(JSONKey(key))], message)], mode: mode).renderString(root)
        let text = try diagnostic(0, in: html)
        #expect(!text.contains("<img") && !text.contains("</script>"))
        #expect(text.contains("&lt;img") && text.contains("\\u000d\\u000a\\u0000"))
        #expect(text.contains("&amp;quot;"))
        #expect(text.contains("\\u007f\\u0085\\u202e"))
        #expect(text.contains("~1/a\\u0000\\u000d\\u000a&lt;/script&gt;"))
        #expect(!text.utf8.contains(0) && !text.utf8.contains(13))
        #expect(text.contains("data-missing=\"false\""))
    }
    let empty = try annotated([]).renderString(.null)
    #expect(!empty.contains("Caller diagnostics") && !empty.contains("schema validity"))
}

@Test func annotationHTMLDocumentSpansAreCoherentAndReplacementInventsNone() throws {
    let bytes = Data(" \n{\"é\":9007199254740993,\"e\u{301}\": [true,null]} \n".utf8)
    let document = try JSONParser().parseDocument(bytes, source: "private-source-not-archived")
    let paths: [[JSONLocationComponent]] = [[], [.key("é")], [.key("é"), .index(1)], [.key("é"), .index(9)]]
    let renderer = annotated(paths.map { issue($0) })
    let html = try renderer.renderString(document)
    // Known byte intervals independently derived from the exact input bytes.
    let scalarStart = try #require(bytes.range(of: Data("9007199254740993".utf8))).lowerBound
    let scalar = try diagnostic(1, in: html)
    #expect(scalar.contains("Value source span: \(scalarStart)..&lt;\(scalarStart+16) bytes"))
    let nullStart = try #require(bytes.range(of: Data("null".utf8))).lowerBound
    #expect(try diagnostic(2, in: html).contains("Value source span: \(nullStart)..&lt;\(nullStart+4) bytes"))
    let arrayStart = try #require(bytes.firstIndex(of: 91)), arrayEnd = try #require(bytes.firstIndex(of: 93)) + 1
    let parentText = try diagnostic(3, in: html)
    #expect(parentText.contains("Parent source span: \(arrayStart)..&lt;\(arrayEnd) bytes"))
    #expect(!html.contains("private-source-not-archived"))
    #expect(!html.contains("sourceBytes") && !html.contains("line 1"))
    for unmapped in [JSONDocument(root: document.root), document.replacingRoot(document.root), document.replacingRoot(.null)] {
        #expect(try !renderer.renderString(unmapped).contains("source span:"))
    }
}

@Test func annotationHTMLPublicDocumentOverloadsRetainValueFunctionShapes() throws {
    let renderer = annotated([issue([])])
    let bytes: (JSON) throws -> Data = renderer.render
    let text: (JSON) throws -> String = renderer.renderString
    let byteReport: (JSON) throws -> JSONHTMLRenderReport<Data> = renderer.renderWithReport
    let textReport: (JSON) throws -> JSONHTMLRenderReport<String> = renderer.renderStringWithReport
    let docBytes: (JSONDocument) throws -> Data = renderer.render
    let docText: (JSONDocument) throws -> String = renderer.renderString
    let docByteReport: (JSONDocument) throws -> JSONHTMLRenderReport<Data> = renderer.renderWithReport
    let docTextReport: (JSONDocument) throws -> JSONHTMLRenderReport<String> = renderer.renderStringWithReport
    let document = JSONDocument(root: .null)
    #expect(try bytes(.null) == docBytes(document))
    #expect(try Array(text(.null).utf8) == Array(docText(document).utf8))
    #expect(try byteReport(.null).statistics == docByteReport(document).statistics)
    #expect(try textReport(.null).statistics == docTextReport(document).statistics)
}

@Test func annotationHTMLCountCapsAreInclusiveAndZeroIsMeaningful() throws {
    let annotations = [issue([]), issue([])]
    for count: UInt64 in [1,2,3] {
        var limits = JSONHTMLLimits(); limits.maxAnnotations = count
        if count < 2 {
            #expect(throws: JSONHTMLFailure.limitExceeded(.annotations, limit: 1, attempted: 2)) { try annotated(annotations, limits: limits).render(.null) }
        } else { #expect(try annotated(annotations, limits: limits).renderWithReport(.null).statistics.annotations == 2) }
    }
    var limits = JSONHTMLLimits(); limits.maxAnnotations = 0
    #expect(try annotated([], limits: limits).renderWithReport(.null).statistics.annotations == 0)
    #expect(throws: JSONHTMLFailure.self) { try annotated([issue([])], limits: limits).render(.null) }
    limits.maxAnnotations = UInt64.max
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try annotated([], limits: limits).render(.null) }
    #expect(throws: JSONHTMLFailure.counterOverflow(.annotations)) { try JSONHTMLDocumentBuffer.adding(.annotations, UInt64.max, 1, UInt64.max) }
}

@Test func annotationHTMLBoundsMessagesAndFailedPathSuffixesCumulatively() throws {
    let annotations = [issue([.key("~/"), .index(123)], "message"), issue([], "other")]
    let report = try annotated(annotations).renderWithReport(.null)
    #expect(report.statistics.operation[.diagnosticBytes] == 17) // 7+2+3+5, both annotations and full failed path.
    for cap: UInt64 in [16,17,18] {
        var limits = JSONHTMLLimits(); limits.core[.diagnosticBytes] = cap
        if cap < 17 { #expect(throws: JSONFailure.self) { try annotated(annotations, limits: limits).render(.null) } }
        else { #expect(try annotated(annotations, limits: limits).render(.null) == report.result) }
    }
    for (metric, cap) in [(JSONResourceMetric.pointerTokens, UInt64(1)), (.pointerBytes, 8), (.keyBytes, 1), (.stringBytes, 6)] {
        var limits = JSONHTMLLimits(); limits.core[metric] = cap
        #expect(throws: JSONFailure.self) { try annotated(annotations, limits: limits).render(.null) }
    }
    // Invalid suffixes cannot hide behind the first missing component.
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try annotated([issue([.key("absent"), .index(-1)])]).render(.null) }
}

@Test func annotationHTMLSharesAdmissionAndFinalMaterializationBudgets() throws {
    let root = try JSONParser().parse(#"{"a":[1,2]}"#)
    for mode in [JSONHTMLPresentation.formatted, .interactive] {
        let annotations = [issue([.key("a"), .index(1)])]
        let renderer = annotated(annotations, mode: mode)
        let report = try renderer.renderWithReport(root), text = try renderer.renderStringWithReport(root)
        #expect(report.result == Data(text.result.utf8) && report.statistics == text.statistics)
        #expect(report.statistics.operation[.nodes] == 4 && report.statistics.renderedJSONNodes == 4)
        #expect(report.statistics.operation[.retainedBytes] == report.statistics.documentBytes)
        for metric in [JSONResourceMetric.workUnits, .outputBytes, .retainedBytes] {
            let boundary = metric == .retainedBytes ? report.statistics.operation.peakLogicalRetainedBytes : report.statistics.operation[metric]
            for cap in [boundary-1,boundary,boundary+1] {
                var limits = JSONHTMLLimits(); limits.core[metric] = cap
                if cap < boundary { #expect(throws: JSONFailure.self) { try annotated(annotations, mode: mode, limits: limits).render(root) } }
                else { #expect(try annotated(annotations, mode: mode, limits: limits).render(root) == report.result) }
            }
        }
    }
}

@Test func annotationHTMLBindingFailureCleansScratchAndLatchesMeter() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
    let renderer = annotated([issue([]), issue([.key("missing"), .index(-1)])])
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try renderer.render(.null, meter: &meter) }
    #expect(meter.used(.retainedBytes) == 17)
    let work = meter.used(.workUnits)
    #expect(throws: JSONHTMLFailure.invalidConfiguration) { try renderer.render(.null, meter: &meter) }
    #expect(meter.used(.workUnits) == work)
    try meter.release(17)
}

@Test func annotationHTMLCancellationInBindingAndSourceScansIsTerminal() async throws {
    let root = try JSONParser().parse(#"{"é":[1,2,3],"é":false}"#)
    let document = try JSONParser().parseDocument(JSONWriter().write(root))
    for threshold: UInt64 in [64,256] {
        try await Task {
            var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
            var meter = try JSONWorkMeter(limits: limits, domain: .writing); try meter.retain(17)
            meter.checkpointObserver = { work in if work >= threshold { withUnsafeCurrentTask { $0?.cancel() } } }
            let renderer = annotated(Array(repeating: issue([.key("é")], String(repeating: "x", count: 100)), count: 8))
            #expect(throws: CancellationError.self) { try renderer.render(root, document: document, meter: &meter) }
            #expect(meter.used(.retainedBytes) == 17 && meter.used(.outputBytes) == 0)
            let work = meter.used(.workUnits)
            #expect(throws: CancellationError.self) { try renderer.render(root, meter: &meter) }
            #expect(meter.used(.workUnits) == work)
            try meter.release(17)
        }.value
    }
    // Rendezvous inside a real source-map helper after earlier binding has consumed work.
    let wide = JSON.array(Array(repeating: .null, count: 500))
    let mapped = try JSONParser().parseDocument(JSONWriter().write(wide))
    try await Task {
        var limits = JSONLimits.balanced; limits[.cancellationQuantum] = 1
        var meter = try JSONWorkMeter(limits: limits, domain: .writing); try meter.retain(17)
        try JSONAdmission.value(wide, meter: &meter)
        let renderer = annotated([issue([.index(499)])])
        let records = try renderer.bindAnnotations(wide, document: nil, meter: &meter)
        try meter.release(UInt64(records.count) * 64)
        let earlierWork = meter.used(.workUnits)
        meter.checkpointObserver = { work in if work >= earlierWork + 4 { withUnsafeCurrentTask { $0?.cancel() } } }
        let map = try #require(mapped.sourceMap)
        #expect(throws: CancellationError.self) { try map.span(at: [.index(499)], meter: &meter) }
        #expect(meter.used(.workUnits) >= earlierWork + 4)
        #expect(meter.used(.retainedBytes) == 17)
        #expect(throws: CancellationError.self) { try renderer.render(wide, document: mapped, meter: &meter) }
        #expect(meter.used(.retainedBytes) == 17)
        try meter.release(17)
    }.value
}

@Test func sharedAnnotatedDocumentRendererHasIndependentConcurrentInvocations() async throws {
    let document = try JSONParser().parseDocument(Data(#"{"é":1,"é":[2,3]}"#.utf8))
    let renderer = annotated([issue([.key("é")]), issue([.key("é"), .index(1)]), issue([.key("absent")])])
    let expected = try renderer.renderWithReport(document)
    try await withThrowingTaskGroup(of: JSONHTMLRenderReport<Data>.self) { group in
        for _ in 0..<16 { group.addTask { try renderer.renderWithReport(document) } }
        var count = 0
        for try await actual in group { #expect(actual.result == expected.result && actual.statistics == expected.statistics); count += 1 }
        #expect(count == 16)
    }
}

@Test func annotationHTMLDeepWideAndDuplicateBindingsKeepStableOrdinals() throws {
    var root: JSON = .null, path: [JSONLocationComponent] = []
    for _ in 0..<60 { root = .array([root]); path.append(.index(0)) }
    let annotations = [issue(path), issue(path, "second")]
    let html = try annotated(annotations).renderString(root)
    #expect(html.contains("id=\"jh-n-60\"") && html.contains("aria-describedby=\"jh-a-0 jh-a-1\""))
    #expect(try diagnostic(1, in: html).contains("data-target=\"jh-n-60\""))
    let wide = JSON.array(Array(repeating: .null, count: 500))
    #expect(try diagnostic(0, in: annotated([issue([.index(499)])]).renderString(wide)).contains("data-target=\"jh-n-500\""))
}

@Test func annotationHTMLSourceAdmissionHonorsConfiguredMappingAndInputCaps() throws {
    let document = try JSONParser().parseDocument(Data(#"{"a":[1,2]}"#.utf8))
    for metric in [JSONResourceMetric.sourceMapEntries, .inputBytes] {
        let boundary = metric == .sourceMapEntries ? UInt64(document.sourceMap!.entries.count) : UInt64(document.sourceBytes!.count)
        for cap in [boundary-1,boundary,boundary+1] {
            var limits = JSONHTMLLimits(); limits.core[metric] = cap
            if cap < boundary { #expect(throws: JSONFailure.self) { try annotated([issue([.key("a")])], limits: limits).render(document) } }
            else { #expect(try annotated([issue([.key("a")])], limits: limits).renderString(document).contains("Value source span:")) }
        }
    }
}
