// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONRegexRuntime

@Test func deterministicIndependentRegexDifferentialCases() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    let data = try Data(contentsOf: root.appendingPathComponent("Fixtures/Regex/differential.json"))
    let fixture = try #require(JSONParser().parse(data).arrayValue)
    var count = 0
    for record in fixture {
        let pattern = try #require(record.objectValue?["pattern"]?.stringValue)
        let cases = try #require(record.objectValue?["cases"]?.arrayValue)
        var meter = try JSONWorkMeter(limits: .offline, domain: .regex)
        let program = try RegexCompiler.compile(pattern, meter: &meter)
        let retained = meter.used(.retainedBytes)
        for test in cases {
            let subject = try #require(test.objectValue?["subject"]?.stringValue)
            let expected = try #require(test.objectValue?["expected"]?.booleanValue as Bool?)
            #expect(try program.search(subject, meter: &meter) == expected, "pattern: \(pattern), subject: \(subject)")
            #expect(meter.used(.regexRetainedBytes) == 0)
            #expect(meter.used(.retainedBytes) == retained)
            count += 1
        }
    }
    #expect(fixture.count == 442)
    #expect(count == 31_824)
}
