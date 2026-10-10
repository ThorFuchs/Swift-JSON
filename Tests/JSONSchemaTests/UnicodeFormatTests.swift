// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONSchema

@Test func pinnedUnicode13NativeNFCMatchesAllNormalizationCases() throws {
    let path = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Fixtures/Unicode/NormalizationTest-13.0.0.txt")
    let input = try String(contentsOf: path,encoding: .utf8)
    var cases = 0, comparisons = 0
    for line in input.split(separator: "\n") {
        let data = line.split(separator: "#",maxSplits: 1,omittingEmptySubsequences: false)[0].trimmingCharacters(in: .whitespaces)
        if data.isEmpty || data.hasPrefix("@") { continue }
        let values = data.split(separator: ";").prefix(5).map { $0.split(whereSeparator: \.isWhitespace).map { UInt32($0,radix: 16)! } }
        #expect(values.count == 5)
        let expected = [values[1],values[1],values[1],values[3],values[3]]
        for i in values.indices {
            var meter = try JSONWorkMeter(limits: .balanced,domain: .schemaEvaluation)
            let actual = try JSONIDNAUnicode.normalize(values[i],meter: &meter)
            #expect(actual == expected[i], "normalization case \(cases), column \(i)")
            comparisons += 1
        }
        cases += 1
    }
    #expect(cases == 18_853); #expect(comparisons == 94_265)
    print("NFC_RECEIPT cases=\(cases) comparisons=\(comparisons)")
}
@Test func formatWorkAndNormalizationAreInterruptibleAndFinite() throws {
    var limits = JSONLimits.balanced; limits[.evaluationWorkUnits] = 100
    var meter = try JSONWorkMeter(limits: limits,domain: .schemaEvaluation)
    #expect(throws: JSONFailure.self) { try JSONSchemaFormats.test(String(repeating: "\u{200B}",count: 1_000) + "example.test",name: .idnHostname,meter: &meter) }
    var regexMeter = try JSONWorkMeter(limits: limits,domain: .schemaEvaluation)
    #expect(throws: JSONFailure.self) { try JSONSchemaFormats.test(String(repeating: "a",count: 1_000),name: .regex,meter: &regexMeter) }
}
