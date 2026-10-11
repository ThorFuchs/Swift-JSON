// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONPatch
import JSONStreaming
public func mobileSDKProbe() throws -> Bool {
    let value = try JSONParser().parse(#"{"count":9007199254740993,"name":"Ada"}"#)
    let schema = try JSONSchemaDocument(JSONParser().parse(#"{"type":"object","properties":{"name":{"pattern":"^A"}},"required":["name"]}"#))
    let plan = try JSONSchemaCompiler().compile(schema)
    let verdict = try JSONSchemaValidator().validate(value, against: plan)
    let merged = try JSONMergePatch(.null).applying(to: value)
    _ = JSONAsyncWriter()
    return verdict.isValid && merged == .null
}
