// SPDX-License-Identifier: Apache-2.0
import Testing
@testable import JSON

private struct WideFields: Encodable {
    let keys: [String]
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: JSONCodingKey.self)
        for (position, key) in keys.enumerated() { try container.encode(position, forKey: JSONCodingKey(key)) }
        // Replacing keeps the first key at its insertion position.
        try container.encode(0, forKey: JSONCodingKey(keys[0]))
    }
}

@Test func indexedPublicationCoversBuildersParserNativeCodingAndEditing() throws {
    let keys = (0..<129).map { "field-\($0)" } + ["\u{e9}", "e\u{301}", "", "/", "~"]
    let members = keys.enumerated().map { JSONMember($0.element, value: .number(JSONNumber(integer: $0.offset))) }
    let checked = try JSONObject(members: members)
    let built = try JSONObject.build { builder in
        for member in members { try builder.append(member.key.string, value: member.value) }
    }
    let parsed = try JSONParser().parse(JSONWriter().write(.object(checked))).objectValue!
    let coded = try JSONValueEncoder().encode(WideFields(keys: keys)).objectValue!
    let edited = try checked.setting(.boolean(true), for: "replacement").removing("replacement")
    for object in [checked, built, parsed, coded, edited] {
        #expect(object.members.map(\.key) == checked.members.map(\.key))
        for member in members {
            #expect(object[member.key] == member.value)
            #expect(try JSON.object(object).requiredMember(member.key.string) == member.value)
        }
        #expect(object["absent"] == nil)
    }
}

@Test func controlledIndexCollisionsAndRefusedRehashPreservePriorMetadata() throws {
    var index = JSONExactKeyIndex(fingerprintMask: 0)
    var meter = try JSONWorkMeter(limits: .offline, domain: .core)
    for position in 0..<257 {
        #expect(try index.insert(JSONKey("collision-\(position)"), position: position, meter: &meter))
    }
    for position in 0..<257 { #expect(try index.find(JSONKey("collision-\(position)"), meter: &meter) == position) }
    #expect(try !index.insert(JSONKey("collision-1"), position: 999, meter: &meter))
    #expect(try index.find(JSONKey("absent"), meter: &meter) == nil)
    var bounded = JSONExactKeyIndex()
    var limits = JSONLimits.balanced; limits[.retainedBytes] = 32 * 48
    var limited = try JSONWorkMeter(limits: limits, domain: .core)
    for position in 0..<31 { #expect(try bounded.insert(JSONKey("key-\(position)"), position: position, meter: &limited)) }
    #expect(throws: JSONFailure.self) { try bounded.insert(JSONKey("key-31"), position: 31, meter: &limited) }
    for position in 0..<31 { #expect(bounded.find(JSONKey("key-\(position)")) == position) }
    #expect(bounded.find(JSONKey("key-31")) == nil)
}

@Test func indexedDuplicateRecognitionRetainsSecondKeyLocationAndNonthrowingFinish() throws {
    let fields = (0..<64).map { "\"k\($0)\":null" }.joined(separator: ",")
    let prefix = "{" + fields + ","
    // The value/colon after the duplicate is malformed; duplicate still wins.
    let malformed = prefix + "\"k0\" ???"
    do {
        _ = try JSONParser().parse(malformed)
        Issue.record("Duplicate was not recognized")
    } catch let error as JSONFailure {
        #expect(error.code == .duplicateKey)
        #expect(error.location?.byteOffset == UInt64(prefix.utf8.count))
    }
    var builder = try JSONObjectAccumulator()
    for position in 0..<64 { try builder.append("k\(position)", value: .null) }
    #expect(throws: JSONFailure.self) { try builder.append("k0", value: .boolean(true)) }
    let completed = builder.finish()
    #expect(completed.count == 64)
    #expect(completed["k0"] == .null)
}

@Test func indexedGrowthAndCollisionScansCheckCancellation() async throws {
    let task = Task.detached { () throws -> Bool in
        var meter = try JSONWorkMeter(limits: .offline, domain: .core)
        var index = JSONExactKeyIndex(fingerprintMask: 0)
        for position in 0..<64 { _ = try index.insert(JSONKey("key-\(position)"), position: position, meter: &meter) }
        let starting = meter.statistics()[.workUnits]
        meter.checkpointObserver = { work in
            if work > starting { withUnsafeCurrentTask { $0?.cancel() } }
        }
        do {
            for position in 64..<1000 { _ = try index.insert(JSONKey("key-\(position)"), position: position, meter: &meter) }
            return false
        } catch is CancellationError {
            // Prior keys remain valid after an interrupted owned search/growth.
            return index.find(JSONKey("key-0")) == 0 && index.find(JSONKey("key-63")) == 63
        }
    }
    #expect(try await task.value)
}

@Test func immutableIndexedObjectCanBeSharedAcrossTasks() async throws {
    let members = (0..<256).map { JSONMember("key-\($0)", value: .number(JSONNumber(integer: $0))) }
    let value = JSON.object(try JSONObject(members: members))
    try await withThrowingTaskGroup(of: Void.self) { group in
        for position in 0..<32 {
            group.addTask {
                for _ in 0..<10 {
                    let selected = try value.requiredMember("key-\(position * 7)"); #expect(selected == .number(JSONNumber(integer: position * 7)))
                }
            }
        }
        try await group.waitForAll()
    }
}
