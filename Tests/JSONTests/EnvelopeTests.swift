// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }
private func decode(_ text: String, options: JSONEnvelopeOptions = .init()) throws -> JSONEnvelope {
    try JSONEnvelope.decode(Data(text.utf8), options: options)
}
/// Digests computed independently with Python's hashlib over the RFC 8785 payload bytes.
private let taskDigest = "sha256:87245ae1c062ec8fd5e2ab1ac60fbc44f6822d6176fe850381db1fd6e97c7810"
private let taskEnvelope = #"{"digest":"sha256:87245ae1c062ec8fd5e2ab1ac60fbc44f6822d6176fe850381db1fd6e97c7810","format":"swift-json-envelope","formatVersion":1,"payload":{"id":7,"state":"done"},"type":"mcp.task","version":3}"#

@Test func envelopeEncodesPinnedCanonicalBytesAndDigest() throws {
    let envelope = try JSONEnvelope(type: "mcp.task", version: 3, payload: parse(#"{"state":"done","id":7.0}"#))
    let encoding = try envelope.encode()
    #expect(String(decoding: encoding.data, as: UTF8.self) == taskEnvelope)
    #expect(encoding.digest == taskDigest)
    // The assembled bytes equal the canonical writer's output for the same object.
    #expect(encoding.data == (try JSONCanonicalWriter().write(parse(taskEnvelope))))
    #expect(try JSONEnvelope(type: "t", version: 1, payload: .null).encode().digest ==
            "sha256:74234e98afe7498fb5daf1f36ac2d78acc339464f950703b8c019892f982b90b")
    let unicode = try JSONEnvelope(type: "café/ü", version: 9_007_199_254_740_991, payload: parse(#"{"€":"é","a":[1,0.1,1e21]}"#))
    let unicodeEncoding = try unicode.encode()
    #expect(unicodeEncoding.digest == "sha256:c03fa255bcdb45e82dc0a02f2c19c989fc723c823c1103f597e047f411e2ab78")
    #expect(String(decoding: unicodeEncoding.data, as: UTF8.self).hasSuffix(#""type":"café/ü","version":9007199254740991}"#))
}

@Test func equalEnvelopesHaveEqualBytesAndRoundTrip() throws {
    let a = try JSONEnvelope(type: "doc", version: 2, payload: parse(#"{"b":[1.50,{"y":null,"x":true}],"a":"s"}"#))
    let b = try JSONEnvelope(type: "doc", version: 2, payload: parse(#"{"a":"s","b":[1.5,{"x":true,"y":null}]}"#))
    #expect(a == b)
    #expect(try a.encode() == b.encode())
    #expect(try JSONEnvelope.decode(a.encode().data) == a)
    // Any strict spelling decodes: reordered members and whitespace are allowed.
    let spaced = "{\n  \"version\": 3, \"type\": \"mcp.task\",\n  \"payload\": { \"state\": \"done\", \"id\": 7 },\n" +
                 "  \"formatVersion\": 1, \"format\": \"swift-json-envelope\", \"digest\": \"\(taskDigest)\"\n}"
    let decoded = try decode(spaced)
    let expectedPayload = try parse(#"{"id":7,"state":"done"}"#)
    #expect(decoded.type == "mcp.task" && decoded.version == 3 && decoded.payload == expectedPayload)
    #expect(try decoded.encode().data == Data(taskEnvelope.utf8))
    let report = try JSONEnvelope.decodeWithReport(Data(taskEnvelope.utf8))
    #expect(report.result == decoded && report.statistics[.workUnits] > 0)
    #expect(try a.encodeWithReport().statistics[.outputBytes] == UInt64(try a.encode().data.count))
}

@Test func envelopeDecodingDetectsCorruptionAndInvalidFields() throws {
    func replacing(_ old: String, _ new: String) -> String { taskEnvelope.replacingOccurrences(of: old, with: new) }
    let cases: [(String, JSONEnvelopeFailure)] = [
        (replacing(#""state":"done""#, #""state":"dona""#), .digestMismatch),
        (replacing(#""id":7"#, #""id":8"#), .digestMismatch),
        (replacing("swift-json-envelope", "swift-json-value"), .invalidFormat),
        (replacing(#","version":3}"#, #","version":3,"extra":0}"#), .invalidFormat),
        (replacing(#""type":"mcp.task","#, ""), .invalidFormat),
        ("[1]", .invalidFormat), ("{}", .invalidFormat),
        (replacing(#""formatVersion":1"#, #""formatVersion":2"#), .unsupportedFormatVersion),
        (replacing(#""formatVersion":1"#, #""formatVersion":1.5"#), .unsupportedFormatVersion),
        (replacing(#""formatVersion":1"#, #""formatVersion":2147483648"#), .unsupportedFormatVersion),
        (replacing(#""formatVersion":1"#, #""formatVersion":9223372036854775808"#), .unsupportedFormatVersion),
        (replacing(#""formatVersion":1"#, #""formatVersion":"1""#), .invalidFormat),
        (replacing(#""mcp.task""#, #""""#), .invalidType),
        (replacing(#""mcp.task""#, "7"), .invalidType),
        (replacing(#""version":3"#, #""version":0"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":-9223372036854775808"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":9223372036854775807"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":9223372036854775808"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":3.5"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":9007199254740992"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":99999999999999999999"#), .invalidVersion),
        (replacing(#""version":3"#, #""version":"3""#), .invalidVersion),
        (replacing("87245ae1", "87245AE1"), .invalidDigest),
        (replacing("sha256:", "sha512:"), .invalidDigest),
        (replacing(#""sha256:87245ae1"#, #""sha256:7245ae1"#), .invalidDigest),
    ]
    for (text, expected) in cases {
        #expect(throws: expected, "\(text)") { try decode(text) }
    }
    // Syntax and duplicate members stay JSON failures.
    #expect { try decode(String(taskEnvelope.dropLast())) } throws: { ($0 as? JSONFailure)?.category == .syntax }
    #expect { try decode(replacing(#","version":3}"#, #","version":3,"version":3}"#)) } throws: { ($0 as? JSONFailure)?.code == .duplicateKey }
}

@Test func envelopeValidatesTypeVersionAndNumberPolicy() throws {
    #expect(throws: JSONEnvelopeFailure.invalidType) { try JSONEnvelope(type: "", version: 1, payload: .null) }
    #expect(throws: JSONEnvelopeFailure.invalidType) { try JSONEnvelope(type: String(repeating: "é", count: 129), version: 1, payload: .null) }
    _ = try JSONEnvelope(type: String(repeating: "é", count: 128), version: 1, payload: .null)
    let rejectedVersions: [Int64] = [0, -1, .min, 9_007_199_254_740_992, .max]
    for version in rejectedVersions {
        #expect(throws: JSONEnvelopeFailure.invalidVersion) { try JSONEnvelope(type: "t", version: version, payload: .null) }
    }
    // The envelope wire contract is independent of the host's Int width.
    // Exercise values below, at and beyond the wasm32 signed-integer ceiling.
    let accepted: [Int64] = [1, 2_147_483_647, 2_147_483_648, 4_294_967_295, 4_294_967_296, 9_007_199_254_740_991]
    let versions: ClosedRange<Int64> = JSONEnvelope.versions
    #expect(versions == 1...9_007_199_254_740_991)
    for version in accepted {
        let value = try JSONEnvelope(type: "mcp.task", version: version, payload: parse(#"{"id":7,"state":"done"}"#))
        let pinned = taskEnvelope.replacingOccurrences(of: #""version":3}"#, with: "\"version\":\(version)}")
        let encoded = try value.encode()
        #expect(encoded.data == Data(pinned.utf8))
        #expect(encoded.digest == taskDigest)
        let decoded = try decode(pinned)
        let decodedVersion: Int64 = decoded.version
        #expect(decodedVersion == version)
        #expect(decoded == value)
        #expect(try decoded.encode() == encoded)
    }
    // A number binary64 cannot spell exactly is refused unless rounding is chosen on both sides.
    let inexact = try JSONEnvelope(type: "t", version: 1, payload: parse("[0.10000000000000001]"))
    #expect { try inexact.encode() } throws: { ($0 as? JSONFailure)?.code == .inexactConversion }
    let rounding = JSONEnvelopeOptions(numberPolicy: .rounding)
    let rounded = try inexact.encode(options: rounding)
    #expect(String(decoding: rounded.data, as: UTF8.self).contains(#""payload":[0.1]"#))
    #expect(try JSONEnvelope.decode(rounded.data, options: rounding).payload == (try parse("[0.1]")))
    let stored = String(decoding: rounded.data, as: UTF8.self).replacingOccurrences(of: "[0.1]", with: "[0.10000000000000001]")
    #expect { try decode(stored) } throws: { ($0 as? JSONFailure)?.code == .inexactConversion }
    #expect(try decode(stored, options: rounding).payload == (try parse("[0.10000000000000001]")))
}

@Test func envelopeOperationsAreBounded() throws {
    var limits = JSONLimits.balanced; limits[.inputBytes] = 64
    #expect { try decode(taskEnvelope, options: .init(limits: limits)) } throws: { ($0 as? JSONFailure)?.resource?.metric == .inputBytes }
    limits = .balanced; limits[.outputBytes] = 100
    let envelope = try JSONEnvelope(type: "mcp.task", version: 3, payload: parse(#"{"id":7,"state":"done"}"#))
    #expect { try envelope.encode(options: .init(limits: limits)) } throws: { ($0 as? JSONFailure)?.resource?.metric == .outputBytes }
    limits[.outputBytes] = UInt64(taskEnvelope.utf8.count)
    #expect(try envelope.encode(options: .init(limits: limits)).data.count == taskEnvelope.utf8.count)
}
