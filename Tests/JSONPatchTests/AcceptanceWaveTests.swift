// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONPatch

@Test func qaWidePatchEditsPreserveExactKeyOrderThroughIndexTransitions() throws {
    // The two scalar-distinct keys make width 30 an actual 32-member object.
    // Moving a member removes it before adding, exercising 32 -> 31 -> 32.
    for width in [29, 30, 31, 32, 33, 61, 62, 63, 64, 65] {
        let members = (0..<width).map { JSONMember("k\($0)", value: .number(JSONNumber(integer: $0))) } + [.init("é", value: 1), .init("e\u{301}", value: 2)]
        let original = JSON.object(try JSONObject(members: members))
        let patch = try JSONPatch(json: JSONParser().parse(#"[{"op":"test","path":"/é","value":1.00e0},{"op":"replace","path":"/é","value":3},{"op":"move","from":"/é","path":"/~1~0"},{"op":"add","path":"/é","value":4}]"#))
        guard case .document(let result) = try patch.applying(to: original) else { Issue.record("Unexpected root removal"); return }
        let object = try #require(result.objectValue)
        #expect(object.members.map(\.key) == members.dropLast().map(\.key) + [JSONKey("/~"), JSONKey("e\u{301}")])
        #expect(object["é"] == 3 && object["e\u{301}"] == 4 && object["/~"] == 2)
        #expect(original.objectValue?["é"] == 1 && original.objectValue?["e\u{301}"] == 2)
        let merge = try JSONMergePatch(JSONParser().parse(#"{"é":null,"é":5}"#)).applying(to: result)
        #expect(merge.objectValue?["é"] == nil && merge.objectValue?["e\u{301}"] == 5)
        #expect(merge.objectValue?["/~"] == 2)
    }
}

@Test func qaIndexedPatchCumulativeBoundaryRefusesWithoutPublishingStage() throws {
    let input = JSON.object(try JSONObject(members: (0..<64).map { .init("k\($0)", value: .null) }))
    let patch = try JSONPatch(operations: [
        .replace(path: JSONPointer(parsing: "/k63"), value: 9),
        .remove(path: JSONPointer(parsing: "/k0")),
        .add(path: JSONPointer(parsing: "/new"), value: .null)
    ])
    let baseline = try patch.applyingWithReport(to: .document(input))
    var limits = JSONLimits.balanced; limits[.patchWorkUnits] = baseline.statistics[.patchWorkUnits]
    #expect(try patch.applying(to: input, options: .init(limits: limits)) == baseline.result)
    limits[.patchWorkUnits] -= 1
    do { _ = try patch.applying(to: input, options: .init(limits: limits)); Issue.record("Missing cumulative refusal") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .patchWorkUnits) }
    #expect(input.objectValue?["k0"] == .null && input.objectValue?["k63"] == .null)
}
