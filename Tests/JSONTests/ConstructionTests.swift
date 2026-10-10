// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@Test func explicitConstructionDoesNotFlattenOrOverwrite() throws {
    let array = try JSON.buildArray { values in
        try values.append(.array([1, 2])); try values.append(contentsOf: [3, 4])
    }
    #expect(array == .array([.array([1, 2]), 3, 4]))
    let object = try JSONObject.build { try $0.append("array", value: array) }
    #expect(object["array"] == array)
    #expect(throws: JSONFailure.self) {
        try JSONObject.build { try $0.append("same", value: 1); try $0.append("same", value: 2) }
    }
}
@Test func buildersEnforceBeforeInsertion() throws {
    var limits = JSONLimits.balanced; limits[.arrayItems] = 1
    #expect(throws: JSONFailure.self) { try JSON.buildArray(limits: limits) { try $0.append(1); try $0.append(2) } }
    limits = .balanced; limits[.maxDepth] = 1
    #expect(throws: JSONFailure.self) { try JSON.buildArray(limits: limits) { try $0.append(.array([])) } }
}
