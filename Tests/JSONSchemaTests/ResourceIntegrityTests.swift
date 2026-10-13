// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
@testable import JSONSchema

@Test func builtinIntegrityRejectsCorruptionAndPreservesOperationalFailures() throws {
    let data = Data("abc".utf8)
    let expected = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
    var valid = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
    try JSONSchemaRegistry.verifyBuiltin(data, size: 3, expectedHash: expected, meter: &valid)
    #expect(valid.used(.retainedBytes) == 0)
    for (bytes, size, hash) in [(Data("abd".utf8), UInt64(3), expected), (data, 4, expected), (data, 3, String(repeating: "0", count: 64))] {
        var invocation = try JSONWorkMeter(limits: .balanced, domain: .schemaCompilation)
        #expect(throws: JSONSchemaCompilationFailure.self) { try JSONSchemaRegistry.verifyBuiltin(bytes, size: size, expectedHash: hash, meter: &invocation) }
    }
    var limits = JSONLimits.balanced; limits[.compileWorkUnits] = 100
    var exhausted = try JSONWorkMeter(limits: limits, domain: .schemaCompilation)
    #expect(throws: JSONFailure.self) { try JSONSchemaRegistry.verifyBuiltin(data, size: 3, expectedHash: expected, meter: &exhausted) }
    #expect(exhausted.used(.retainedBytes) == 0)
}
