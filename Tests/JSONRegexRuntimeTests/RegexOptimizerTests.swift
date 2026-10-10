// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONRegexRuntime

/// Immutable program reuse is safe without sharing a matcher, capture array or mutable meter.
@Test func sharedRegexProgramHasExclusiveConcurrentSearchState() async throws {
    var compilation = try JSONWorkMeter(limits: .balanced, domain: .regex)
    let program = try RegexCompiler.compile(#"^(?<word>[ab]+)\k<word>$"#, meter: &compilation)
    let results = try await withThrowingTaskGroup(of: Bool.self) { group in
        for index in 0..<40 {
            group.addTask {
                var meter = try JSONWorkMeter(limits: .balanced, domain: .schemaEvaluation)
                let subject = index.isMultiple(of: 2) ? "abab" : "abba"
                let result = try program.search(subject, meter: &meter)
                return result == index.isMultiple(of: 2) && meter.used(.regexRetainedBytes) == 0
            }
        }
        var count = 0
        for try await success in group { #expect(success); count += 1 }
        return count
    }
    #expect(results == 40)
}
