// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema

private func pinned(_ name: String) throws -> Data {
    try Data(contentsOf: #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")))
}

private func refused(_ body: () throws -> Void) throws -> JSONFailure {
    do { try body() } catch let failure as JSONFailure { return failure }
    Issue.record("Expected a structured native failure")
    throw PinnedFailure.missingFailure
}
private enum PinnedFailure: Error { case missingFailure, caller }

@Test func pinnedDocumentsHaveIndependentCapacityAndCumulativeStatistics() throws {
    let entry = try pinned("entry-577"), resource = try pinned("resource-152")
    let larger = try pinned("resource-578")
    #expect(entry.count == 577 && resource.count == 152 && larger.count == 578)
    var limits = JSONLimits.balanced
    limits[.inputBytes] = 577
    let report = try JSON.withComposition(limits: limits) { scope in
        (try scope.parseDocument(entry), try scope.parseDocument(resource))
    }
    #expect(report.statistics[.inputBytes] == 729)
    #expect(report.result.0.sourceBytes == entry && report.result.1.sourceBytes == resource)
    let repeated = try JSON.withComposition(limits: limits) { scope in
        (try scope.parseDocument(entry), try scope.parseDocument(resource), try scope.parseDocument(entry))
    }
    #expect(repeated.statistics[.inputBytes] == 1306)
    #expect(repeated.result.0.sourceBytes == repeated.result.2.sourceBytes)
    #expect(repeated.statistics[.retainedBytes] > report.statistics[.retainedBytes])
    #expect(repeated.statistics[.workUnits] > report.statistics[.workUnits])
    limits[.inputBytes] = 576
    let first = try refused { _ = try JSON.withComposition(limits: limits) { try $0.parseDocument(entry) } }
    #expect(first.category == .resource && first.code == .limitExceeded)
    #expect(first.resource?.domain == .parsing && first.resource?.metric == .inputBytes)
    #expect(first.resource?.limit == 576 && first.resource?.attemptedUsage == 577)
    limits[.inputBytes] = 577
    let second = try refused {
        _ = try JSON.withComposition(limits: limits) { scope in
            _ = try scope.parseDocument(entry)
            do { _ = try scope.parseDocument(larger) } catch { }
            do { _ = try scope.parseDocument(resource) } catch { }
            throw PinnedFailure.caller
        }
    }
    #expect(second.category == .resource && second.code == .limitExceeded)
    #expect(second.resource?.domain == .parsing && second.resource?.metric == .inputBytes)
    #expect(second.resource?.limit == 577 && second.resource?.attemptedUsage == 578)
}

@Test func pinnedSyntaxFailuresRemainDistinctFromResourceRefusalAndSticky() throws {
    for (data, expected) in [(try pinned("invalid-json"), JSONFailure.Code.unexpectedEOF),
                             (try pinned("duplicate-decoded-key"), .duplicateKey),
                             (Data(), .unexpectedEOF)] {
        let failure = try refused {
            _ = try JSON.withComposition { scope in
                do { _ = try scope.parseDocument(data) } catch { }
                do { try scope.reserveExternalLogicalBytes(UInt64.max, count: 2) } catch { }
                return 7
            }
        }
        #expect(failure.category == .syntax && failure.code == expected)
        #expect(failure.resource == nil)
    }
}

@Test func pinnedExactSourceAndAll49CompletionCountersUseNativeAuthority() throws {
    let bytes = try pinned("source-exact")
    let report = try JSON.withComposition { scope in
        let document = try scope.parseDocument(bytes)
        let number = try scope.resolve(scope.pointer(parsing: "/large"), in: document.root)
        let fraction = try scope.resolve(scope.pointer(uriFragment: "#/%66raction"), in: document.root)
        let uri = try scope.uri("https://EXAMPLE.invalid/a/../schema#/%252F")
        return (document, number, fraction, try scope.removingFragment(uri))
    }
    #expect(report.result.0.sourceBytes == bytes)
    #expect(report.result.1.numberValue?.originalLexeme == "9007199254740993")
    #expect(report.result.2.numberValue?.originalLexeme == "0.0100")
    #expect(report.result.3.string == "https://example.invalid/schema")
    let root = report.result.0.root
    #expect(Array(try #require(root.objectValue?["precomposed"]?.stringValue).unicodeScalars).map(\.value) == [0xE9])
    #expect(Array(try #require(root.objectValue?["decomposed"]?.stringValue).unicodeScalars).map(\.value) == [0x65, 0x301])
    #expect(root.objectValue?["schemaType"] == .array(["number", "integer"]))
    #expect(root.objectValue?["schemaUnknown"]?.objectValue?["x-unrecognized"] == true)
    #expect(report.statistics[.compileWorkUnits] == 0 && report.statistics[.compiledPlanBytes] == 0)
    let empty = try JSON.withComposition { _ in 7 }.statistics
    #expect(JSONResourceMetric.allCases.count == 49 && empty.accountingVersion == 1)
    #expect(empty.domain == .core && empty.peakLogicalRetainedBytes == 424)
    for metric in JSONResourceMetric.allCases {
        let expected: UInt64 = metric == .workUnits ? 50 : metric == .retainedBytes ? 424 : 0
        #expect(empty[metric] == expected)
    }
    for (metric, exact) in [(JSONResourceMetric.workUnits, UInt64(50)), (.retainedBytes, 424)] {
        var limits = JSONLimits.balanced
        limits[metric] = exact - 1
        let failure = try refused { _ = try JSON.withComposition(limits: limits) { _ in 7 } }
        #expect(failure.category == .resource && failure.code == .limitExceeded)
        #expect(failure.resource?.domain == .core && failure.resource?.metric == metric)
        #expect(failure.resource?.limit == exact - 1 && failure.resource?.attemptedUsage == exact)
    }
}
