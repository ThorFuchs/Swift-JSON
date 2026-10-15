// SPDX-License-Identifier: Apache-2.0
import Foundation
import Testing
import JSON

private enum E2Outcome<T: Equatable>: Equatable {
    case value(T), failure(JSONFailure), cancelled
}
private func outcome<T: Equatable>(_ body: () throws -> T) throws -> E2Outcome<T> {
    do { return .value(try body()) }
    catch let error as JSONFailure { return .failure(error) }
    catch is CancellationError { return .cancelled }
}

@Test func e2ParseDelegatesEveryInputKindAndPreservesLexemes() throws {
    for text in [#"{"n":9007199254740993,"é":1,"e\u0301":2,"z":-0.00e2}"#, "[null,true,1.0,1e0]", " \n42\t"] {
        let parser = JSONParser()
        let a = try JSON.parse(text), b = try parser.parse(text)
        #expect(a == b)
        #expect(try JSON.parse(Data(text.utf8)) == parser.parse(Data(text.utf8)))
        #expect(try JSON.parse(Array(text.utf8)) == parser.parse(Array(text.utf8)))
        let writer = JSONWriter(options: .init(numberStyle: .preserved))
        #expect(try writer.write(a) == writer.write(b))
    }
}

@Test func e2ParseFailuresKeepLocationsAndInputKindAccounting() throws {
    let vectors: [[UInt8]] = [[], [0x22, 0xff, 0x22], Array("[1,]".utf8), Array("true false".utf8), Array(#"{"a":1,"\u0061":2}"#.utf8), [0xef,0xbb,0xbf,0x30]]
    for bytes in vectors {
        #expect(try outcome { try JSON.parse(bytes) } == outcome { try JSONParser().parse(bytes) })
        #expect(try outcome { try JSON.parse(Data(bytes)) } == outcome { try JSONParser().parse(Data(bytes)) })
    }
    for text in ["", "1 2", #"{"a":0,"a":1}"#, #""\uD800""#] {
        #expect(try outcome { try JSON.parse(text) } == outcome { try JSONParser().parse(text) })
    }
}

@Test func e2ParseInclusiveQuotasMatchEachDelegate() throws {
    let text = #"{"n":1}"#, bytes = Array(text.utf8), data = Data(text.utf8)
    for metric in [JSONResourceMetric.inputBytes, .workUnits, .retainedBytes, .nodes, .keyBytes] {
        for cap in 0...160 {
            var limits = JSONLimits.balanced; limits[metric] = UInt64(cap)
            let options = JSONParsingOptions(limits: limits), parser = JSONParser(options: options)
            #expect(try outcome { try JSON.parse(text, options: options) } == outcome { try parser.parse(text) })
            #expect(try outcome { try JSON.parse(data, options: options) } == outcome { try parser.parse(data) })
            #expect(try outcome { try JSON.parse(bytes, options: options) } == outcome { try parser.parse(bytes) })
        }
    }
    var limits = JSONLimits.balanced; limits[.inputBytes] = UInt64(bytes.count)
    #expect(try JSON.parse(bytes, options: .init(limits: limits)) == JSONParser().parse(bytes))
    limits[.inputBytes] -= 1
    #expect(throws: JSONFailure.self) { try JSON.parse(bytes, options: .init(limits: limits)) }
}

@Test func e2ObjectBuilderUsesExistingOrderAndDuplicateRules() throws {
    let body: (inout JSONObjectAccumulator) throws -> Void = {
        try $0.append("é", value: 1); try $0.append("e\u{301}", value: 2); try $0.append("null", value: .null)
    }
    let a = try JSON.buildObject(body), b = JSON.object(try JSONObject.build(body))
    #expect(a == b)
    #expect(try JSONWriter().write(a) == JSONWriter().write(b))
    let duplicate: (inout JSONObjectAccumulator) throws -> Void = {
        try $0.append("a", value: 1); try $0.append("a", value: 2)
    }
    #expect(try outcome { try JSON.buildObject(duplicate) } == outcome { .object(try JSONObject.build(duplicate)) })
}

@Test func e2ObjectBuilderQuotasRemainCumulative() throws {
    let body: (inout JSONObjectAccumulator) throws -> Void = { try $0.append("a", value: 1); try $0.append("b", value: 2) }
    for cap in 0...180 {
        var limits = JSONLimits.balanced; limits[.workUnits] = UInt64(cap)
        #expect(try outcome { try JSON.buildObject(limits: limits, body) } == outcome { .object(try JSONObject.build(limits: limits, body)) })
    }
    var limits = JSONLimits.balanced; limits[.objectMembers] = 1
    #expect(throws: JSONFailure.self) { try JSON.buildObject(limits: limits, body) }
}

@Test func e2NumberTextPreservesExactIdentityAndFailures() throws {
    for text in ["1", "1.0", "1e0", "-0.0", "9007199254740993", "0.1", "1e1000000", "", "01", "1e", "NaN"] {
        #expect(try outcome { try JSON.number(parsing: text) } == outcome { .number(try JSONNumber(parsing: text)) })
        if let number = try? JSONNumber(parsing: text) {
            #expect(try JSON.number(parsing: text).numberValue?.originalLexeme == number.originalLexeme)
        }
    }
    for cap in 0...80 {
        var limits = JSONLimits.balanced; limits[.numericWorkUnits] = UInt64(cap)
        #expect(try outcome { try JSON.number(parsing: "123.00", limits: limits) } == outcome { .number(try JSONNumber(parsing: "123.00", limits: limits)) })
    }
}

@Test func e2PointerRootOrientationRetainsStrictTraversal() throws {
    let value = try JSON.parse(#"{"a/b":{"~":[null,7]},"":9}"#)
    for path in ["", "/", "/a~1b/~0/1", "/a~1b/~0/0", "/missing", "/a~1b/~0/01", "/a~1b/~0/-", "/a~1b/~0/1/x"] {
        let pointer = try JSONPointer(parsing: path)
        #expect(try outcome { try value.value(at: pointer) } == outcome { try pointer.resolve(in: value) })
        for cap in 0...100 {
            var limits = JSONLimits.balanced; limits[.workUnits] = UInt64(cap)
            #expect(try outcome { try value.value(at: pointer, limits: limits) } == outcome { try pointer.resolve(in: value, limits: limits) })
        }
    }
}

@Test func e2ContainsKeySeparatesNullMissingAndScalarSpellings() throws {
    let object = try JSONObject(members: [JSONMember("é", value: .null), JSONMember("e\u{301}", value: 2)])
    #expect(object.containsKey("é")); #expect(object.containsKey("e\u{301}")); #expect(!object.containsKey("missing"))
    let dynamic = "é"
    #expect(object.containsKey(JSONKey(dynamic)) == (object[dynamic] != nil))
    let changed = try object.setting(3, for: "é").removing("e\u{301}").setting(4, for: "e\u{301}")
    #expect(changed.members.map(\.key) == object.members.map(\.key))
    #expect(throws: JSONFailure(.typeMismatch, code: .wrongKind)) { try JSON.boolean(false).presence(of: "é") }
}

@Test func e2PresenceMapAndFoldSelectExactlyOneBranch() throws {
    for state in [JSONPresence<Int>.absent, .null, .value(3)] {
        var calls = 0
        let mapped = state.map { calls += 1; return String($0) }
        var branches: [String] = []
        let result = mapped.fold(absent: { branches.append("absent"); return "missing" }, null: { branches.append("null"); return "null" }, value: { branches.append("value"); return $0 })
        switch state {
        case .absent: #expect(calls == 0 && mapped == .absent && result == "missing" && branches == ["absent"])
        case .null: #expect(calls == 0 && mapped == .null && result == "null" && branches == ["null"])
        case .value: #expect(calls == 1 && mapped == .value("3") && result == "3" && branches == ["value"])
        }
        let set: Set<JSONPresence<Int>> = [state]
        #expect(set.contains(state))
    }
}

private enum E2CallbackError: Error, Equatable { case sentinel }
@Test func e2CallerErrorsPropagateWithoutFallback() {
    #expect(throws: E2CallbackError.sentinel) { try JSON.buildObject { _ in throw E2CallbackError.sentinel } }
    #expect(throws: E2CallbackError.sentinel) { try JSONPresence.value(1).map { _ -> Int in throw E2CallbackError.sentinel } }
    for state in [JSONPresence<Int>.absent, .null, .value(1)] {
        #expect(throws: E2CallbackError.sentinel) {
            try state.fold(absent: { throw E2CallbackError.sentinel }, null: { throw E2CallbackError.sentinel }, value: { _ in throw E2CallbackError.sentinel }) as Int
        }
    }
}

@Test func e2OldLiteralAndFactoryCallsitesKeepTheirTypes() throws {
    let a: JSON = .number(42), b = JSON.number(JSONNumber(integer: 42))
    let factory: (JSONNumber) -> JSON = JSON.number
    #expect(a == b && factory(42) == a)
    #expect([JSONNumber(integer: 42)].map(JSON.number) == [a])
    if case .number(let n) = a { #expect(n == 42) } else { Issue.record("Enum pattern changed") }
    struct Model: Codable, Equatable { let n: Int }
    #expect(try JSON(encoding: Model(n: 42)).decode(Model.self) == Model(n: 42))
}

@Test func e2CancellationPropagatesThroughCoreFacades() async throws {
    let pointer = try JSONPointer(parsing: "")
    let cancelled = await Task {
        withUnsafeCurrentTask { $0?.cancel() }
        let operations: [() throws -> JSON] = [
            { try JSON.parse("0") }, { try JSON.parse(Data([48])) }, { try JSON.parse([48]) },
            { try JSON.number(parsing: "0") }, { try JSON.buildObject { _ in } }, { try JSON.null.value(at: pointer) }
        ]
        for operation in operations { #expect(throws: CancellationError.self, performing: operation) }
        return true
    }.value
    #expect(cancelled)
    let during = await Task {
        do {
            _ = try JSON.buildObject { object in
                try object.append("before", value: 1)
                withUnsafeCurrentTask { $0?.cancel() }
                try object.append("after", value: 2)
            }
            return false
        } catch is CancellationError { return true } catch { return false }
    }.value
    #expect(during)
}
