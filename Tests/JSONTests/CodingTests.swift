// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
import JSON
private struct CodingSample: Codable, Equatable {
    let count: UInt64
    let name: String
    let flags: [Bool]
    let missing: Int?
    let bytes: Data
}
@Test func nativeCodingUsesValuesAndComposedBytes() throws {
    let model = CodingSample(count: UInt64.max, name: "e\u{301}", flags: [true, false], missing: nil, bytes: Data([0,1,255]))
    let value = try JSONValueEncoder().encode(model)
    #expect(try JSONValueDecoder().decode(CodingSample.self, from: value) == model)
    let bytes = try JSONWriter().encode(model)
    #expect(try JSONParser().decode(CodingSample.self, from: bytes) == model)
    #expect(try value.presence(of: "missing") == .absent)
    let exact = try JSONParser().parse(#"{"é":1,"é":2,"n":12345678901234567890123456789012345678901234567890}"#)
    #expect(try JSONValueEncoder().encode(exact) == exact)
    #expect(try JSONValueDecoder().decode(JSON.self, from: exact) == exact)
}
private struct PresenceSample: Codable {
    let value: JSONPresence<Int>
    enum CodingKeys: String, CodingKey { case value }
    init(_ value: JSONPresence<Int>) { self.value = value }
    init(from decoder: any Decoder) throws { value = try decoder.container(keyedBy: CodingKeys.self).decodePresence(Int.self, forKey: .value) }
    func encode(to encoder: any Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encodePresence(value, forKey: .value) }
}
@Test func explicitKeyedPresenceIsObservable() throws {
    for state: JSONPresence<Int> in [.absent, .null, .value(4)] {
        let value = try JSONValueEncoder().encode(PresenceSample(state))
        #expect(try JSONValueDecoder().decode(PresenceSample.self, from: value).value == state)
    }
    #expect(throws: DecodingError.self) { try JSONValueDecoder().decode(PresenceSample.self, from: JSONParser().parse(#"{"value":"wrong"}"#)) }
}
private enum CallerFailure: Error { case expected }
private struct ThrowingModel: Encodable { func encode(to encoder: any Encoder) throws { throw CallerFailure.expected } }
@Test func userErrorsAndNumericFailuresPropagate() throws {
    #expect(throws: CallerFailure.self) { try JSONValueEncoder().encode(ThrowingModel()) }
    #expect(throws: EncodingError.self) { try JSONValueEncoder().encode(Double.infinity) }
    #expect(throws: DecodingError.self) { try JSONValueDecoder().decode(Int8.self, from: .number(128)) }
    #expect(throws: EncodingError.self) { try Foundation.JSONEncoder().encode(JSONNumber(parsing: "1e1000000")) }
}
private class BaseModel: Codable {
    var base: Int = 7
    enum CodingKeys: String, CodingKey { case base }
    init() {}
    required init(from decoder: any Decoder) throws { base = try decoder.container(keyedBy: CodingKeys.self).decode(Int.self, forKey: .base) }
    func encode(to encoder: any Encoder) throws { var c = encoder.container(keyedBy: CodingKeys.self); try c.encode(base, forKey: .base) }
}
private final class DerivedModel: BaseModel {
    var derived: String = "value"
    enum Keys: String, CodingKey { case derived }
    override init() { super.init() }
    required init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self); derived = try c.decode(String.self, forKey: .derived)
        try super.init(from: c.superDecoder())
    }
    override func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self); try c.encode(derived, forKey: .derived); try super.encode(to: c.superEncoder())
    }
}
@Test func superCodingAndNonSendableModelsWorkSynchronously() throws {
    let encoded = try JSONValueEncoder().encode(DerivedModel())
    let report = try JSONValueDecoder().decodeWithReport(DerivedModel.self, from: encoded)
    #expect(report.result.base == 7 && report.result.derived == "value")
}
@Test func dateStrategiesAndCumulativeFacadeLimits() throws {
    let date = Date(timeIntervalSince1970: 1234.5)
    for strategy in [JSONCodingOptions.DateStrategy.deferredToDate, .secondsSince1970, .iso8601] {
        let coding = JSONCodingOptions(dateStrategy: strategy)
        let encoded = try JSONValueEncoder(options: coding).encode(date)
        #expect(try JSONValueDecoder(options: coding).decode(Date.self, from: encoded) == date)
    }
    var limits = JSONLimits.balanced; limits[.workUnits] = 4
    #expect(throws: JSONFailure.self) { try JSONWriter(options: .init(limits: limits)).encode([1,2,3]) }
}
private struct UserInfoModel: Codable {
    let observed: String
    static let key = CodingUserInfoKey(rawValue: "trace")!
    init(from decoder: any Decoder) throws { observed = decoder.userInfo[Self.key] as? String ?? "missing" }
    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer(); try container.encode(encoder.userInfo[Self.key] as? String ?? "missing")
    }
}
@Test func boundedUserInfoAndBothComposedProfilesApply() throws {
    let coding = JSONCodingOptions(userInfo: [UserInfoModel.key: "visible"])
    let model = try JSONValueDecoder(options: coding).decode(UserInfoModel.self, from: .null)
    #expect(model.observed == "visible")
    #expect(try JSONValueEncoder(options: coding).encode(model) == "visible")
    var limits = JSONLimits.balanced; limits[.stringBytes] = 1
    #expect(throws: JSONFailure.self) { try JSONWriter().encode("long", coding: .init(limits: limits)) }
    #expect(throws: JSONFailure.self) { try JSONParser().decode(String.self, from: Data(#""long""#.utf8), coding: .init(limits: limits)) }
    limits = .balanced; limits[.keyBytes] = 1
    #expect(throws: JSONFailure.self) { try JSONValueDecoder(options: .init(limits: limits, userInfo: [UserInfoModel.key: "visible"])).decode(UserInfoModel.self, from: .null) }
}

@Test func nativeJSONKeyFingerprintSharesTheDecoderWorkBudget() throws {
    let value = JSON.string(String(repeating: "a",count: 64))
    let text = try JSONValueDecoder().decodeWithReport(String.self,from: value)
    let key = try JSONValueDecoder().decodeWithReport(JSONKey.self,from: value)
    #expect(key.result.string == text.result)
    #expect(key.statistics[.workUnits] > text.statistics[.workUnits])
    var limits = JSONLimits.balanced; limits[.workUnits] = text.statistics[.workUnits] + 1
    #expect(try JSONValueDecoder(options: .init(limits: limits)).decode(String.self,from: value) == text.result)
    #expect(throws: JSONFailure.self) { try JSONValueDecoder(options: .init(limits: limits)).decode(JSONKey.self,from: value) }
}

@Test func nativeBase64CoversAllOctetsPaddingMalformedInputAndWorkLimits() throws {
    let bytes = Array(UInt8.min...UInt8.max)
    for count in 0...bytes.count {
        let data = Data(bytes.prefix(count)), encoded = try JSONValueEncoder().encode(data)
        #expect(encoded.stringValue == data.base64EncodedString())
        #expect(try JSONValueDecoder().decode(Data.self,from: encoded) == data)
    }
    for text in ["YQ", "YQ=", "=Q==", "Y=Q=", "YQ==YQ==", "YQ==\n", "é===", "!!!!"] {
        #expect(throws: DecodingError.self) { try JSONValueDecoder().decode(Data.self,from: .string(text)) }
    }
    var limits = JSONLimits.balanced; limits[.stringBytes] = 3
    #expect(throws: JSONFailure.self) { try JSONValueEncoder(options: .init(limits: limits)).encode(Data([1])) }
    let baseline = try JSONValueDecoder().decodeWithReport(Data.self,from: "YQ==")
    #expect(baseline.result == Data([97]) && baseline.statistics[.workUnits] > 4)
    limits = .balanced; limits[.workUnits] = 5
    #expect(throws: JSONFailure.self) { try JSONValueDecoder(options: .init(limits: limits)).decode(Data.self,from: "YQ==") }
}

@Test func fixedISO8601StrategiesRejectUnboundedDatesAndTexts() throws {
    let options = JSONCodingOptions(dateStrategy: .iso8601)
    #expect(throws: EncodingError.self) { try JSONValueEncoder(options: options).encode(Date(timeIntervalSince1970: .infinity)) }
    #expect(throws: EncodingError.self) { try JSONValueEncoder(options: options).encode(Date(timeIntervalSince1970: 253_402_300_800)) }
    #expect(throws: DecodingError.self) { try JSONValueDecoder(options: options).decode(Date.self,from: .string(String(repeating: "1",count: 1000))) }
}

@Test func stringDictionaryProjectionRejectsScalarCollisions() throws {
    let exact = try JSONParser().parse(#"{"é":1,"é":2}"#)
    #expect(try JSONValueDecoder().decode(JSON.self, from: exact) == exact)
    #expect(throws: DecodingError.self) {
        try JSONValueDecoder().decode([String: Int].self, from: exact)
    }
    #expect(try JSONValueDecoder().decode([String: Int].self, from: JSONParser().parse(#"{"a":1,"b":2}"#)) == ["a":1,"b":2])
    let object = try #require(exact.objectValue)
    #expect(try JSONValueEncoder().encode(object) == exact)
    #expect(try JSONValueDecoder().decode(JSONObject.self, from: exact) == object)
    #expect(throws: DecodingError.self) { try JSONValueDecoder().decode(JSONObject.self, from: .null) }
}

private struct SpellingProjection: Decodable {
    enum Keys: String, CodingKey { case composed = "é" }
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Keys.self)
        for key in container.allKeys { _ = try container.decode(Int.self, forKey: key) }
    }
}
@Test func codingKeyEnumerationRejectsChangedScalarSpelling() throws {
    #expect(throws: DecodingError.self) {
        try JSONValueDecoder().decode(SpellingProjection.self, from: JSONParser().parse(#"{"é":2}"#))
    }
    _ = try JSONValueDecoder().decode(SpellingProjection.self, from: JSONParser().parse(#"{"é":2}"#))
}
