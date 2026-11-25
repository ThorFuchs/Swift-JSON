// SPDX-License-Identifier: Apache-2.0
import JSON
import Testing
@testable import JSONFoundationModels

private func parse(_ text: String) throws -> JSON { try JSONParser().parse(text) }
private func relay(_ value: JSON, limits: JSONLimits = .balanced) throws -> JSONOperationReport<String> {
    try JF2ValueBoundary.export(value, limits: limits, make: { $0 }, read: { $0 })
}

@Test func jf2ExactNativeRoundtrips() throws {
    for text in ["null", "true", "9007199254740993", "9223372036854775807",
                 "0.12345678901234567890123456789", "1e100", #"{"a":[1,null,{"b":true}]}"#,
                 #"{"\u00e9":1,"e\u0301":2}"#, #""e\u0301""#] {
        let value = try parse(text)
        let report = try relay(value)
        #expect(try JSONComparison.equals(value, parse(report.result)))
        #expect(report.statistics[.workUnits] > 0)
    }
}

@Test func jf2RejectsSemanticLoss() throws {
    let pairs = [("9007199254740993", "9007199254740992"),
                 ("0.12345678901234567890123456789", "0.12345678901234568"),
                 (#"{"a":null}"#, "{}"), (#"{"\u00e9":1,"e\u0301":2}"#, #"{"\u00e9":2}"#),
                 (#""e\u0301""#, #""\u00e9""#), ("[1,2]", "[2,1]"), ("1", "true")]
    for (original, changed) in pairs {
        let value = try parse(original)
        #expect(throws: JSONGeneratedContentBridgeFailure.changedValue) {
            try JF2ValueBoundary.export(value, limits: .balanced, make: { _ in changed }, read: { $0 })
        }
    }
}

@Test func jf2AcceptsOnlySemanticNotTextIdentity() throws {
    let value = try parse(#"{"a":1.00,"b":2}"#)
    let returned = #"{"b":2e0,"a":1}"#
    let report = try JF2ValueBoundary.export(value, limits: .balanced, make: { _ in returned }, read: { $0 })
    #expect(report.result == returned)
}

@Test func jf2MalformedForeignJSONRejected() throws {
    for malformed in ["", "{}{}", "NaN", #"{"x":1,"x":2}"#, #""\ud800""#] {
        #expect(throws: JSONFailure.self) {
            try JF2ValueBoundary.importValue(limits: .balanced) { malformed }
        }
        #expect(throws: JSONFailure.self) {
            try JF2ValueBoundary.export(.null, limits: .balanced, make: { _ in malformed }, read: { $0 })
        }
    }
}

@Test func jf2IncompleteForeignSnapshotRejected() throws {
    #expect(throws: JSONGeneratedContentBridgeFailure.incompleteContent) {
        try JF2ValueBoundary.importValue(limits: .balanced) {
            throw JSONGeneratedContentBridgeFailure.incompleteContent
        }
    }
    #expect(throws: JSONGeneratedContentBridgeFailure.incompleteContent) {
        try JF2ValueBoundary.export(.null, limits: .balanced, make: { $0 }, read: { _ in
            throw JSONGeneratedContentBridgeFailure.incompleteContent
        })
    }
}

@Test func jf2InputOutputLimitsDoNotReset() throws {
    var limits = JSONLimits.balanced
    limits[.inputBytes] = 3
    #expect(throws: JSONFailure.self) { try JF2ValueBoundary.importValue(limits: limits) { "null" } }
    #expect(throws: JSONFailure.self) { try relay(.null, limits: limits) }
    limits = .balanced; limits[.outputBytes] = 3
    #expect(throws: JSONFailure.self) { try relay(.null, limits: limits) }
}

@Test func jf2CumulativeBudgetBoundary() throws {
    let value = try parse(#"{"n":9007199254740993,"a":[true,null,"text"]}"#)
    let observed = try relay(value)
    var limits = JSONLimits.balanced
    limits[.workUnits] = observed.statistics[.workUnits]
    limits[.retainedBytes] = observed.statistics.peakLogicalRetainedBytes
    #expect(try relay(value, limits: limits).statistics == observed.statistics)
    var lessWork = limits; lessWork[.workUnits] -= 1
    #expect(throws: JSONFailure.self) { try relay(value, limits: lessWork) }
    var lessRetention = limits; lessRetention[.retainedBytes] -= 1
    #expect(throws: JSONFailure.self) { try relay(value, limits: lessRetention) }
}

@Test func jf2CancellationAfterForeignCallback() async throws {
    let task = Task {
        try JF2ValueBoundary.export(.null, limits: .balanced, make: { text in
            withUnsafeCurrentTask { $0?.cancel() }
            return text
        }, read: { _ in
            Issue.record("Cancelled invocation read foreign value")
            return "null"
        })
    }
    await #expect(throws: CancellationError.self) { try await task.value }
}

#if (os(macOS) || os(iOS)) && canImport(FoundationModels)
import FoundationModels

@available(macOS 27.0, iOS 27.0, *)
@Test func jf2AppleOrdinaryValueRoundtrip() throws {
    let bridge = JSONGeneratedContentBridge()
    let original = try parse(#"{"query":"test","limit":2,"tags":["a","b"],"active":true}"#)
    let exported = try bridge.generatedContentWithReport(from: original)
    #expect(exported.result.isComplete)
    #expect(try JSONComparison.equals(original, bridge.json(from: exported.result)))
    #expect(exported.statistics[.workUnits] > 0)
}

@available(macOS 27.0, iOS 27.0, *)
@Test func jf2AppleExactOrExplicitRejection() throws {
    let bridge = JSONGeneratedContentBridge()
    // The JF1 matrix will determine which of these the real SDK preserves.
    // No assertion that a difficult value must be representable; any returned
    // content must have passed the exact native semantic equality guard.
    for text in ["9007199254740993", "9223372036854775807", "0.12345678901234567890123456789",
                 "1e100", #"{"\u00e9":1,"e\u0301":2}"#, #"{"a":null}"#] {
        let original = try parse(text)
        do {
            let exported = try bridge.generatedContent(from: original)
            #expect(try JSONComparison.equals(original, bridge.json(from: exported)))
        } catch let failure as JSONGeneratedContentBridgeFailure {
            #expect([.changedValue, .frameworkRejected, .incompleteContent].contains(failure))
        // Other native errors are deliberately not swallowed: inspect unexpected
        // parser/limit failures on these small inputs as a separate finding.
        }
    }
}

#endif
