// SPDX-License-Identifier: Apache-2.0
import JSON
import JSONSchema
import JSONStreaming
import JSONPatch
import JSONHTML
public func mobileFiveProbe() throws -> Bool {
 let value = try JSONParser().parse(#"{"n":9007199254740993}"#)
 let plan = try JSONSchemaCompiler().compile(JSONSchemaDocument(JSONParser().parse(#"{"type":"object"}"#)))
 let verdict = try JSONSchemaValidator().validate(value,against:plan)
 _ = JSONAsyncWriter()
 let merged = try JSONMergePatch(.null).applying(to:value)
 let html = try JSONHTMLRenderer().render(value)
 return verdict.isValid && merged == .null && !html.bytes.isEmpty
}
