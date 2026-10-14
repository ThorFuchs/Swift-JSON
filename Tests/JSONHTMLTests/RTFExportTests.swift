// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import Testing
@testable import JSONHTML
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif

@Test func exportRTFIsOptInAndEscapesExecutableLookingText() throws {
    let value: JSON = .string("{}\\rtf1 \\object \\u123? ée\u{301}😀\t\n")
    let item = try JSONExportDocument.prepare(value, options: .init(formats: [.rtf]))
    let bytes = try item.data(for: .rtf)
    let text = String(decoding: bytes, as: UTF8.self)
    #expect(text.hasPrefix("{\\rtf1\\ansi") && text.hasSuffix("}"))
    #expect(text.contains(#"\{\}"#))
    #expect(text.contains(#"\\\\rtf1"#) && text.contains(#"\\\\object"#))
    #expect(text.contains(#"\u233?e\u769?\u-10179?\u-8704?"#))
    #expect(text.contains(#"\\u0009\\u000a"#)) // JSON string escapes are not indentation controls.
    #expect(!text.contains("\\field") && !text.contains("\\pict") && !text.contains("\\objdata"))
    #expect(item.availableFormats == [.rtf] && item.advertisedFormats == [.rtf])
    #expect(try JSONExportDocument.prepare(.null).availableFormats.count == 4)
    #expect(try JSONExportDocument.prepare(value, options: .init(formats: [.rtf], theme: .dark)).data(for: .rtf) == bytes)
}

@Test func exportRTFStyleAndUTF16CapBoundariesAreInclusive() throws {
    for delta in [-1, 0, 1] {
        var limits = JSONExportLimits()
        limits.maxRTFStyleRuns = UInt64(1 + delta); limits.maxRTFUTF16Units = 4
        if delta < 0 {
            #expect(throws: JSONExportFailure.limitExceeded(.rtfStyleRuns, limit: 0, attempted: 1)) {
                try JSONExportDocument.prepare(.null, options: .init(formats: [.rtf], limits: limits))
            }
        } else { #expect(try JSONExportDocument.prepare(.null, options: .init(formats: [.rtf], limits: limits)).availableFormats == [.rtf]) }
        limits.maxRTFStyleRuns = 1; limits.maxRTFUTF16Units = UInt64(4 + delta)
        if delta < 0 {
            #expect(throws: JSONExportFailure.limitExceeded(.rtfUTF16Units, limit: 3, attempted: 4)) {
                try JSONExportDocument.prepare(.null, options: .init(formats: [.rtf], limits: limits))
            }
        } else { #expect(try JSONExportDocument.prepare(.null, options: .init(formats: [.rtf], limits: limits)).availableFormats == [.rtf]) }
    }
    for cap in [UInt64(2), 3] {
        let options = JSONExportOptions(formats: [.rtf], limits: .init(maxRTFStyleRuns: cap))
        if cap == 2 {
            #expect(throws: JSONExportFailure.limitExceeded(.rtfStyleRuns, limit: 2, attempted: 3)) {
                try JSONExportDocument.prepare(.array([.null]), options: options)
            }
        } else { #expect(try JSONExportDocument.prepare(.array([.null]), options: options).availableFormats == [.rtf]) }
    }
    // Two quotes plus a supplementary scalar require four UTF-16 units.
    #expect(throws: JSONExportFailure.limitExceeded(.rtfUTF16Units, limit: 3, attempted: 4)) {
        try JSONExportDocument.prepare(.string("😀"), options: .init(formats: [.rtf], limits: .init(maxRTFUTF16Units: 3)))
    }
    for limits in [JSONExportLimits(maxRTFStyleRuns: .max), .init(maxRTFUTF16Units: .max)] {
        #expect(throws: JSONExportFailure.invalidConfiguration) {
            try JSONExportDocument.prepare(.null, options: .init(formats: [.rtf], limits: limits))
        }
    }
    #expect(throws: JSONExportFailure.counterOverflow(.rtfUTF16Units)) {
        try JSONExportBuffer.adding(.rtfUTF16Units, .max, 1, .max)
    }
}

@Test func exportRTFOutputRetentionAndAggregateCapsApplyBeforeGrowth() throws {
    let root: JSON = .array([.string("é😀"), .null])
    let options = JSONExportOptions(formats: [.rtf])
    let baseline = try JSONExportDocument.prepareWithReport(root, options: options)
    for metric in [JSONResourceMetric.workUnits, .outputBytes, .retainedBytes] {
        let boundary = metric == .retainedBytes ? baseline.operation.peakLogicalRetainedBytes : baseline.operation[metric]
        for delta in [-1, 0, 1] {
            var changed = options
            changed.limits.core[metric] = UInt64(Int64(boundary) + Int64(delta))
            if delta < 0 { #expect(throws: JSONFailure.self) { try JSONExportDocument.prepare(root, options: changed) } }
            else { #expect(try JSONExportDocument.prepareWithReport(root, options: changed).operation == baseline.operation) }
        }
    }
    for delta in [-1, 0, 1] {
        var changed = options
        changed.limits.maxRepresentationBytes = UInt64(Int64(baseline.preparedBytes) + Int64(delta))
        changed.limits.maxPreparedBytes = changed.limits.maxRepresentationBytes
        if delta < 0 { #expect(throws: JSONExportFailure.self) { try JSONExportDocument.prepare(root, options: changed) } }
        else { #expect(try JSONExportDocument.prepareWithReport(root, options: changed).preparedBytes == baseline.preparedBytes) }
    }
}

@Test func exportRTFSharesAdmissionAndTerminalFailureWithOtherFormats() throws {
    let root: JSON = .array([.null, true])
    let alone = try JSONExportDocument.prepareWithReport(root, options: .init(formats: [.rtf]))
    let combined = try JSONExportDocument.prepareWithReport(root, options: .init(formats: [.json, .rtf]))
    #expect(combined.operation[.nodes] == 3 && alone.operation[.nodes] == 3)
    var limits = JSONLimits.balanced; limits[.workUnits] = alone.operation[.workUnits]
    #expect(throws: JSONFailure.self) {
        try JSONExportDocument.prepare(root, options: .init(formats: [.json, .rtf], limits: .init(core: limits)))
    }
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
    #expect(throws: JSONExportFailure.self) {
        try JSONExportDocument.prepare(root, options: .init(formats: [.json, .rtf], limits: .init(maxRTFStyleRuns: 0)), meter: &meter)
    }
    #expect(meter.used(.retainedBytes) == 17 && meter.used(.outputBytes) > 0)
    let work = meter.used(.workUnits)
    #expect(throws: JSONExportFailure.self) { try JSONExportDocument.prepare(root, options: .init(formats: [.rtf]), meter: &meter) }
    #expect(meter.used(.workUnits) == work)
}

@Test func exportRTFCancellationDuringEscapingIsTerminal() async throws {
    let root: JSON = .string(String(repeating: "😀{}\\", count: 1_000))
    let options = JSONExportOptions(formats: [.rtf])
    let baseline = try JSONExportDocument.prepareWithReport(root, options: options)
    let task = Task {
        var meter = try JSONWorkMeter(limits: .balanced, domain: .writing); try meter.retain(17)
        meter.checkpointObserver = { work in
            if work >= baseline.operation[.workUnits] / 2 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        #expect(throws: CancellationError.self) { try JSONExportDocument.prepare(root, options: options, meter: &meter) }
        #expect(meter.used(.outputBytes) > 1_000 && meter.used(.outputBytes) < baseline.operation[.outputBytes])
        #expect(meter.used(.retainedBytes) == 17)
        #expect(throws: CancellationError.self) { try meter.checkpoint() }
    }
    try await task.value
}

#if canImport(AppKit) || canImport(UIKit)
@Test @MainActor func appleRTFNativeDecodePreservesTextAndActualStyles() throws {
    let source = #"{"é":"é😀{}\\\t\n","n":-0.00e+2,"b":true,"z":null}"#
    let root = try JSONParser().parse(source)
    for width in [1, 4, 8] {
        let item = try JSONExportDocument.prepare(root, options: .init(formats: [.plainText, .rtf], tabWidth: width))
        let decoded = try NSAttributedString(data: item.data(for: .rtf), options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        #expect(try Data(decoded.string.utf8) == item.data(for: .plainText))
        #expect(decoded.length == decoded.string.utf16.count)
        let body = decoded.string as NSString
        for (text, rgb) in [("\"é\"", [33,75,110]), ("e\u{301}😀", [35,111,59]), ("-0.00e+2", [143,59,16]), ("true", [106,58,156]), ("null", [100,100,100])] {
            let range = body.range(of: text)
            try #require(range.location != NSNotFound && NSMaxRange(range) <= decoded.length)
            let attributes = decoded.attributes(at: range.location, effectiveRange: nil)
            #if canImport(AppKit)
            let font = try #require(attributes[.font] as? NSFont)
            let color = try #require((attributes[.foregroundColor] as? NSColor)?.usingColorSpace(.deviceRGB))
            let expected = try #require(NSColor(calibratedRed: CGFloat(rgb[0])/255, green: CGFloat(rgb[1])/255, blue: CGFloat(rgb[2])/255, alpha: 1).usingColorSpace(.deviceRGB))
            #expect(abs(color.redComponent * 255 - expected.redComponent * 255) < 0.01)
            #expect(abs(color.greenComponent * 255 - expected.greenComponent * 255) < 0.01)
            #expect(abs(color.blueComponent * 255 - expected.blueComponent * 255) < 0.01)
            #else
            let font = try #require(attributes[.font] as? UIFont)
            let color = try #require(attributes[.foregroundColor] as? UIColor)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            #expect(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
            #expect(abs(red * 255 - CGFloat(rgb[0])) < 0.01 && abs(green * 255 - CGFloat(rgb[1])) < 0.01 && abs(blue * 255 - CGFloat(rgb[2])) < 0.01)
            #endif
            #expect(font.fontName.contains("Menlo") && font.pointSize == 11)
        }
        let paragraph = try #require(decoded.attribute(.paragraphStyle, at: (decoded.string as NSString).range(of: "\"é\"").location, effectiveRange: nil) as? NSParagraphStyle)
        #expect(paragraph.tabStops.count == 1)
        #expect(abs(paragraph.tabStops[0].location - CGFloat(width) * 6.6) < 0.01)
    }
    var deep: JSON = .string("LAST-CONTENT-SENTINEL")
    for _ in 0..<64 { deep = .array([deep]) }
    let deepItem = try JSONExportDocument.prepare(deep, options: .init(formats: [.rtf, .plainText], indentation: 3))
    let deepDecoded = try NSAttributedString(data: deepItem.data(for: .rtf), options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
    #expect(try Data(deepDecoded.string.utf8) == deepItem.data(for: .plainText))
    let sentinel = (deepDecoded.string as NSString).range(of: "LAST-CONTENT-SENTINEL")
    let deepParagraph = try #require(deepDecoded.attribute(.paragraphStyle, at: sentinel.location, effectiveRange: nil) as? NSParagraphStyle)
    #expect(deepParagraph.tabStops.count == 192)
    #expect(abs(deepParagraph.tabStops[191].location - 192 * 26.4) < 0.01)
    for root in [JSON.null, true, .number(42), .string("\u{85}\u{2028}\u{2029}e\u{301}😀"), .array([]), .object(try JSONObject(members: []))] {
        let item = try JSONExportDocument.prepare(root, options: .init(formats: [.rtf, .plainText]))
        let decoded = try NSAttributedString(data: item.data(for: .rtf), options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil)
        #expect(try Data(decoded.string.utf8) == item.data(for: .plainText))
    }
}
#endif
