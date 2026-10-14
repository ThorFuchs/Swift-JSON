// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONPatch

private func patchGapFailure(_ code: JSONFailure.Code, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected patch failure") }
    catch let failure as JSONFailure { #expect(failure.category == .patch); #expect(failure.code == code) }
    catch { Issue.record("Unexpected failure: \(error)") }
}

@Test func qaPatchMalformedDeclarationsRefuseBeforeApplication() throws {
    for text in ["{}", "[null]", #"[{}]"#, #"[{"op":1,"path":""}]"#, #"[{"op":"add","path":1,"value":null}]"#,
                 #"[{"op":"add","path":""}]"#, #"[{"op":"copy","path":""}]"#, #"[{"op":"copy","from":false,"path":""}]"#,
                 #"[{"op":"unknown","path":""}]"#] {
        let raw = try JSONParser().parse(text)
        patchGapFailure(.invalidOperation) { _ = try JSONPatch(json: raw) }
    }
    let nullPayload = try JSONPatch(json: JSONParser().parse(#"[{"op":"add","path":"","value":null,"ignored":true}]"#))
    #expect(try nullPayload.applying(to: JSONPatchResult.removed) == .document(.null))
}

@Test func qaPatchRemovedRootRefusesEveryOperationRequiringPresence() throws {
    let root = try JSONPointer(parsing: ""), member = try JSONPointer(parsing: "/member")
    let operations: [JSONPatchOperation] = [.add(path: member,value:1), .test(path:root,value:.null),
        .copy(from:root,path:root), .move(from:root,path:root), .remove(path:root), .replace(path:root,value:1)]
    for operation in operations {
        let patch = try JSONPatch(operations: [operation])
        patchGapFailure(.missingTarget) { _ = try patch.applying(to: JSONPatchResult.removed) }
    }
    #expect(try JSONPatch(operations: []).applying(to: JSONPatchResult.removed) == .removed)
}

@Test func qaPatchSamePathMoveRequiresExistingSourceAndChargesCumulatively() throws {
    let input = try JSONParser().parse(#"{"a/b":[1,2]}"#)
    let path = try JSONPointer(parsing: "/a~1b/0")
    let one = try JSONPatch(operations: [.move(from:path,path:path)]).applyingWithReport(to:.document(input))
    #expect(one.result == .document(input) && one.statistics[.operations] == 1)
    let twice = try JSONPatch(operations: [.move(from:path,path:path), .move(from:path,path:path)])
    let report = try twice.applyingWithReport(to:.document(input))
    #expect(report.result == .document(input) && report.statistics[.operations] == 2)
    #expect(report.statistics[.workUnits] > one.statistics[.workUnits])
    var limits = JSONLimits.balanced; limits[.workUnits] = one.statistics[.workUnits]
    do { _ = try twice.applying(to:input,options:.init(limits:limits)); Issue.record("Expected cumulative refusal") }
    catch let failure as JSONFailure { #expect(failure.category == .resource && failure.resource?.metric == .workUnits) }
    let absent = try JSONPointer(parsing: "/missing")
    do { _ = try JSONPatch(operations:[.move(from:absent,path:absent)]).applying(to:input); Issue.record("Expected absent source") }
    catch let failure as JSONFailure { #expect(failure.code == .missingTarget) }
    #expect(try input == JSONParser().parse(#"{"a/b":[1,2]}"#))
}

@Test func qaPatchMoveUnrelatedPrefixAndCopyToRootHaveRFCResults() throws {
    let input = try JSONParser().parse(#"{"a":1,"b":{}}"#)
    let move = try JSONPatch(operations:[.move(from:JSONPointer(parsing:"/a"),path:JSONPointer(parsing:"/b/c"))])
    #expect(try move.applying(to:input) == .document(JSONParser().parse(#"{"b":{"c":1}}"#)))
    for operation in try [JSONPatchOperation.copy(from:JSONPointer(parsing:"/a"),path:JSONPointer(parsing:"")),
                      .move(from:JSONPointer(parsing:"/a"),path:JSONPointer(parsing:""))] {
        #expect(try JSONPatch(operations:[operation]).applying(to:input) == .document(1))
    }
    // Moving the entire root into its own descendant is forbidden, including null.
    patchGapFailure(.invalidOperation) {
        _ = try JSONPatch(operations:[.move(from:JSONPointer(parsing:""),path:JSONPointer(parsing:"/b"))]).applying(to:input)
    }
}

@Test func qaPatchNestedArrayEditsRebuildAncestorsAndRefuseScalarParentsTransactionally() throws {
    let input = try JSONParser().parse(#"{"a/b":[{"~":[1,2]},null]}"#)
    let path = try JSONPointer(parsing: "/a~1b/0/~0/1")
    let patch = try JSONPatch(operations: [.replace(path: path, value: 17),
        .add(path: JSONPointer(parsing: "/a~1b/0/~0/-"), value: 3), .remove(path: JSONPointer(parsing: "/a~1b/1"))])
    let expected = try JSONParser().parse(#"{"a/b":[{"~":[1,17,3]}]}"#)
    #expect(try patch.applying(to: input) == .document(expected))
    for badPath in ["/a~1b/1/child", "/a~1b/1/child/deeper"] {
        let failing = try JSONPatch(operations: [.replace(path: path, value: 17), .add(path: JSONPointer(parsing: badPath), value: 3)])
        do { _ = try failing.applying(to: input); Issue.record("Expected scalar parent refusal") }
        catch let failure as JSONFailure { #expect(failure.category == .typeMismatch && failure.code == .wrongKind) }
        #expect(try input == JSONParser().parse(#"{"a/b":[{"~":[1,2]},null]}"#))
    }
}
