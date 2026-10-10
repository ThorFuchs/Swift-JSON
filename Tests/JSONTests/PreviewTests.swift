// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@Test func previewRedactsExactKeysBeforeTraversingValues() throws {
    let value = try JSONObject.build { members in
        try members.append("password", value: .string("sensitive-value"))
        try members.append("é", value: 1)
        try members.append("e\u{301}", value: 2)
    }
    let preview = try JSONPreview.render(.object(value), options: .init(redaction: .init(keys: ["password", "é"])))
    #expect(preview.complete && !preview.text.contains("sensitive-value"))
    let parsed = try JSONParser().parse(preview.text)
    #expect(try parsed.requiredMember("e\u{301}") == 2)
    #expect(try parsed.requiredMember("é") == "[REDACTED]")
}
@Test func previewCapsTotalTraversalAndOutputWithoutAdmittingWholeDocument() throws {
    let wide = JSON.array(Array(repeating: .array([1,2,3]), count: 100_000))
    let report = try JSONPreview.renderWithReport(wide)
    #expect(!report.result.complete && report.result.text.hasSuffix("[...]"))
    #expect(report.statistics[.nodes] <= 32 && report.result.text.utf8.count <= 4096)
    let small = try JSONPreview.render(.string(String(repeating: "𝄞", count: 1000)), options: .init(maxBytes: 32))
    #expect(!small.complete && small.text.utf8.count <= 32 && !small.text.contains("�"))
    let deep = try JSONPreview.render(.array([.array([.array([1])])]), options: .init(maxDepth: 1))
    #expect(!deep.complete)
}
