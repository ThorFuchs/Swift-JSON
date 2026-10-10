// SPDX-License-Identifier: Apache-2.0
import Foundation
import JSON
import JSONSchema
import JSONStreaming
import JSONPatch

func requireSendable<T: Sendable>(_ value: T) {}
let exact = try JSONNumber(parsing: "9007199254740993")
let object = try JSONObject.build {
    try $0.append("count", value: .number(exact))
    try $0.append("note", value: .null)
}
let value: JSON = .object(object)
requireSendable(value)
requireSendable(JSONLimits.balanced)
requireSendable(JSONFailure(.syntax, code: .invalidSyntax))
let count = try exact.integer(as: Int64.self)
precondition(count == 9_007_199_254_740_993)
precondition(object.presence(of: "note") == .null)
try runREADMEExamples()
try await runProductExamples()
print("Consumer passed: exact values/Codable/Pointer, Patch/Merge Patch, schema documents/registry, streams/sink, reports and Sendable; immutable schema compilation/evaluation/output/inspection")
