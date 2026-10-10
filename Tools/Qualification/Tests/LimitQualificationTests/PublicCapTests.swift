// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON
import JSONSchema
import JSONStreaming
import JSONPatch

private struct OneChunk: AsyncSequence {
    typealias Element = JSONByteChunk
    let bytes: [UInt8]
    func makeAsyncIterator() -> Iterator { .init(bytes: bytes) }
    struct Iterator: AsyncIteratorProtocol {
        var bytes: [UInt8]?
        mutating func next() async -> JSONByteChunk? {
            guard let value = bytes else { return nil }; bytes = nil; return .init(value)
        }
    }
}

@Test func publicOperationsReachEveryActiveResourceCap() async throws {
    let raw = try JSONParser().parse(#"{"properties":{"a":{"pattern":"(a)"}}}"#)
    let plan = try JSONSchemaCompiler().compileWithReport(raw).result
    let instance = try JSONParser().parse(#"{"a":"a"}"#)
    let invalid = try JSONSchemaCompiler().compileWithReport(JSON.boolean(false)).result
    let patch = try JSONPatch(json: JSONParser().parse(#"[{"op":"add","path":"/a","value":1}]"#))
    var reached = Set<JSONResourceMetric>()
    for metric in JSONResourceMetric.allCases {
        var limits = JSONLimits.balanced; limits[metric] = 0
        // Zero scratch is the selected E09 policy: no reusable pool exists.
        // Cancellation quantum is a configuration constraint, not a work counter.
        if metric == .maxReusableBufferBytes {
            var records = 0
            for try await event in JSONTopLevelArraySequence(OneChunk(bytes: Array("[1,2,3]".utf8)), options: .init(limits: limits)) {
                if case .element = event { records += 1 }
            }
            #expect(records == 3); reached.insert(metric); print("CAP_PROBE \(metric.rawValue) zero-scratch-success"); continue
        }
        do {
            switch metric {
            case .inputBytes, .workUnits, .cancellationQuantum: _ = try JSONParser(options: .init(limits: limits)).parse("null")
            case .maxDepth, .arrayItems: _ = try JSONParser(options: .init(limits: limits)).parse("[1]")
            case .nodes, .numberDigits, .numberTokenBytes, .numericWorkUnits: _ = try JSONParser(options: .init(limits: limits)).parse("1")
            case .objectMembers, .keyBytes: _ = try JSONParser(options: .init(limits: limits)).parse(#"{"a":1}"#)
            case .stringBytes, .aggregateTextBytes, .retainedBytes: _ = try JSONParser(options: .init(limits: limits)).parse(#""a""#)
            case .absoluteExponent: _ = try JSONParser(options: .init(limits: limits)).parse("1e1")
            case .outputBytes: _ = try JSONWriter(options: .init(limits: limits)).write(.null)
            case .sourceMapEntries: _ = try JSONParser(options: .init(limits: limits)).parseDocument(Data("null".utf8))
            case .issues, .diagnosticBytes: _ = try JSONSchemaValidator(options: .init(limits: limits)).validate(.null, against: invalid)
            case .schemaDocuments, .schemaBytes, .schemaNodes, .referenceEdges, .compileWorkUnits,
                 .compiledPlanBytes, .regexPatternBytes, .aggregateRegexPatternBytes, .regexProgramInstructions,
                 .regexCompileWorkUnits, .regexCaptureGroups:
                _ = try JSONSchemaCompiler(options: .init(limits: limits)).compileWithReport(raw)
            case .evaluationWorkUnits, .evaluationFrames, .annotationEntries, .annotationBytes,
                 .regexSearchWorkUnits, .aggregateRegexWorkUnits, .regexRetainedBytes:
                _ = try JSONSchemaValidator(options: .init(limits: limits)).validate(instance, against: plan)
            case .pointerBytes, .pointerTokens: _ = try JSONPointer(parsing: "/a", limits: limits)
            case .operations, .patchWorkUnits: _ = try patch.applying(to: .object(JSONObject()), options: .init(limits: limits))
            case .chunkBytes, .pendingEvents, .totalInputBytes, .totalWorkUnits, .totalScannedNodes:
                var stream = JSONEventSequence(OneChunk(bytes: Array("[1]".utf8)), options: .init(limits: limits)).makeAsyncIterator()
                while try await stream.next() != nil {}
            case .pendingValues, .totalRecords:
                var stream = JSONTopLevelArraySequence(OneChunk(bytes: Array("[1]".utf8)), options: .init(limits: limits)).makeAsyncIterator()
                while try await stream.next() != nil {}
            case .maxReusableBufferBytes: break
            }
            Issue.record("Public operation escaped cap \(metric.rawValue)")
        } catch let failure as JSONFailure {
            if metric == .cancellationQuantum { #expect(failure.code == .invalidLimits && failure.category == .configuration) }
            else { #expect(failure.category == .resource && failure.resource?.metric == metric, "Wrong cap: \(metric.rawValue) => \(failure)") }
            reached.insert(metric); print("CAP_PROBE \(metric.rawValue) \(failure.code.rawValue)")
        }
    }
    #expect(reached == Set(JSONResourceMetric.allCases) && reached.count == 49)
}
