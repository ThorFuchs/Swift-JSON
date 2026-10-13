// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing
@testable import JSONHTML
#if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
import CoreTransferable
import UniformTypeIdentifiers
#endif

@Test func exportSixRootsAndEmptyContainersAreComplete() throws {
    for source in ["null", "true", "1.00E+2", #""é😀""#, "[]", "{}", "[1,null]", #"{"a":false}"#] {
        let value = try JSONParser().parse(source)
        let report = try JSONExportDocument.prepareWithReport(value)
        let item = report.result
        #expect(item.availableFormats == [.json, .plainText, .markdown, .html])
        #expect(item.availableFormats == item.advertisedFormats)
        #expect(try JSONParser().parse(item.data(for: .json)) == value)
        #expect(try item.data(for: .json) == item.data(for: .plainText))
        #expect(report.operation[.nodes] == (source == "[1,null]" ? 3 : source == #"{"a":false}"# ? 2 : 1))
        #expect(report.preparedBytes == report.representationBytes.values.reduce(0, +))
    }
}

@Test func exportExactScalarsOrderAndLexemesUseIndependentByteAnswers() throws {
    let value = try JSONParser().parse(#"{"é":9007199254740993,"é":-0.00e+2,"":1.2300E-7,"0":"é","__proto__":true}"#)
    let expected = "{\n\t\"é\": 9007199254740993,\n\t\"e\u{301}\": -0.00e+2,\n\t\"\": 1.2300E-7,\n\t\"0\": \"e\u{301}\",\n\t\"__proto__\": true\n}"
    let item = try JSONExportDocument.prepare(value)
    #expect(try item.data(for: .json) == Data(expected.utf8))
    #expect(try item.data(for: .markdown) == Data(("```json\n" + expected + "\n```\n").utf8))
    #expect(try JSONExportDocument.prepare(.number(42)).data(for: .json) == Data("42".utf8))
}

@Test func exportPlainStringRootRemainsQuotedAndMarkdownFenceIsSafe() throws {
    let value: JSON = .string("`````` ~~~~~ </script> & 😀")
    let item = try JSONExportDocument.prepare(value)
    let body = #""`````` ~~~~~ </script> & 😀""#
    #expect(try item.data(for: .plainText) == Data(body.utf8))
    #expect(try item.data(for: .markdown) == Data(("```````json\n" + body + "\n```````\n").utf8))
}

@Test func exportCompactJSONDoesNotChangePrettyTextOrMarkdown() throws {
    let item = try JSONExportDocument.prepare(.array([.null]), options: .init(compactJSON: true))
    #expect(try item.data(for: .json) == Data("[null]".utf8))
    #expect(try item.data(for: .plainText) == Data("[\n\tnull\n]".utf8))
    #expect(try item.data(for: .markdown) == Data("```json\n[\n\tnull\n]\n```\n".utf8))
}

@Test func exportStaticHTMLHasNoInteractiveOrExecutablePayload() throws {
    let item = try JSONExportDocument.prepare(.string("</style><script>boom</script>&"),
        options: .init(title: "</title>&"))
    let html = String(decoding: try item.data(for: .html), as: UTF8.self)
    #expect(html.contains("class=\"light tabs-4\""))
    #expect(html.contains("&lt;/style&gt;&lt;script&gt;boom&lt;/script&gt;&amp;"))
    #expect(html.contains("script-src 'none'") && html.contains("default-src 'none'"))
    for forbidden in ["<script", "<button", "<details", "<nav", "hidden", "src=\""] { #expect(!html.contains(forbidden)) }
}

@Test func exportSelectionRetainsHiddenArtifactsAndLookupIsExact() throws {
    let all = try JSONExportDocument.prepare(.null)
    let markdown = try all.selecting([.markdown])
    #expect(markdown.availableFormats == all.availableFormats && markdown.advertisedFormats == [.markdown])
    #expect(try markdown.data(for: .json) == all.data(for: .json))
    #expect(throws: JSONExportFailure.invalidConfiguration) { try all.selecting([]) }
    #expect(throws: JSONExportFailure.unavailableFormat(.pdf)) { try all.selecting([.pdf]) }
    #expect(throws: JSONExportFailure.unavailableFormat(.rtf)) { try all.data(for: .rtf) }
}

@Test func exportMetadataRejectsUnsafeComponentsAndBoundsUTF8() throws {
    for name in ["", ".", "..", "../x", "a/b", "a\\b", "a:b", "a\n", "x\u{85}", "x\u{202e}"] {
        #expect(throws: JSONExportFailure.invalidConfiguration) {
            try JSONExportDocument.prepare(.null, options: .init(filenameStem: name))
        }
    }
    for title in ["x\r", "x\u{0}", "x\u{85}"] {
        #expect(throws: JSONExportFailure.invalidConfiguration) {
            try JSONExportDocument.prepare(.null, options: .init(title: title))
        }
    }
    for cap in [UInt64(1), 2, 3] {
        let options = JSONExportOptions(formats: [.json], filenameStem: "é", title: "é",
            limits: .init(maxTitleBytes: cap, maxFilenameBytes: cap))
        if cap < 2 { #expect(throws: JSONExportFailure.self) { try JSONExportDocument.prepare(.null, options: options) } }
        else { #expect(try JSONExportDocument.prepare(.null, options: options).filenameStem.utf8.count == 2) }
    }
}

@Test func exportAdditionalCapBoundariesAreInclusive() throws {
    let report = try JSONExportDocument.prepareWithReport(.array([.null]))
    let largest = try #require(report.representationBytes.values.max())
    for delta in [-1, 0, 1] {
        for aggregate in [false, true] {
            var limits = JSONExportLimits()
            let cap = UInt64(Int64(aggregate ? report.preparedBytes : largest) + Int64(delta))
            if aggregate { limits.maxPreparedBytes = cap } else { limits.maxRepresentationBytes = cap }
            if delta < 0 { #expect(throws: (any Error).self) { try JSONExportDocument.prepare(.array([.null]), options: .init(limits: limits)) } }
            else { #expect(try JSONExportDocument.prepareWithReport(.array([.null]), options: .init(limits: limits)).preparedBytes == report.preparedBytes) }
        }
    }
    #expect(throws: JSONExportFailure.self) { try JSONExportDocument.prepare(.null, options: .init(limits: .init(maxPreparedBytes: 0))) }
    #expect(throws: JSONExportFailure.invalidConfiguration) { try JSONExportDocument.prepare(.null, options: .init(limits: .init(maxPreparedBytes: .max))) }
    #expect(throws: JSONExportFailure.counterOverflow(.preparedBytes)) { try JSONExportBuffer.adding(.preparedBytes, .max, 1, .max) }
}

@Test func exportWorkOutputAndRetentionAreCumulativeWithOneAdmission() throws {
    let root: JSON = .array([.null, true])
    let baseline = try JSONExportDocument.prepareWithReport(root)
    #expect(baseline.operation[.nodes] == 3)
    for metric in [JSONResourceMetric.workUnits, .outputBytes, .retainedBytes] {
        let boundary = metric == .retainedBytes ? baseline.operation.peakLogicalRetainedBytes : baseline.operation[metric]
        for delta in [-1, 0, 1] {
            var core = JSONLimits.balanced; core[metric] = UInt64(Int64(boundary) + Int64(delta)); core[.nodes] = 3
            let options = JSONExportOptions(limits: .init(core: core))
            if delta < 0 { #expect(throws: JSONFailure.self) { try JSONExportDocument.prepare(root, options: options) } }
            else { #expect(try JSONExportDocument.prepareWithReport(root, options: options).operation == baseline.operation) }
        }
    }
    let single = try JSONExportDocument.prepareWithReport(root, options: .init(formats: [.json]))
    var core = JSONLimits.balanced; core[.workUnits] = single.operation[.workUnits]
    #expect(throws: JSONFailure.self) { try JSONExportDocument.prepare(root, options: .init(limits: .init(core: core))) }
}

@Test func exportFailuresLatchAndReleaseScratchWithoutReplacingOuterMeter() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
    let options = JSONExportOptions(limits: .init(maxPreparedBytes: 1))
    #expect(throws: JSONExportFailure.self) { try JSONExportDocument.prepare(.null, options: options, meter: &meter) }
    #expect(meter.used(.retainedBytes) == 17)
    let work = meter.used(.workUnits)
    #expect(throws: JSONExportFailure.self) { try JSONExportDocument.prepare(.null, options: .init(), meter: &meter) }
    #expect(meter.used(.workUnits) == work)
}

@Test func exportCancellationInsideAdmissionIsTerminal() async throws {
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
        meter.checkpointObserver = { work in if work > 1_000 { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) {
            try JSONExportDocument.prepare(.string(String(repeating: "x", count: 2_000)), options: .init(), meter: &meter)
        }
        #expect(meter.used(.workUnits) > 1_000 && meter.used(.retainedBytes) == 17)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
    }
    try await task.value
}

@Test func sharedExportPreparationsHaveIndependentConcurrentState() async throws {
    let root = try JSONParser().parse(#"{"é":9007199254740993,"é":[-0.00e+2,null]}"#)
    let expected = try JSONExportDocument.prepareWithReport(root)
    try await withThrowingTaskGroup(of: JSONExportReport<JSONExportDocument>.self) { group in
        for _ in 0..<16 { group.addTask { try JSONExportDocument.prepareWithReport(root) } }
        var count = 0
        for try await report in group {
            #expect(report.operation == expected.operation && report.preparedBytes == expected.preparedBytes)
            for format in report.result.availableFormats { #expect(try report.result.data(for: format) == expected.result.data(for: format)) }
            count += 1
        }
        #expect(count == 16)
    }
}

@Test func exportDeepWideAndRestrictiveConfigurationRemainBounded() throws {
    var root: JSON = .string("LAST-CONTENT-SENTINEL")
    for _ in 0..<64 { root = .array([root]) }
    let wide = try JSONObject(members: (0..<300).map { JSONMember("k\($0)", value: .number(JSONNumber(integer: $0))) })
    for value in [root, .object(wide)] {
        let item = try JSONExportDocument.prepare(value)
        #expect(try JSONParser().parse(item.data(for: .json)) == value)
    }
    for indentation in [-1, 9] { #expect(throws: JSONExportFailure.invalidConfiguration) { try JSONExportDocument.prepare(.null, options: .init(indentation: indentation)) } }
    for width in [0, 9] { #expect(throws: JSONExportFailure.invalidConfiguration) { try JSONExportDocument.prepare(.null, options: .init(tabWidth: width)) } }
    #expect(throws: JSONExportFailure.invalidConfiguration) { try JSONExportDocument.prepare(.null, options: .init(formats: [])) }
    #expect(throws: JSONExportFailure.unsupportedFormat(.rtf)) { try JSONExportDocument.prepare(.null, options: .init(formats: [.json, .rtf])) }
    #expect(throws: JSONExportFailure.preparationRequired(.pdf)) { try JSONExportDocument.prepare(.null, options: .init(formats: [.json, .pdf])) }
}

#if canImport(CoreTransferable) && canImport(UniformTypeIdentifiers)
@Test func appleTransferTypesAndSelectedBytesMatchAvailableArtifacts() async throws {
    #expect(JSON.exportedContentTypes() == [.json, .html, .utf8PlainText, .markdown])
    #expect(JSON.importedContentTypes() == [.json])
    #expect(JSONExportDocument.importedContentTypes().isEmpty)
    let root: JSON = .array([.null])
    let item = try JSONExportDocument.prepare(root)
    for (format, type) in [(JSONExportFormat.json, UTType.json), (.plainText, .utf8PlainText), (.markdown, .markdown), (.html, .html)] {
        let selected = try item.selecting([format])
        #expect(selected.exportedContentTypes() == [type])
        #expect(try await selected.exported(as: type) == item.data(for: format))
        #expect(try await root.exported(as: type) == item.data(for: format))
    }
    let markdown = try item.selecting([.markdown])
    // The guard rejects hidden candidates; generic text matching then reaches Markdown.
    #expect(try await markdown.exported(as: .text) == item.data(for: .markdown))
    #expect(try await markdown.exported(as: .markdown) == item.data(for: .markdown))
    do { _ = try await markdown.exported(as: .json); Issue.record("Hidden JSON bytes escaped selected-format transfer") }
    catch { #expect(!String(describing: error).isEmpty) }
}

@Test func appleNativeJSONImportIsStrictAndPreservesExactBytes() async throws {
    let input = Data(#"{"é":9007199254740993,"é":-0.00e+2}"#.utf8)
    let value = try await JSON(importing: input, contentType: .json)
    #expect(try JSONWriter(options: .init(numberStyle: .preserved)).write(value) == input)
    for bytes in [Data([0xff]), Data(#"{"a":1,"a":2}"#.utf8), Data("null true".utf8), Data("[1,]".utf8)] {
        #expect(throws: JSONFailure.self) { try JSONParser().parse(bytes) }
        do { _ = try await JSON(importing: bytes, contentType: .json); Issue.record("Invalid native JSON was accepted") }
        catch { #expect(!String(describing: error).isEmpty) } // CoreTransferable wraps the parser error.
    }
}
#endif

@Test func exportResultCopyCancellationLeavesNoArtifactAndLatches() async throws {
    let root: JSON = .string(String(repeating: "x", count: 2_000))
    let options = JSONExportOptions(formats: [.json])
    let baseline = try JSONExportDocument.prepareWithReport(root, options: options)
    let threshold = baseline.operation[.workUnits] - 1
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
        meter.checkpointObserver = { work in if work >= threshold { withUnsafeCurrentTask { $0?.cancel() } } }
        #expect(throws: CancellationError.self) { try JSONExportDocument.prepare(root, options: options, meter: &meter) }
        #expect(meter.used(.outputBytes) == baseline.operation[.outputBytes])
        #expect(meter.used(.retainedBytes) == 0)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
    }
    try await task.value
}
