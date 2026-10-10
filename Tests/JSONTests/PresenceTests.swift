// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
@Test func absenceNullAndWrongKindRemainDistinct() throws {
    let object = try JSONObject(members: [JSONMember("null", value: .null), JSONMember("value", value: 4)])
    #expect(object.presence(of: "missing") == .absent)
    #expect(object.presence(of: "null") == .null)
    #expect(object.presence(of: "value") == .value(4))
    #expect(throws: JSONFailure.self) { try JSON.boolean(false).presence(of: "value") }
    #expect(throws: JSONFailure.self) { try JSON.object(object).requiredMember("missing") }
    #expect(try JSON.object(object).requiredMember("null") == .null)
}
