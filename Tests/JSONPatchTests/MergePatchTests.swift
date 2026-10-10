// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONPatch
private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }
@Test func mergePatchRFC7396ExamplesAndScalarKeys() throws {
    let target = try parse(#"{"title":"Goodbye!","author":{"givenName":"John","familyName":"Doe"},"tags":["example","sample"],"content":"unchanged"}"#)
    let changes = try parse(#"{"title":"Hello!","phoneNumber":"+01-123-456-7890","author":{"familyName":null},"tags":["example"]}"#)
    #expect(try JSONMergePatch(changes).applying(to: target) == parse(#"{"title":"Hello!","author":{"givenName":"John"},"tags":["example"],"content":"unchanged","phoneNumber":"+01-123-456-7890"}"#))
    #expect(try JSONMergePatch(.null).applying(to: target) == .null)
    #expect(try JSONMergePatch(parse(#"{"a":{"b":null,"c":3}}"#)).applying(to: .array([])) == parse(#"{"a":{"c":3}}"#))
    let distinct = try parse(#"{"é":1,"é":2}"#)
    #expect(try JSONMergePatch(parse(#"{"é":null}"#)).applying(to: distinct) == parse(#"{"é":2}"#))
}

@Test func mergePatchAdmitsInputsIndividuallyAndChecksIntermediateStates() throws {
    let input = try parse(#"{"drop":[1,2,3],"keep":0}"#)
    var limits = JSONLimits.balanced; limits[.nodes] = 6
    #expect(try JSONMergePatch(parse(#"{"keep":1}"#)).applying(to: input,options: .init(limits: limits)) == parse(#"{"drop":[1,2,3],"keep":1}"#))
    // Both inputs fit separately and the final result fits, but the first stage does not.
    let patch = try parse(#"{"grow":[4,5,6],"drop":null}"#)
    #expect(throws: JSONFailure.self) { try JSONMergePatch(patch).applying(to: input,options: .init(limits: limits)) }
    #expect(input == (try parse(#"{"drop":[1,2,3],"keep":0}"#)))
}
