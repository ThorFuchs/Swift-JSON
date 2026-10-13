// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import JSON

@Test func exactFormattingKeepsLegacyDefaultsAndAddsLiteralTabs() throws {
    let root = try JSONParser().parse(#"{"b":[-0.00e+2,true],"a":"é"}"#)
    #expect(try JSONWriter().writeString(root) == #"{"b":[0,true],"a":"é"}"#)
    let legacy = JSONWritingOptions(indentation: 2, keyOrder: .insertion, numberStyle: .preserved)
    #expect(try JSONWriter(options: legacy).writeString(root) == "{\n  \"b\": [\n    -0.00e+2,\n    true\n  ],\n  \"a\": \"é\"\n}")
    var tabs = legacy; tabs.indentationUnit = .tabs; tabs.indentation = 1
    #expect(try JSONWriter(options: tabs).writeString(root) == "{\n\t\"b\": [\n\t\t-0.00e+2,\n\t\ttrue\n\t],\n\t\"a\": \"é\"\n}")
    tabs.indentation = 8
    #expect(try JSONWriter(options: tabs).writeString(.array([.null])) == "[\n" + String(repeating: "\t", count: 8) + "null\n]")
    tabs.indentation = 0
    #expect(try JSONWriter(options: tabs).writeString(.array([1])) == "[\n1\n]")
    tabs.indentation = nil
    #expect(try JSONWriter(options: tabs).writeString(root) == #"{"b":[-0.00e+2,true],"a":"é"}"#)
    for count in [-1, 9, Int.max] {
        tabs.indentation = count
        #expect(throws: JSONFailure.self) { try JSONWriter(options: tabs).write(root) }
    }
}

@Test func classifiedWriterBytesUseTheSameGrammarAndAccounting() throws {
    for text in ["null", "true", "-0.00e+2", #""a\u0000\"\\é""#, "[]", "{}", #"{"é":1,"é":false,"a":[null,"x"]}"#] {
        let root = try JSONParser().parse(text)
        for unit in [JSONIndentationUnit.spaces, .tabs] {
            let options = JSONWritingOptions(indentation: 2, numberStyle: .preserved, indentationUnit: unit)
            var plainMeter = try JSONWorkMeter(limits: .balanced, domain: .writing)
            var typedMeter = try JSONWorkMeter(limits: .balanced, domain: .writing)
            var plain = JSONWritingCursor(value: root, options: options)
            var typed = JSONWritingCursor(value: root, options: options)
            var a: [UInt8] = [], b: [UInt8] = [], nodes = 0
            while let byte = try plain.next(meter: &plainMeter) { a.append(byte) }
            while let token = try typed.nextToken(meter: &typedMeter) {
                b.append(token.byte)
                if token.beginsValue { nodes += 1 }
                if token.kind == .whitespace { #expect([9, 10, 32].contains(token.byte)) }
            }
            #expect(a == b)
            #expect(plainMeter.statistics() == typedMeter.statistics())
            #expect(Data(b) == (try JSONWriter(options: options).write(root)))
            #expect(nodes == (text.contains("\"a\":") ? 6 : 1))
        }
    }
}

@Test func classifiedWriterSeparatesKeysFromStringValuesAndNumericFallback() throws {
    let root = try JSONObject(members: [JSONMember("key", value: .string("value")), JSONMember("n", value: .number(JSONNumber(parsing: "12.50")))])
    var meter = try JSONWorkMeter(limits: .balanced, domain: .writing)
    var cursor = JSONWritingCursor(value: .object(root), options: .init())
    var keys: [UInt8] = [], strings: [UInt8] = [], numbers: [UInt8] = []
    while let token = try cursor.nextToken(meter: &meter) {
        switch token.kind {
        case .key: keys.append(token.byte)
        case .string: strings.append(token.byte)
        case .number: numbers.append(token.byte)
        default: break
        }
    }
    #expect(String(decoding: keys, as: UTF8.self) == #""key""n""#)
    #expect(String(decoding: strings, as: UTF8.self) == #""value""#)
    #expect(String(decoding: numbers, as: UTF8.self) == "125e-1")
}
