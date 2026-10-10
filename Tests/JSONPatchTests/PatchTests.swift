// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONPatch
private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }
private func patch(_ text: String) throws -> JSONPatch { try JSONPatch(json: parse(text)) }
@Test func allRFC6902OperationsAndArrayMoveOrdering() throws {
    let input = try parse(#"{"a":[1,2,3],"x":true}"#)
    let operations = try patch(#"[{"op":"test","path":"/x","value":true},{"op":"move","from":"/a/0","path":"/a/2"},{"op":"copy","from":"/a","path":"/b"},{"op":"add","path":"/a/-","value":4},{"op":"replace","path":"/x","value":null},{"op":"remove","path":"/a/0"}]"#)
    let result = try operations.applying(to: input)
    #expect(result == .document(try parse(#"{"a":[3,1,4],"x":null,"b":[2,3,1]}"#)))
    #expect(input == (try parse(#"{"a":[1,2,3],"x":true}"#)))
}
@Test func rootRemovalRecreationAndNullRemainDistinct() throws {
    #expect(try patch(#"[{"op":"remove","path":""}]"#).applying(to: .null) == .removed)
    #expect(try patch(#"[{"op":"remove","path":""},{"op":"add","path":"","value":null}]"#).applying(to: .null) == .document(.null))
    #expect(throws: JSONFailure.self) { try patch(#"[{"op":"remove","path":""},{"op":"replace","path":"","value":1}]"#).applying(to: .null) }
}
@Test func patchFailuresAreTransactionalAndStrict() throws {
    let input = try parse(#"{"a":{"b":1},"items":[1]}"#)
    for text in [
        #"[{"op":"move","from":"/a","path":"/a/c"}]"#,
        #"[{"op":"add","path":"/missing/child","value":1}]"#,
        #"[{"op":"remove","path":"/items/01"}]"#,
        #"[{"op":"test","path":"/a/b","value":2}]"#,
        #"[{"op":"replace","path":"/a/b","value":2},{"op":"remove","path":"/missing"}]"#
    ] { #expect(throws: JSONFailure.self) { try patch(text).applying(to: input) } }
    #expect(input == (try parse(#"{"a":{"b":1},"items":[1]}"#)))
    #expect(try patch(#"[{"op":"test","path":"/a/b","value":1.00,"ignored":false}]"#).applying(to: input) == .document(input))
}
@Test func patchLimitsCoverIntermediateGrowthAndCumulativeWork() throws {
    var limits = JSONLimits.balanced; limits[.arrayItems] = 1
    let operations = try patch(#"[{"op":"add","path":"/-","value":2},{"op":"remove","path":"/0"}]"#)
    #expect(throws: JSONFailure.self) { try operations.applying(to: .array([1]), options: .init(limits: limits)) }
    limits = .balanced; limits[.operations] = 0
    #expect(throws: JSONFailure.self) { try operations.applying(to: .array([1]), options: .init(limits: limits)) }
    // Merge Patch visits are not RFC 6902 operations.
    #expect(try JSONMergePatch(parse(#"{"a":1,"b":2}"#)).applying(to: .null, options: .init(limits: limits)) == parse(#"{"a":1,"b":2}"#))
    limits = .balanced; limits[.patchWorkUnits] = 2
    #expect(throws: JSONFailure.self) { try JSONMergePatch(.null).applying(to: .array([1,2,3]), options: .init(limits: limits)) }
}
@Test func stagedNodeAndOutputCapsApplyBeforeLaterRemoval() throws {
    var limits = JSONLimits.balanced; limits[.nodes] = 3
    #expect(try patch(#"[{"op":"add","path":"/-","value":2}]"#).applying(to: .array([1]), options: .init(limits: limits)) == .document(.array([1,2])))
    limits[.outputBytes] = 4
    #expect(throws: JSONFailure.self) { try patch(#"[{"op":"add","path":"/-","value":2},{"op":"remove","path":"/0"}]"#).applying(to: .array([1]), options: .init(limits: limits)) }
    #expect(throws: JSONFailure.self) { try JSONMergePatch(.array([1,2])).applying(to: .null, options: .init(limits: limits)) }
}

@Test func discardedStagesReleaseOwnershipWithoutRefundingWork() throws {
    let path = try JSONPointer(parsing: "/0")
    let patch = try JSONPatch(operations: Array(repeating: .replace(path: path,value: 1),count: 1_000))
    var limits = JSONLimits.balanced; limits[.retainedBytes] = 1024
    let report = try patch.applyingWithReport(to: .document(.array([1])),options: .init(limits: limits))
    #expect(report.result == .document(.array([1])))
    #expect(report.statistics[.operations] == 1_000 && report.statistics[.patchWorkUnits] > 1_000)
    #expect(report.statistics.peakLogicalRetainedBytes < 1024)
}
