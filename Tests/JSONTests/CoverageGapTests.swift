// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private func gapFailure(_ category: JSONFailure.Category, _ code: JSONFailure.Code, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected \(category)/\(code)") }
    catch let failure as JSONFailure { #expect(failure.category == category); #expect(failure.code == code) }
    catch { Issue.record("Unexpected error: \(error)") }
}
private func gapAccess(_ path: [JSONLocationComponent], _ code: JSONFailure.Code = .wrongKind, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected access failure") }
    catch let failure as JSONAccessFailure { #expect(failure.path == path); #expect(failure.cause.code == code) }
    catch { Issue.record("Unexpected error: \(error)") }
}

@Test func qaReadWrongKindProjectionsRecoverWithinOneScope() throws {
    let value = try JSONParser().parse(#"{"value":true,"good":17}"#)
    let report = try value.readWithReport { root in
        let wrong = try root["value"]
        gapAccess([.key("value")]) { _ = try wrong.requiredString() }
        gapAccess([.key("value")]) { _ = try wrong.requiredNumber() }
        gapAccess([.key("value")]) { _ = try wrong.requiredObject() }
        gapAccess([.key("value")]) { _ = try wrong.requiredArray() }
        gapAccess([.key("value")]) { _ = try wrong.requiredDouble(policy: .exact) }
        gapAccess([.key("value")]) { _ = try wrong.requiredDecimal(policy: .exact) }
        return try root["good"].requiredNumber()
    }
    #expect(report.result == JSONNumber(integer: 17))
    #expect(report.statistics[.workUnits] > 0 && report.statistics[.retainedBytes] == 0)
}

@Test func qaReadRawAndTypedPresenceUseLiteralScalarKeys() throws {
    let value = try JSONParser().parse(#"{"é":1,"e\u0301":2,"nil":null,"wrong":[],"empty":""}"#)
    try value.read { (root: JSONReadCursor) throws -> Void in
        #expect(try root.presence(of: "é") == .value(1))
        #expect(try root.presence(of: JSONKey("e\u{301}")) == .value(2))
        #expect(try root.presence(of: "nil") == .null)
        #expect(try root.presence(of: "absent") == .absent)
        gapAccess([.key("wrong")]) { _ = try root.stringPresence(of: "wrong") }
        gapAccess([.key("wrong")]) { _ = try root.booleanPresence(of: JSONKey("wrong")) }
        gapAccess([.key("wrong")]) { _ = try root.numberPresence(of: "wrong") }
        gapAccess([.key("wrong"), .key("member")]) { _ = try root["wrong"].presence(of: "member") }
        #expect(try root.stringPresence(of: "empty") == .value(""))
    }
}

@Test func qaReadFailedDecimalProjectionReleasesTemporaryRetention() throws {
    let value = try JSONParser().parse("999999999999999999999999999999999999999")
    let once = try value.readWithReport { root in
        gapAccess([], .inexactConversion) { _ = try root.requiredDecimal(policy: .exact) }
        return try root.requiredNumber()
    }
    var limits = JSONLimits.balanced; limits[.retainedBytes] = once.statistics.peakLogicalRetainedBytes
    let repeated = try value.readWithReport(limits: limits) { root in
        for _ in 0..<32 { gapAccess([], .inexactConversion) { _ = try root.requiredDecimal(policy: .exact) } }
        return try root.requiredNumber()
    }
    #expect(repeated.result == once.result)
    #expect(repeated.statistics.peakLogicalRetainedBytes == once.statistics.peakLogicalRetainedBytes)
    #expect(repeated.statistics[.retainedBytes] == 0)
    #expect(repeated.statistics[.numericWorkUnits] > once.statistics[.numericWorkUnits])
}

@Test func qaPointerCompositionPreservesLiteralTokensAndInclusiveLimits() throws {
    let base = try JSONPointer(tokens: ["a/b"]), tail = try JSONPointer(tokens: ["~", "é", "e\u{301}"])
    let combined = try base.appending(tail)
    #expect(combined.tokens == [JSONKey("a/b"), "~", "é", "e\u{301}"])
    #expect(combined.string == "/a~1b/~0/é/e\u{301}")
    #expect(try combined.appending(JSONPointer(parsing: "")) == combined)
    #expect(try JSONPointer(parsing: "").appending(tail) == tail)
    #expect(try base.appending(key: "/~").string == "/a~1b/~1~0")
    var limits = JSONLimits.balanced; limits[.pointerTokens] = 4
    #expect(try base.appending(tail, limits: limits) == combined)
    limits[.pointerTokens] = 3
    gapFailure(.resource, .limitExceeded) { _ = try base.appending(tail, limits: limits) }
    gapFailure(.pointer, .invalidIndex) { _ = try base.appending(index: -1) }
}

@Test func qaPointerFragmentRefusalsAndNavigationHavePreciseCauses() throws {
    for fragment in ["#/%", "#/%A", "#/%G0", "#/%0g", "#/%ff", "/a"] {
        gapFailure(.pointer, .invalidPointer) { _ = try JSONPointer.uriFragment(fragment) }
    }
    let object = try JSONParser().parse(#"{"present":null}"#)
    gapFailure(.pointer, .missingTarget) { _ = try JSONPointer(parsing: "/missing").resolve(in: object) }
    gapFailure(.typeMismatch, .wrongKind) { _ = try JSONPointer(parsing: "/present/child").resolve(in: object) }
    gapFailure(.pointer, .invalidIndex) { _ = try JSONPointer(parsing: "/999999999999999999999999999999999999").resolve(in: .array([1])) }
}

@Test func qaPreviewScalarEscapesAndNormalizedNumbersAreStrictWhenComplete() throws {
    let cases: [(JSON, String)] = [(.null, "null"), (.boolean(true), "true"), (.boolean(false), "false"),
        (.string("\"\\\n\t\u{0}"), #""\"\\\u000a\u0009\u0000""#),
        (try JSONParser().parse("-12.00e3"), "-12e3")]
    for (value, expected) in cases {
        let preview = try JSONPreview.render(value)
        #expect(preview.complete && preview.text == expected)
        #expect(try JSONParser().parse(preview.text) == value)
    }
}

@Test func qaPreviewOmissionKeepsUTF8WholeAtEveryScalarByteBoundary() throws {
    for capacity in 8...12 {
        let preview = try JSONPreview.render(.string("🚀x"), options: .init(maxBytes: UInt64(capacity)))
        #expect(!preview.complete && preview.text.hasSuffix("[...]"))
        #expect(preview.text.utf8.count <= capacity && !preview.text.contains("�"))
        #expect(preview.text == (capacity < 12 ? "\"[...]" : "\"🚀[...]"))
    }
    let object = try JSONParser().parse(#"{"x":{"private":"secret"}}"#)
    let shallow = try JSONPreview.render(object, options: .init(maxDepth: 1))
    #expect(!shallow.complete && shallow.text == #"{"x":"[...]"}[...]"#)
    let zero = try JSONPreview.render(.null, options: .init(maxNodes: 0))
    #expect(!zero.complete && zero.text == "[...]")
}

@Test func qaPreviewInvalidOptionsAreConfigurationFailures() {
    for options in [JSONPreviewOptions(maxDepth: -1), .init(maxBytes: 6)] {
        gapFailure(.configuration, .invalidLimits) { _ = try JSONPreview.render(.null, options: options) }
    }
}

@Test func qaValueHashLawsCoverEveryKindAndExactObjectIdentity() throws {
    let equivalents: [(JSON, JSON)] = [(.null,.null), (true,true), (false,false), ("e\u{301}","e\u{301}"),
        (try JSONParser().parse("1.00"), 1), (.array([.null,true,"x"]), .array([.null,true,"x"])),
        (try JSONParser().parse(#"{"é":1,"e\u0301":2}"#), try JSONParser().parse(#"{"e\u0301":2.0,"é":1e0}"#))]
    for (a,b) in equivalents { #expect(a == b); #expect(a.hashValue == b.hashValue); #expect(Set([a,b]).count == 1) }
    #expect(JSON.boolean(true) != false)
    #expect(JSON.array([1]) != .array([1,2]))
    #expect(try JSONParser().parse(#"{"a":1}"#) != JSONParser().parse(#"{"b":1}"#))
    #expect(try JSONParser().parse(#"{"a":1}"#) != JSONParser().parse(#"{"a":1,"b":2}"#))
    let nilValue: JSON = nil, array: JSON = [nil,true,"x"]
    #expect(nilValue == .null && array == .array([.null,true,"x"]))
}

@Test func qaDecodeConvenienceReportPreservesExactIntegerAndWorkRefusal() throws {
    let value = try JSONParser().parse("9007199254740993")
    let report = try value.decodeWithReport(UInt64.self)
    #expect(report.result == 9_007_199_254_740_993)
    #expect(report.statistics.domain == .coding && report.statistics[.numericWorkUnits] > 0)
    var coding = JSONCodingOptions(); coding.limits[.workUnits] = report.statistics[.workUnits]
    #expect(try value.decodeWithReport(UInt64.self, coding: coding).result == report.result)
    coding.limits[.workUnits] -= 1
    gapFailure(.resource, .limitExceeded) { _ = try value.decodeWithReport(UInt64.self, coding: coding) }
}
