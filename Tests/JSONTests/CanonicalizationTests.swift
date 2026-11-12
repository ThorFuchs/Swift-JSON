// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import JSON

private func canonical(_ value: JSON, _ policy: JSONCanonicalWriter.NumberPolicy = .preserving) throws -> String {
    String(decoding: try JSONCanonicalWriter(numberPolicy: policy).write(value), as: UTF8.self)
}
private func canonical(parsing text: String, _ policy: JSONCanonicalWriter.NumberPolicy = .preserving) throws -> String {
    try canonical(JSONParser().parse(text), policy)
}
private func expectInexact(_ body: () throws -> Void) {
    do { try body(); Issue.record("Expected an inexact-conversion failure") }
    catch let failure as JSONFailure { #expect(failure.category == .conversion && failure.code == .inexactConversion) }
    catch { Issue.record("Unexpected error: \(error)") }
}

/// RFC 8785 Appendix B: binary64 bit patterns and their ECMAScript spelling.
@Test func canonicalNumbersMatchTheRFC8785AppendixBVectors() throws {
    let vectors: [(UInt64, String)] = [
        (0x0000000000000000, "0"), (0x8000000000000000, "0"),
        (0x0000000000000001, "5e-324"), (0x8000000000000001, "-5e-324"),
        (0x7fefffffffffffff, "1.7976931348623157e+308"), (0xffefffffffffffff, "-1.7976931348623157e+308"),
        (0x4340000000000000, "9007199254740992"), (0xc340000000000000, "-9007199254740992"),
        (0x4430000000000000, "295147905179352830000"),
        (0x44b52d02c7e14af5, "9.999999999999997e+22"), (0x44b52d02c7e14af6, "1e+23"),
        (0x44b52d02c7e14af7, "1.0000000000000001e+23"),
        (0x444b1ae4d6e2ef4e, "999999999999999700000"), (0x444b1ae4d6e2ef4f, "999999999999999900000"),
        (0x444b1ae4d6e2ef50, "1e+21"),
        (0x3eb0c6f7a0b5ed8c, "9.999999999999997e-7"), (0x3eb0c6f7a0b5ed8d, "0.000001"),
        (0x41b3de4355555553, "333333333.3333332"), (0x41b3de4355555554, "333333333.33333325"),
        (0x41b3de4355555555, "333333333.3333333"), (0x41b3de4355555556, "333333333.3333334"),
        (0x41b3de4355555557, "333333333.33333343"),
        (0xbecbf647612f3696, "-0.0000033333333333333333"),
        (0x43143ff3c1cb0959, "1424953923781206.2"),
    ]
    for (bits, expected) in vectors {
        let double = Double(bitPattern: bits)
        // Swift's round-trip decimal is exactly the canonical value, so it is preserved.
        #expect(try canonical(.number(.fromFiniteDouble(double))) == expected, "\(String(bits, radix: 16))")
        // The exact binary expansion needs rounding to reach the same spelling.
        var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
        let exact = try JSONNumber.exactBinary(double, meter: &meter)
        #expect(try canonical(.number(exact), .rounding) == expected, "\(String(bits, radix: 16))")
    }
    for bits: UInt64 in [0x7fffffffffffffff, 0x7ff0000000000000] {
        expectInexact { _ = try JSONNumber.fromFiniteDouble(Double(bitPattern: bits)) }
    }
}

/// RFC 8785 section 3.2.2: the complete sample, whose numbers need rounding.
@Test func canonicalOutputMatchesTheRFC8785Sample() throws {
    let input = #"""
    {
      "numbers": [333333333.33333329, 1E30, 4.50, 2e-3, 0.000000000000000000000000001],
      "string": "\u20ac$\u000F\u000aA'\u0042\u0022\u005c\\\"\/",
      "literals": [null, true, false]
    }
    """#
    let expected = #"{"literals":[null,true,false],"numbers":[333333333.3333333,1e+30,4.5,0.002,1e-27],"string":"€$\u000f\nA'B\"\\\\\"/"}"#
    #expect(try canonical(parsing: input, .rounding) == expected)
    // 333333333.33333329 is not the binary64 value it rounds to, so preserving refuses it.
    expectInexact { _ = try canonical(parsing: input) }
}

/// RFC 8785 section 3.2.3: keys sort by UTF-16 code units, not scalar values.
@Test func canonicalKeysSortByUTF16CodeUnits() throws {
    let input = #"""
    {"\u20ac": "Euro Sign", "\r": "Carriage Return", "\ufb33": "Hebrew Letter Dalet With Dagesh",
     "1": "One", "\ud83d\ude00": "Emoji: Grinning Face", "\u0080": "Control",
     "\u00f6": "Latin Small Letter O With Diaeresis"}
    """#
    let text = try canonical(parsing: input)
    let order = ["Carriage Return", "One", "Control", "Latin Small Letter O With Diaeresis",
                 "Euro Sign", "Emoji: Grinning Face", "Hebrew Letter Dalet With Dagesh"]
    let positions = order.map { text.range(of: "\"\($0)\"")!.lowerBound }
    #expect(positions == positions.sorted())
    // Scalar order puts U+FB33 before U+1F600; UTF-16 order puts the surrogate pair first.
    let scalar = try JSONWriter(options: .init(keyOrder: .scalar)).writeString(JSONParser().parse(input))
    #expect(scalar.range(of: "Hebrew")!.lowerBound < scalar.range(of: "Emoji")!.lowerBound)
    #expect(text.range(of: "Emoji")!.lowerBound < text.range(of: "Hebrew")!.lowerBound)
}

@Test func canonicalStringsUseShortEscapesAndLiteralUTF8() throws {
    let text = "\u{8}\t\n\u{C}\r\u{1}\u{1F}\"\\/\u{7F}é\u{1F600}"
    #expect(try canonical(.string(text)) == "\"\\b\\t\\n\\f\\r\\u0001\\u001f\\\"\\\\/\u{7F}é\u{1F600}\"")
    // The ordinary writer keeps its \u00xx spelling for every control character.
    #expect(try JSONWriter().writeString(.string("\n")) == #""\u000a""#)
}

@Test func preservingPolicyKeepsExactValuesAndRefusesChangedOnes() throws {
    let accepted: [(String, String)] = [
        ("0.1", "0.1"), ("1E30", "1e+30"), ("4.50", "4.5"), ("-0", "0"), ("-0.0e7", "0"), ("100", "100"),
        ("1e21", "1e+21"), ("1e20", "100000000000000000000"), ("0.000001", "0.000001"), ("1e-7", "1e-7"),
        ("-1.5e-7", "-1.5e-7"), ("123.456", "123.456"), ("9007199254740992", "9007199254740992"),
        ("1.0", "1"), ("12e-1", "1.2"),
    ]
    for (input, expected) in accepted {
        #expect(try canonical(parsing: input) == expected, "\(input)")
        #expect(try canonical(parsing: input, .rounding) == expected, "\(input)")
    }
    for input in ["9007199254740993", "0.10000000000000001", "1e-400", "333333333.33333329"] {
        expectInexact { _ = try canonical(parsing: input) }
    }
    #expect(try canonical(parsing: "9007199254740993", .rounding) == "9007199254740992")
    #expect(try canonical(parsing: "1e-400", .rounding) == "0")
    for input in ["1e400", "-1e400"] {
        expectInexact { _ = try canonical(parsing: input) }
        expectInexact { _ = try canonical(parsing: input, .rounding) }
    }
}

@Test func equalValuesProduceEqualCanonicalBytes() throws {
    let a = try JSONParser().parse(#"{"b":[1.0,{"y":true,"x":null}],"a":"é"}"#)
    let b = try JSONParser().parse(#"{ "a" : "é", "b" : [ 1, { "x" : null, "y" : true } ] }"#)
    #expect(a == b)
    let bytes = try JSONCanonicalWriter().write(a)
    #expect(try JSONCanonicalWriter().write(b) == bytes)
    #expect(String(decoding: bytes, as: UTF8.self) == #"{"a":"é","b":[1,{"x":null,"y":true}]}"#)
    // Canonical output parses back to an equal value.
    #expect(try JSONParser().parse(bytes) == a)
    #expect(try canonical(.array([])) == "[]")
    #expect(try canonical(.object(JSONObject())) == "{}")
}

@Test func canonicalWritingIsBoundedAndReported() throws {
    let root = try JSONParser().parse(#"{"z":[1,2,3],"a":"text"}"#)
    let report = try JSONCanonicalWriter().writeWithReport(root)
    #expect(report.result.count == 24)
    #expect(report.statistics[.outputBytes] == 24)
    #expect(report.statistics.domain == .writing)
    var limits = JSONLimits.balanced; limits[.outputBytes] = 24
    #expect(try JSONCanonicalWriter(limits: limits).write(root) == report.result)
    limits[.outputBytes] = 23
    do { _ = try JSONCanonicalWriter(limits: limits).write(root); Issue.record("Expected an output limit failure") }
    catch let failure as JSONFailure { #expect(failure.code == .limitExceeded && failure.resource?.metric == .outputBytes) }
    limits = .balanced; limits[.maxDepth] = 1
    do { _ = try JSONCanonicalWriter(limits: limits).write(root); Issue.record("Expected a depth limit failure") }
    catch let failure as JSONFailure { #expect(failure.category == .resource) }
}

@Test func cancelledCanonicalWritingThrowsCancellation() async {
    let root = JSON.array(Array(repeating: .string(String(repeating: "x", count: 64)), count: 4096))
    let task = Task {
        while !Task.isCancelled { await Task.yield() }
        _ = try JSONCanonicalWriter().write(root)
    }
    task.cancel()
    do { try await task.value; Issue.record("Cancelled canonical writing must throw") }
    catch { #expect(error is CancellationError) }
}
