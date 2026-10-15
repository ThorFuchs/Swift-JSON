// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONRegexRuntime

@Test func qaRegexControlHexAndAstralEscapesHaveFixedScalarOracles() throws {
    // Authored vectors for the shipped ECMA-262 Unicode escape grammar.
    let cases: [(String,String)] = [(#"^\n\r\f\v\t$"#, "\n\r\u{c}\u{b}\t"),
        (#"^\xAF\xaf$"#, "¯¯"), (#"^\u00e9\u{1f680}$"#, "é🚀"),
        (#"^\uD83D\uDE80$"#, "🚀"), (#"^[\n\r\f\v]$"#, "\u{c}"), (#"^\cz$"#, "\u{1a}")]
    for (pattern, subject) in cases {
        var meter = try JSONWorkMeter(limits:.balanced,domain:.regex)
        let program = try RegexCompiler.compile(pattern,meter:&meter)
        #expect(try program.search(subject,meter:&meter))
        #expect(try program.search(subject+"x",meter:&meter) == false)
        #expect(meter.used(.regexRetainedBytes) == 0 && meter.used(.regexCompileWorkUnits) > 0)
    }
}

@Test func qaRegexMalformedEscapesAreInvalidPatternsRatherThanNoMatch() throws {
    let patterns = ["\\", #"\x"#, #"\x0"#, #"\xGG"#, #"\c1"#, #"[\B]"#,
        #"\u{}"#, #"\u{g}"#, #"\u{110000}"#, #"\u{ffffff}"#, #"\u{12"#, #"\u12Q4"#,
        #"\uD800\uZZZZ"#, #"\01"#, #"[\1]"#, #"\kX"#, #"(?<>a)"#, #"(?<\x61>a)"#, #"(?<\u{31}>a)"#]
    for pattern in patterns {
        var meter = try JSONWorkMeter(limits:.balanced,domain:.regex)
        do { _ = try RegexCompiler.compile(pattern,meter:&meter); Issue.record("Accepted malformed pattern: \(pattern)") }
        catch let failure as RegexFailure {
            switch failure { case .invalidPattern: break; case .unsupportedPattern: Issue.record("Wrong grammar failure classification") }
        }
        #expect(meter.used(.regexCompileWorkUnits) > 0)
    }
}

@Test func qaRegexEscapedCaptureNamesAndUnmatchedReferencesRetainScalarIdentity() throws {
    var meter = try JSONWorkMeter(limits:.balanced,domain:.regex)
    let program = try RegexCompiler.compile(#"^(?<\u{e9}>a)(?<e\u0301>b)\k<é>\k<é>$"#,meter:&meter)
    #expect(try program.search("abab",meter:&meter))
    #expect(try program.search("abaa",meter:&meter) == false)
    let optional = try RegexCompiler.compile(#"^(?:(?<x>a)|b)\k<x>$"#,meter:&meter)
    #expect(try optional.search("b",meter:&meter))
    #expect(try optional.search("aa",meter:&meter))
    #expect(try optional.search("ba",meter:&meter) == false)
}

@Test func qaRegexEscapeCompilationQuotaAndCancellationAreOperational() async throws {
    var limits = JSONLimits.balanced; limits[.regexCompileWorkUnits] = 1
    var meter = try JSONWorkMeter(limits:limits,domain:.regex)
    do { _ = try RegexCompiler.compile(#"\u{1f680}"#,meter:&meter); Issue.record("Expected quota refusal") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .regexCompileWorkUnits) }
    let task = Task.detached {
        var cancelled = try JSONWorkMeter(limits:.balanced,domain:.regex)
        withUnsafeCurrentTask { $0?.cancel() }
        do { _ = try RegexCompiler.compile(#"\u{1f680}"#,meter:&cancelled); return false }
        catch is CancellationError { return true }
    }
    #expect(try await task.value)
}
