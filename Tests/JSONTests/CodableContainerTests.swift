// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private enum Field: String, CodingKey { case object, array, value, named, superValue = "super", missing, a, b }
private enum ProbeError: Error, Equatable { case expectedFailure, caller }

private func capture(_ body: () throws -> Void) -> any Error {
    do { try body(); Issue.record("Expected operation to fail"); return ProbeError.expectedFailure }
    catch { return error }
}
private func path(_ context: DecodingError.Context, _ names: [String], _ indices: [Int?]) {
    #expect(context.codingPath.map(\.stringValue) == names)
    #expect(context.codingPath.map(\.intValue) == indices)
}
private func resource(_ error: any Error, metric: JSONResourceMetric, limit: UInt64,
                      attempted: UInt64, domain: JSONOperationDomain = .coding) throws {
    let failure = try #require(error as? JSONFailure)
    #expect(failure.category == .resource && failure.code == .limitExceeded)
    #expect(failure.location == nil)
    let violation = try #require(failure.resource)
    #expect(violation.domain == domain && violation.metric == metric)
    #expect(violation.limit == limit && violation.attemptedUsage == attempted && !violation.overflow)
}
private func wrongKind(_ error: any Error, names: [String], indices: [Int?]) {
    guard case DecodingError.typeMismatch(_, let context) = error else {
        Issue.record("Expected typeMismatch, received \(type(of: error))"); return
    }
    path(context, names, indices)
    #expect(context.underlyingError as? JSONFailure == JSONFailure(.typeMismatch, code: .wrongKind))
}

private struct KeyedTree: Codable, Equatable {
    let number: Int
    let text: String
    init() { number = 7; text = "e\u{301}" }
    func encode(to encoder: any Encoder) throws {
        var root = encoder.container(keyedBy: Field.self)
        var object = root.nestedContainer(keyedBy: Field.self, forKey: .object)
        #expect(object.codingPath.map(\.stringValue) == ["object"])
        try object.encode(number, forKey: .value)
        var array = root.nestedUnkeyedContainer(forKey: .array)
        #expect(array.codingPath.map(\.stringValue) == ["array"])
        try array.encodeNil(); try array.encode(text)
        let named = root.superEncoder(forKey: .named)
        #expect(named.codingPath.map(\.stringValue) == ["named"])
        var namedValue = named.singleValueContainer(); try namedValue.encode(true)
        let inherited = root.superEncoder()
        #expect(inherited.codingPath.map(\.stringValue) == ["super"])
        var inheritedValue = inherited.singleValueContainer(); try inheritedValue.encode(2)
    }
    init(from decoder: any Decoder) throws {
        let root = try decoder.container(keyedBy: Field.self)
        let object = try root.nestedContainer(keyedBy: Field.self, forKey: .object)
        #expect(object.codingPath.map(\.stringValue) == ["object"])
        number = try object.decode(Int.self, forKey: .value)
        var array = try root.nestedUnkeyedContainer(forKey: .array)
        #expect(array.codingPath.map(\.stringValue) == ["array"])
        #expect(try array.decodeNil()); text = try array.decode(String.self)
        #expect(array.isAtEnd && array.currentIndex == 2 && array.count == 2)
        let named = try root.superDecoder(forKey: .named)
        #expect(named.codingPath.map(\.stringValue) == ["named"])
        #expect(try named.singleValueContainer().decode(Bool.self))
        let inherited = try root.superDecoder()
        #expect(inherited.codingPath.map(\.stringValue) == ["super"])
        #expect(try inherited.singleValueContainer().decode(Int.self) == 2)
    }
}

@Test func qaCodableKeyedNestedAndNamedSuperContainersMatchGolden() throws {
    let golden = try JSONParser().parse(#"{"object":{"value":7},"array":[null,"é"],"named":true,"super":2}"#)
    let encoded = try JSONValueEncoder().encode(KeyedTree())
    #expect(encoded == golden)
    #expect(encoded.objectValue?.map { $0.key.string } == ["object", "array", "named", "super"])
    #expect(try JSONValueDecoder().decode(KeyedTree.self, from: golden) == KeyedTree())
}

private struct UnkeyedTree: Codable {
    init() {}
    func encode(to encoder: any Encoder) throws {
        var root = encoder.unkeyedContainer()
        #expect(root.count == 0)
        try root.encodeNil()
        var object = root.nestedContainer(keyedBy: Field.self)
        #expect(object.codingPath.map(\.stringValue) == ["1"])
        #expect(object.codingPath.map(\.intValue) == [1])
        try object.encode(7, forKey: .value)
        var array = root.nestedUnkeyedContainer(); try array.encode(true)
        let inherited = root.superEncoder()
        #expect(inherited.codingPath.map(\.intValue) == [3])
        var value = inherited.singleValueContainer(); try value.encode("base")
        #expect(root.count == 4)
    }
    init(from decoder: any Decoder) throws {
        var root = try decoder.unkeyedContainer()
        #expect(root.count == 4 && root.currentIndex == 0 && !root.isAtEnd)
        #expect(try root.decodeNil())
        let object = try root.nestedContainer(keyedBy: Field.self)
        #expect(object.codingPath.map(\.intValue) == [1])
        #expect(try object.decode(Int.self, forKey: .value) == 7)
        var array = try root.nestedUnkeyedContainer()
        #expect(array.codingPath.map(\.intValue) == [2])
        #expect(try array.decode(Bool.self) && array.isAtEnd)
        let inherited = try root.superDecoder()
        #expect(inherited.codingPath.map(\.intValue) == [3])
        #expect(try inherited.singleValueContainer().decode(String.self) == "base")
        #expect(root.isAtEnd && root.currentIndex == 4)
    }
}
@Test func qaCodableUnkeyedNestedAndSuperContainersMatchGolden() throws {
    let golden = try JSONParser().parse(#"[null,{"value":7},[true],"base"]"#)
    #expect(try JSONValueEncoder().encode(UnkeyedTree()) == golden)
    _ = try JSONValueDecoder().decode(UnkeyedTree.self, from: golden)
}

private struct EmptyContainers: Encodable {
    let mode: Int
    func encode(to encoder: any Encoder) throws {
        switch mode {
        case 0: _ = encoder.container(keyedBy: Field.self)
        case 1: _ = encoder.unkeyedContainer()
        case 2:
            var c = encoder.container(keyedBy: Field.self)
            _ = c.nestedContainer(keyedBy: Field.self, forKey: .object)
            _ = c.nestedUnkeyedContainer(forKey: .array)
        default:
            var c = encoder.unkeyedContainer()
            _ = c.nestedContainer(keyedBy: Field.self); _ = c.nestedUnkeyedContainer()
        }
    }
}
@Test func qaCodableEmptyContainersAreValuesWithoutPlaceholderNulls() throws {
    for (mode, text) in ["{}", "[]", #"{"object":{},"array":[]}"#, "[{},[]]"].enumerated() {
        #expect(try JSONValueEncoder().encode(EmptyContainers(mode: mode)) == JSONParser().parse(text))
    }
}

private struct ReusedKeyed: Encodable {
    func encode(to encoder: any Encoder) throws {
        var first = encoder.container(keyedBy: Field.self)
        try first.encode(1, forKey: .a); try first.encode(2, forKey: .b)
        var again = encoder.container(keyedBy: Field.self)
        try again.encode(3, forKey: .a)
        #expect(first.codingPath.isEmpty && again.codingPath.isEmpty)
    }
}
@Test func qaCodableReusedKeyedContainerReplacesWithoutReordering() throws {
    let value = try JSONValueEncoder().encode(ReusedKeyed())
    #expect(try JSONWriter().writeString(value) == #"{"a":3,"b":2}"#)
}

private struct SingleBox<T: Codable>: Codable {
    let value: T
    init(_ value: T) { self.value = value }
    func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(value) }
    init(from decoder: any Decoder) throws { value = try decoder.singleValueContainer().decode(T.self) }
}
private func primitive<T: Codable & Equatable>(_ value: T, _ golden: String) throws {
    let expected = try JSONParser().parse(golden)
    #expect(try JSONValueEncoder().encode(SingleBox(value)) == expected)
    #expect(try JSONValueDecoder().decode(SingleBox<T>.self, from: expected).value == value)
}
@Test func qaCodableSingleValuePrimitiveOverloadsHaveIndependentExpectedValues() throws {
    try primitive(true, "true"); try primitive("e\u{301}", #""é""#)
    try primitive(Double(1.5), "1.5"); try primitive(Float(0.5), "0.5")
    // These vectors also compile and execute on wasm32: no host-width Int.max assumption.
    try primitive(Int(-123), "-123"); try primitive(Int8.min, "-128")
    try primitive(Int16.min, "-32768"); try primitive(Int32.min, "-2147483648")
    try primitive(Int64.min, "-9223372036854775808")
    try primitive(UInt(123), "123"); try primitive(UInt8.max, "255")
    try primitive(UInt16.max, "65535"); try primitive(UInt32.max, "4294967295")
    try primitive(UInt64.max, "18446744073709551615")
}
private struct NilSingle: Codable {
    init() {}
    func encode(to encoder: any Encoder) throws { var c = encoder.singleValueContainer(); try c.encodeNil() }
    init(from decoder: any Decoder) throws { #expect(try decoder.singleValueContainer().decodeNil()) }
}
@Test func qaCodableSingleNilAndExactGenericPayloadPreserveKinds() throws {
    #expect(try JSONValueEncoder().encode(NilSingle()) == .null)
    _ = try JSONValueDecoder().decode(NilSingle.self, from: .null)
    for text in ["null", "false", #""x""#, "9007199254740993", "[1]", #"{"é":1,"é":2}"#] {
        let value = try JSONParser().parse(text)
        #expect(try JSONValueEncoder().encode(SingleBox(value)) == value)
        #expect(try JSONValueDecoder().decode(SingleBox<JSON>.self, from: value).value == value)
    }
}

private struct CursorRecovery: Decodable {
    init(from decoder: any Decoder) throws {
        var c = try decoder.unkeyedContainer()
        #expect(try c.decodeNil() && c.currentIndex == 1)
        #expect(try !c.decodeNil() && c.currentIndex == 1)
        wrongKind(capture { _ = try c.decode(Int.self) }, names: ["1"], indices: [1])
        #expect(c.currentIndex == 1)
        #expect(try c.decode(String.self) == "text" && c.currentIndex == 2)
        #expect(try c.decode(Int.self) == 7 && c.currentIndex == 3 && c.isAtEnd)
        let error = capture { _ = try c.decodeNil() }
        guard case DecodingError.valueNotFound(_, let context) = error else { Issue.record("Expected exhausted container"); return }
        path(context, [], []); #expect(context.underlyingError == nil)
        #expect(c.currentIndex == 3)
    }
}
@Test func qaCodableUnkeyedNilIndexAndOrdinaryErrorsRemainRecoverable() throws {
    _ = try JSONValueDecoder().decode(CursorRecovery.self, from: JSONParser().parse(#"[null,"text",7]"#))
}

private struct NestedInteger: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Field.self)
        let object = try c.nestedContainer(keyedBy: Field.self, forKey: .object)
        var array = try object.nestedUnkeyedContainer(forKey: .array)
        let item = try array.nestedContainer(keyedBy: Field.self)
        _ = try item.decode(Int8.self, forKey: .value)
    }
}
@Test func qaCodableNestedWrongKindHasCompleteTypedCodingPath() throws {
    let value = try JSONParser().parse(#"{"object":{"array":[{"value":"bad"}]}}"#)
    wrongKind(capture { _ = try JSONValueDecoder().decode(NestedInteger.self, from: value) },
              names: ["object", "array", "0", "value"], indices: [nil, nil, 0, nil])
}
@Test func qaCodableNestedMissingKeyHasParentPathAndExactMissingKey() throws {
    let value = try JSONParser().parse(#"{"object":{"array":[{}]}}"#)
    let error = capture { _ = try JSONValueDecoder().decode(NestedInteger.self, from: value) }
    guard case DecodingError.keyNotFound(let key, let context) = error else { Issue.record("Expected keyNotFound"); return }
    #expect(key.stringValue == "value" && key.intValue == nil)
    path(context, ["object", "array", "0"], [nil, nil, 0]); #expect(context.underlyingError == nil)
}
@Test func qaCodableNestedInexactIntegerHasConversionCauseAndFullPath() throws {
    for token in ["128", "-129", "1.5"] {
        let value = try JSONParser().parse("{\"object\":{\"array\":[{\"value\":\(token)}]}}")
        let error = capture { _ = try JSONValueDecoder().decode(NestedInteger.self, from: value) }
        guard case DecodingError.dataCorrupted(let context) = error else { Issue.record("Expected dataCorrupted"); continue }
        path(context, ["object", "array", "0", "value"], [nil, nil, 0, nil])
        #expect(context.underlyingError as? JSONFailure == JSONFailure(.conversion, code: .inexactConversion))
    }
}
@Test func qaCodableNestedContainerWrongKindIdentifiesItsBoundary() throws {
    for (text, names, indices): (String, [String], [Int?]) in [
        (#"{"object":[]}"#, ["object"], [nil]),
        (#"{"object":{"array":{}}}"#, ["object", "array"], [nil, nil]),
        (#"{"object":{"array":[false]}}"#, ["object", "array", "0"], [nil, nil, 0])
    ] {
        let value = try JSONParser().parse(text)
        wrongKind(capture { _ = try JSONValueDecoder().decode(NestedInteger.self, from: value) }, names: names, indices: indices)
    }
}

private struct KeyEnumeration: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Field.self)
        #expect(c.allKeys.map(\.stringValue) == ["value"])
        #expect(c.contains(.value) && !c.contains(.missing))
        #expect(try c.decodeNil(forKey: .value))
        let error = capture { _ = try c.decodeNil(forKey: .missing) }
        guard case DecodingError.keyNotFound(let key, let context) = error else { Issue.record("Expected missing key"); return }
        #expect(key.stringValue == "missing"); path(context, [], [])
    }
}
@Test func qaCodableKeyEnumerationUnknownKeysAndNullPresenceAreDistinct() throws {
    _ = try JSONValueDecoder().decode(KeyEnumeration.self, from: JSONParser().parse(#"{"ignored":1,"value":null}"#))
}

private struct FailingKeyedChild: Encodable {
    let mode: Int
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Field.self); try c.encode(1, forKey: .a)
        switch mode {
        case 0: _ = c.nestedContainer(keyedBy: Field.self, forKey: .b)
        case 1: _ = c.nestedUnkeyedContainer(forKey: .b)
        case 2: _ = c.superEncoder(forKey: .b)
        default: _ = c.superEncoder()
        }
        try resource(capture { try c.encode(3, forKey: .a) }, metric: .objectMembers, limit: 1, attempted: 2)
        // Caller deliberately catches the refusal. The invocation must still fail.
    }
}
@Test func qaCodableAllNonthrowingKeyedChildRequestsLatchTheFirstFailure() throws {
    var limits = JSONLimits.balanced; limits[.objectMembers] = 1
    for mode in 0..<4 {
        try resource(capture { _ = try JSONValueEncoder(options: .init(limits: limits)).encode(FailingKeyedChild(mode: mode)) },
                     metric: .objectMembers, limit: 1, attempted: 2)
    }
}
private struct FailingUnkeyedChild: Encodable {
    let mode: Int
    func encode(to encoder: any Encoder) throws {
        var c = encoder.unkeyedContainer(); try c.encode(1)
        switch mode {
        case 0: _ = c.nestedContainer(keyedBy: Field.self)
        case 1: _ = c.nestedUnkeyedContainer()
        default: _ = c.superEncoder()
        }
        try resource(capture { try c.encode(2) }, metric: .arrayItems, limit: 1, attempted: 2)
    }
}
@Test func qaCodableAllNonthrowingUnkeyedChildRequestsLatchTheFirstFailure() throws {
    var limits = JSONLimits.balanced; limits[.arrayItems] = 1
    for mode in 0..<3 {
        try resource(capture { _ = try JSONValueEncoder(options: .init(limits: limits)).encode(FailingUnkeyedChild(mode: mode)) },
                     metric: .arrayItems, limit: 1, attempted: 2)
    }
}

private struct IgnoreValue: Decodable { init(from decoder: any Decoder) throws {} }
private struct ContainsFailure: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Field.self)
        #expect(!c.contains(.value))
        let first = try #require(capture { _ = try c.decode(Int.self, forKey: .value) } as? JSONFailure)
        #expect(first.resource?.metric == .workUnits)
        #expect(!c.contains(.missing))
        #expect(capture { _ = try c.decodeNil(forKey: .value) } as? JSONFailure == first)
    }
}
private struct AllKeysFailure: Decodable {
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: Field.self)
        #expect(c.allKeys.isEmpty)
        let first = try #require(capture { _ = try c.decode(Int.self, forKey: .value) } as? JSONFailure)
        #expect(first.resource?.metric == .workUnits)
        #expect(c.allKeys.isEmpty)
        #expect(capture { _ = try c.superDecoder() } as? JSONFailure == first)
    }
}
@Test func qaCodableContainsCannotTurnExhaustionIntoAbsenceOrSuccess() throws {
    let value = try JSONParser().parse(#"{"value":7}"#)
    let admitted = try JSONValueDecoder().decodeWithReport(IgnoreValue.self, from: value).statistics[.workUnits]
    var limits = JSONLimits.balanced; limits[.workUnits] = admitted
    try resource(capture { _ = try JSONValueDecoder(options: .init(limits: limits)).decode(ContainsFailure.self, from: value) },
                 metric: .workUnits, limit: admitted, attempted: admitted + 1)
}
@Test func qaCodableAllKeysCannotTurnExhaustionIntoAnEmptySuccessfulModel() throws {
    let value = try JSONParser().parse(#"{"value":7}"#)
    let admitted = try JSONValueDecoder().decodeWithReport(IgnoreValue.self, from: value).statistics[.workUnits]
    var limits = JSONLimits.balanced; limits[.workUnits] = admitted
    try resource(capture { _ = try JSONValueDecoder(options: .init(limits: limits)).decode(AllKeysFailure.self, from: value) },
                 metric: .workUnits, limit: admitted, attempted: admitted + 1)
}

private struct ConflictContainers: Encodable {
    let startsKeyed: Bool
    func encode(to encoder: any Encoder) throws {
        if startsKeyed { _ = encoder.container(keyedBy: Field.self); _ = encoder.unkeyedContainer() }
        else { _ = encoder.unkeyedContainer(); _ = encoder.container(keyedBy: Field.self) }
    }
}
@Test func qaCodableConflictingNonthrowingRootContainersDoNotReturnAValue() throws {
    for keyed in [true, false] {
        let error = capture { _ = try JSONValueEncoder().encode(ConflictContainers(startsKeyed: keyed)) }
        guard case EncodingError.invalidValue(_, let context) = error else { Issue.record("Expected conflicting-container invalidValue"); continue }
        #expect(context.codingPath.isEmpty && context.underlyingError == nil)
    }
}
private struct NoEncodedValue: Encodable { func encode(to encoder: any Encoder) throws {} }
@Test func qaCodableUnsetRootReportsAnEncodingFailure() throws {
    let error = capture { _ = try JSONValueEncoder().encode(NoEncodedValue()) }
    guard case EncodingError.invalidValue(let value, let context) = error else { Issue.record("Expected unset invalidValue"); return }
    #expect(value as? String == "unset" && context.codingPath.isEmpty)
}

@Test func qaCodableNestedEncodingSharesOneInclusiveWorkLedger() throws {
    let baseline = try JSONValueEncoder().encodeWithReport(KeyedTree())
    let used = baseline.statistics[.workUnits]
    #expect(used > 0 && baseline.statistics.domain == .coding && baseline.statistics.accountingVersion == 1)
    var limits = JSONLimits.balanced; limits[.workUnits] = used
    let bounded = try JSONValueEncoder(options: .init(limits: limits)).encodeWithReport(KeyedTree())
    #expect(bounded.result == baseline.result && bounded.statistics[.workUnits] == used)
    limits[.workUnits] = used - 1
    try resource(capture { _ = try JSONValueEncoder(options: .init(limits: limits)).encode(KeyedTree()) },
                 metric: .workUnits, limit: used - 1, attempted: used)
}
@Test func qaCodableNestedDecodingSharesOneInclusiveWorkLedger() throws {
    let golden = try JSONParser().parse(#"{"object":{"value":7},"array":[null,"é"],"named":true,"super":2}"#)
    let baseline = try JSONValueDecoder().decodeWithReport(KeyedTree.self, from: golden)
    let used = baseline.statistics[.workUnits]
    #expect(used > 0 && baseline.statistics.domain == .coding && baseline.statistics.accountingVersion == 1)
    var limits = JSONLimits.balanced; limits[.workUnits] = used
    let bounded = try JSONValueDecoder(options: .init(limits: limits)).decodeWithReport(KeyedTree.self, from: golden)
    #expect(bounded.result == KeyedTree() && bounded.statistics[.workUnits] == used)
    limits[.workUnits] = used - 1
    try resource(capture { _ = try JSONValueDecoder(options: .init(limits: limits)).decode(KeyedTree.self, from: golden) },
                 metric: .workUnits, limit: used - 1, attempted: used)
}

private struct CancelDuringContainer: Encodable {
    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: Field.self)
        withUnsafeCurrentTask { $0?.cancel() }
        _ = c.nestedUnkeyedContainer(forKey: .array)
        #expect(capture { try c.encode(1, forKey: .value) } is CancellationError)
    }
}
@Test func qaCodableCaughtContainerCancellationRemainsTerminal() async {
    let task = Task { capture { _ = try JSONValueEncoder().encode(CancelDuringContainer()) } is CancellationError }
    #expect(await task.value)
}

private struct ThrowCaller: Encodable { func encode(to encoder: any Encoder) throws { throw ProbeError.caller } }
@Test func qaCodableCallerErrorRemainsDistinctFromOwnedFailures() throws {
    let error = capture { _ = try JSONValueEncoder().encode(ThrowCaller()) }
    #expect(error as? ProbeError == .caller)
    // A fresh independent invocation remains usable after caller or owned failure.
    #expect(try JSONValueEncoder().encode(SingleBox(7)) == 7)
}

@Test func qaCodableFloatRangeFailureCarriesNestedPath() throws {
    let value = try JSONParser().parse("[1e1000]")
    let error = capture { _ = try JSONValueDecoder().decode([Float].self, from: value) }
    guard case DecodingError.dataCorrupted(let context) = error else { Issue.record("Expected finite-range dataCorrupted"); return }
    path(context, ["0"], [0]); #expect(context.underlyingError == nil)
}
