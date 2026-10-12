// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
@testable import JSON

private struct ReadModel: Codable, Equatable { let count: UInt64; let name: String; let bytes: Data }
private struct MeterWitness: Decodable {
    let identity: ObjectIdentifier
    let work: UInt64
    init(from decoder: any Decoder) throws {
        let native = try #require(decoder as? JSONNativeDecoder)
        identity = ObjectIdentifier(native.state); work = native.state.meter.statistics()[.workUnits]
    }
}
private struct UserInfoWitness: Decodable {
    let marker: String
    init(from decoder: any Decoder) throws {
        marker = try #require(decoder.userInfo[CodingUserInfoKey(rawValue: "marker")!] as? String)
    }
}
private enum ReadCallerFailure: Error { case expected }
private struct RefusingDecode: Decodable { init(from decoder: any Decoder) throws { throw ReadCallerFailure.expected } }
private struct CatchingOwnedFailure: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.singleValueContainer()
        do { _ = try c.decode(UInt64.self) } catch {}
    }
}
private func expectAccess(_ path: [JSONLocationComponent], _ code: JSONFailure.Code, _ body: () throws -> Void) {
    do { try body(); Issue.record("Expected a typed access failure") }
    catch let error as JSONAccessFailure { #expect(error.path == path); #expect(error.cause.code == code) }
    catch { Issue.record("Unexpected error: \(type(of: error))") }
}

@Test func readAccessChainedBracketsAndRequiredKinds() throws {
    let value = try JSONParser().parse(#"{"users":[{"name":"Ada","age":9007199254740993}],"0":false,"empty":"","zero":0,"false":false,"null":null}"#)
    try value.read { root in
        let user = try root[JSONKey("users")][0]
        #expect(try user["name"].requiredString() == "Ada")
        #expect(try user["age"].requiredInteger(as: UInt64.self) == 9_007_199_254_740_993)
        #expect(try root["0"].requiredBoolean() == false)
        #expect(try root["users"].requiredArray().count == 1)
        #expect(try user.requiredObject().count == 2)
        #expect(try root["null"].requiredValue() == .null)
        #expect(try root.stringPresence(of: "empty") == .value(""))
        #expect(try root.numberPresence(of: "zero") == .value(JSONNumber(integer: 0)))
        #expect(try root.booleanPresence(of: "false") == .value(false))
        #expect(try root.presence(of: JSONKey("missing")) == .absent)
        #expect(try root.stringPresence(of: JSONKey("null")) == .null)
    }
}

@Test func readAccessExactKeysAndFirstFailingHop() throws {
    let keys = ["", "0", "/", "~", "a.b", "\u{e9}", "e\u{301}", "🚀"]
    let value = JSON.object(try JSONObject(members: keys.map { .init($0, value: .string($0)) }))
    try value.read { root in
        for key in keys { let text = try root[key].requiredString(); #expect(text.utf8.elementsEqual(key.utf8)) }
        expectAccess([.key("missing")], .missingMember) { _ = try root["missing"]["later"] }
        expectAccess([.index(0)], .wrongKind) { _ = try root[0] }
        expectAccess([.key("0"), .key("later")], .wrongKind) { _ = try root["0"]["later"] }
        expectAccess([.key("0")], .wrongKind) { _ = try root["0"].requiredBoolean() }
    }
    try JSON.array([.null]).read { root in
        expectAccess([.index(-1)], .invalidIndex) { _ = try root[-1] }
        expectAccess([.index(1)], .missingTarget) { _ = try root[1] }
        expectAccess([.key("0")], .wrongKind) { _ = try root["0"] }
    }
}

@Test func readAccessExactNumericPoliciesAndBounds() throws {
    for text in ["9007199254740993", "18446744073709551615"] {
        let value = try JSONParser().parse(text)
        #expect(try value.read { try $0.requiredInteger(as: UInt64.self) } == UInt64(text))
    }
    #expect(try JSONParser().parse("-9223372036854775808").read { try $0.requiredInteger(as: Int64.self) } == Int64.min)
    for text in ["1.5", "18446744073709551616", "-1"] {
        let value = try JSONParser().parse(text)
        expectAccess([], .inexactConversion) { _ = try value.read { try $0.requiredInteger(as: UInt64.self) } }
    }
    let tenth = try JSONParser().parse("0.1")
    expectAccess([], .inexactConversion) { _ = try tenth.read { try $0.requiredDouble(policy: .exact) } }
    #expect(try tenth.read { try $0.requiredDouble(policy: .rounded) } == 0.1)
    #expect(try tenth.read { try $0.requiredDecimal(policy: .exact) } == Decimal(string: "0.1"))
    let huge = try JSONParser().parse("1e100000")
    expectAccess([], .inexactConversion) { _ = try huge.read { try $0.requiredDouble(policy: .rounded) } }
}

@Test func readAccessMappedDiagnosticsAndReplacedRootCoherence() throws {
    let bytes = Data("{\n  \"user\": {\"age\": \"wrong\"}\n}".utf8)
    let document = try JSONParser().parseDocument(bytes, source: "fixture")
    do {
        _ = try document.read { try $0["user"]["age"].requiredInteger(as: Int.self) }
        Issue.record("Expected mapped kind failure")
    } catch let error as JSONAccessFailure {
        #expect(error.path == [.key("user"), .key("age")])
        #expect(error.cause.location?.byteOffset == 20)
        #expect(error.cause.location?.line == 2)
        #expect(error.cause.location?.column == 19)
        #expect(JSONDiagnostic(error).failure == error.cause)
    }
    do { _ = try document.read { try $0["user"]["age"]["child"].requiredValue() } }
    catch let error as JSONAccessFailure { #expect(error.cause.location?.byteOffset == 20) }
    do { _ = try document.read { try $0["user"]["missing"].requiredValue() } }
    catch let error as JSONAccessFailure { #expect(error.cause.location?.byteOffset == 12) }
    do { _ = try document.replacingRoot(document.root).read { try $0["user"]["age"].requiredBoolean() } }
    catch let error as JSONAccessFailure { #expect(error.cause.location == nil) }
}

@Test func readAccessSharedProjectionLimitsAndTerminalAccounting() throws {
    var history = JSONCodingOptions(); history.limits[.stringBytes] = 6
    #expect(throws: JSONFailure.self) { try JSON.string("history").read { try $0.decode(String.self, coding: history) } }
    var huge = JSONLimits.balanced; huge[.inputBytes] = UInt64(Int.max) - 1
    var lifetime = try JSONWorkMeter(limits: huge, domain: .core)
    for _ in 0..<2 { try lifetime.charge(.inputBytes, huge[.inputBytes]); try lifetime.resetValueBounds() }
    #expect(throws: JSONFailure.self) { try lifetime.charge(.inputBytes, huge[.inputBytes]) }
    let terminal = lifetime.statistics()[.inputBytes]
    #expect(throws: JSONFailure.self) { try lifetime.checkpoint() }
    #expect(lifetime.statistics()[.inputBytes] == terminal)
    let model = ReadModel(count: .max, name: "e\u{301}", bytes: Data([0, 1, 255]))
    let value = try JSON(encoding: model)
    #expect(try value.decode(ReadModel.self) == model)
    #expect(try value.read { try $0.decode(ReadModel.self) } == model)
    let baseline = try value.readWithReport { _ in 0 }
    let decoded = try value.readWithReport { try $0.decode(ReadModel.self) }
    #expect(decoded.statistics.domain == .core)
    #expect(decoded.statistics[.workUnits] > baseline.statistics[.workUnits])
    #expect(decoded.statistics[.numericWorkUnits] > baseline.statistics[.numericWorkUnits])
    try value.read { root in
        let first = try root.decode(MeterWitness.self)
        let second = try root["count"].decode(MeterWitness.self)
        #expect(first.identity == second.identity && second.work > first.work)
        let info = JSONCodingOptions(userInfo: [CodingUserInfoKey(rawValue: "marker")!: "qualified"])
        #expect(try root.decode(UserInfoWitness.self, coding: info).marker == "qualified")
    }
    var coding = JSONCodingOptions(); coding.limits[.workUnits] = baseline.statistics[.workUnits] - 1
    #expect(throws: JSONFailure.self) {
        try value.read { root in
            do { _ = try root.decode(ReadModel.self, coding: coding) } catch {}
            return 0
        }
    }
    var limits = JSONLimits.balanced; limits[.workUnits] = decoded.statistics[.workUnits]
    #expect(try value.read(limits: limits) { try $0.decode(ReadModel.self) } == model)
    #expect(throws: JSONFailure.self) {
        try value.read(limits: limits) { root in
            _ = try root.decode(ReadModel.self)
            return try root.decode(ReadModel.self)
        }
    }
    #expect(throws: ReadCallerFailure.self) { try value.read { try $0.decode(RefusingDecode.self) } }
    let text = try JSONParser().parse("18446744073709551615")
    let admitted = try text.readWithReport { _ in 0 }
    var tight = JSONCodingOptions(); tight.limits[.workUnits] = admitted.statistics[.workUnits] + 2
    #expect(throws: JSONFailure.self) { try text.read { try $0.decode(CatchingOwnedFailure.self, coding: tight) } }
    #expect(throws: JSONFailure.self) { try text.decode(CatchingOwnedFailure.self, coding: tight) }
}

@Test func readAccessPresenceAvoidsCallerDecodeAndPreservesNativeFidelity() throws {
    let value = try JSONParser().parse(#"{"null":null,"wrong":"no","good":9007199254740993,"é":1,"e\u0301":2}"#)
    try value.read { root in
        switch try root.presence(of: "missing", as: RefusingDecode.self) { case .absent: break; default: Issue.record("Missing decoded") }
        switch try root.presence(of: JSONKey("null"), as: RefusingDecode.self) { case .null: break; default: Issue.record("Null decoded") }
        #expect(try root.presence(of: "good", as: UInt64.self) == .value(9_007_199_254_740_993))
        #expect(throws: DecodingError.self) { try root.presence(of: "wrong", as: UInt64.self) }
        #expect(throws: ReadCallerFailure.self) { try root.presence(of: "good", as: RefusingDecode.self) }
        #expect(try root.decode(JSON.self) == value)
        #expect(throws: DecodingError.self) { try root.decode([String: JSON].self) }
    }
    #expect(try value.decode(JSON.self) == value)
    #expect(try JSONParser().parse("9007199254740993").decode(JSONNumber.self) == JSONNumber(parsing: "9007199254740993"))
    #expect(try value.decode(JSONObject.self).count == 5)
}

@Test func readAccessEscapedHandlesInvalidateAndReleaseRootAndSource() throws {
    let document = try JSONParser().parseDocument(Data(#"{"child":{"name":"value"}}"#.utf8))
    let escaped = try document.read { try $0["child"] }
    #expect(throws: JSONFailure.self) { try escaped.requiredValue() }
    let scope = try JSONReadScope(document, limits: .balanced)
    weak let state = scope.state
    let cursor = JSONReadCursor(scope: scope, selection: JSONReadPath(scope: scope, components: [], bytes: 0))
    _ = try scope.complete(try cursor["child"])
    #expect(scope.document == nil && scope.state == nil && state == nil)
    #expect(throws: JSONFailure.self) { try cursor.requiredObject() }
}

@Test func readAccessPathCopiesReleaseLiveRetentionAndFailCompletePaths() throws {
    let value = try JSONParser().parse(#"{"child":{"name":"value"}}"#)
    func attempt(_ root: JSONReadCursor) throws {
        do {
            _ = try root["child"]["name"].requiredBoolean()
            Issue.record("Expected ordinary kind failure")
        } catch let error as JSONAccessFailure { #expect(error.path == [.key("child"), .key("name")]) }
    }
    let one = try value.readWithReport { root in try attempt(root) }
    var limits = JSONLimits.balanced; limits[.retainedBytes] = one.statistics.peakLogicalRetainedBytes
    let repeated = try value.readWithReport(limits: limits) { root in
        for _ in 0..<100 { try attempt(root) }
    }
    #expect(repeated.statistics.peakLogicalRetainedBytes == one.statistics.peakLogicalRetainedBytes)
    #expect(repeated.statistics[.retainedBytes] == 0)
    #expect(repeated.statistics[.workUnits] > one.statistics[.workUnits])
    let oneText = try value.readWithReport { try $0["child"]["name"].requiredString() }
    limits = .balanced; limits[.retainedBytes] = oneText.statistics.peakLogicalRetainedBytes
    let repeatedText = try value.readWithReport(limits: limits) { root in
        for _ in 0..<100 { _ = try root["child"]["name"].requiredString() }
    }
    #expect(repeatedText.statistics[.retainedBytes] == 0)
    #expect(repeatedText.statistics.peakLogicalRetainedBytes == oneText.statistics.peakLogicalRetainedBytes)
    limits = .balanced; limits[.pointerBytes] = 5
    #expect(throws: JSONFailure.self) { try value.read(limits: limits) { try $0["child"] } }
    limits = .balanced; limits[.diagnosticBytes] = 5
    #expect(throws: JSONFailure.self) { try value.read(limits: limits) { try $0["child"] } }

}

@Test func readAccessCaughtCancellationCannotCertifyCompletion() async throws {
    let task = Task.detached { () throws -> Bool in
        let value = try JSONParser().parse(#"{"name":"value"}"#)
        do {
            _ = try value.read { root in
                withUnsafeCurrentTask { $0?.cancel() }
                do { _ = try root["name"].requiredString() } catch is CancellationError {}
                return 0
            }
            return false
        } catch is CancellationError { return true }
    }
    #expect(try await task.value)
}

@Test func readAccessBridgeStrategiesAndForeignNaturalCodingRemainDistinct() throws {
    let value = ReadModel(count: .max, name: "sensor", bytes: Data([1, 2, 255]))
    for strategy in [JSONCodingOptions.DataStrategy.base64, .deferredToData] {
        let coding = JSONCodingOptions(dataStrategy: strategy)
        let encoded = try JSON(encoding: value, coding: coding)
        #expect(try encoded == JSONValueEncoder(options: coding).encode(value))
        #expect(try encoded.decode(ReadModel.self, coding: coding) == value)
    }
    for strategy in [JSONCodingOptions.DateStrategy.deferredToDate, .secondsSince1970, .iso8601] {
        let coding = JSONCodingOptions(dateStrategy: strategy)
        let date = Date(timeIntervalSince1970: 1_600_000_000.25)
        let encoded = try JSON(encoding: date, coding: coding)
        let decoded = try encoded.decode(Date.self, coding: coding)
        let reference = try JSONValueDecoder(options: coding).decode(Date.self, from: encoded)
        #expect(decoded == reference)
        #expect(decoded == date)
    }
    for text in ["-9223372036854775808", "18446744073709551615", "0.1"] {
        let number = try JSONNumber(parsing: text)
        let bytes = try Foundation.JSONEncoder().encode(number)
        #expect(try Foundation.JSONDecoder().decode(JSONNumber.self, from: bytes) == number)
    }
    let huge = try JSONNumber(parsing: "1e100000")
    #expect(throws: EncodingError.self) { try Foundation.JSONEncoder().encode(huge) }
}
