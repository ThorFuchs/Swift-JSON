// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONPatch

@Test func wideIndexedPatchStagesRebuildExactMetadataAndKeepOrder() throws {
    let members = (0..<128).map { JSONMember("field-\($0)", value: .null) } + [JSONMember("é", value: 1), JSONMember("e\u{301}", value: 2)]
    let value = JSON.object(try JSONObject(members: members))
    let patch = try JSONPatch(operations: [
        .replace(path: JSONPointer(parsing: "/field-127"), value: true),
        .test(path: JSONPointer(parsing: "/e\u{301}"), value: 2),
        .copy(from: JSONPointer(parsing: "/é"), path: JSONPointer(parsing: "/copied"))
    ])
    guard case .document(let changed) = try patch.applying(to: value) else { Issue.record("Removed a present root"); return }
    #expect(try changed.requiredMember("field-127") == true)
    #expect(try changed.requiredMember("e\u{301}") == 2)
    #expect(try changed.requiredMember("copied") == 1)
    #expect(changed.objectValue!.members.map(\.key) == members.map(\.key) + [JSONKey("copied")])
    let merged = try JSONMergePatch(JSONParser().parse(#"{"field-127":null,"é":3}"#)).applying(to: changed)
    #expect(try merged.presence(of: "field-127") == .absent)
    #expect(try merged.requiredMember("é") == 3)
    #expect(try merged.requiredMember("e\u{301}") == 2)
    #expect(value.objectValue!.count == 130)
}
