// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@testable import JSONRegexRuntime

@Test(arguments: [
    (#"^[a-z\d]+$"#, "abc123", true), (#"^[a-z\d]+$"#, "é", false), (#"^[^a-c]+$"#, "xyz", true),
    (#"^[\D\S]$"#, "a", true), (#"^[\D\S]$"#, "5", true), (#"^[\D\S]$"#, " ", true),
    (#"^[]$"#, "a", false), (#"^[^]$"#, "𝄞", true), (#"[𝄞-𝄟]"#, "𝄟", true),
    (#"^a{2,4}$"#, "aaa", true), (#"^a{2,4}$"#, "aaaaa", false), (#"^a{0}$"#, "", true),
    (#"^(?:ab|cd)+$"#, "abcdab", true), (#"^(?:ab|cd)+$"#, "abc", false),
    (#"^(a|ab)c$"#, "abc", true), (#"^a+?a$"#, "aaaa", true), (#"^a??a$"#, "a", true),
    (#"^(a*)b\1$"#, "aabaa", true), (#"^(a*)b\1$"#, "aaba", false),
    (#"^(a|(b))\2c$"#, "ac", true), (#"^\1(a)$"#, "a", true),
    (#"^(?<unit>a+)b\k<unit>$"#, "aabaa", true),
    (#"^(?=(a+))a*b\1$"#, "aabaa", true), (#"^(?=(a+))a*b\1$"#, "aaba", false),
    (#"^(?!ab)a.$"#, "ac", true), (#"^(?!ab)a.$"#, "ab", false),
    (#"(?<=ab)c"#, "zabc", true), (#"(?<!ab)c"#, "zabc", false), (#"(?<!ab)c"#, "zac", true),
    (#"(?<=([ab]+)([bc]+))\1\2$"#, "abcabc", true),
    (#"^(?:(a)|(b))+\1\2$"#, "abb", true), (#"^(?:(a)|(b))+\1\2$"#, "abba", false),
    (#"^(?:){3}$"#, "", true), (#"^(a?)*\1$"#, "", true), (#"^(a?)+\1$"#, "", true),
    (#"\bcat\b"#, "a cat!", true), (#"\bcat\b"#, "scatter", false), (#"\Bcat"#, "scatter", true),
    (#"^[\s]+$"#, "\u{feff}\u{2028}\u{a0}", true), (#"^\w+$"#, "ſ", false),
    (#"^\cA$"#, "\u{1}", true), (#"^[\b]$"#, "\u{8}", true),
    (#"^a{9999999999999999999999999999999}$"#, "a", false)
])
func scalarBacktrackingSemantics(pattern: String, subject: String, expected: Bool) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    let program = try RegexCompiler.compile(pattern, meter: &meter)
    #expect(try program.search(subject, meter: &meter) == expected)
    #expect(meter.used(.regexRetainedBytes) == 0)
}

@Test(arguments: ["(", ")", "a**", "a{3,2}", "a{999999999999999999999,999999999999999999998}", "[z-a]", #"[\d-a]"#, #"\1"#, #"(?<x>a)(?<x>b)"#, #"\k<x>"#, #"\q"#, #"(?=a)+"#])
func malformedRegexGrammarIsACompilationFailure(pattern: String) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    #expect(throws: RegexFailure.self) { try RegexCompiler.compile(pattern, meter: &meter) }
}

@Test(arguments: [
    (#"^\p{Letter}+$"#, "é𝔄", true), (#"^\p{L}+$"#, "a5", false),
    (#"^\p{gc=Decimal_Number}+$"#, "٥", true), (#"^\p{Nd}+$"#, "Ⅴ", false),
    (#"^\p{sc=Greek}+$"#, "α", true), (#"^\p{Script=Latin}+$"#, "α", false),
    (#"^\p{Script_Extensions=Hira}$"#, "ー", true), (#"^\p{Script=Hira}$"#, "ー", false),
    (#"^\p{scx=Common}$"#, "ー", false), (#"^\p{sc=Common}$"#, "ー", true),
    (#"^[\p{ASCII}\p{Script=Greek}]+$"#, "5α", true), (#"^\P{ASCII}$"#, "𝄞", true),
    (#"^\p{Emoji}$"#, "🦊", true), (#"^\p{Any}$"#, "\u{10ffff}", true),
    (#"^\p{Assigned}$"#, "\u{10ffff}", false), (#"^\p{Cs}$"#, "�", false),
    (#"^(?<é>a)\k<é>$"#, "aa", true), (#"^(?<é>a)\k<é>$"#, "aa", true),
    (#"^(?<\u0061>a)\k<a>$"#, "aa", true), (#"^(?<𝒜>a)\k<𝒜>$"#, "aa", true),
    (#"^(?<é>a)(?<é>b)\k<é>\k<é>$"#, "abab", true)
])
func pinnedUnicodePropertiesAndIdentifierNames(pattern: String, subject: String, expected: Bool) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    let program = try RegexCompiler.compile(pattern, meter: &meter)
    #expect(try program.search(subject, meter: &meter) == expected)
}

@Test(arguments: [#"\p{letter}"#, #"\p{Script=greek}"#, #"\p{Script=NoSuch}"#, #"\p{General Category=L}"#, #"\p{L=Yes}"#, #"\p{Block=ASCII}"#, #"\p{}"#, #"\p{Emoji_Keycap_Sequence}"#, #"(?<0>a)"#, #"(?<\uD800>a)"#])
func unknownOrMisspelledPropertyNamesFailCompilation(pattern: String) throws {
    var meter = try JSONWorkMeter(limits: .balanced, domain: .regex)
    #expect(throws: RegexFailure.self) { try RegexCompiler.compile(pattern, meter: &meter) }
}
