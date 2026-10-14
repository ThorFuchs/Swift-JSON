// SPDX-License-Identifier: Apache-2.0
import Testing
import Foundation
import JSON
import JSONPatch

private struct ReplayGenerator {
    var state: UInt64 = 0x53574a313231
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407; return state
    }
}
// Independent positive-integer decimal oracle: factor powers of ten explicitly.
private func decimal(_ value: Int64) -> String {
    if value == 0 { return "0" }
    var coefficient = value, power = 0
    while coefficient % 10 == 0 { coefficient /= 10; power += 1 }
    return String(coefficient) + (power == 0 ? "" : "e" + String(power))
}
@Test func qaE2ESeededModelsMatchOrderedMemberAndIntegerOracles() throws {
    var random = ReplayGenerator()
    for index in 0..<128 {
        let a = Int64(random.next() % 100_000), b = Int64(random.next() % 100_000)
        let text = "{\"case\":\(index),\"é\":\(a),\"e\\u0301\":\(b),\"items\":[true,null,\(a)],\"amount\":\(a).00}"
        let value = try JSONParser().parse(text), object = try #require(value.objectValue)
        let keys = ["case", "é", "e\u{301}", "items", "amount"].map { Array($0.utf8) }
        #expect(object.members.map { Array($0.key.string.utf8) } == keys)
        #expect(object["case"] == .number(.init(integer: index)))
        #expect(object["é"] == .number(.init(integer: a)) && object["e\u{301}"] == .number(.init(integer: b)))
        #expect(object["items"] == .array([true, .null, .number(.init(integer: a))]))
        #expect(object["amount"]?.numberValue == JSONNumber(integer: a))
        let n = decimal(Int64(index)), x = decimal(a), y = decimal(b)
        let canonical = "{\"case\":\(n),\"é\":\(x),\"é\":\(y),\"items\":[true,null,\(x)],\"amount\":\(x)}"
        #expect(try JSONWriter().write(value) == Data(canonical.utf8))
        let changed = try JSONMergePatch(JSONParser().parse(#"{"amount":null,"ok":true}"#)).applying(to: value)
        let expected = "{\"case\":\(n),\"é\":\(x),\"é\":\(y),\"items\":[true,null,\(x)],\"ok\":true}"
        #expect(try JSONWriter().write(changed) == Data(expected.utf8))
    }
}
@Test func qaE2EMinimizedMalformedReplaysHavePreciseFailures() throws {
    // Each edit independently violates JSON grammar; no random 'must be invalid' assumption.
    let cases: [(String, [UInt8], JSONFailure.Code)] = [
        ("trailing-comma", Array("[0,]".utf8), .invalidSyntax),
        ("leading-zero", Array("[01]".utf8), .invalidNumber),
        ("comment", Array("[0/*x*/]".utf8), .invalidSyntax),
        ("raw-control", [34,10,34], .invalidSyntax),
        ("invalid-utf8", [34,0xc0,0xaf,34], .invalidUTF8),
        ("decoded-duplicate", Array(#"{"a":0,"\u0061":1}"#.utf8), .duplicateKey),
        ("unpaired-surrogate", Array(#""\uD800""#.utf8), .invalidSyntax),
        ("truncated-escape", Array(#""\u00"#.utf8), .unexpectedEOF),
        ("second-root", Array("0 1".utf8), .trailingData)
    ]
    var generator = ReplayGenerator()
    for index in 0..<128 {
        let number = generator.next() % 99_999 + 1
        var bytes = Array("[\(number)]".utf8)
        bytes.insert(48, at: 1) // A leading zero before a nonzero integer is always invalid.
        do { _ = try JSONParser().parse(bytes); Issue.record("Accepted seeded leading-zero mutation \(index)") }
        catch let failure as JSONFailure {
            #expect(failure.category == .syntax && failure.code == .invalidNumber && failure.resource == nil)
        }
    }
    for (id, bytes, code) in cases {
        do { _ = try JSONParser().parse(bytes); Issue.record("Accepted minimized replay: \(id)") }
        catch let failure as JSONFailure {
            #expect(failure.category == .syntax && failure.code == code, "\(id)")
            #expect(failure.resource == nil, "\(id)")
            #expect((failure.location != nil) == (id != "leading-zero"), "\(id)")
        }
    }
}
