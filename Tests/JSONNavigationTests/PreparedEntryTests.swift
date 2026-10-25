// SPDX-License-Identifier: Apache-2.0
import Foundation
import Synchronization
import Testing
import JSON
import JSONNavigation

private enum PreparationMarker: Error { case original, replacement }
private struct PreparedProbe: JSONReadPreparation, JSONTraversalOwnedReducer {
    enum Mode { case noop, charged, text, caught, cancel, transferred, doubleTransfer }
    var mode = Mode.noop
    var text = "é"
    var prepared = false
    mutating func prepare(context: inout JSONReadPreparationContext) throws {
        prepared = true
        switch mode {
        case .charged: try context.work(17)
        case .text: try context.admitText(text)
        case .caught:
            do { try context.recordFailure(PreparationMarker.original) } catch { }
        case .cancel:
            withUnsafeCurrentTask { $0?.cancel() }
            do { try context.checkpoint() } catch { }
            throw PreparationMarker.replacement
        default: break
        }
    }
    mutating func observe(_ hit: JSONTraversalHit, value: JSON,
                          context: inout JSONTraversalContext) throws -> JSONTraversalAction {
        #expect(prepared)
        return .continue
    }
    mutating func finish(_ summary: JSONTraversalSummary,
                         context: inout JSONTraversalContext) throws -> JSONDocument? {
        if mode == .charged { try context.work(19) }
        if mode == .transferred || mode == .doubleTransfer {
            let source = try context.transferDocumentOwnership()
            if mode == .doubleTransfer {
                do { _ = try context.transferDocumentOwnership() } catch { }
            }
            return source
        }
        return nil
    }
}

@Test func navigationPreparedD0NoopMatchesOriginalEveryCounter() throws {
    let source = try JSONParser().parseDocument(Data(#"{"x":[1,null],"é":"e\u0301"}"#.utf8))
    let walk = JSONTraversal(document: source)
    let original = try walk.visit { _, _ in .continue }
    var reducer = PreparedProbe()
    let prepared = try walk.inspectPreparedOwned(reducer: &reducer)
    for metric in JSONResourceMetric.allCases { #expect(original.statistics[metric] == prepared.statistics[metric]) }
    #expect(original.statistics.peakLogicalRetainedBytes == prepared.statistics.peakLogicalRetainedBytes)
}

@Test func navigationPreparedD0CumulativeWorkAndSingleSourceAdmission() throws {
    let walk = JSONTraversal(document: .init(root: [0,1,2]))
    let original = try walk.visit { _, _ in .continue }
    var reducer = PreparedProbe(mode: .charged)
    let report = try walk.inspectPreparedOwned(reducer: &reducer)
    #expect(report.statistics[.nodes] == original.statistics[.nodes])
    #expect(report.statistics[.workUnits] == original.statistics[.workUnits] + 36)
    var limits = JSONLimits.balanced
    limits[.workUnits] = report.statistics[.workUnits]
    reducer = .init(mode: .charged)
    #expect(try JSONTraversal(document: walk.document, limits: limits).inspectPreparedOwned(reducer: &reducer).statistics[.workUnits] == limits[.workUnits])
    limits[.workUnits] -= 1; reducer = .init(mode: .charged)
    do { _ = try JSONTraversal(document: walk.document, limits: limits).inspectPreparedOwned(reducer: &reducer); Issue.record("Expected cumulative work refusal") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .workUnits) }
}

@Test func navigationPreparedD0ProfileTextRetainedAndCounted() throws {
    var reducer = PreparedProbe(mode: .text)
    let result = try JSONTraversal(document: .init(root: .null)).inspectPreparedOwned(reducer: &reducer)
    #expect(result.statistics[.aggregateTextBytes] == 2)
    #expect(result.statistics[.retainedBytes] == 2)
    #expect(result.statistics[.nodes] == 1)
    var limits = JSONLimits.balanced
    limits[.retainedBytes] = result.statistics.peakLogicalRetainedBytes
    reducer = .init(mode: .text)
    _ = try JSONTraversal(document: .init(root: .null), limits: limits).inspectPreparedOwned(reducer: &reducer)
    limits[.retainedBytes] -= 1; reducer = .init(mode: .text)
    do { _ = try JSONTraversal(document: .init(root: .null), limits: limits).inspectPreparedOwned(reducer: &reducer); Issue.record("Expected live retention refusal") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .retainedBytes) }
}

@Test func navigationPreparedD0InnerProfileTextCancellationPrecedesRoot() async throws {
    let text = String(repeating: "é", count: 1024)
    let task = Task {
        var limits = JSONLimits.balanced; limits[.nodes] = 0
        var walk = JSONTraversal(document: .init(root: .null), limits: limits)
        walk.checkpointObserver = { work in
            if work >= 1023 { withUnsafeCurrentTask { $0?.cancel() } }
        }
        var reducer = PreparedProbe(mode: .text, text: text)
        return try walk.inspectPreparedOwned(reducer: &reducer)
    }
    do { _ = try await task.value; Issue.record("Expected cancellation within profile text") }
    catch is CancellationError { }
}

@Test func navigationPreparedD0CaughtProfileFailurePrecedesAdmission() throws {
    var limits = JSONLimits.balanced; limits[.nodes] = 0
    var reducer = PreparedProbe(mode: .caught)
    do { _ = try JSONTraversal(document: .init(root: .null), limits: limits).inspectPreparedOwned(reducer: &reducer); Issue.record("Expected original preparation error") }
    catch PreparationMarker.original { }
}

@Test func navigationPreparedD0CancellationCannotBecomeReplacement() async throws {
    let task = Task {
        var reducer = PreparedProbe(mode: .cancel)
        return try JSONTraversal(document: .init(root: .null)).inspectPreparedOwned(reducer: &reducer)
    }
    do { _ = try await task.value; Issue.record("Expected original cancellation") }
    catch is CancellationError { }
}

@Test func navigationPreparedD0ForbiddenPreAdmissionAccessLatches() throws {
    for action in 0..<4 {
        let scope = try JSONReadScope(preparingWith: .balanced)
        defer { scope.invalidate() }
        let state = try #require(scope.state)
        do {
            switch action {
            case 0: _ = try scope.select([], state: state)
            case 1: _ = try scope.transferDocumentOwnership()
            case 2: _ = try scope.complete(0)
            default: _ = try scope.append(.key("x"), to: [], state: state)
            }
            Issue.record("Unadmitted scope must refuse")
        } catch let failure as JSONFailure { #expect(failure.code == .invalidOperation) }
        do { try scope.admitPrepared(.init(root: .null)); Issue.record("Invalid phase error must remain terminal") }
        catch let failure as JSONFailure { #expect(failure.code == .invalidOperation) }
    }
}

@Test func navigationPreparedD0OneShotAdmissionAndTransfer() throws {
    let scope = try JSONReadScope(preparingWith: .balanced)
    defer { scope.invalidate() }
    try scope.admitPrepared(.init(root: .null))
    do { try scope.admitPrepared(.init(root: .null)); Issue.record("Second admission must fail") }
    catch let failure as JSONFailure { #expect(failure.code == .invalidOperation) }
    var reducer = PreparedProbe(mode: .doubleTransfer)
    do { _ = try JSONTraversal(document: .init(root: .null)).inspectPreparedOwned(reducer: &reducer); Issue.record("Caught second transfer cannot publish") }
    catch let failure as JSONFailure { #expect(failure.code == .invalidOperation) }
}

@Test func navigationPreparedD0SourceTransferAndInvalidationAllExits() throws {
    let facts = Mutex<[(Bool,Bool)]>([])
    let source = try JSONParser().parseDocument(Data("[0,1,2]".utf8))
    var walk = JSONTraversal(document: source)
    walk.lifetimeObserver = { root, state in facts.withLock { $0.append((root,state)) } }
    var reducer = PreparedProbe(mode: .transferred)
    let report = try walk.inspectPreparedOwned(reducer: &reducer)
    #expect(report.result?.sourceBytes == source.sourceBytes)
    #expect(report.statistics[.retainedBytes] > 0)
    reducer = .init(mode: .caught)
    do { _ = try walk.inspectPreparedOwned(reducer: &reducer); Issue.record("Expected preparation error") }
    catch PreparationMarker.original { }
    var limits = JSONLimits.balanced; limits[.nodes] = 0
    walk = JSONTraversal(document: source, limits: limits)
    walk.lifetimeObserver = { root, state in facts.withLock { $0.append((root,state)) } }
    reducer = .init()
    do { _ = try walk.inspectPreparedOwned(reducer: &reducer); Issue.record("Expected admission error") }
    catch let failure as JSONFailure { #expect(failure.resource?.metric == .nodes) }
    let observed = facts.withLock { $0 }
    #expect(observed.count == 3 && observed.allSatisfy { $0.0 && $0.1 })
}

@Test func navigationPreparedD0IndependentConcurrentHealth() async throws {
    let source = JSONDocument(root: [0,1,2])
    try await withThrowingTaskGroup(of: UInt64.self) { group in
        for _ in 0..<16 {
            group.addTask {
                var reducer = PreparedProbe(mode: .charged)
                return try JSONTraversal(document: source).inspectPreparedOwned(reducer: &reducer).statistics[.workUnits]
            }
        }
        var counts: [UInt64] = []
        for try await count in group { counts.append(count) }
        #expect(counts.count == 16 && counts.allSatisfy { $0 == counts[0] })
    }
}
