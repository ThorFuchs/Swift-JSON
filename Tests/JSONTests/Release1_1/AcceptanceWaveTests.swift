// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import JSON

private func qaPreserved(_ value: JSON) throws -> Data {
    try JSONWriter(options: .init(numberStyle: .preserved)).write(value)
}

// Fixed seed; the complete compact token is the independent fidelity oracle.
private func qaDocuments() -> [String] {
    var seed: UInt64 = 0x534A_1100_A11C_E001
    return (0..<192).map { index in
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let exact = "9007199254740993\(seed % 1000)"
        let fields = (0..<(32 + Int(seed % 5))).map { "\"k\($0)\":\($0)" }.joined(separator: ",")
        switch index % 6 {
        case 0: return "null"
        case 1: return index % 12 == 1 ? "true" : "false"
        case 2: return index % 12 == 2 ? "-0.00e+2" : exact
        case 3: return "\"é-é-🚀-\(seed % 1000)\""
        case 4: return "[\(exact),0.1,-0.00e+2,null,[],{},\"é\"]"
        default: return "{\(fields),\"é\":\(exact),\"é\":0.1,\"/~/\":null,\"\":false}"
        }
    }
}

@Test func qaGeneratedExactRoundTripsAcrossNativeAndForeignPayloads() throws {
    let documents = qaDocuments()
    #expect(documents.count == 192)
    for (index, compact) in documents.enumerated() {
        let expected = Data(compact.utf8)
        let root = try JSONParser().parse(" \r\n" + compact + "\t ")
        #expect(try qaPreserved(root) == expected, "seed case \(index)")
        let projected = try root.read { try $0.decode(JSON.self) }
        #expect(try qaPreserved(projected) == expected)
        let payload = try JSONCodablePayload(preserving: root)
        let native = try JSONValueEncoder().encode(payload)
        let nativeRestored = try native.decode(JSONCodablePayload.self)
        let jsonRestored = try JSONDecoder().decode(JSONCodablePayload.self, from: JSONEncoder().encode(payload))
        let plistRestored = try PropertyListDecoder().decode(JSONCodablePayload.self, from: PropertyListEncoder().encode(payload))
        for restored in [nativeRestored, jsonRestored, plistRestored] {
            #expect(try qaPreserved(restored.value()) == expected, "seed case \(index)")
        }
    }
}

@Test func qaIndexThresholdEditsAgreeWithOrderedScalarOracle() throws {
    for width in [0, 1, 7, 8, 15, 16, 31, 32, 33, 63, 64, 65, 127, 128, 257] {
        let keys = (0..<width).map { "prefix-\($0)-é" } + ["é", "e\u{301}", "", "/~"]
        let members = keys.enumerated().map { JSONMember($0.element, value: .number(JSONNumber(integer: $0.offset))) }
        var accumulator = try JSONObjectAccumulator()
        for member in members { try accumulator.append(member.key.string, value: member.value) }
        let accumulated = accumulator.finish()
        let checked = try JSONObject(members: members)
        let parsed = try #require(JSONParser().parse(qaPreserved(.object(checked))).objectValue)
        for object in [checked, parsed, accumulated] {
            var edited = try object.setting(999, for: "é")
            edited = try edited.removing("e\u{301}").setting(998, for: "e\u{301}")
            let expectedKeys = keys.filter { !$0.utf8.elementsEqual("e\u{301}".utf8) } + ["e\u{301}"]
            #expect(edited.members.map(\.key) == expectedKeys.map { JSONKey($0) })
            for (position, key) in keys.enumerated() {
                let expected: JSON = key.utf8.elementsEqual("é".utf8) ? 999 : key.utf8.elementsEqual("e\u{301}".utf8) ? 998 : .number(JSONNumber(integer: position))
                #expect(edited[JSONKey(key)] == expected)
                #expect(try JSON.object(edited).read { try $0[key].requiredValue() } == expected)
            }
            #expect(edited["not-present"] == nil)
        }
    }
}

@Test func qaSmallIntegerProjectionUsesMathematicalRangeOracle() throws {
    for integer in -129...256 {
        for token in ["\(integer)", "\(integer).000e0"] {
            let value = try JSONParser().parse(token)
            if let expected = Int8(exactly: integer) {
                #expect(try value.read { try $0.requiredInteger(as: Int8.self) } == expected)
                #expect(try value.decode(Int8.self) == expected)
            } else {
                #expect(throws: JSONAccessFailure.self) { try value.read { try $0.requiredInteger(as: Int8.self) } }
                #expect(throws: DecodingError.self) { try value.decode(Int8.self) }
            }
            if let expected = UInt8(exactly: integer) {
                #expect(try value.read { try $0.requiredInteger(as: UInt8.self) } == expected)
            } else { #expect(throws: JSONAccessFailure.self) { try value.read { try $0.requiredInteger(as: UInt8.self) } } }
        }
    }
}

@Test func qaNativeBase64MatchesCanonicalByteFixturesAndRejectsUnusedBits() throws {
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)
    for length in 0...258 {
        let bytes = Data((0..<length).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ length) })
        let canonical = bytes.base64EncodedString() // Independent fixture generation only.
        #expect(try JSON(encoding: bytes) == .string(canonical))
        #expect(try JSON.string(canonical).decode(Data.self) == bytes)
    }
    var rejected = 0
    for byte in 0..<64 {
        var one = Array(Data([UInt8(byte)]).base64EncodedString().utf8)
        let canonicalIndex = try #require(alphabet.firstIndex(of: one[1]))
        for unused in 1...15 {
            one[1] = alphabet[canonicalIndex | unused]
            #expect(throws: DecodingError.self) { try JSON.string(String(decoding: one, as: UTF8.self)).decode(Data.self) }
            rejected += 1
        }
        var two = Array(Data([UInt8(byte), 255]).base64EncodedString().utf8)
        let secondIndex = try #require(alphabet.firstIndex(of: two[2]))
        for unused in 1...3 {
            two[2] = alphabet[secondIndex | unused]
            #expect(throws: DecodingError.self) { try JSON.string(String(decoding: two, as: UTF8.self)).decode(Data.self) }
            rejected += 1
        }
    }
    #expect(rejected == 1152)
}

private struct QARecoveringData: Decodable {
    init(from decoder: any Decoder) throws {
        let native = try #require(decoder as? JSONNativeDecoder)
        let container = try decoder.singleValueContainer()
        let before = native.state.meter.used(.retainedBytes)
        let startingWork = native.state.meter.used(.workUnits)
        for _ in 0..<100 {
            do { _ = try container.decode(Data.self); Issue.record("Malformed Base64 accepted") }
            catch is DecodingError { }
            #expect(native.state.meter.used(.retainedBytes) == before, "failed Base64 scratch must be released")
        }
        #expect(native.state.meter.used(.workUnits) > startingWork, "failed work must not be refunded")
    }
}
@Test func qaCaughtMalformedDataReleasesScratchWithoutRefundingWork() throws {
    for malformed in ["AB==", "AAB=", "AAAA!", "AAAAAA==x"] {
        _ = try JSON.string(malformed).decode(QARecoveringData.self)
    }
}

@Test func qaReaderTighteningPersistsAfterOrdinaryProjectionFailure() throws {
    let root = try JSONParser().parse(#"{"history":"0123456789","n":1,"bad":"wrong"}"#)
    let admission = try root.readWithReport { _ in 0 }
    var coding = JSONCodingOptions()
    coding.limits[.workUnits] = admission.statistics[.workUnits] + 1000
    #expect(throws: JSONFailure.self) {
        try root.read { cursor in
            do { _ = try cursor["bad"].decode(Int.self, coding: coding) } catch is DecodingError { }
            for _ in 0..<1000 { _ = try cursor["n"].requiredInteger(as: Int.self) }
        }
    }
    coding = .init(); coding.limits[.stringBytes] = 9
    #expect(throws: JSONFailure.self) {
        try root.read { cursor in
            do { _ = try cursor["n"].decode(Int.self, coding: coding) } catch {}
            return 0 // Restriction checks admitted history, including unselected text.
        }
    }
}

private enum QACallerError: Error { case expected }
private struct QAThrowingModel: Decodable {
    init(from decoder: any Decoder) throws {
        _ = try decoder.singleValueContainer().decode(Double.self)
        throw QACallerError.expected
    }
}
@Test func qaCaughtCallerProjectionReleasesOwnedTemporaries() throws {
    let number = try JSONParser().parse("0.125")
    func attempt(_ cursor: JSONReadCursor) throws {
        do { _ = try cursor.decode(QAThrowingModel.self); Issue.record("Caller error disappeared") }
        catch QACallerError.expected { }
    }
    let one = try number.readWithReport { cursor in
        try attempt(cursor)
        #expect(try cursor.requiredDouble(policy: .exact) == 0.125)
    }
    var limits = JSONLimits.balanced; limits[.retainedBytes] = one.statistics.peakLogicalRetainedBytes
    let repeated = try number.readWithReport(limits: limits) { cursor in
        for _ in 0..<100 { try attempt(cursor) }
        #expect(try cursor.requiredDouble(policy: .exact) == 0.125)
    }
    #expect(repeated.statistics[.retainedBytes] == 0)
    #expect(repeated.statistics[.workUnits] > one.statistics[.workUnits])
}

@Test func qaBase64CleanupKeepsResourceAndCancellationTerminal() async throws {
    let canonical = Data(repeating: 255, count: 256).base64EncodedString()
    var limits = JSONLimits.balanced; limits[.retainedBytes] = 49
    var meter = try JSONWorkMeter(limits: limits, domain: .coding)
    try meter.retain(17) // An enclosing owner's reservation must survive.
    do { _ = try JSONBase64.decode(canonical, meter: &meter); Issue.record("Expected scratch refusal") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .retainedBytes) }
    #expect(meter.used(.retainedBytes) == 17 && meter.used(.workUnits) > 0)
    #expect(throws: JSONFailure.self) { try meter.checkpoint() }
    try meter.release(17)
    let cancelled = Task {
        var options = JSONLimits.balanced; options[.cancellationQuantum] = 1
        var local = try JSONWorkMeter(limits: options, domain: .coding)
        try local.retain(17)
        local.checkpointObserver = { work in
            if work >= 20 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        do { _ = try JSONBase64.decode(canonical, meter: &local); Issue.record("Cancellation disappeared") }
        catch is CancellationError { }
        #expect(local.used(.retainedBytes) == 17 && local.used(.workUnits) >= 20)
        #expect(throws: CancellationError.self) { try local.checkpoint() }
        try local.release(17)
    }
    try await cancelled.value
}

@Test func qaPayloadCreateAndOpenInclusiveWorkRetentionMatrix() throws {
    for compact in ["null", "0.1", "-0.00e+2", "[]", "{}", #"{"é":9007199254740993,"é":[null,false]}"#] {
        let value = try JSONParser().parse(compact)
        let made = try JSONCodablePayload.preservingWithReport(value)
        let opened = try made.result.valueWithReport()
        for (operation, statistics) in [(0, made.statistics), (1, opened.statistics)] {
            for metric in [JSONResourceMetric.workUnits, .retainedBytes] {
                let boundary = metric == .retainedBytes ? statistics.peakLogicalRetainedBytes : statistics[metric]
                var limits = JSONLimits.balanced; limits[metric] = boundary
                if operation == 0 { _ = try JSONCodablePayload(preserving: value, limits: limits) }
                else { #expect(try qaPreserved(made.result.value(limits: limits)) == Data(compact.utf8)) }
                limits[metric] = boundary - 1
                do {
                    if operation == 0 { _ = try JSONCodablePayload(preserving: value, limits: limits) }
                    else { _ = try made.result.value(limits: limits) }
                    Issue.record("Missing inclusive quota refusal")
                } catch let failure as JSONFailure {
                    #expect(failure.category == .resource && failure.resource?.metric == metric)
                }
            }
        }
    }
}

@Test func qaMappedScalarPathsUseUTF8ByteCoordinates() throws {
    let text = "{\n \"é\":{\"/~/\":[null,\"wrong\"]},\n \"é\":false\n}"
    let document = try JSONParser().parseDocument(Data(text.utf8), source: "qa")
    let prefix = "{\n \"é\":{\"/~/\":[null,"
    do { _ = try document.read { try $0["é"]["/~/"][1].requiredInteger(as: Int.self) }; Issue.record("Missing mapped failure") }
    catch let error as JSONAccessFailure {
        #expect(error.path == [.key("é"), .key("/~/"), .index(1)])
        #expect(error.cause.location?.byteOffset == UInt64(prefix.utf8.count))
        #expect(error.cause.location?.line == 2)
        #expect(error.cause.location?.column == UInt64(prefix.split(separator: "\n").last!.utf8.count + 1))
    }
    #expect(try document.read { try $0["e\u{301}"].requiredBoolean() } == false)
}

@Test func qaSharedPayloadAndRootHaveIndependentConcurrentReadScopes() async throws {
    let root = try JSONParser().parse(#"{"é":9007199254740993,"é":0.1,"a":[null,false]}"#)
    let payload = try JSONCodablePayload(preserving: root)
    let expected = try qaPreserved(root)
    try await withThrowingTaskGroup(of: Void.self) { group in
        for _ in 0..<16 {
            group.addTask {
                for _ in 0..<20 {
                    #expect(try qaPreserved(payload.value()) == expected)
                    let report = try root.readWithReport { cursor in
                        #expect(try cursor["é"].requiredInteger(as: UInt64.self) == 9_007_199_254_740_993)
                        return try cursor["e\u{301}"].requiredDouble(policy: .rounded)
                    }
                    #expect(report.result == 0.1 && report.statistics[.retainedBytes] == 0)
                }
            }
        }
        try await group.waitForAll()
    }
}
