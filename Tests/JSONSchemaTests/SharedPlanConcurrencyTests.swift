// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func concurrentSchemaEvaluationsHaveExclusiveDynamicRegexAndAnnotationState() async throws {
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(##"{"$dynamicAnchor":"node","anyOf":[{"type":"null"},{"type":"object","properties":{"next":{"$dynamicRef":"#node"},"label":{"type":"string","pattern":"^(a|b)+$"}},"required":["next","label"],"unevaluatedProperties":false}]}"##)))
    let valid = try JSONParser().parse(#"{"next":{"next":null,"label":"aba"},"label":"bbb"}"#)
    let invalid = try JSONParser().parse(#"{"next":null,"label":"ab!"}"#)
    let correct = try await withThrowingTaskGroup(of: Bool.self) { group in
        for i in 0..<64 {
            group.addTask {
                let expected = i%2 == 0
                let result = try JSONSchemaValidator(options: .init(collectAnnotations: true)).validate(expected ? valid : invalid,against: plan)
                return result.isValid == expected
            }
        }
        var count = 0
        for try await passed in group { if passed { count += 1 } }
        return count
    }
    #expect(correct == 64)
}
