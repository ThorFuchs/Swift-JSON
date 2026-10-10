// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import JSON

@Test(arguments: ["[1,,2]", "[1,]", "{\"a\" 1}", "{\"a\":1,}", "{\"a\":1 \"b\":2}", "true false", "\u{feff}null", "\"\\uD800\"", "\"\\x20\"", "\"\u{1}\""])
func strictMalformedInput(text: String) {
    #expect(throws: JSONFailure.self) { try JSONParser().parse(text) }
}
@Test(arguments: [[UInt8(34), 0xc0, 0xaf, 34], [34, 0xed, 0xa0, 0x80, 34], [34, 0xf4, 0x90, 0x80, 0x80, 34], [34, 0xe2, 34]])
func malformedUTF8(bytes: [UInt8]) { #expect(throws: JSONFailure.self) { try JSONParser().parse(bytes) } }

private func splitParse(_ chunks: [[UInt8]]) throws -> JSON {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .parsing)
    var machine = JSONTokenMachine(), assembler = JSONValueAssembler()
    var result: JSON?
    for bytes in chunks {
        var index = 0
        while index < bytes.count {
            if let event = try machine.next(in: bytes, index: &index, meter: &meter), let value = try assembler.consume(event, meter: &meter) { result = value }
        }
    }
    while machine.state != .finished {
        if let event = try machine.finish(meter: &meter), let value = try assembler.consume(event, meter: &meter) { result = value }
    }
    return try #require(result)
}
@Test(arguments: ["{\"é\":1,\"é\":2,\"pair\":\"\\uD834\\uDD1E\",\"a\":[null,true,12.50e-2]}", "[\"😀\",\"a\\\"b\\\\c\",-1e-5]", "123.456e-7", "null"])
func everyByteSplitUsesIdenticalGrammar(text: String) throws {
    let bytes = Array(text.utf8), expected = try JSONParser().parse(bytes)
    for split in 0...bytes.count {
        #expect(try splitParse([Array(bytes[..<split]), Array(bytes[split...])]) == expected)
    }
    #expect(try splitParse(bytes.map { [$0] }) == expected)
}
@Test func allControlsWriterRoundTripAndPrettyOrder() throws {
    let controls = String(String.UnicodeScalarView((0...31).map { Unicode.Scalar($0)! }))
    let value = JSON.string(controls + "\"\\😀")
    let bytes = try JSONWriter().write(value)
    #expect(!bytes.contains(where: { $0 < 32 }))
    #expect(try JSONParser().parse(bytes) == value)
    let object = try JSONObject(members: [JSONMember("z", value: 1), JSONMember("a", value: .array([true, .null]))])
    let pretty = try JSONWriter(options: .init(indentation: 2, keyOrder: .scalar)).writeString(.object(object))
    #expect(pretty == "{\n  \"a\": [\n    true,\n    null\n  ],\n  \"z\": 1\n}")
    #expect(try JSONParser().parse(pretty) == .object(object))
}
@Test func parserReportsAndTerminalFailure() throws {
    let report = try JSONParser().parseWithReport(Array(" [1] \n".utf8))
    #expect(report.statistics[.inputBytes] == 6)
    #expect(report.statistics[.nodes] == 2)
    var meter = try JSONWorkMeter(limits: .balanced, domain: .parsing)
    var machine = JSONTokenMachine(), index = 0
    let bytes = Array("[?]".utf8)
    _ = try machine.next(in: bytes, index: &index, meter: &meter)
    do { _ = try machine.next(in: bytes, index: &index, meter: &meter); Issue.record("Malformed input accepted") } catch {}
    #expect(machine.state == .failed)
    #expect(throws: JSONFailure.self) { try machine.finish(meter: &meter) }
}

@Test func pinnedIndependentSyntaxSuite() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/External/syntax/test_parsing")
    let files = try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil).filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    #expect(files.count == 318)
    var accepted = 0, rejected = 0, policy = 0
    for file in files {
        let name = file.lastPathComponent
        let duplicate = name == "y_object_duplicated_key.json" || name == "y_object_duplicated_key_and_value.json"
        do {
            _ = try JSONParser().parse(Data(contentsOf: file))
            #expect(!name.hasPrefix("n_") && !duplicate, "Unexpected acceptance: \(name)")
            accepted += 1
        } catch let failure as JSONFailure {
            #expect(!name.hasPrefix("y_") || duplicate, "Unexpected rejection: \(name), \(failure.code)")
            if name.hasPrefix("i_") || duplicate || failure.category == .resource { policy += 1 } else { rejected += 1 }
        }
    }
    print("JSONTestSuite pin 1ef36fa01286573e846ac449e8683f8833c5b26a: observed=\(files.count) accepted=\(accepted) rejected=\(rejected) policy_rejections=\(policy)")
}
