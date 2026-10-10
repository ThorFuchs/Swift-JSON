// SPDX-License-Identifier: Apache-2.0
import Testing
@testable import JSONRegexRuntime
import JSON
@Test(arguments: [
    ("é", "e\u{301}", false), ("𝄞", "prefix𝄞suffix", true), (#"\uD834\uDD1E"#, "𝄞", true),
    (#"\u{1D11E}"#, "𝄞", true), ("^a.$", "ab", true), ("a$", "a\n", false), (".", "\u{2028}", false),
    ("", "", true), (#"\uD800"#, "�", false), (#"a\+b"#, "a+b", true)
])
func nativeRegexScalarPortVectors(pattern: String, subject: String, expected: Bool) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    let program = try RegexCompiler.compile(pattern, meter: &meter)
    #expect(try program.search(subject, meter: &meter) == expected)
}
@Test func regexCompilationAndSearchHaveSeparateWorkCeilings() throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    #expect(throws: RegexFailure.self) { try RegexCompiler.compile(#"\p{UnknownProperty}"#, meter: &meter) }
    var limits = JSONLimits.balanced; limits[.regexSearchWorkUnits] = 20
    var small = try JSONWorkMeter(limits: limits, domain: .regex)
    let program = try RegexCompiler.compile("x", meter: &small)
    #expect(throws: JSONFailure.self) { try program.search(String(repeating: "a", count: 100), meter: &small) }
    limits = .balanced; limits[.regexProgramInstructions] = 2
    var compile = try JSONWorkMeter(limits: limits, domain: .regex)
    #expect(throws: JSONFailure.self) { try RegexCompiler.compile("abc", meter: &compile) }
}
@Test func regexSearchLimitResetsButAggregateLimitNeverResets() throws {
    var limits = JSONLimits.balanced; limits[.aggregateRegexWorkUnits] = 10
    var meter = try JSONWorkMeter(limits: limits, domain: .schemaEvaluation)
    let program = try RegexCompiler.compile("x", meter: &meter)
    _ = try program.search("a", meter: &meter)
    #expect(throws: JSONFailure.self) { try program.search("a", meter: &meter) }
}
