// SPDX-License-Identifier: Apache-2.0
import Testing
@testable import JSON

@Test func wideLookupPreservesExactKeysOrderAndCollisionConfirmation() throws {
    let prefix = String(repeating: "p", count: 64)
    let padding = (0..<32).map { JSONMember(prefix + String($0), value: .boolean(false)) }
    let special = ["", "0", "/", "~", "a.b", "\u{e9}", "e\u{301}"]
    let members = padding + special.map { JSONMember($0, value: .string($0)) } + [JSONMember("nullable", value: .null)]
    let object = try JSONObject(members: members)
    let value = JSON.object(object)
    for key in special {
        let selected = try value.requiredMember(key)
        #expect(selected.stringValue?.utf8.elementsEqual(key.utf8) == true)
        #expect(try JSONPointer(tokens: [key]).resolve(in: value) == selected)
    }
    #expect(try value.requiredMember("nullable") == .null)
    #expect(try value.presence(of: "absent") == .absent)
    #expect(try value.presence(of: "nullable") == .null)
    #expect(object.members.map(\.key) == members.map(\.key))
    #expect(try JSONComparison.equals(value, .object(JSONObject(members: members.reversed()))))
    // Force a fingerprint hit at the production candidate comparator. Distinct
    // decoded scalar spellings must still fail full UTF-8 confirmation.
    let composed = JSONKey("\u{e9}")
    var meter = try JSONWorkMeter(limits: .balanced, domain: .core)
    #expect(try !composed.matches("e\u{301}", fingerprint: composed.fingerprint, meter: &meter))
    #expect(try composed.matches("\u{e9}", fingerprint: composed.fingerprint, meter: &meter))
}

@Test func wideLookupEnforcesInclusiveCumulativeWorkAndInnerCancellation() async throws {
    let prefix = String(repeating: "p", count: 128)
    let members = (0..<256).map { JSONMember(prefix + String($0), value: .boolean(true)) }
    let object = try JSONObject(members: members, limits: .offline)
    let key = members.last!.key.string
    let value = JSON.object(object)
    var meter = try JSONWorkMeter(limits: .offline, domain: .core)
    try JSONAdmission.text(key, key: true, meter: &meter)
    #expect(try object.lookup(key, meter: &meter) == .boolean(true))
    let inclusive = meter.statistics()[.workUnits]
    var limits = JSONLimits.offline; limits[.workUnits] = inclusive
    #expect(try value.requiredMember(key, limits: limits) == .boolean(true))
    limits[.workUnits] = inclusive - 1
    do {
        _ = try value.requiredMember(key, limits: limits)
        Issue.record("Lookup ignored its inclusive work ceiling")
    } catch let failure as JSONFailure { #expect(failure.resource?.metric == .workUnits) }
    var shared = try JSONWorkMeter(limits: limits, domain: .core)
    #expect(try object.lookup(key, meter: &shared) == .boolean(true))
    #expect(throws: JSONFailure.self) { try object.lookup(key, meter: &shared) }
    let task = Task.detached { () throws -> UInt64 in
        var meter = try JSONWorkMeter(limits: .offline, domain: .core)
        meter.checkpointObserver = { work in
            if work >= 1400 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        do {
            for _ in 0..<1000 { _ = try object.lookup(key, meter: &meter) }
            return 0
        } catch is CancellationError { return meter.statistics()[.workUnits] }
    }
    #expect(try await task.value >= 1400)
}
