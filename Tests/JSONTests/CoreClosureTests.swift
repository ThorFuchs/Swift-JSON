// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private func closureFailure(_ category: JSONFailure.Category, _ code: JSONFailure.Code,
                            metric: JSONResourceMetric? = nil, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected \(category)/\(code)") }
    catch let failure as JSONFailure {
        #expect(failure.category == category && failure.code == code)
        if let metric { #expect(failure.resource?.metric == metric) }
    } catch { Issue.record("Unexpected error: \(error)") }
}

@Test func qaCoreNumericTextPreservesLexemesAndFallsBackUnderInclusiveOutputCaps() throws {
    let parsed = try JSONNumber(parsing: "-12.00e3")
    #expect(try parsed.numericText(style: .normalized) == "-12e3")
    #expect(try parsed.numericText(style: .preserved) == "-12.00e3")
    #expect(try JSONNumber(integer: -12).numericText(style: .preserved) == "-12")
    var limits = JSONLimits.balanced; limits[.outputBytes] = 8
    #expect(try parsed.numericText(style: .preserved, limits: limits) == "-12.00e3")
    limits[.outputBytes] = 7
    closureFailure(.resource, .limitExceeded, metric: .outputBytes) {
        _ = try parsed.numericText(style: .preserved, limits: limits)
    }
}

@Test func qaCoreBinaryZeroSubnormalAndNonfiniteConversionsHaveExactOutcomes() throws {
    for text in ["0", "-0", "0e-999"] {
        #expect(try JSONNumber(parsing: text).doubleValue(policy: .exact) == 0)
    }
    for text in ["5e-324", "-5e-324"] {
        let number = try JSONNumber(parsing: text)
        let expected = text.hasPrefix("-") ? -Double.leastNonzeroMagnitude : Double.leastNonzeroMagnitude
        #expect(try number.doubleValue(policy: .rounded).bitPattern == expected.bitPattern)
        closureFailure(.conversion, .inexactConversion) { _ = try number.doubleValue(policy: .exact) }
    }
    #expect(try JSONNumber(parsing: "1e-1000").doubleValue(policy: .rounded) == 0)
    for value in [Double.nan, Double.infinity, -Double.infinity] {
        closureFailure(.conversion, .inexactConversion) { _ = try JSONNumber.fromFiniteDouble(value) }
    }
}

@Test func qaCoreSourceDocumentFinishesNumbersAtEOFWithCoherentSpans() throws {
    for (text, expected) in [("123", JSON.number(JSONNumber(integer: 123))),
                             ("-12.50e2", JSON.number(JSONNumber(integer: -1250))), ("0", JSON.number(JSONNumber(integer: 0)))] {
        let bytes = Data(text.utf8)
        let document = try JSONParser().parseDocument(bytes, source: "authored-eof")
        #expect(document.root == expected)
        #expect(document.source == "authored-eof" && document.sourceBytes == bytes)
        let map = try #require(document.sourceMap)
        let span = try #require(try map.span(at: []))
        #expect(span.start == 0 && span.end == UInt64(bytes.count))
        #expect(try map.span(at: [], kind: .memberKey) == nil)
        let replacement = document.replacingRoot(.null)
        #expect(replacement.source == nil && replacement.sourceBytes == nil && replacement.sourceMap == nil)
    }
}

@Test func qaCoreSourceMapDistinguishesTypedKeyAndIndexPaths() throws {
    let document = try JSONParser().parseDocument(Data(#"{"0":[17]}"#.utf8))
    let map = try #require(document.sourceMap)
    let key = try #require(try map.span(at: [.key("0")], kind: .memberKey))
    let element = try #require(try map.span(at: [.key("0"), .index(0)]))
    #expect(key.start == 1 && key.end == 4 && element.start == 6 && element.end == 8)
    #expect(try map.span(at: [.index(0)]) == nil)
    #expect(try map.span(at: [.key("0"), .key("0")]) == nil)
}

@Test func qaCoreValueMemberAndPresenceRefusalsKeepKindsDistinct() throws {
    closureFailure(.typeMismatch, .wrongKind) { _ = try JSON.null.requiredMember("x") }
    let value = try JSONParser().parse(#"{"null":null,"é":1,"e\u0301":2}"#)
    #expect(try value.presence(of: "null") == .null)
    #expect(try value.presence(of: "missing") == .absent)
    #expect(try value.presence(of: "é") == .value(1))
    #expect(try value.presence(of: "e\u{301}") == .value(2))
    #expect(try value.requiredMember("null") == .null)
    #expect(try value.requiredMember("é") == 1 && value.requiredMember("e\u{301}") == 2)
    closureFailure(.missingValue, .missingMember) { _ = try value.requiredMember("missing") }
}

@Test func qaCoreJSONKeyForeignAndNativeCodablePreserveScalarSpelling() throws {
    for text in ["", "a/~", "é", "e\u{301}", "🚀"] {
        let key = JSONKey(text)
        let foreign = try Foundation.JSONEncoder().encode(key)
        let decoded = try Foundation.JSONDecoder().decode(JSONKey.self, from: foreign)
        #expect(Array(decoded.string.utf8) == Array(text.utf8))
        let native = try JSONValueEncoder().encode(key)
        #expect(native == .string(text))
        #expect(try JSONValueDecoder().decode(JSONKey.self, from: native) == key)
    }
}

private struct DelegatedExactNumber: Codable {
    let number: JSONNumber
    init(_ number: JSONNumber) { self.number = number }
    init(from decoder: any Decoder) throws { number = try JSONNumber(from: decoder) }
    func encode(to encoder: any Encoder) throws { try number.encode(to: encoder) }
}
private struct NumberEnvelope: Codable { let payload: DelegatedExactNumber }

@Test func qaCoreCustomModelCanDelegateExactNumberCodingWithoutForeignProjection() throws {
    let number = try JSONNumber(parsing: "900719925474099312345678901234567890123456789.00")
    let model = NumberEnvelope(payload: DelegatedExactNumber(number))
    let encoded = try JSONValueEncoder().encode(model)
    #expect(try encoded.requiredMember("payload") == .number(number))
    let decoded = try encoded.decodeWithReport(NumberEnvelope.self)
    #expect(decoded.result.payload.number == number && decoded.statistics[.workUnits] > 0)
    #expect(try decoded.result.payload.number.numericText(style: .preserved) == "900719925474099312345678901234567890123456789.00")
    do {
        _ = try JSONValueDecoder().decode(NumberEnvelope.self, from: JSONParser().parse(#"{"payload":false}"#))
        Issue.record("Boolean must not decode as a number")
    } catch DecodingError.typeMismatch(let type, let context) {
        #expect(type == JSONNumber.self && context.codingPath.map(\.stringValue) == ["payload"])
        #expect((context.underlyingError as? JSONFailure)?.code == .wrongKind)
    }
}

private struct DataEnvelope: Decodable { let payload: Data }
private struct DateEnvelope: Decodable { let payload: Date }
private struct IntegerEnvelope: Decodable { let payload: Int }
private struct ExplicitIntegerEnvelope: Decodable {
    enum Key: String, CodingKey { case payload }
    let payload: Int8
    init(from decoder: any Decoder) throws {
        let object = try decoder.container(keyedBy: Key.self)
        let child = try object.superDecoder(forKey: .payload)
        payload = try child.singleValueContainer().decode(Int8.self)
    }
}
private func wrongKind<T: Decodable>(_ type: T.Type, value: JSON, options: JSONCodingOptions = .init()) throws {
    do { _ = try JSONValueDecoder(options: options).decode(type, from: value); Issue.record("Expected wrong kind") }
    catch DecodingError.typeMismatch(_, let context) {
        #expect(context.codingPath.map(\.stringValue) == ["payload"])
        #expect((context.underlyingError as? JSONFailure)?.category == .typeMismatch)
        #expect((context.underlyingError as? JSONFailure)?.code == .wrongKind)
    }
}

@Test func qaCoreNativeDataDateAndIntegerWrongKindsKeepNestedPaths() throws {
    let value = try JSONParser().parse(#"{"payload":false}"#)
    try wrongKind(DataEnvelope.self, value: value)
    try wrongKind(DateEnvelope.self, value: value, options: .init(dateStrategy: .iso8601))
    try wrongKind(IntegerEnvelope.self, value: value)
    try wrongKind(ExplicitIntegerEnvelope.self, value: value)
}

@Test func qaCoreMalformedBase64ReportsSyntaxAtTheNestedField() throws {
    for text in ["AA!A", "AAA!"] {
        let value = JSON.object(try JSONObject(members: [.init("payload", value: .string(text))]))
        do { _ = try value.decode(DataEnvelope.self); Issue.record("Expected malformed base64") }
        catch DecodingError.dataCorrupted(let context) {
            #expect(context.codingPath.map(\.stringValue) == ["payload"])
            #expect((context.underlyingError as? JSONFailure)?.category == .syntax)
            #expect((context.underlyingError as? JSONFailure)?.code == .invalidSyntax)
        }
    }
}

@Test func qaCoreMalformedISO8601IsCorruptionRatherThanWrongKind() throws {
    let value = try JSONParser().parse(#"{"payload":"not a date"}"#)
    do {
        _ = try value.decode(DateEnvelope.self, coding: .init(dateStrategy: .iso8601))
        Issue.record("Expected malformed date")
    } catch DecodingError.dataCorrupted(let context) {
        #expect(context.codingPath.map(\.stringValue) == ["payload"])
    }
}

@Test func qaCoreMalformedBase64ReleasesScratchAndKeepsScopeWorkCumulative() throws {
    let value = try JSONParser().parse(#"{"bad":"Zm9vAAA!","good":17}"#)
    func probe(_ attempts: Int, _ limits: JSONLimits) throws -> JSONOperationReport<Int> {
        try value.readWithReport(limits: limits) { root in
            let bad = try root["bad"]
            for _ in 0..<attempts {
                do { _ = try bad.decode(Data.self); Issue.record("Expected malformed base64") }
                catch DecodingError.dataCorrupted(let context) {
                    // Native model projection starts at the selected value. Its
                    // Codable path is relative to that projection root.
                    #expect(context.codingPath.isEmpty)
                    #expect((context.underlyingError as? JSONFailure)?.code == .invalidSyntax)
                }
            }
            return try root["good"].requiredInteger(as: Int.self)
        }
    }
    let once = try probe(1, .balanced)
    var limits = JSONLimits.balanced; limits[.retainedBytes] = once.statistics.peakLogicalRetainedBytes
    let repeated = try probe(32, limits)
    #expect(once.result == 17 && repeated.result == 17)
    #expect(repeated.statistics.peakLogicalRetainedBytes == once.statistics.peakLogicalRetainedBytes)
    #expect(repeated.statistics[.retainedBytes] == 0)
    #expect(repeated.statistics[.workUnits] > once.statistics[.workUnits])
}

@Test func qaCoreScalarSortedPrefixKeysHaveIndependentGoldenAndCumulativeWork() throws {
    let keys = ["🚀", "é", "e\u{301}", "aa", "a/", "a", ""]
    let object = try JSONObject(members: keys.map { JSONMember($0, value: .null) })
    let golden = #"{"":null,"a":null,"a/":null,"aa":null,"é":null,"é":null,"🚀":null}"#
    let writer = JSONWriter(options: .init(keyOrder: .scalar))
    let baseline = try writer.writeWithReport(.object(object))
    #expect(Array(baseline.result) == Array(golden.utf8))
    #expect(object.members.map(\.key) == keys.map { JSONKey($0) })
    var limits = JSONLimits.balanced; limits[.workUnits] = baseline.statistics[.workUnits]
    #expect(try JSONWriter(options: .init(limits: limits, keyOrder: .scalar)).write(.object(object)) == baseline.result)
    limits[.workUnits] -= 1
    closureFailure(.resource, .limitExceeded, metric: .workUnits) {
        _ = try JSONWriter(options: .init(limits: limits, keyOrder: .scalar)).write(.object(object))
    }
}

@Test func qaCoreWriterRejectsInvalidIndentationBeforeOutput() {
    for indentation in [-1, 9] {
        closureFailure(.configuration, .invalidLimits) {
            _ = try JSONWriter(options: .init(indentation: indentation)).write(.null)
        }
    }
}

@Test func qaCoreRemovingAbsentMemberPreservesSmallAndIndexedObjectsButStillAdmits() throws {
    for count in [0, 1, 31, 32, 64] {
        let object = try JSONObject(members: (0..<count).map { JSONMember("k\($0)", value: .number(JSONNumber(integer: $0))) })
        let result = try object.removing("absent")
        #expect(result == object && result.members.map(\.key) == object.members.map(\.key))
        var limits = JSONLimits.balanced; limits[.workUnits] = 0
        closureFailure(.resource, .limitExceeded, metric: .workUnits) { _ = try object.removing("absent", limits: limits) }
    }
}

private struct ReusedUnkeyed: Encodable {
    func encode(to encoder: any Encoder) throws {
        var first = encoder.unkeyedContainer(); try first.encode(1)
        var second = encoder.unkeyedContainer(); try second.encode("two")
        try first.encode(false)
    }
}
private struct DoubleWrite: Encodable {
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer(); try container.encode(1); try container.encode(2)
    }
}
private struct DoubleWriteEnvelope: Encodable { let payload = DoubleWrite() }

@Test func qaCoreReusedUnkeyedContainersShareStateAndDoubleSingleWritesFail() throws {
    #expect(try JSONValueEncoder().encode(ReusedUnkeyed()) == .array([1, "two", false]))
    do { _ = try JSONValueEncoder().encode(DoubleWriteEnvelope()); Issue.record("Expected duplicate single write") }
    catch EncodingError.invalidValue(_, let context) {
        #expect(context.codingPath.map(\.stringValue) == ["payload"])
    }
}

@Test func qaCoreIntegerKeyDictionaryProjectionKeepsItsNumericKeys() throws {
    let value = try JSONParser().parse(#"{"-1":"negative","17":"positive"}"#)
    let model = try value.decode([Int: String].self)
    #expect(model == [-1: "negative", 17: "positive"])
    #expect(try JSONValueEncoder().encode(model) == value)
}

private struct BoundedWideFields: Encodable {
    struct Field: CodingKey {
        let stringValue: String
        var intValue: Int? { nil }
        init(_ text: String) { stringValue = text }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Field.self)
        for index in 0..<64 { try container.encodeNil(forKey: Field("k\(index)")) }
    }
}

@Test func qaCoreWideEncodingRefusesEveryInsufficientWorkBudgetAndAcceptsTheBoundary() throws {
    let baseline = try JSONValueEncoder().encodeWithReport(BoundedWideFields())
    let work = baseline.statistics[.workUnits]
    // This exhaustive quota sweep is deliberately bounded as test work too.
    try #require(work > 0 && work <= 8192)
    let golden = try JSONObject(members: (0..<64).map { JSONMember("k\($0)", value: .null) })
    #expect(baseline.result == .object(golden))
    for quota in 0..<work {
        var limits = JSONLimits.balanced; limits[.workUnits] = quota
        do {
            _ = try JSONValueEncoder(options: .init(limits: limits)).encode(BoundedWideFields())
            Issue.record("Insufficient cumulative work accepted: \(quota)")
        } catch let failure as JSONFailure {
            #expect(failure.category == .resource && failure.code == .limitExceeded)
            let resource = try #require(failure.resource)
            let attempted = try #require(resource.attemptedUsage)
            #expect(resource.metric == .workUnits && resource.limit == quota && attempted > quota)
        }
    }
    var limits = JSONLimits.balanced; limits[.workUnits] = work
    let accepted = try JSONValueEncoder(options: .init(limits: limits)).encodeWithReport(BoundedWideFields())
    #expect(accepted.result == baseline.result && accepted.statistics[.workUnits] == work)
    #expect(golden.count == 64 && golden["k63"] == .null)
}

@Test func qaCoreFiniteDoubleRoundTripsAndDecimalOverflowHaveExplicitFidelity() throws {
    for value in [0.0, -12.5, 0.1, Double.greatestFiniteMagnitude] {
        let number = try JSONNumber.fromFiniteDouble(value)
        #expect(try number.doubleValue(policy: .rounded) == value)
    }
    let decimalTenth = try JSONNumber.fromFiniteDouble(0.1)
    #expect(decimalTenth == (try JSONNumber(parsing: "0.1")))
    closureFailure(.conversion, .inexactConversion) { _ = try decimalTenth.doubleValue(policy: .exact) }
    for policy in [JSONNumberConversionPolicy.exact, .rounded] {
        closureFailure(.conversion, .inexactConversion) { _ = try JSONNumber(parsing: "9e165").decimalValue(policy: policy) }
    }
}

@Test func qaCoreMappedErrorConstructionSharesWorkAndCannotMaskQuotaFailure() throws {
    let document = try JSONParser().parseDocument(Data(#"{"x":false}"#.utf8))
    func probe(_ limits: JSONLimits) throws -> JSONOperationReport<Int> {
        try document.readWithReport(limits: limits) { root in
            do { _ = try root["x"].requiredNumber(); Issue.record("Expected wrong kind") }
            catch let failure as JSONAccessFailure {
                #expect(failure.path == [.key("x")] && failure.cause.code == .wrongKind)
                #expect(failure.cause.location?.byteOffset == 5)
            }
            return 17
        }
    }
    let baseline = try probe(.balanced); let work = baseline.statistics[.workUnits]
    try #require(work > 0 && work <= 1024)
    for quota in 0..<work {
        var limits = JSONLimits.balanced; limits[.workUnits] = quota
        closureFailure(.resource, .limitExceeded, metric: .workUnits) { _ = try probe(limits) }
    }
    var limits = JSONLimits.balanced; limits[.workUnits] = work
    let boundary = try probe(limits)
    #expect(boundary.result == 17 && boundary.statistics[.workUnits] == work && boundary.statistics[.retainedBytes] == 0)
}

@Test func qaCorePayloadFieldEncodingSharesEveryNativeWorkBoundary() throws {
    let payload = try JSONCodablePayload(preserving: .null)
    let baseline = try JSONValueEncoder().encodeWithReport(payload)
    let expected = try JSONParser().parse(#"{"format":"swift-json-value","version":1,"utf8Base64":"bnVsbA=="}"#)
    #expect(baseline.result == expected)
    let work = baseline.statistics[.workUnits]; try #require(work > 0 && work <= 2048)
    for quota in 0..<work {
        var limits = JSONLimits.balanced; limits[.workUnits] = quota
        closureFailure(.resource, .limitExceeded, metric: .workUnits) {
            _ = try JSONValueEncoder(options: .init(limits: limits)).encode(payload)
        }
    }
    var limits = JSONLimits.balanced; limits[.workUnits] = work
    #expect(try JSONValueEncoder(options: .init(limits: limits)).encode(payload) == expected)
    #expect(try payload.value() == .null)
}
