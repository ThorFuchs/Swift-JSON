// SPDX-License-Identifier: Apache-2.0
import Testing
import JSON
import JSONSchema

@Test func wideIndexedInstancesPreserveRequiredDependenciesAndExactKeys() throws {
    let members = (0..<128).map { JSONMember("field-\($0)", value: .null) } + [JSONMember("é", value: 1), JSONMember("e\u{301}", value: 2)]
    let value = JSON.object(try JSONObject(members: members))
    let schema = try JSONParser().parse(#"{"type":"object","required":["field-127","é","e\u0301"],"properties":{"field-127":{"type":"null"},"é":{"const":1},"e\u0301":{"const":2}},"dependentRequired":{"field-126":["field-127"]}}"#)
    let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(schema))
    #expect(try JSONSchemaValidator().validate(value, against: plan).isValid)
    let missing = JSON.object(try value.objectValue!.removing("field-127"))
    #expect(try !JSONSchemaValidator().validate(missing, against: plan).isValid)
    let changed = JSON.object(try value.objectValue!.setting(2, for: "é"))
    #expect(try !JSONSchemaValidator().validate(changed, against: plan).isValid)
}
