// SPDX-License-Identifier: Apache-2.0
import Testing
@testable import JSON

@Test func scalarIdentityAndOrderedObjectSemantics() throws {
    let composed = "\u{e9}", decomposed = "e\u{301}"
    #expect(composed == decomposed) // Demonstrates why native String equality is unsuitable.
    #expect(JSONKey(composed) != JSONKey(decomposed))
    #expect(JSON.string(composed) != JSON.string(decomposed))
    let object = try JSONObject(members: [JSONMember(composed, value: 1), JSONMember(decomposed, value: 2)])
    #expect(object.count == 2)
    #expect(object[composed] == 1)
    #expect(object[decomposed] == 2)
    let reversed = try JSONObject(members: object.members.reversed())
    #expect(object == reversed)
    #expect(object.hashValue == reversed.hashValue)
    #expect(object.members[0].key == JSONKey(composed))
    #expect(try JSONComparison.equals(.object(object), .object(reversed)))
}
@Test func duplicateKeysFailAndReplacementKeepsOrder() throws {
    #expect(throws: JSONFailure.self) { try JSONObject(members: [JSONMember("a", value: 1), JSONMember("a", value: 2)]) }
    let original = try JSONObject(members: [JSONMember("a", value: 1), JSONMember("b", value: 2)])
    let changed = try original.setting(3, for: "a")
    #expect(changed.members[0].value == 3)
    #expect(original["a"] == 1)
    let reinserted = try original.removing("a").setting(4, for: "a")
    #expect(reinserted.members.last?.key == "a")
}
@Test func comparisonAndCallerValueAdmissionAreBounded() throws {
    let value: JSON = .array([1, 2, 3])
    var limits = JSONLimits.balanced
    limits[.nodes] = 3
    #expect(throws: JSONFailure.self) { try JSONComparison.equals(value, value, limits: limits) }
    limits = .balanced; limits[.workUnits] = 5
    #expect(throws: JSONFailure.self) { try JSONComparison.equals(.string("long string"), .string("long string"), limits: limits) }
}
