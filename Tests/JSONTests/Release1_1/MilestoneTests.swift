// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
@testable import JSON

@Test func readerProbeSharesNavigationConversionAndProjectionMeter() throws {
    struct Model: Decodable { let count: UInt64 }
    let value = try JSONParser().parse(#"{"users":[{"name":"Ada","model":{"count":9007199254740993}}]}"#)
    let report = try probeReadWithReport(value) { root in
        let user = try root["users"][0]
        #expect(try user[JSONKey("name")].requiredString() == "Ada")
        let number = try user["model"]["count"].requiredInteger(as: UInt64.self)
        let before = try #require(user.scope.state).meter.statistics()[.workUnits]
        let identity = ObjectIdentifier(try #require(user.scope.state))
        let model = try user["model"].decode(Model.self)
        #expect(ObjectIdentifier(try #require(user.scope.state)) == identity)
        #expect(try #require(user.scope.state).meter.statistics()[.workUnits] > before)
        #expect(model.count == number && number == 9_007_199_254_740_993)
        return number
    }
    #expect(report.statistics.domain == .core)
    #expect(report.statistics[.numericWorkUnits] > 0)
    // Same scope that succeeds once cannot reset its meter for each repeated read.
    var limits = JSONLimits.balanced; limits[.workUnits] = report.statistics[.workUnits]
    #expect(throws: JSONFailure.self) {
        try probeReadWithReport(value, limits: limits) { root in
            for _ in 0..<10 { _ = try root["users"][0]["model"].decode(Model.self) }
        }
    }
}

@Test func readerProbeInvalidatesEscapesAndReleasesRootAndSource() throws {
    let document = try JSONParser().parseDocument(Data(#"{"name":"Ada"}"#.utf8), source: "probe.json")
    let scope = try ProbeReadScope(document, limits: .balanced)
    weak let state = scope.state
    let cursor = ProbeReadCursor(scope: scope, path: [])
    #expect(try cursor["name"].requiredString() == "Ada")
    scope.invalidate()
    #expect(scope.document == nil && scope.state == nil && state == nil)
    #expect(throws: JSONFailure.self) { try cursor["name"].requiredString() }
    let escaped = try probeReadWithReport(document.root) { try $0["name"] }.result
    #expect(escaped.scope.document == nil && escaped.scope.state == nil)
    #expect(throws: JSONFailure.self) { try escaped.requiredString() }
    var failedEscape: ProbeReadCursor?
    enum CallerError: Error { case failed }
    #expect(throws: CallerError.self) {
        try probeReadWithReport(document.root) { root in
            failedEscape = root
            throw CallerError.failed
        }
    }
    #expect(try #require(failedEscape).scope.document == nil)
}

@Test func readerProbeLatchesCaughtResourceFailures() throws {
    let value = try JSONParser().parse(#"{"name":"Ada"}"#)
    var limits = JSONLimits.balanced; limits[.pointerTokens] = 0
    #expect(throws: JSONFailure.self) {
        try probeReadWithReport(value, limits: limits) { root in
            do { _ = try root["name"] } catch let failure as JSONFailure {
                #expect(failure.resource?.metric == .pointerTokens)
            }
            return "caught"
        }
    }
    let report = try probeReadWithReport(value) { root in
        do { _ = try root["missing"] } catch let failure as ProbeAccessFailure {
            #expect(failure.path == [.key("missing")])
            #expect(failure.cause.code == .missingMember)
        }
        return try root["name"].requiredString()
    }
    #expect(report.result == "Ada")
}

private final class ProbeCancellationProgress: Sendable {
    let ready = Mutex(false)
    let resume = DispatchSemaphore(value: 0)
    func checkpoint(_ work: UInt64) {
        guard work > 0 else { return }
        let stop = ready.withLock { flag in if flag { return false }; flag = true; return true }
        if stop { resume.wait() }
    }
}

@Test func readerProbeLatchesCaughtInnerCancellation() async throws {
    let value = try JSONParser().parse(#"{"name":"Ada"}"#)
    let progress = ProbeCancellationProgress()
    let task = Task.detached { () throws -> Bool in
        do {
            _ = try probeReadWithReport(value) { root in
                let state = try #require(root.scope.state)
                state.meter.checkpointObserver = { progress.checkpoint($0) }
                do { _ = try root["name"].requiredString() } catch is CancellationError {}
                return true
            }
            return false
        } catch is CancellationError { return true }
    }
    while !progress.ready.withLock({ $0 }) { await Task.yield() }
    task.cancel(); progress.resume.signal()
    #expect(try await task.value)
}

private func indexIdentity<I: ProbeIndex>(_ type: I.Type) throws {
    var meter = try JSONWorkMeter(limits: .offline, domain: .core)
    var index = I()
    let strings = ["", "0", "/", "~", "a.b", "\u{e9}", "e\u{301}"] + (0..<512).map { "prefix-\($0)" }
    for (position, text) in strings.enumerated() {
        try index.insert(ProbeKey(text, position: position, collision: true, meter: &meter), meter: &meter)
    }
    for (position, text) in strings.enumerated() {
        #expect(try index.find(ProbeKey(text, position: -1, collision: true, meter: &meter), meter: &meter) == position)
    }
    #expect(try index.find(ProbeKey("absent", position: -1, collision: true, meter: &meter), meter: &meter) == nil)
    #expect(throws: JSONFailure.self) {
        try index.insert(ProbeKey("e\u{301}", position: -1, collision: true, meter: &meter), meter: &meter)
    }
}
@Test func indexProbesConfirmExactIdentityDespiteSyntheticCollisions() throws {
    try indexIdentity(ProbeScalarIndex.self); try indexIdentity(ProbeLinearIndex.self)
    try indexIdentity(ProbeAVLIndex.self); try indexIdentity(ProbeHashIndex.self)
}

@Test func indexProbesEnforceGrowthWorkAndInnerCancellation() async throws {
    for budget: JSONResourceMetric in [.workUnits, .retainedBytes] {
        var limits = JSONLimits.balanced; limits[budget] = 1
        var meter = try JSONWorkMeter(limits: limits, domain: .core)
        var index = ProbeHashIndex()
        #expect(throws: JSONFailure.self) {
            try index.insert(ProbeKey("", position: 0, meter: &meter), meter: &meter)
        }
    }
    let progress = ProbeCancellationProgress()
    let task = Task.detached { () throws -> UInt64 in
        var meter = try JSONWorkMeter(limits: .offline, domain: .core)
        var index = ProbeAVLIndex()
        for position in 0..<512 {
            try index.insert(ProbeKey("key\(position)", position: position, meter: &meter), meter: &meter)
        }
        meter.checkpointObserver = { progress.checkpoint($0) }
        do {
            for position in 0..<10000 {
                _ = try index.find(ProbeKey("key\(position % 512)", position: -1, meter: &meter), meter: &meter)
            }
            return 0
        } catch is CancellationError { return meter.statistics()[.workUnits] }
    }
    while !progress.ready.withLock({ $0 }) { await Task.yield() }
    task.cancel(); progress.resume.signal()
    #expect(try await task.value > 0)
}

@Test func duplicateRecognitionPrecedesValueAndClosingSyntax() throws {
    // Second decoded key is complete, but neither its colon nor value has arrived.
    let input = Array(#"{"a":0,"\u0061""#.utf8)
    do {
        _ = try JSONParser().parse(input)
        Issue.record("Duplicate input unexpectedly parsed")
    } catch let failure as JSONFailure {
        #expect(failure.code == .duplicateKey)
        #expect(failure.location?.byteOffset == 7)
    }
}
