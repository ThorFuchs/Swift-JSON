// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import JSON

private struct PayloadFixtures: Decodable {
    struct Fixture: Decodable {
        struct Envelope: Codable { let format: String; let version: Int; let utf8Base64: String }
        let id: String; let inner_utf8_sha256: String; let inner_json: String; let envelope: Envelope
    }
    let cases: [Fixture]
}
private func payloadFixtures() throws -> PayloadFixtures {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<4 { root.deleteLastPathComponent() }
    return try JSONDecoder().decode(PayloadFixtures.self, from: Data(contentsOf: root.appendingPathComponent("Tools/Release1_1Probes/Fixtures/version1.json")))
}
private func preserved(_ value: JSON) throws -> Data { try JSONWriter(options: .init(numberStyle: .preserved)).write(value) }
private struct PayloadPair: Codable { let a: JSONCodablePayload; let b: JSONCodablePayload }

@Test func payloadVersionOneGoldenFixturesPreserveScalarsOrderAndLexemes() throws {
    let fixtures = try payloadFixtures().cases
    #expect(fixtures.count == 8)
    for fixture in fixtures {
        let bytes = Data(fixture.inner_json.utf8)
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        #expect(try JSONSHA256Core.hexadecimal(bytes, accounting: &meter) == fixture.inner_utf8_sha256)
        let root = try JSONParser().parse(bytes)
        let payload = try JSONCodablePayload(preserving: root)
        let encoded = try JSONEncoder().encode(payload)
        let fields = try JSONDecoder().decode(PayloadFixtures.Fixture.Envelope.self, from: encoded)
        #expect(fields.format == "swift-json-value" && fields.version == 1)
        #expect(fields.utf8Base64 == fixture.envelope.utf8Base64)
        let decoded = try JSONDecoder().decode(JSONCodablePayload.self, from: JSONEncoder().encode(fixture.envelope))
        let opened = try decoded.value()
        #expect(try preserved(opened) == bytes)
        #expect(try preserved(JSONDecoder().decode(JSONCodablePayload.self, from: encoded).value()) == bytes)
    }
    for text in ["[]", "{}"] {
        let payload = try JSONCodablePayload(preserving: JSONParser().parse(text))
        #expect(try preserved(JSONDecoder().decode(JSONCodablePayload.self, from: JSONEncoder().encode(payload)).value()) == Data(text.utf8))
    }
}
@Test func payloadForeignPropertyListAndNestedNativeCodingRemainExact() throws {
    let root = try JSONParser().parse(#"{"b":-0.00e+2,"é":9007199254740993,"é":0.1,"":null}"#)
    let payload = try JSONCodablePayload(preserving: root)
    let pair = PayloadPair(a: payload, b: payload)
    let plist = try PropertyListEncoder().encode(pair)
    let reread = try PropertyListDecoder().decode(PayloadPair.self, from: plist)
    #expect(try preserved(reread.a.value()) == preserved(root))
    #expect(try preserved(reread.b.value()) == preserved(root))
    let native = try JSONValueEncoder().encode(pair)
    let decoded = try native.decode(PayloadPair.self)
    #expect(try preserved(decoded.a.value()) == preserved(root))
    #expect(try preserved(decoded.b.value()) == preserved(root))
}
@Test func payloadWrongFieldsAndUnsupportedVersionsUseCodableErrors() throws {
    for text in [#"{}"#, #"{"format":null,"version":1,"utf8Base64":"bnVsbA=="}"#,
                 #"{"format":3,"version":1,"utf8Base64":"bnVsbA=="}"#,
                 #"{"format":"swift-json-value","version":"1","utf8Base64":"bnVsbA=="}"#,
                 #"{"format":"other","version":1,"utf8Base64":"bnVsbA=="}"#,
                 #"{"format":"swift-json-value","version":2,"utf8Base64":"bnVsbA=="}"#] {
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(JSONCodablePayload.self, from: Data(text.utf8)) }
    }
    let extra = #"{"format":"swift-json-value","version":1,"utf8Base64":"bnVsbA==","metadata":true}"#
    #expect(try JSONDecoder().decode(JSONCodablePayload.self, from: Data(extra.utf8)).value().isNull)
}
@Test func payloadRejectsMalformedBase64AndCompleteInnerGrammar() throws {
    var texts = ["", "A", "bnVsbA=", "bnVsbA===", "bnVs bA==", "bnVsbB==", "AB==", "AAB=", "____", "AA==AA=="]
    let invalidBytes: [[UInt8]] = [[0xFF], Array("null true".utf8), Array("01".utf8), Array(#"{"é":0,"\u00e9":1}"#.utf8), Array(#""\uD800""#.utf8), Array("[1,]".utf8)]
    texts += invalidBytes.map { Data($0).base64EncodedString() } // Fixture creation only.
    for text in texts {
        let fields = PayloadFixtures.Fixture.Envelope(format: "swift-json-value", version: 1, utf8Base64: text)
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(JSONCodablePayload.self, from: JSONEncoder().encode(fields)) }
    }
    // The shared native Data codec also requires canonical unused padding bits.
    for text in ["AB==", "AAB="] { #expect(throws: DecodingError.self) { try JSONValueDecoder().decode(Data.self, from: .string(text)) } }
    let spaced = PayloadFixtures.Fixture.Envelope(format: "swift-json-value", version: 1, utf8Base64: Data(" null \n".utf8).base64EncodedString())
    #expect(try JSONDecoder().decode(JSONCodablePayload.self, from: JSONEncoder().encode(spaced)).value().isNull)
}
@Test func payloadInclusiveOwnedBudgetsAndEnvelopeExpansionAreChecked() throws {
    let root = try JSONParser().parse("0.1")
    let made = try JSONCodablePayload.preservingWithReport(root)
    let work = made.statistics[.workUnits]
    var limits = JSONLimits.balanced; limits[.workUnits] = work
    #expect(try JSONCodablePayload.preservingWithReport(root, limits: limits).statistics[.workUnits] == work)
    limits[.workUnits] = work - 1
    #expect(throws: JSONFailure.self) { try JSONCodablePayload(preserving: root, limits: limits) }
    limits = .balanced; limits[.stringBytes] = 3 // Inner 0.1 fits; MC4x does not.
    #expect(throws: JSONFailure.self) { try JSONCodablePayload(preserving: root, limits: limits) }
    limits = .balanced; limits[.outputBytes] = 4 // Inner fits; fixed envelope does not.
    #expect(throws: JSONFailure.self) { try JSONCodablePayload(preserving: root, limits: limits) }
    let opened = try made.result.valueWithReport()
    limits = .balanced; limits[.retainedBytes] = opened.statistics.peakLogicalRetainedBytes
    #expect(try preserved(made.result.value(limits: limits)) == preserved(root))
    limits[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try made.result.value(limits: limits) }
    #expect(try made.result.valueWithReport(limits: .offline).statistics[.workUnits] == opened.statistics[.workUnits])
}
@Test func payloadNativeCompositionUsesOneCumulativeMeter() throws {
    let payload = try JSONCodablePayload(preserving: JSONParser().parse("[0.1,9007199254740993,null]"))
    let single = try JSONValueEncoder().encodeWithReport(payload)
    let pair = PayloadPair(a: payload, b: payload)
    let both = try JSONValueEncoder().encodeWithReport(pair)
    #expect(both.statistics[.workUnits] > single.statistics[.workUnits])
    var limits = JSONLimits.balanced; limits[.workUnits] = single.statistics[.workUnits]
    #expect(throws: JSONFailure.self) { try JSONValueEncoder(options: .init(limits: limits)).encode(pair) }
    let opened = try JSONValueDecoder().decodeWithReport(JSONCodablePayload.self, from: single.result)
    limits = .balanced; limits[.workUnits] = opened.statistics[.workUnits] - 1
    #expect(throws: JSONFailure.self) { try JSONValueDecoder(options: .init(limits: limits)).decode(JSONCodablePayload.self, from: single.result) }
    #expect(opened.statistics[.nodes] > 3)
}
private struct CatchingPayload: Decodable {
    init(from decoder: any Decoder) throws {
        do { _ = try JSONCodablePayload(from: decoder) } catch { /* Deliberate caller misuse. */ }
    }
}
private struct InterruptingPayload: Encodable {
    let payload: JSONCodablePayload
    func encode(to encoder: any Encoder) throws {
        let native = try #require(encoder as? JSONNativeEncoder)
        let threshold = native.state.meter.used(.workUnits) + 100
        native.state.meter.checkpointObserver = { work in
            if work >= threshold { withUnsafeCurrentTask { $0?.cancel() } }
        }
        try payload.encode(to: encoder)
    }
}
@Test func payloadCaughtOperationalFailureStaysTerminalAndCorruptionDoesNot() throws {
    let payload = try JSONCodablePayload(preserving: JSONParser().parse("[0.1,9007199254740993,null]"))
    let envelope = try JSONValueEncoder().encode(payload)
    let report = try JSONValueDecoder().decodeWithReport(JSONCodablePayload.self, from: envelope)
    var limits = JSONLimits.balanced; limits[.workUnits] = report.statistics[.workUnits] - 1
    #expect(throws: JSONFailure.self) { try JSONValueDecoder(options: .init(limits: limits)).decode(CatchingPayload.self, from: envelope) }
    let corrupt = try JSONParser().parse(#"{"format":"swift-json-value","version":2,"utf8Base64":"bnVsbA=="}"#)
    _ = try corrupt.decode(CatchingPayload.self) // Corruption can be handled explicitly.
    var meter = try JSONWorkMeter(limits: limits, domain: .coding)
    try meter.work(limits[.workUnits])
    #expect(throws: JSONFailure.self) { try meter.work() }
    let terminal = meter.statistics()
    #expect(throws: JSONFailure.self) { try meter.checkpoint() }
    #expect(meter.statistics()[.workUnits] == terminal[.workUnits])
}
@Test func payloadCancellationDoesNotReturnAValidatedResult() async throws {
    let payload = try JSONCodablePayload(preserving: .string(String(repeating: "é", count: 1024)))
    let task = Task {
        withUnsafeCurrentTask { $0?.cancel() }
        return try payload.valueWithReport()
    }
    await #expect(throws: CancellationError.self) { try await task.value }
    let inOwnedLoop = Task { try JSONValueEncoder().encode(InterruptingPayload(payload: payload)) }
    await #expect(throws: CancellationError.self) { try await inOwnedLoop.value }
}
